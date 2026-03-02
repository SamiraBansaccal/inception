# 👤 User Documentation - Inception Interfaces

This documentation explains how to access and use the various graphical interfaces deployed within the Inception infrastructure once launched.

---

## 🔐 1. General Access (Security)

The infrastructure uses self-signed SSL/TLS certificates.  
**During your first connection**, your browser will display a security warning ("Your connection is not private").
1. Click on **Advanced Settings**.
2. Click on **Proceed to address (unsafe)**.

---

## 📝 2. WordPress (CMS) (& ⚡ Redis (Bonus))

WordPress is the main interface for managing the site's content.

* **Visitor URL**: `https://login.42.fr/`
* **Administration URL**: `https://login.42.fr/wp-admin/`
* **Credentials**: Defined in `secrets/`.
* **Usage**:
    * **Dashboard**: Overview of site activity.
    * **Posts/Pages**: Creation and modification of textual content.
    * **Appearance**: Customization of the visual theme.
    * **Plugins**: Adding features (Redis Cache, etc.).
* **Cache Management (Redis)**: 
    * The object cache is managed by the "Redis Object Cache" extension.
    * **Clearing the cache via Portainer**: If needed, you can purge the cache by simply restarting the `redis` container from the Portainer interface. Since Redis is RAM-based storage, a restart instantly clears all volatile data.

---

## 🗄️ 3. Adminer (Database Manager) (Bonus)

Adminer allows you to administer MariaDB without a command line.

* **URL**: `https://login.42.fr/adminer`
* **Credentials**: Defined in `secrets/`.
* **Connection**:
    * **System**: MySQL / MariaDB
    * **Server**: `mariadb` (Use the Docker service name, not 'localhost')
    * **Username**: `your_db_user`
    * **Password**: `your_db_password`
    * **Database**: `your_db_name`
* **Usage**: Allows viewing WordPress tables, executing manual SQL queries, or exporting the database.

---

## 🐳 4. Portainer (Docker Management) (Bonus)

Monitoring interface to visualize the status of containers.

* **URL**: `https://login.42.fr/portainer`
* **Credentials**: Defined in `secrets/`.
* **Usage**:
    * **Containers**: See which services are "Running", consult logs, or restart a container with one click.
    * **Images**: See the disk space used by Docker images.
    * **Networks**: Visualize the `inception_network` bridge network.
    * **Logs**: Visualize PHP or SQL errors in real-time.
    * **Console**: Execute commands directly inside containers without going through the host terminal.

---

## 📁 5. FTP Access (File Transfer) (Bonus)

The FTP service (`vsftpd`) allows you to modify WordPress source files secured by TLS (FTPS).

* **Recommended Software**: FileZilla or the `lftp` CLI tool.
* **Credentials**: Identical to the WordPress administrator to ensure consistency of write rights on the `/var/www/html` volume.
* **Connection via CLI (lftp)**:
    ```bash
   lftp -u wp_admin,wp_admin_pass -e "set ftp:ssl-force true; set ssl:verify-certificate no;" login.42.fr
    ```
    If you get the "Name or service not known" error, add "127.0.0.1 login.42.fr" to your VM's /etc/hosts.
* **Graphical Client Configuration**:
    * **Host**: `sabansac.42.fr` | **Port**: 21.
    * **Protocol**: FTP with explicit TLS.
    * **Mode**: Passive (Ports 21100-21110) to ensure passage through the Docker NAT.

---

## 📄 6. Static Site (Bonus)

An independent presentation page served by a dedicated Nginx instance.

* **URL**: `https://sabansac.42.fr/static/`
* **Operation**: This service is purely static (HTML/CSS).