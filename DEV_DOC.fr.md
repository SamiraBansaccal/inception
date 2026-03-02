# 👨‍💻 Developer Documentation - Technical Deep Dive

Cette documentation détaille la configuration technique de chaque conteneur et les choix d'implémentation pour le développement.
Si le site est innacessible, mettre le reseau :
- en bridge sur la vm
- en nat : verifier le port forwarding (nginx, ftp passif et ssh) de la vm et les /etc/hosts de la machine hote (add 127.0.0.1   login.42.fr)
---

## 🏗️ Architecture des Services

## 1. 🌐 NGINX (Serveur Web & Reverse Proxy)

* **Base** : Alpine Linux (via le Dockerfile `requirements/nginx`).
* **Rôle Principal** : Point d'entrée HTTPS unique (Port 443) de l'infrastructure web. Il chiffre le trafic entrant et le dispatche vers les bons conteneurs (WordPress, Adminer, Portainer, Site Statique) selon l'URL demandée.
* **Sécurité & SSL** : 
    * Restreint aux protocoles sécurisés **TLSv1.2** et **TLSv1.3** uniquement.
    * Les certificats `.crt` et `.key` sont générés à la volée via OpenSSL dans le script d'entrypoint.
    * Ces certificats sont stockés dans le volume `ssl_certificate` (`/etc/nginx/ssl`), ce qui permet de les **partager avec le service FTP** pour configurer le FTPS sans générer de doublons.

### 📝 Configuration du Routage (`nginx.conf`)
Le fichier de configuration définit un bloc `server` unique écoutant sur le port 443 et gère le routage interne :

1. **La route principale (`/`) -> WordPress**
    * Pointe vers le volume partagé `/var/www/html`.
    * NGINX ne lit pas le PHP. Il intercepte toutes les requêtes terminant par `.php` et les transfère au conteneur `wordpress` sur le port `9000` via le protocole **FastCGI**.
2. **La route `/static/` -> Site Statique (Bonus)**
    * Fonctionne en mode Reverse Proxy simple (`proxy_pass`). NGINX redirige le trafic vers le conteneur `static` qui écoute sur son propre port interne `8080`.
3. **La route `/adminer/` -> Interface DB (Bonus)**
    * Cherche l'index `adminer.php` dans `/var/www`.
    * Comme pour WordPress, le code PHP est envoyé au conteneur `adminer` sur son port `9000` via FastCGI.
4. **La route `/portainer/` -> GUI Docker (Bonus)**
    * Redirige vers le conteneur `portainer` (port `9000`).
    * **Spécificité technique** : NGINX intègre des headers spécifiques (`Upgrade $http_upgrade`, `Connection 'upgrade'`) pour supporter les WebSockets. C'est indispensable pour que la fonctionnalité de terminal/console intégrée à Portainer fonctionne à travers le proxy.

### 🐳 Intégration Docker Compose
* **Dépendance** : `depends_on: - wordpress` garantit que NGINX ne démarre que si WordPress est lancé, évitant les erreurs 502 (Bad Gateway) au démarrage.
* **Réseau** : Connecté au réseau interne `inception` pour communiquer avec les autres conteneurs par leurs noms de service (résolution DNS interne de Docker).
* **Volumes montés** :
    * `wordpress_data` : Pour lire les assets statiques (CSS/JS/Images) de WordPress directement sans réveiller PHP.
    * `ssl_certificate` : Pour le stockage des clés TLS.
    * `adminer_data` : Pour accéder au script PHP d'Adminer.
    * `portainer_data` : Monté dans le cas où Portainer stocke ses propres datas sur un dossier partagé.

### 🛠️ Commandes Utiles (NGINX)
* **Recharger la configuration à chaud (sans rebooter le conteneur)** : 
    ```bash
    docker exec -it nginx nginx -s reload
    ```
* **Vérifier la validité de la syntaxe du `nginx.conf`** :
    ```bash
    docker exec -it nginx nginx -t
    ```
* **Lister tous les processus actifs dans NGINX** :
    ```bash
    docker exec -it nginx ps aux | grep nginx
    ```

## 2. 🗄️ MariaDB (Gestionnaire de Base de Données)

* **Base** : Alpine Linux (via le Dockerfile `requirements/mariadb`).
* **Rôle** : Moteur de base de données SQL relationnelle pour WordPress et les services bonus.
* **Sécurité (Hardening)** : 
    * **Isolation réseau** : Le conteneur n'expose aucun port sur l'hôte. Il est accessible uniquement via le réseau interne `inception` sur le port **3306**.
    * **Gestion des Secrets** : Utilisation des **Docker Secrets**. Les mots de passe (`db_root_pass` et `db_pass`) ne sont jamais stockés dans les variables d'environnement (visibles via `docker inspect`), mais lus directement depuis `/run/secrets/` par le script d'initialisation.
    * **Privilèges** : L'utilisateur SQL est restreint à sa base spécifique (`${SQL_DB}.*`), limitant la portée en cas d'intrusion.

### 📜 Logique d'Initialisation (`Entrypoint`)
Le démarrage repose sur un script qui gère l'idempotence (ne pas écraser les données si elles existent déjà) :

1. **Installation du répertoire de données** : Si `/var/lib/mysql/mysql` n'existe pas, `mariadb-install-db` initialise la structure de base.
2. **Script SQL Temporaire** : Un fichier `/tmp/init.sql` est généré dynamiquement pour :
    * Créer la base de données.
    * Créer l'utilisateur avec des droits d'accès depuis n'importe quel hôte interne (`@'%'`).
    * Sécuriser le compte **root** avec un mot de passe fort récupéré depuis les secrets.
3. **Lancement du Daemon** : `mysqld` démarre en utilisant `--init-file=/tmp/init.sql`, garantissant que la configuration de sécurité est appliquée avant toute connexion client.



### 🐳 Intégration Docker Compose
* **Healthcheck** : Le conteneur utilise `mysqladmin ping` pour confirmer que le service est réellement prêt à répondre aux requêtes. Cela permet aux services dépendants (WordPress) d'attendre que la DB soit "Healthy" avant de tenter une connexion.
* **Persistance** : Le volume `mariadb_data` est monté sur `/var/lib/mysql`. Toutes les tables, index et données survivent au redémarrage ou à la suppression des conteneurs.
* **Secrets** : Injection des fichiers de secrets définis à la racine du projet vers le conteneur.

### 🛠️ Commandes Utiles (MariaDB)
* **Entrer dans la console MySQL depuis l'hôte** :
    ```bash
    docker exec -it mariadb mysql -u root -p"$(cat /path/to/secret/root_pass)"
    ```
* **Vérifier l'état de santé du service** :
    ```bash
    docker inspect --format='{{json .State.Health}}' mariadb
    ```
* **Vérifier la taille de la base de données sur le disque** :
    ```bash
    docker exec -it mariadb du -sh /var/lib/mysql
    ```

## 3. 📝 WordPress & PHP-FPM (Moteur Applicatif)

* **Base** : Alpine 3.18.
* **Rôle** : Interpréteur PHP (FastCGI) traitant la logique du site. Il fait le pont entre les requêtes de NGINX et les données de MariaDB/Redis.
* **Port** : 9000.

### ⚙️ Configuration Réseau & PHP
* **Écoute Réseau** : Le fichier `www.conf` est modifié via `sed` pour passer de `127.0.0.1:9000` à `9000` (équivalent à `0.0.0.0:9000`). 
    * *Pourquoi ?* Par défaut, PHP-FPM n'écoute que lui-même. Pour que NGINX (un autre conteneur) puisse lui envoyer des fichiers `.php`, PHP-FPM doit écouter sur l'interface réseau partagée du conteneur.
* **Résolution DNS** : L'hôte de la base de données est configuré sur `mariadb`. Dans le réseau Docker `inception`, permettant  de trouver MariaDB sans IP statique.

### 📜 Logique de l'Entrypoint (WP-CLI)
L'installation est automatisée via l'outil **WP-CLI** pour garantir une stack reproductible sans intervention manuelle :
1. **Création du `wp-config.php`** : Injection des variables d'environnement et des secrets (`/run/secrets/db_pass`).
2. **Setup Redis** : Configuration des constantes `WP_REDIS_HOST` et `WP_CACHE` pour lier le service de cache.
3. **Installation du Core** : Définit l'URL en `https`, le titre, et crée le compte **Administrateur** via les secrets.
4. **Utilisateur Author** : Création du second utilisateur requis avec des droits restreints (`author`).
5. **Finalisation Redis** : Installation physique du plugin `redis-cache` et activation de la liaison objet via `wp redis enable`.

### 📂 Gestion des Droits & Umask
* **Propriétaire** : `chown -R nobody:nobody`. Alpine utilise l'utilisateur `nobody` pour les processus web par sécurité (privilèges minimaux).
* **Le réglage `umask 0002`** : 
    * Le `umask` (User Mask) est un filtre qui retire des permissions lors de la création d'un fichier.
    * En informatique, la permission max est `777` pour un dossier et `666` pour un fichier.
    * Avec `0002`, on soustrait `2` au dernier bit (Others). 
    * **Résultat** : Les nouveaux dossiers sont en `775` et les fichiers en `664`. Cela permet au groupe (dont fait partie egalement le serveur FTP) d'avoir des droits de lecture/écriture coherents (pas de prob de permission entre ce qui a ete ecrit par le ftp_user et le wp_user), tout en limitant les droits des utilisateurs "étrangers" au système.

### 🐳 Intégration Docker Compose
* **Dépendance de santé** : Utilise `condition: service_healthy` sur MariaDB. WordPress attend que la base de données soit prête à recevoir des requêtes SQL avant de lancer son script de configuration.
* **Dépendance de readyness** sur `redis` pour s'assurer que le service de cache est disponible lors de l'activation du plugin.
* **Gestion des Secrets** : Monte 7 fichiers de secrets pour gérer l'intégralité des identifiants (Admin, User, DB) sans jamais les exposer dans l'historique du conteneur.
* **Persistance** : Le volume `wordpress_data` stocke tout le répertoire `/var/www/html`, permettant de conserver le code source, les thèmes, les plugins et les fichiers média uploadés.

### 🛠️ Commandes Utiles (WordPress)
* **Lister les utilisateurs enregistrés** :
    ```bash
    docker exec -it wordpress wp user list --allow-root
    ```
* **Vérifier l'état de la connexion Redis** : 
    ```bash
    docker exec -it wordpress wp redis status --allow-root
    ```
* **Vider le cache Redis depuis WordPress** :
    ```bash
    docker exec -it wordpress wp redis flush --allow-root
    ```

## 4. ⚡ Redis (Object Cache)

* **Base** : Alpine 3.18.
* **Rôle** : Système de stockage de données clé-valeur en mémoire vive (RAM). Il sert de cache d'objets pour WordPress.
* **Port** : 6379.

### ⚙️ Configuration & Fonctionnement
* **Optimisation des performances** : Au lieu de solliciter MariaDB (lecture disque) à chaque chargement de page, WordPress stocke les résultats des requêtes SQL fréquentes dans Redis (lecture RAM). Cela réduit drastiquement le temps de réponse du site.
* **Mode Protégé (`--protected-mode no`)** : 
    * Par défaut, Redis refuse les connexions qui ne viennent pas de `localhost`.
    * Le réglage `no` permet d'accepter les requêtes provenant du réseau interne `inception`. La sécurité est maintenue car le port 6379 n'est pas exposé sur l'hôte.

### 📜 Liaison avec WordPress
L'intégration est pilotée par le script d'entrypoint de WordPress via trois étapes :
1. **Configuration** : `wp config set WP_REDIS_HOST redis` définit le nom du service comme cible.
2. **Installation** : Le plugin `redis-cache` est injecté dans les fichiers de WordPress.
3. **Activation** : La commande `wp redis enable` crée un fichier `object-cache.php` dans le répertoire `wp-content`, ce qui détourne les requêtes SQL vers Redis.

### 🐳 Intégration Docker Compose
* **Réseau** : Isolé dans le réseau `inception`. Seul le conteneur WordPress a besoin de communiquer avec lui.
* **Persistance** : Contrairement à MariaDB, Redis est ici utilisé comme cache volatil. Si le conteneur redémarre, le cache est vidé et se reconstruit au fur et à mesure des visites, garantissant des données toujours fraîches.

### 🛠️ Commandes Utiles (Redis)
* **Monitorer les requêtes en temps réel** (pour prouver au correcteur que le cache fonctionne) :
    ```bash
    docker exec -it redis redis-cli monitor
    ```
* **Vérifier les statistiques d'utilisation de la mémoire** :
    ```bash
    docker exec -it redis redis-cli info memory
    ```
* **Vider manuellement le cache** :
    ```bash
    docker exec -it redis redis-cli flushall
    ```
Pour Redis, tu ne trouveras pas de "fichier texte" avec les clés et valeurs à l'intérieur. Redis est une base de données In-Memory : tout est stocké dans la RAM pour aller vite. Si tu veux voir ce qu'il y a dedans, tu dois utiliser la commande docker exec -it redis redis-cli KEYS "*"

## 5. 📂 FTP Server (vsftpd)

* **Base** : Alpine 3.18.
* **Service** : `vsftpd` (Very Secure FTP Daemon).
* **Rôle** : Permet le transfert de fichiers sécurisé (FTPS) directement dans le volume WordPress (`/var/www/html`).
* **Ports** : 21 (Commande) + 21100-21110 (Données en mode passif).

### ⚙️ Configuration & Sécurité (FTPS)
* **Chiffrement SSL/TLS** : Contrairement au FTP classique qui transmet les mots de passe en clair, cette configuration force l'utilisation du TLS (`ssl_enable=YES`).
* **Partage de Certificats** : Le conteneur monte le volume `ssl_certificate`. Il utilise exactement les mêmes certificats que NGINX (`nginx.crt`/`nginx.key`), assurant une cohérence de sécurité sur toute l'infrastructure.
* **Isolation (Chroot)** : `chroot_local_user=YES` enferme l'utilisateur dans son répertoire personnel. Il est techniquement impossible pour l'utilisateur FTP de remonter dans l'arborescence du conteneur pour voir d'autres fichiers système.

### 🌐 Mode Passif & Docker NAT
Le FTP traditionnel (Mode Actif) échoue souvent derrière un firewall ou un réseau Docker NAT. 
* **Solution** : `pasv_enable=YES`. Le serveur ouvre une plage de ports spécifique (`21100-21110`) pour le transfert des données. 
* **Liaison Compose** : Ces ports sont explicitement ouverts dans le `docker-compose.yml` pour permettre la communication entre le client FTP externe et le conteneur.

### 📜 Logique de l'Entrypoint
Le script prépare l'environnement avant de lancer le daemon :
1. **Création de l'utilisateur** : Récupère le nom d'utilisateur (`wp_admin`) et le mot de passe depuis les **Docker Secrets**. on suppose que celui qui modifie via ftp, ayant les memes pouvoir qu un admin wp, devrait donc avoir la meme identite et eviter de multiplier les utilisateurs, on reutilise le meme login, mais ces login ne sont pas lies et pouraient etre differents.
2. **Assignation au groupe** : L'utilisateur est ajouté au groupe `nobody`. C'est le point de synchronisation avec WordPress : les deux services partagent le même groupe pour éviter les conflits de permission.
3. **Réglage du Umask** : Défini à `0002`.
    * **Fichiers** : Créés en `664` (Lecture/Écriture pour le proprio et le groupe).
    * **Dossiers** : Créés en `775`.
    * *Utilité* : Cela garantit que si tu uploades un fichier via FTP, WordPress (qui est aussi dans le groupe `nobody`) pourra le modifier ou le supprimer sans erreur "Permission Denied".

### 🐳 Intégration Docker Compose
* **Volumes** : 
    * `wordpress_data` : Monté sur `/var/www/html` pour accéder aux fichiers du site.
    * `ssl_certificate` : Pour récupérer les clés de chiffrement générées par NGINX.
* **Compatibilité Alpine** : `seccomp_sandbox=NO` est ajouté dans le `.conf`. C'est indispensable car vsftpd utilise des appels système qui sont parfois bloqués par le moteur Docker sur Alpine, sinon le daemon crash au premier login.

### 🛠️ Commandes Utiles
* **Vérifier les logs de connexion et de transfert** :
    ```bash
    docker exec -it ftp tail -f /var/log/vsftpd.log
    ```
* **Tester la connexion locale (si lftp est installé sur l'hôte)** :
    ```bash
    lftp -u user,password -e "set ftp:ssl-force true; set ssl:verify-certificate no;" localhost
    ```
## 6. 📂 Adminer (Gestion de Base de Données)

* **Base** : Alpine 3.18.
* **Rôle** : Interface graphique (GUI) légère pour administrer MariaDB.
* **Port** : 9000 (FastCGI).

### ⚙️ Configuration & Authentification
* **Connexion Manuelle** : Contrairement à WordPress qui est pré-configuré via `wp-config.php`, Adminer est une interface neutre. 
    * À l'ouverture de la page, l'utilisateur doit renseigner manuellement : **Serveur** (`mariadb`), **Utilisateur**, **Mot de passe** et le **Nom de la base**. 
    * C'est Adminer qui utilise ensuite l'extension `php81-mysqli` pour établir la connexion au port 3306 du conteneur MariaDB.
* **Sessions PHP** : L'installation de `php81-session` est critique pour maintenir l'état de connexion de l'utilisateur entre deux clics dans l'interface.

### 📜 Logique de l'Entrypoint
Le script gère la présence du fichier `adminer.php` dans le volume partagé :
2. **Redémarrage** : Si le conteneur redémarre mais que le volume existe déjà (les données persistent), le script voit que le fichier est présent et ne fait rien, préservant ainsi les fichiers existants.

### 🐳 Intégration Docker Compose
* **Volume Partagé** : Utilise `adminer_data` monté sur `/var/www/adminer`. Ce volume est également monté dans le conteneur NGINX pour que ce dernier puisse "voir" le fichier PHP à servir.
* **Réseau** : Isolé dans le réseau `inception`. Adminer utilise le DNS interne de Docker pour se connecter à `mariadb`.

### 🛠️ Commandes Utiles
* **Vérifier que le fichier adminer.php est bien dans le volume** :
    ```bash
    docker exec -it adminer ls -l /var/www/adminer
    ```
* **Vérifier les logs de connexion à la DB via Adminer** :
    ```bash
    docker logs adminer
    ```

## 7. 🐳 Portainer (Gestionnaire d'Infrastructure Docker)

* **Base** : Alpine 3.18.
* **Rôle** : Interface graphique (GUI) permettant de monitorer et de gérer l'ensemble des conteneurs, images, réseaux et volumes du projet Inception.
* **Port interne** : 9000 (HTTP).

### ⚙️ Fonctionnement & Privilèges
* **Docker Socket (`/var/run/docker.sock`)** : C'est la pièce maîtresse du service. En montant le socket de l'hôte dans le conteneur, Portainer peut "sortir" de son isolation pour envoyer des instructions directement au moteur Docker du système Debian. Cela lui permet de lister les autres conteneurs et d'afficher leurs logs ou stats en temps réel.
* **Authentification automatique** : L'utilisation du flag `--admin-password-file` dans l'entrypoint permet de définir le mot de passe administrateur dès le premier lancement via un **Docker Secret**. Cela évite d'avoir à configurer manuellement le compte admin lors de la première connexion web.

### 📜 Logique de l'Entrypoint
Le script lance l'exécutable Portainer avec les paramètres spécifiques à l'environnement Inception :
2. **`--data /data`** : Définit l'emplacement de la base de données interne de Portainer (utilisateurs, réglages, historique) sur un volume persistant.
3. **`-H unix:///var/run/docker.sock`** : Connecte Portainer à l'API Docker locale via le socket unix.
4. **`--admin-password-file`** : Récupère le secret stocké dans `/run/secrets/portainer_pass` pour sécuriser l'instance.

### 🐳 Intégration Docker Compose
* **Volumes** : 
    * `/var/run/docker.sock:/var/run/docker.sock` : Montage critique pour le contrôle de l'hôte.
    * `portainer_data` : Assure la persistance de la configuration de Portainer.
* **Reverse Proxy (NGINX)** : servi par NGINX sur `https://sabansac.42.fr/portainer/`. NGINX gère l'Upgrade des WebSockets pour permettre l'utilisation du terminal des container dans l'interface Portainer.

### 🛠️ Commandes Utiles (Portainer)
* **Vérifier que Portainer communique bien avec le Socket** :
    ```bash
    docker exec -it portainer ./portainer --version
    ```
* **Vérifier la persistance des données** :
    ```bash
    docker exec -it portainer ls -l /data
    ```
* **Voir les logs de l'interface en cas de crash** :
    ```bash
    docker logs portainer
    ```

## 8. 📄 Static Site (Site de Présentation)

* **Base** : Alpine 3.18 / Nginx.
* **Rôle** : Hébergeur de contenu statique (HTML/CSS) servi via un serveur web dédié.
* **Port interne** : 8080.

### ⚙️ Architecture Nginx-to-Nginx
Ce service utilise sa propre instance Nginx indépendante du proxy principal :
1. **Écoute** : Le fichier `nginx.conf` interne est configuré pour écouter sur le port **8080** uniquement.
2. **Reverse Proxy** : Lorsqu'un utilisateur demande `https://sabansac.42.fr/static/`, le Nginx principal (Port 443) relaie la requête au Nginx de ce conteneur (Port 8080) via l'instruction `proxy_pass`.
3. **Isolation** : Le contenu du site (`index.html`, `styles.css`) est physiquement stocké dans `/var/www/static` à l'intérieur de ce conteneur, totalement séparé des volumes de WordPress ou Adminer.

### 📜 Logique de l'Entrypoint
Le script automatise la configuration finale lors du lancement du conteneur :
* **Dynamic Server Name** : Utilise `sed` pour injecter la variable d'environnement `${DOMAIN_NAME}` directement dans la configuration Nginx du site statique. Cela permet de garder le conteneur portable quel que soit le domaine utilisé.
* **Foreground Execution** : Lance Nginx avec l'option `daemon off;` pour s'assurer que le processus reste au premier plan, ce qui est indispensable pour que Docker ne considère pas le conteneur comme arrêté.

### 🐳 Intégration Docker Compose
* **Réseau** : Connecté au réseau `inception`. Comme il n'a pas de bloc `ports`, il est invisible depuis l'extérieur (Internet) ; seul le conteneur Nginx principal peut l'atteindre.
* **Dépendance** : Bien qu'il soit autonome, le `depends_on: - nginx` assure une cohérence dans l'ordre de démarrage de la stack de bonus.

### 🛠️ Commandes Utiles (Static)
* **Vérifier que le Nginx interne sert bien les fichiers** :
    ```bash
    docker exec -it static curl localhost:8080
    ```
* **Vérifier la configuration Nginx générée par l'entrypoint** :
    ```bash
    docker exec -it static cat /etc/nginx/nginx.conf
    ```
* **Vérifier la présence des assets statiques** :
    ```bash
    docker exec -it static ls -l /var/www/static
    ```
---
## 🛠️ Maintenance & Développement

### ⚠️ Criticité des Données (Analyse des Volumes)

Avant d'exécuter un `make fclean`, il est crucial de comprendre l'impact de la suppression sur chaque service. Tous les volumes ne sont pas égaux :

| Service | Importance | Conséquence d'une suppression |
| :--- | :--- | :--- |
| **MariaDB** | 🔴 **Critique** | **Perte totale** de tout le contenu (articles, pages, comptes utilisateurs, configuration WordPress). Inrécupérable sans backup SQL. |
| **WordPress** | 🟠 **Élevée** | Supprime les fichiers média (images uploadées) et les plugins installés manuellement. La structure du site reste en DB, mais les fichiers seront absents. |
| **Portainer** | 🟡 **Moyenne** | Réinitialise l'interface Portainer et son historique mais cela n'impacte pas vos autres conteneurs. |
| **Redis** | 🟢 **Nulle** | Aucune gravité. Redis est un cache. Les données seront reconstruites automatiquement par WordPress lors des prochaines visites. |
| **Static / Adminer** | ⚪ **Aucune** | Ces services sont "stateless" (sans état). Leurs volumes (si présents) ne contiennent que des fichiers temporaires ou de configuration fixe. |

### 💡 Bonnes pratiques en Production
* **Avant un fclean** : Effectuez toujours un export de la base de données via Adminer ou un `mysqldump` depuis le conteneur MariaDB.
* **Modification de code** : Si vous changez uniquement le CSS du site statique ou un script PHP, préférez un `make up-<service>` plutôt qu'un `fclean`. Le volume préservera vos données tout en mettant à jour le code exécuté.

### 🧹 Gestion des Volumes & Réinitialisation
Si vous modifiez la structure de la base de données, l'installation initiale de WordPress, ou si l'infrastructure est corrompue, un simple redémarrage ne suffira pas car les données persistent dans les volumes.
1. Exécutez `make fclean` : Cette commande est radicale. Elle détruit les conteneurs, purge le système Docker (`prune -af`), et **supprime physiquement les dossiers locaux** de données (`/home/$(USER)/data`).
2. Relancez `make re` pour forcer une réinitialisation propre et repasser dans les scripts d'Entrypoint.

### 🔐 Variables d'Environnement et Secrets
La sécurité du projet repose sur la non-exposition des identifiants. Toutes les données sensibles sont centralisées :
* Les variables globales dans `srcs/.env`.
* Les mots de passe dans le dossier `./secrets/` à la racine.

> 💡 **Génération Automatique** : Lors du premier `make`, le Makefile génère automatiquement ces fichiers avec des **valeurs par défaut** (ex: `db_pass_val`) pour tester l'infrastructure rapidement. 
> ⚠️ **En production/évaluation** : Vous devez modifier le contenu de ces fichiers pour définir vos propres mots de passe robustes. Ces fichiers et dossiers sont inclus dans le `.gitignore` pour garantir qu'ils ne soient **jamais** poussés sur le dépôt public.

### 🔍 Debugging Rapide (via Makefile)
Le projet intègre des commandes Makefile dynamiques pour simplifier le débugging sans avoir à taper les commandes Docker complètes :

* **Vérifier l'état de l'infrastructure** : 
    ```bash
    make status
    ```
* **Voir les logs en direct d'un service précis** (ex: nginx, wordpress, ftp) :
    ```bash
    make log-<nom_du_service>
    # Exemple : make log-mariadb
    ```
* **Ouvrir un terminal (shell) dans un conteneur actif** :
    ```bash
    make shell-<nom_du_service>
    # Exemple : make shell-wordpress
    ```
* **Relancer/Reconstruire un seul service après une modification** :
    ```bash
    make up-<nom_du_service>
    ```