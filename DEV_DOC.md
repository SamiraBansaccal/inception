# 👨‍💻 Developer Documentation - Technical Deep Dive

Cette documentation détaille la configuration technique de chaque conteneur et les choix d'implémentation pour le développement.

---

## 🏗️ Architecture des Services

### 1. NGINX (The Entry Point)
* **Base** : Alpine Linux.
* **Rôle** : Seul point d'entrée (Port 443). Gère le protocole TLS (1.2/1.3).
* **Configuration** : Le fichier `nginx.conf` définit les blocs `server` qui redirigent le trafic :
    * Requêtes `.php` vers `wordpress:9000` via FastCGI.
    * Routes `/adminer`, `/portainer` vers leurs services respectifs.
* **Certificats** : Générés via `openssl` dans l'Entrypoint.

### 2. MariaDB (The Vault)
* **Base** : Alpine ou Debian.
* **Rôle** : Stockage relationnel SQL.
* **Sécurité** : 
    * Écoute uniquement sur le réseau interne (port 3306).
    * Initialisation via un script `.sql` ou variables d'environnement pour créer la DB et l'utilisateur au premier lancement.
* **Persistance** : Volume `db-data` monté sur `/var/lib/mysql`.

### 3. WordPress & PHP-FPM (The Engine)
* **Base** : Alpine Linux avec `php8x-fpm`.
* **Rôle** : Interprétation du code PHP.
* **Spécificité** : Utilisation de `wp-cli` dans le script d'entrée pour :
    1. Télécharger WordPress.
    2. Configurer le `wp-config.php`.
    3. Installer le site et créer l'utilisateur admin automatiquement.
* **Communication** : Utilise le port 9000 pour parler à Nginx.

### 4. Redis (The Accelerator)
* **Base** : Alpine Linux.
* **Rôle** : Cache objet en mémoire (Key-Value store).
* **Fonctionnement** : Réduit les appels à MariaDB en stockant les résultats de requêtes SQL fréquentes. WordPress doit avoir l'extension "Redis Object Cache" activée pour l'utiliser.

### 5. FTP Server (The Bridge)
* **Service** : `vsftpd`.
* **Rôle** : Accès sécurisé au système de fichiers.
* **Configuration** : 
    * `chroot_local_user=YES` pour isoler l'utilisateur dans son dossier.
    * Plage de ports passifs définie pour traverser le firewall Docker.

---

## 🛠️ Maintenance & Développement

### Gestion des Volumes
Si vous modifiez la structure de la base de données ou le code WordPress et que les changements ne s'appliquent pas :
1. Faites un `make fclean` pour supprimer les volumes locaux.
2. Relancez `make` pour forcer une réinitialisation propre.

### Variables d'Environnement (.env)
Toutes les données sensibles sont centralisées dans le fichier `.env` à la racine de `srcs/`.
> ⚠️ **Ne jamais push le fichier .env sur le dépôt public.**

### Debugging Rapide
* **Vérifier les logs d'un service spécifique** : `docker logs <container_name>`
* **Tester la connectivité entre containers** :
    ```bash
    docker exec -it wordpress ping mariadb
    ```