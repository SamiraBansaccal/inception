

# 🏗️ Inception - Docker Infrastructure Project

# I. Description : General 

Le projet **Inception** a pour objectif de concevoir et déployer une infrastructure web complète en utilisant exclusivement Docker comme technologie de conteneurisation. Ce projet met en œuvre une stack classique d’infrastructure web moderne et vise à introduire les principes fondamentaux des architectures en microservices. 

Contrairement aux architectures monolithiques traditionnelles, où tous les composants d’une application cohabitent dans un seul environnement, l’approche microservices consiste à séparer chaque service dans un environnement isolé, indépendant et spécialisé. Cette séparation permet :

* **Une meilleure isolation des responsabilités.**
* **Une maintenance simplifiée.**
* **Une évolutivité plus fine.**
* **Une sécurité renforcée.**
* **Une meilleure compréhension des couches d’une infrastructure web.**

### Sommaire :

* **I. Description: general**
* **II Architecture Overview and Docker key-concepts**
* **III. Requirements :Stack, Composants et interactions**
* **IV Instructions**
* **V Resources**
* **VI AI Usage Declaration**

# II. 🐳 Docker & Infrastructure Concepts

Ce projet utilise Docker pour conteneuriser une infrastructure de services interconnectés. Cette section détaille le fonctionnement interne de Docker ainsi que les choix architecturaux de l'infrastructure Inception.

## A. Docker : Une abstraction du Noyau Linux

Docker est un outil de gestion de conteneurs. Contrairement à la gestion manuelle (via `chroot` ou `cgroups`), Docker automatise le cycle de vie des environnements isolés. **Docker n'invente rien.** Il ne crée pas de "machine" ; il automatise des fonctionnalités déjà présentes nativement dans le **Noyau Linux (Kernel)**.

### Le cycle de vie d'une application Docker :
1. **Dockerfile (La Recette)** : Un fichier texte contenant les instructions séquentielles pour assembler l'environnement (`FROM`, `RUN`, `COPY`).
2. **Image (Le Moule)** : Le résultat immuable (*read-only*) de la construction du Dockerfile. Elle est composée de couches (*layers*) superposées.
3. **Conteneur (L'Instance)** : Une instance en cours d'exécution d'une image. Docker ajoute une couche accessible en écriture au-dessus de l'image immuable pour permettre les modifications temporaires.

### 💡 Concept : Virtualisation vs Conteneurisation (L'illusion d’isolation)

Une Machine Virtuelle utilise un Hyperviseur pour simuler du hardware et faire tourner un OS complet, tandis que Docker est une isolation au niveau du système d'exploitation. Docker utilise trois piliers du Kernel pour isoler les processus :

* **Namespaces** : Isole la vue du système (chaque conteneur croit avoir ses propres interfaces réseaux, ses propres processus `PID 1` et son propre système de fichiers).
* **Control Groups (Cgroups)** : Gère l'allocation des ressources (CPU, RAM, I/O).
* **chroot & rlimit** : Docker utilise des versions évoluées de `chroot` (comme `pivot_root`) pour changer la racine du système de fichiers, et `rlimit` pour empêcher un conteneur de saturer les ressources de l'hôte.

| Caractéristique | Machine Virtuelle (VM) | Docker (Conteneur) |
| :--- | :--- | :--- |
| **Architecture** | Virtualisation du matériel (Hardware). Chaque VM possède son propre OS complet (Guest OS). | Virtualisation du système d'exploitation. Les conteneurs partagent le Kernel de l'hôte (Linux). |
| **Isolation** | Isolation forte via un Hyperviseur. | Isolation des processus via les Namespaces (vue système) et Cgroups (ressources). |
| **Performance** | Lourde (Go), lente au démarrage (boot OS). | Légère (Mo), démarrage instantané (simple processus). |

> **Implication dans le projet :** L'infrastructure Inception est extrêmement légère. Chaque service (Nginx, MariaDB, etc.) est un simple processus isolé tournant directement sur le Kernel de la machine hôte (VM de l'école 42), sans la surcharge d'un OS invité.

---

## B. Docker Compose : L'Orchestration des Micro-services

### ⚙️ Concept : Un service = Un conteneur
Le principe fondamental de Docker est qu'un conteneur ne doit exécuter qu'une seule tâche principale. Car on ne peut débugger qu'un seul process qui tourne en root dans le container. **Docker Compose** permet de lier ces unités isolées pour former une infrastructure cohérente via un fichier `docker-compose.yml`. 

Docker Compose permet de :
* Définir l'infrastructure complète dans un seul fichier YAML (`docker-compose.yml`).
* Gérer les dépendances de démarrage (ex: WordPress attend que MariaDB soit prêt via `healthcheck` et `depends_on`).
* Créer un réseau dédié pour l'isolation des services.

> **Implication dans le projet :** Plutôt que d'avoir un serveur "tout-en-un", l'architecture Inception sépare les responsabilités.

---

## C. Réseaux (Networking) : Isolation et Communication

### 🌐 Concept : Bridge Network vs DNS Interne

* **Réseau Hôte (NAT)** : 🔌 Redirection de ports (Hôte -> VM -> Docker)
Pour accéder aux services depuis la machine hôte, une couche spécifique de redirection de ports est configurée :

| Service | Port Externe (Hôte) | Port Interne (Conteneur) | Utilité |
| :--- | :--- | :--- | :--- |
| **SSH** | `4242` | `22` | Accès distant à la VM (VS Code / Terminal) |
| **NGINX** | `443` | `443` | Accès Web (HTTPS) pour tous les services web |
| **FTP** | `21` | `21` | Commandes de contrôle FTP (FTPS) |
| **Données FTP** | `21100-21110` | `21100-21110` | Transfert de fichiers (Mode Passif) |

En raison des restrictions réseau sur les ordinateurs de l'école, nous ne pouvions pas choisir le mode bridge pour l'hôte ; mais sur un projet privé, si l'hôte est en bridge, le conteneur partage l'adresse IP et l'espace réseau de la machine hôte. Aucune isolation réseau.

* **Docker Network (Bridge)** : *Utilisé dans ce projet.* Crée un réseau virtuel privé.
    * **Isolation** : Les conteneurs ne sont pas accessibles de l'extérieur sauf si des ports sont explicitement publiés.
    * **DNS Interne** : Docker résout automatiquement les noms de services. Le service `wordpress` peut communiquer avec la base de données simplement en utilisant l'hôte `mariadb` (pas d'IP à gérer). Si un service est nommé `mariadb`, tout autre conteneur sur le même réseau peut le contacter via le nom `mariadb` au lieu d'une adresse IP instable.

**Implication dans le projet :**
* **Ports Ouverts (Exposed)** : Aucun port de MariaDB ou WordPress n'est exposé sur la machine hôte. Ils ne sont accessibles que par Nginx à l'intérieur du réseau Docker.
* **Ports Publiés (Published)** : Seuls le port **443** (Nginx) et le port **21** (FTP) sont ouverts sur l'IP de la machine hôte pour permettre l'accès utilisateur.
* **Lien Inter-services** : WordPress communique avec MariaDB via l'hôte `mariadb:3306`. Cette communication est totalement invisible pour quelqu'un tentant d'attaquer la machine hôte depuis l'extérieur.

### 📊 Résumé des flux réseaux (Ports)

| Service | Port Interne (Docker) | Port Externe (Hôte) | Pourquoi ? |
| :--- | :--- | :--- | :--- |
| **Nginx** | 443 | **443** | Entrée sécurisée standard. |
| **WordPress** | 9000 | Aucun | Protégé par le proxy Nginx. |
| **MariaDB** | 3306 | Aucun | Sécurité maximale des données. |
| **FTP** | 21 + 21100-21110 | **21 + 21100-21110** | Accès direct pour transfert de fichiers. |
| **Adminer** | 8080 | Aucun | Accessible via Nginx (`/adminer`). |

---

## D. Stockage : Volumes vs Bind Mounts

### 💾 Concept : Persistance de la donnée (Stateful vs Stateless)
Un conteneur est "stateless" : Les conteneurs étant éphémères, les données sont perdues à leur suppression. Deux solutions existent :

* **Volumes Docker (Gérés)** : Docker gère l'emplacement sur le disque (`/var/lib/docker/volumes`). C'est la méthode la plus sûre et performante.
* **Bind Mounts** : Un lien direct vers un dossier spécifique de l'hôte (ex: `/home/user/data`). Moins portable et plus risqué au niveau des permissions. Le dossier actuel de l'hôte est "projeté" dans le conteneur. 
    * *Avantage :* Si tu modifies le code sur ton PC, le conteneur le voit instantanément (super pour le dev).

**Implication dans le projet (Choix des volumes) :** Nous utilisons des Volumes nommés uniquement pour les données essentielles :
* **`db-data`** : Pour MariaDB. Indispensable pour ne pas perdre les utilisateurs/articles au redémarrage.
* **`wp-data`** : Partagé entre **WordPress** (écriture du code), **Nginx** (lecture des fichiers statiques) et **FTP** (upload distant). Ce partage de volume est ce qui permet à trois conteneurs distincts de travailler sur les mêmes fichiers simultanément.
* **`certs-data`** : Partagé entre **Nginx** et **FTP**. Cela évite de générer deux jeux de certificats différents et garantit une identité SSL unique pour toute l'infrastructure.

> **Pourquoi pas les autres ?** Les services comme Adminer ou le Site Statique ne génèrent pas de données utilisateur. S'ils redémarrent, repartir à zéro garantit une infrastructure propre ("Clean State").

---

## E. Sécurité : Gestion des Secrets

### 🔐 Concept : Environnement vs Secrets
La gestion des données sensibles (mots de passe, clés API) est critique.
* **Environment Variables (ENV)** : Stockées dans la configuration du conteneur et visibles via `docker inspect` et dans les processus système. Utile pour la configuration non-sensible (nom de DB, user).
* **Docker Secrets** : Méthode sécurisée. Les données sont chiffrées au repos et montées temporairement dans le conteneur (généralement dans `/run/secrets/`). Elles ne sont jamais exposées en clair dans les logs ou l'inspection du conteneur.

**Implication dans le projet :** Les mots de passe `MYSQL_ROOT_PASSWORD` et les identifiants de base de données sont injectés via des fichiers de secrets. Ils sont stockés dans le dossier `/run/secrets/` à l'intérieur des conteneurs, les rendant inaccessibles aux scripts malveillants qui ne feraient que scanner l'environnement système.

# III. Requirements : Composants et interactions

### a. NGINX – Reverse Proxy et terminaison TLS

NGINX est utilisé comme point d’entrée unique de l’infrastructure.  
Son rôle principal ici est celui de **reverse proxy sécurisé**.  
Il reçoit toutes les requêtes HTTPS sur le port 443, puis les redirige vers les différents services internes selon le chemin demandé.

#### 🔁 Interaction avec les autres services

NGINX est le **seul conteneur exposé publiquement sur le port 443**.

Flux réel d’une requête :

1. Le navigateur établit une connexion TLS vers NGINX.
2. NGINX effectue la **terminaison TLS** (déchiffrement).
3. Selon la route demandée :
   - `/` → transmis à `wordpress:9000` via FastCGI
   - `/adminer` → transmis au container Adminer
   - `/portainer` → transmis au container Portainer
   - `/static` → transmis au container site statique
4. La réponse est renvoyée au client après éventuelle transformation PHP.

NGINX ne connaît pas les adresses IP des containers.  
Il utilise le **DNS interne Docker**, ce qui permet de cibler un service par son nom (`wordpress`, `adminer`, etc.).

Cela repose sur le **Docker Bridge Network**, qui fournit :
- Isolation réseau
- Résolution DNS automatique
- Communication inter-container sécurisée

#### Capacités générales de NGINX

NGINX est un outil extrêmement polyvalent. Il peut :

- Servir des fichiers statiques
- Agir comme load balancer
- Gérer du caching HTTP
- Faire du rate limiting
- Terminer des connexions SSL/TLS
- Servir d’API gateway

Dans ce projet, son rôle est volontairement limité à :

- Terminaison TLS
- Reverse proxy
- Routage interne vers WordPress, Adminer, Portainer et le site statique

#### SSL / TLS – Sécurisation des communications

Les communications sont sécurisées via **TLS 1.2 et TLS 1.3**.

Historiquement, le protocole utilisé pour sécuriser les communications web s’appelait **SSL (Secure Sockets Layer)**.  
SSL a évolué vers **TLS (Transport Layer Security)**, qui en est la version modernisée et sécurisée.

Aujourd’hui, on parle toujours de “certificat SSL”, mais en réalité ce sont des certificats TLS.

Les anciennes versions SSL (v2, v3) sont désormais considérées comme vulnérables.  
TLS 1.2 et 1.3 sont actuellement les versions sécurisées recommandées.

Le projet utilise **OpenSSL**, une implémentation open source largement utilisée pour générer des certificats auto-signés.

Il existe également :

- Des autorités de certification commerciales (DigiCert, GlobalSign, etc.)
- Let’s Encrypt (gratuit)
- Des implémentations propriétaires dans certains environnements d’entreprise

Dans ce projet :

- Un certificat auto-signé est généré dynamiquement au démarrage du container NGINX.
- Le serveur FTP réutilise ces mêmes certificats via un volume partagé.
- Cela garantit une **cohérence d’identité TLS** sur toute l’infrastructure.

---

### b. WordPress avec PHP-FPM

WordPress est un système de gestion de contenu (CMS) écrit en PHP.  
WordPress représente une part significative des sites web mondiaux, ce qui en fait une technologie incontournable malgré sa réputation parfois critiquée d’“usine à gaz”.

Il ne s’agit pas simplement d’un framework, mais d’un écosystème complet permettant :

- La gestion de thèmes
- L’installation de plugins
- La gestion d’utilisateurs
- La création dynamique de contenu

#### 🔁 Interaction avec les autres services

WordPress est placé entre :

- **NGINX** (qui lui transmet les requêtes)
- **MariaDB** (qui stocke les données)
- **Redis** (si activé, pour le cache)
- **FTP** (qui modifie ses fichiers via volume partagé)

Flux technique :

1. NGINX transmet une requête via FastCGI.
2. PHP-FPM interprète le script PHP.
3. Si nécessaire :
   - Requête SQL vers `mariadb:3306`
   - Lecture/écriture dans Redis
4. Génération du HTML.
5. Retour vers NGINX.
6. Envoi au navigateur.

#### PHP-FPM

WordPress fonctionne en PHP, ce qui signifie qu’il nécessite un interpréteur PHP pour transformer le code PHP en HTML exploitable par le navigateur.

Ce rôle est assuré par **PHP-FPM (FastCGI Process Manager)**.

PHP-FPM est un gestionnaire de processus PHP.  
Il ne s’agit pas d’un serveur web, mais d’un interpréteur spécialisé dans l’exécution PHP.

- Écoute sur un port FastCGI
- Reçoit les requêtes de NGINX
- Exécute le code PHP
- Retourne du HTML

Il est **non exposé publiquement**.  
Seul NGINX peut communiquer avec lui via le réseau Docker interne.

---

### c. MariaDB – Serveur de base de données

MariaDB est un serveur de base de données relationnelle, fork open source de MySQL.

Il permet :

- La création de bases de données
- La gestion de tables
- L’exécution de requêtes SQL
- La persistance des données

WordPress utilise MariaDB pour stocker :

- Les articles
- Les utilisateurs
- Les configurations
- Les métadonnées

Le langage utilisé pour interagir avec MariaDB est **SQL (Structured Query Language)**, standard largement utilisé dans les bases relationnelles.

#### 🔁 Interaction réseau

- WordPress communique avec MariaDB via `mariadb:3306`
- MariaDB n’est **pas exposé à l’extérieur**
- L’accès est limité au réseau Docker interne
- Les identifiants sont injectés via Docker Secrets

Cela signifie :

- Impossible d’accéder à la base depuis l’extérieur sans passer par un container autorisé
- Réduction de la surface d’attaque

---

# C. BONUS

### a. Redis – Service de cache

Redis est un système de cache en mémoire.  
Son objectif est d’améliorer les performances en stockant temporairement des données fréquemment utilisées, afin d’éviter des requêtes répétées vers la base de données.

Redis fonctionne comme une base clé-valeur en mémoire.

Dans ce projet, il est utilisé pour optimiser les performances de WordPress.

#### 🔁 Interaction

- WordPress interroge Redis avant MariaDB
- Si donnée trouvée → réponse immédiate
- Sinon → requête SQL → stockage en cache Redis

Cela réduit :

- La charge CPU de MariaDB
- Le nombre de requêtes SQL
- Le temps de réponse global

Redis n’est pas exposé publiquement.

---

### b. Serveur FTP sécurisé

Un serveur FTP est mis en place afin de permettre l’accès distant aux fichiers WordPress.

Il permet :

- La consultation des fichiers
- Leur modification
- Leur transfert

Le serveur FTP utilise TLS pour sécuriser les échanges (FTPS).

TLS n'était pas obligatoire, mais les communications FTP classiques sont en clair.  
Après avoir sécurisé NGINX, la base de données et l’administration WordPress, laisser FTP non chiffré aurait créé une incohérence sécuritaire.

#### 🔁 Interaction

- Partage le même volume que WordPress (`wp-data`)
- Partage les certificats TLS avec NGINX (`certs-data`)
- Utilise les mêmes identifiants que l’administrateur WordPress
- Appartient au même groupe système (`nobody`) pour éviter les conflits de permissions

Cela garantit :

- Cohérence des droits
- Absence de conflits sur les fichiers
- Cohérence d’identité TLS

---

### c. Adminer – Administration de la base de données

Adminer est une interface web légère permettant d’administrer MariaDB depuis un navigateur.

Adminer ne contient pas de base de données en soi.  
Il agit comme **client web pour MariaDB**.

Il permet :

- La consultation, création et modification des tables
- L’exécution de requêtes SQL
- La gestion des utilisateurs
- L’import/export de données

#### 🔁 Interaction

- Accessible via NGINX
- Se connecte à `mariadb:3306`
- Non exposé directement

---

### d. Site statique

Un site statique simple est inclus comme bonus.

Bien qu’il aurait pu être servi directement par NGINX principal, il est isolé dans un container dédié afin de respecter le principe :

> "Un service = un container"

Cela renforce la cohérence architecturale du projet.

---

### e. Portainer

Portainer est une interface web permettant de gérer Docker via le navigateur.

Il permet :

- Visualiser les containers
- Gérer les volumes
- Superviser les réseaux
- Démarrer / arrêter des services

Il est accessible via NGINX.

Bien que principalement destiné aux utilisateurs non-techniques, le choix de ce service tiers orienté administration s'est imposé pour explorer davantage l’univers Docker.

En arrivant à la fin du projet, ce service me semblait de moins en moins indispensable car suffisamment confortable avec les commandes Docker CLI.

Néanmoins :

- Outil utile pour les administrateurs non-dev
- Permet de visualiser l’architecture
- Facilite les discussions techniques grâce à une représentation graphique

---

# IV. Instructions

Le projet est entièrement piloté par un `Makefile` situé à la racine. Ce dernier automatise la création des volumes locaux et l'orchestration des services via Docker Compose.

### 🚀 Commandes de base
* **Lancer l'infrastructure complète** :  
  `make`  
  *(Crée les dossiers de données sur l'hôte, build les images et lance les conteneurs).*

* **Arrêter les services** (sans suppression) :  
  `make down`

* **Nettoyer les conteneurs et réseaux** :  
  `make clean`

* **Réinitialisation totale** (Supprime images, volumes Docker et dossiers de données) :  
  `make fclean`

### 🔧 Administration et Debug
Grâce aux *Pattern Rules* du Makefile, tu peux cibler un service spécifique (`nginx`, `wordpress`, `mariadb`, `ftp`, `redis`, etc.).

* **Gestion individuelle** :  
  Relancer un seul conteneur sans impacter les autres :  
  `make up-<service_name>` (ex: `make up-nginx`)

* **Accès Shell** :  
  Ouvrir un terminal interactif dans un conteneur :  
  `make shell-<service_name>` (ex: `make shell-mariadb`)

* **Consultation des Logs** :  
  * Tous les services : `make logs`  
  * Service précis : `make log-<service_name>` (ex: `make log-wordpress`)

* **État du Cluster** :  
  `make status`

### 📂 Structure des données sur l'hôte
Les volumes persistants sont liés à l'arborescence suivante sur la machine hôte :
* `~/data/wordpress` : Fichiers sources et médias du CMS.
* `~/data/mariadb` : Fichiers binaires de la base de données.

---

# V. Resources

La réalisation de ce projet s’est appuyée sur différentes ressources documentaires officielles et complémentaires.

### Documentation officielle

- Docker Documentation — https://docs.docker.com/
- Docker Compose Documentation — https://docs.docker.com/compose/
- Docker Hub — https://hub.docker.com/
- NGINX Documentation — https://nginx.org/en/docs/
- OpenSSL Documentation — https://www.openssl.org/docs/
- WordPress Documentation — https://wordpress.org/support/
- PHP-FPM Documentation — https://www.php.net/manual/en/install.fpm.php
- MariaDB Documentation — https://mariadb.org/documentation/
- Redis Documentation — https://redis.io/documentation/
- Adminer Documentation — https://www.adminer.org/
- Portainer Documentation — https://docs.portainer.io/

### Ressources complémentaires

- Tutoriels techniques sur YouTube (infrastructure Docker, NGINX reverse proxy, SSL/TLS configuration, WordPress stack setup).  
  *(Les créateurs consultés seront précisés ultérieurement.)*

- Repositories GitHub publics consultés à titre comparatif pour analyser différentes approches d’architecture Docker.

- Discussions techniques communautaires (Stack Overflow, issues GitHub) pour clarifier certains comportements spécifiques.

- L'IA (cf. section suivante)

---

# VI. AI Usage Declaration

Dans le cadre du projet Inception, l’intelligence artificielle a été utilisée comme outil d’assistance, et non comme substitut à la compréhension ou à la réalisation personnelle du projet.

Son utilisation s’est principalement concentrée sur trois axes :

### 1. Support rédactionnel et structuration

L’IA a été utilisée pour optimiser la mise en forme des documents hors code (README, DOC, structuration du Makefile), afin d’améliorer leur clarté et leur lisibilité.

Le contenu conceptuel, les choix architecturaux et les explications techniques proviennent de ma réflexion personnelle. L’IA a servi à reformuler, structurer et harmoniser la présentation.

Cette démarche visait à éviter un investissement disproportionné de temps dans la formulation rédactionnelle, afin de rester concentrée sur les enjeux techniques du projet.

### 2. Support technique explicatif

L’IA a également été utilisée comme outil de clarification conceptuelle.

Certaines documentations officielles, notamment celles de services comme Redis, se sont révélées particulièrement denses ou orientées vers des usages généraux hors contexte Docker. L’IA a permis :

- D’obtenir des explications adaptées à un cas d’usage précis (infrastructure conteneurisée)
- De clarifier des concepts connexes (FastCGI, TLS, réseaux Docker, volumes, gestion des permissions)
- De reformuler des notions complexes lorsque la documentation officielle était difficilement exploitable

L’IA n’a pas remplacé la documentation officielle, mais a servi de complément pédagogique.

### 3. Assistance ponctuelle sur des tâches secondaires

Pour le site statique inclus en bonus, l’IA a été utilisée pour accélérer certaines parties CSS (mise en place de grilles, structuration visuelle). L’objectif principal du projet étant l’architecture Docker et non le développement front-end avancé, ce choix a permis d’optimiser le temps sans compromettre la compréhension technique globale.

Un boilerplate HTML minimal a également été généré afin d’éviter une perte de temps sur une structure basique.

### 4. Vérification et esprit critique

L’IA a été utilisée comme outil de vérification critique :

- Validation d’hypothèses techniques
- Identification d’éventuels angles morts
- Comparaison d’approches trouvées sur GitHub ou dans des tutoriels
- Reformulation de concepts mal compris

L’ensemble des décisions finales d’architecture, de sécurité, de gestion des volumes, des réseaux et des services a été compris et mis en place de manière autonome.

En conclusion, l’intelligence artificielle a été utilisée comme outil d’accompagnement méthodologique et pédagogique, dans une logique de gain de temps et de clarification conceptuelle, sans délégation de la conception ou de l’implémentation fondamentale du projet.
