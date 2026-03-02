# 👤 User Documentation - Inception Interfaces

Cette documentation explique comment accéder et utiliser les différentes interfaces graphiques déployées au sein de l'infrastructure Inception, une fois lancée.

---

## 🔐 1. Accès Général (Sécurité)

L'infrastructure utilise des certificats SSL/TLS auto-signés.  
**Lors de votre première connexion**, votre navigateur affichera un avertissement de sécurité ("Votre connexion n'est pas privée").
1. Cliquez sur **Paramètres avancés**.
2. Cliquez sur **Continuer vers l'adresse (non sécurisé)**.

---

## 📝 2. WordPress (CMS) (& ⚡ Redis (Bonus))

WordPress est l'interface principale pour la gestion du contenu du site.

* **URL Visiteur** : `https://login.42.fr/`
* **URL Administration** : `https://login.42.fr/wp-admin/`
* **Identifiants** : Définis dans `secrets/`.
* **Utilisation** :
    * **Tableau de bord** : Vue d'ensemble de l'activité du site.
    * **Articles/Pages** : Création et modification du contenu textuel.
    * **Apparence** : Personnalisation du thème visuel.
    * **Extensions** : Ajout de fonctionnalités (Redis Cache, etc.).
* **Gestion du Cache (Redis)** : 
    * Le cache objet est géré par l'extension "Redis Object Cache".
    * **Vider le cache via Portainer** : En cas de besoin, vous pouvez purger le cache en redémarrant simplement le conteneur `redis` depuis l'interface Portainer. Redis étant un stockage en RAM, un redémarrage vide instantanément toutes les données volatiles.

---

## 🗄️ 3. Adminer (Gestionnaire de Base de Données) (Bonus)

Adminer permet d'administrer MariaDB sans ligne de commande.

* **URL** : `https://login.42.fr/adminer`
* **Identifiants** : Définis dans `secrets/`.
* **Connexion** :
    * **Système** : MySQL / MariaDB
    * **Serveur** : `mariadb` (Utilisez le nom du service Docker, pas 'localhost')
    * **Utilisateur** : `votre_user_db`
    * **Mot de passe** : `votre_password_db`
    * **Base de données** : `votre_nom_db`
* **Utilisation** : Permet de visualiser les tables WordPress, d'exécuter des requêtes SQL manuelles ou d'exporter la base de données.

---

## 🐳 4. Portainer (Gestion Docker) (Bonus)

Interface de monitoring pour visualiser l'état des conteneurs.

* **URL** : `https://login.42.fr/portainer`
* **Identifiants** : Définis dans `secrets/`.
* **Utilisation** :
    * **Containers** : Voir quels services sont "Running", consulter les logs ou redémarrer un conteneur d'un clic.
    * **Images** : Voir l'espace disque utilisé par les images Docker.
    * **Networks** : Visualiser le bridge network `inception_network`.
	* **Logs** : Visualiser les erreurs PHP ou SQL en temps réel.
    * **Console** : Exécuter des commandes directement dans les conteneurs sans passer par le terminal de l'hôte.
---

## 📁 5. Accès FTP (Transfert de fichiers) (Bonus)

Le service FTP (`vsftpd`) permet de modifier les fichiers sources de WordPress sécurisé par TLS (FTPS).

* **Logiciel conseillé** : FileZilla ou l'outil CLI `lftp`.
* **Identifiants** : Identiques à l'administrateur WordPress pour garantir la cohérence des droits d'écriture sur le volume `/var/www/html`.
* **Connexion via CLI (lftp)** :
    ```bash
   lftp -u wp_admin,wp_admin_pass -e "set ftp:ssl-force true; set ssl:verify-certificate no;" login.42.fr
    ```
	si vous avez l'erreur  "Name or service not known", ajoutez "127.0.0.1 login.42.fr" a /etc/hosts de votre vm
* **Configuration Client Graphique** :
    * **Hôte** : `sabansac.42.fr` | **Port** : 21.
    * **Protocole** : FTP avec TLS explicite.
    * **Mode** : Passif (Ports 21100-21110) pour assurer la traversée du NAT Docker.

---

## 📄 6. Site Statique (Bonus)

Une page de présentation indépendante servie par une instance Nginx dédiée.

* **URL** : `https://sabansac.42.fr/static/`
* **Fonctionnement** : Ce service est purement statique (HTML/CSS).