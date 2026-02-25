# 👤 User Documentation - Inception Interfaces

Cette documentation explique comment accéder et utiliser les différentes interfaces graphiques déployées au sein de l'infrastructure Inception, une fois lancée.

---

## 🔐 1. Accès Général (Sécurité)

L'infrastructure utilise des certificats SSL/TLS auto-signés.  
**Lors de votre première connexion**, votre navigateur affichera un avertissement de sécurité ("Votre connexion n'est pas privée").
1. Cliquez sur **Paramètres avancés**.
2. Cliquez sur **Continuer vers l'adresse (non sécurisé)**.

---

## 📝 2. WordPress (CMS)

WordPress est l'interface principale pour la gestion du contenu du site.

* **URL Visiteur** : `https://login.42.fr/`
* **URL Administration** : `https://login.42.fr/wp-admin`
* **Utilisation** :
    * **Tableau de bord** : Vue d'ensemble de l'activité du site.
    * **Articles/Pages** : Création et modification du contenu textuel.
    * **Apparence** : Personnalisation du thème visuel.
    * **Extensions** : Ajout de fonctionnalités (Redis Cache, etc.).

---

## 🗄️ 3. Adminer (Gestionnaire de Base de Données)

Adminer permet d'administrer MariaDB sans ligne de commande.

* **URL** : `https://login.42.fr/adminer`
* **Connexion** :
    * **Système** : MySQL (ou MariaDB)
    * **Serveur** : `mariadb` (Utilisez le nom du service Docker, pas 'localhost')
    * **Utilisateur** : `votre_user_db`
    * **Mot de passe** : `votre_password_db`
    * **Base de données** : `votre_nom_db`
* **Utilisation** : Permet de visualiser les tables WordPress, d'exécuter des requêtes SQL manuelles ou d'exporter la base de données.

---

## 🐳 4. Portainer (Gestion Docker)

Interface de monitoring pour visualiser l'état des conteneurs.

* **URL** : `https://login.42.fr/portainer`
* **Utilisation** :
    * **Containers** : Voir quels services sont "Running", consulter les logs ou redémarrer un conteneur d'un clic.
    * **Images** : Voir l'espace disque utilisé par les images Docker.
    * **Networks** : Visualiser le bridge network `inception_network`.

---

## 📁 5. Accès FTP (Transfert de fichiers)

Pour modifier les fichiers sources de WordPress directement.

* **Logiciel conseillé** : FileZilla ou Cyberduck.
* **Configuration** :
    * **Hôte** : `login.42.fr`
    * **Protocole** : FTP (avec TLS explicite si configuré).
    * **Port** : 21.
    * **Mode** : Passif (Ports 21100-21110).