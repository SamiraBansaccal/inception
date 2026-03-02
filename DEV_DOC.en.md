# 👨‍💻 Developer Documentation - Technical Deep Dive

This documentation details the technical configuration of each container and the implementation choices for development.
If the site is inaccessible, set the network:
- to bridge on the vm
- to nat: check port forwarding (nginx, passive ftp, and ssh) of the vm and the /etc/hosts of the host machine (add 127.0.0.1 login.42.fr)
---

## 🏗️ Service Architecture

## 1. 🌐 NGINX (Web Server & Reverse Proxy)

* **Base**: Alpine Linux (via Dockerfile `requirements/nginx`).
* **Main Role**: Unique HTTPS entry point (Port 443) for the web infrastructure. It encrypts incoming traffic and dispatches it to the correct containers (WordPress, Adminer, Portainer, Static Site) according to the requested URL.
* **Security & SSL**: 
    * Restricted to secure protocols **TLSv1.2** and **TLSv1.3** only.
    * The `.crt` and `.key` certificates are generated on the fly via OpenSSL in the entrypoint script.
    * These certificates are stored in the `ssl_certificate` volume (`/etc/nginx/ssl`), allowing them to be **shared with the FTP service** to configure FTPS without generating duplicates.

### 📝 Routing Configuration (`nginx.conf`)
The configuration file defines a unique `server` block listening on port 443 and manages internal routing:

1. **The main route (`/`) -> WordPress**
    * Points to the shared volume `/var/www/html`.
    * NGINX does not read PHP. It intercepts all requests ending in `.php` and transfers them to the `wordpress` container on port `9000` via the **FastCGI** protocol.
2. **The `/static/` route -> Static Site (Bonus)**
    * Operates in simple Reverse Proxy mode (`proxy_pass`). NGINX redirects traffic to the `static` container which listens on its own internal port `8080`.
3. **The `/adminer/` route -> DB Interface (Bonus)**
    * Looks for the index `adminer.php` in `/var/www`.
    * As with WordPress, the PHP code is sent to the `adminer` container on its port `9000` via FastCGI.
4. **The `/portainer/` route -> Docker GUI (Bonus)**
    * Redirects to the `portainer` container (port `9000`).
    * **Technical specificity**: NGINX integrates specific headers (`Upgrade $http_upgrade`, `Connection 'upgrade'`) to support WebSockets. This is essential for the terminal/console functionality integrated into Portainer to work through the proxy.

### 🐳 Docker Compose Integration
* **Dependency**: `depends_on: - wordpress` ensures that NGINX only starts if WordPress is launched, avoiding 502 (Bad Gateway) errors at startup.
* **Network**: Connected to the internal `inception` network to communicate with other containers by their service names (internal Docker DNS resolution).
* **Mounted Volumes**:
    * `wordpress_data`: To read WordPress static assets (CSS/JS/Images) directly without waking up PHP.
    * `ssl_certificate`: For storing TLS keys.
    * `adminer_data`: To access the Adminer PHP script.
    * `portainer_data`: Mounted in case Portainer stores its own data on a shared folder.

### 🛠️ Useful Commands (NGINX)
* **Reload configuration on the fly (without rebooting the container)**: 
    ```bash
    docker exec -it nginx nginx -s reload
    ```
* **Verify syntax validity of `nginx.conf`**:
    ```bash
    docker exec -it nginx nginx -t
    ```
* **List all active processes in NGINX**:
    ```bash
    docker exec -it nginx ps aux | grep nginx
    ```

## 2. 🗄️ MariaDB (Database Manager)

* **Base**: Alpine Linux (via Dockerfile `requirements/mariadb`).
* **Role**: Relational SQL database engine for WordPress and bonus services.
* **Security (Hardening)**: 
    * **Network Isolation**: The container does not expose any port on the host. It is accessible only via the internal `inception` network on port **3306**.
    * **Secret Management**: Use of **Docker Secrets**. Passwords (`db_root_pass` and `db_pass`) are never stored in environment variables (visible via `docker inspect`), but read directly from `/run/secrets/` by the initialization script.
    * **Privileges**: The SQL user is restricted to its specific database (`${SQL_DB}.*`), limiting the scope in case of intrusion.

### 📜 Initialization Logic (`Entrypoint`)
Startup relies on a script that manages idempotency (not overwriting data if it already exists):

1. **Data directory installation**: If `/var/lib/mysql/mysql` does not exist, `mariadb-install-db` initializes the basic structure.
2. **Temporary SQL Script**: A `/tmp/init.sql` file is dynamically generated to:
    * Create the database.
    * Create the user with access rights from any internal host (`@'%'`).
    * Secure the **root** account with a strong password retrieved from secrets.
3. **Daemon Launch**: `mysqld` starts using `--init-file=/tmp/init.sql`, ensuring that the security configuration is applied before any client connection.

### 🐳 Docker Compose Integration
* **Healthcheck**: The container uses `mysqladmin ping` to confirm that the service is actually ready to respond to requests. This allows dependent services (WordPress) to wait until the DB is "Healthy" before attempting a connection.
* **Persistence**: The `mariadb_data` volume is mounted on `/var/lib/mysql`. All tables, indexes, and data survive container restart or deletion.
* **Secrets**: Injection of secret files defined at the project root into the container.

### 🛠️ Useful Commands (MariaDB)
* **Enter the MySQL console from the host**:
    ```bash
    docker exec -it mariadb mysql -u root -p"$(cat /path/to/secret/root_pass)"
    ```
* **Check the service health status**:
    ```bash
    docker inspect --format='{{json .State.Health}}' mariadb
    ```
* **Check the database size on disk**:
    ```bash
    docker exec -it mariadb du -sh /var/lib/mysql
    ```

## 3. 📝 WordPress & PHP-FPM (Application Engine)

* **Base**: Alpine 3.18.
* **Role**: PHP interpreter (FastCGI) processing site logic. It bridges NGINX requests and MariaDB/Redis data.
* **Port**: 9000.

### ⚙️ Network & PHP Configuration
* **Network Listening**: The `www.conf` file is modified via `sed` to change from `127.0.0.1:9000` to `9000` (equivalent to `0.0.0.0:9000`). 
    * *Why?* By default, PHP-FPM only listens to itself. For NGINX (another container) to send it `.php` files, PHP-FPM must listen on the container's shared network interface.
* **DNS Resolution**: The database host is configured as `mariadb`. In the Docker `inception` network, this allows finding MariaDB without a static IP.

### 📜 Entrypoint Logic (WP-CLI)
Installation is automated via the **WP-CLI** tool to ensure a reproducible stack without manual intervention:
1. **Creation of `wp-config.php`**: Injection of environment variables and secrets (`/run/secrets/db_pass`).
2. **Redis Setup**: Configuration of `WP_REDIS_HOST` and `WP_CACHE` constants to link the cache service.
3. **Core Installation**: Defines the URL as `https`, the title, and creates the **Administrator** account via secrets.
4. **Author User**: Creation of the second required user with restricted rights (`author`).
5. **Redis Finalization**: Physical installation of the `redis-cache` plugin and activation of the object link via `wp redis enable`.

### 📂 Rights Management & Umask
* **Owner**: `chown -R nobody:nobody`. Alpine uses the `nobody` user for web processes for security (minimal privileges).
* **The `umask 0002` setting**: 
    * The `umask` (User Mask) is a filter that removes permissions when a file is created.
    * In computing, max permission is `777` for a folder and `666` for a file.
    * With `0002`, we subtract `2` from the last bit (Others). 
    * **Result**: New folders are `775` and files are `664`. This allows the group (which the FTP server is also part of) to have coherent read/write rights (no permission problems between what was written by the ftp_user and the wp_user), while limiting the rights of "foreign" users to the system.

### 🐳 Docker Compose Integration
* **Health Dependency**: Uses `condition: service_healthy` on MariaDB. WordPress waits until the database is ready to receive SQL requests before launching its configuration script.
* **Readiness Dependency** on `redis` to ensure the cache service is available when activating the plugin.
* **Secret Management**: Mounts 7 secret files to manage all credentials (Admin, User, DB) without ever exposing them in the container history.
* **Persistence**: The `wordpress_data` volume stores the entire `/var/www/html` directory, allowing the preservation of source code, themes, plugins, and uploaded media files.

### 🛠️ Useful Commands (WordPress)
* **List registered users**:
    ```bash
    docker exec -it wordpress wp user list --allow-root
    ```
* **Check Redis connection status**: 
    ```bash
    docker exec -it wordpress wp redis status --allow-root
    ```
* **Flush Redis cache from WordPress**:
    ```bash
    docker exec -it wordpress wp redis flush --allow-root
    ```

## 4. ⚡ Redis (Object Cache)

* **Base**: Alpine 3.18.
* **Role**: Key-value data storage system in random access memory (RAM). It serves as an object cache for WordPress.
* **Port**: 6379.

### ⚙️ Configuration & Operation
* **Performance Optimization**: Instead of requesting MariaDB (disk reading) at each page load, WordPress stores the results of frequent SQL queries in Redis (RAM reading). This drastically reduces the site response time.
* **Protected Mode (`--protected-mode no`)**: 
    * By default, Redis refuses connections that do not come from `localhost`.
    * Setting it to `no` allows accepting requests coming from the internal `inception` network. Security is maintained because port 6379 is not exposed on the host.

### 📜 Link with WordPress
Integration is driven by the WordPress entrypoint script via three steps:
1. **Configuration**: `wp config set WP_REDIS_HOST redis` defines the service name as the target.
2. **Installation**: The `redis-cache` plugin is injected into WordPress files.
3. **Activation**: The `wp redis enable` command creates an `object-cache.php` file in the `wp-content` directory, which diverts SQL queries to Redis.

### 🐳 Docker Compose Integration
* **Network**: Isolated in the `inception` network. Only the WordPress container needs to communicate with it.
* **Persistence**: Unlike MariaDB, Redis is used here as a volatile cache. If the container restarts, the cache is emptied and reconstructs itself as visits occur, ensuring always fresh data.

### 🛠️ Useful Commands (Redis)
* **Monitor requests in real-time** (to prove to the evaluator that the cache is working):
    ```bash
    docker exec -it redis redis-cli monitor
    ```
* **Check memory usage statistics**:
    ```bash
    docker exec -it redis redis-cli info memory
    ```
* **Manually flush the cache**:
    ```bash
    docker exec -it redis redis-cli flushall
    ```
For Redis, you will not find a "text file" with keys and values inside. Redis is an In-Memory database: everything is stored in RAM to be fast. If you want to see what's inside, you must use the command `docker exec -it redis redis-cli KEYS "*"`

## 5. 📂 FTP Server (vsftpd)

* **Base**: Alpine 3.18.
* **Service**: `vsftpd` (Very Secure FTP Daemon).
* **Role**: Allows secure file transfer (FTPS) directly into the WordPress volume (`/var/www/html`).
* **Ports**: 21 (Command) + 21100-21110 (Data in passive mode).

### ⚙️ Configuration & Security (FTPS)
* **SSL/TLS Encryption**: Unlike classic FTP which transmits passwords in plain text, this configuration forces the use of TLS (`ssl_enable=YES`).
* **Certificate Sharing**: The container mounts the `ssl_certificate` volume. It uses exactly the same certificates as NGINX (`nginx.crt`/`nginx.key`), ensuring security coherence across the entire infrastructure.
* **Isolation (Chroot)**: `chroot_local_user=YES` locks the user in their home directory. It is technically impossible for the FTP user to go up the container tree to see other system files.

### 🌐 Passive Mode & Docker NAT
Traditional FTP (Active Mode) often fails behind a firewall or a Docker NAT network. 
* **Solution**: `pasv_enable=YES`. The server opens a specific port range (`21100-21110`) for data transfer. 
* **Compose Link**: These ports are explicitly opened in `docker-compose.yml` to allow communication between the external FTP client and the container.

### 📜 Entrypoint Logic
The script prepares the environment before launching the daemon:
1. **User Creation**: Retrieves the username (`wp_admin`) and password from **Docker Secrets**. It is assumed that whoever modifies via FTP, having the same powers as a WP admin, should therefore have the same identity to avoid multiplying users; the same login is reused, but these logins are not linked and could be different.
2. **Group Assignment**: The user is added to the `nobody` group. This is the synchronization point with WordPress: both services share the same group to avoid permission conflicts.
3. **Umask Setting**: Defined at `0002`.
    * **Files**: Created in `664` (Read/Write for owner and group).
    * **Folders**: Created in `775`.
    * *Utility*: This ensures that if you upload a file via FTP, WordPress (which is also in the `nobody` group) will be able to modify or delete it without a "Permission Denied" error.

### 🐳 Docker Compose Integration
* **Volumes**: 
    * `wordpress_data`: Mounted on `/var/www/html` to access site files.
    * `ssl_certificate`: To retrieve the encryption keys generated by NGINX.
* **Alpine Compatibility**: `seccomp_sandbox=NO` is added in the `.conf`. This is essential because vsftpd uses system calls that are sometimes blocked by the Docker engine on Alpine, otherwise the daemon crashes at the first login.

### 🛠️ Useful Commands
* **Check connection and transfer logs**:
    ```bash
    docker exec -it ftp tail -f /var/log/vsftpd.log
    ```
* **Test local connection (if lftp is installed on the host)**:
    ```bash
    lftp -u user,password -e "set ftp:ssl-force true; set ssl:verify-certificate no;" localhost
    ```
## 6. 📂 Adminer (Database Management)

* **Base**: Alpine 3.18.
* **Role**: Lightweight graphical interface (GUI) to administer MariaDB.
* **Port**: 9000 (FastCGI).

### ⚙️ Configuration & Authentication
* **Manual Connection**: Unlike WordPress which is pre-configured via `wp-config.php`, Adminer is a neutral interface. 
    * Upon opening the page, the user must manually provide: **Server** (`mariadb`), **Username**, **Password**, and **Database Name**. 
    * Adminer then uses the `php81-mysqli` extension to establish the connection to port 3306 of the MariaDB container.
* **PHP Sessions**: The installation of `php81-session` is critical to maintain the user's connection state between two clicks in the interface.

### 📜 Entrypoint Logic
The script manages the presence of the `adminer.php` file in the shared volume:
2. **Restart**: If the container restarts but the volume already exists (data persists), the script sees that the file is present and does nothing, thus preserving existing files.

### 🐳 Docker Compose Integration
* **Shared Volume**: Uses `adminer_data` mounted on `/var/www/adminer`. This volume is also mounted in the NGINX container so that the latter can "see" the PHP file to serve.
* **Network**: Isolated in the `inception` network. Adminer uses internal Docker DNS to connect to `mariadb`.

### 🛠️ Useful Commands
* **Verify that the adminer.php file is in the volume**:
    ```bash
    docker exec -it adminer ls -l /var/www/adminer
    ```
* **Check DB connection logs via Adminer**:
    ```bash
    docker logs adminer
    ```

## 7. 🐳 Portainer (Docker Infrastructure Manager)

* **Base**: Alpine 3.18.
* **Role**: Graphical interface (GUI) allowing monitoring and management of all containers, images, networks, and volumes of the Inception project.
* **Internal Port**: 9000 (HTTP).

### ⚙️ Operation & Privileges
* **Docker Socket (`/var/run/docker.sock`)**: This is the masterpiece of the service. By mounting the host socket in the container, Portainer can "go out" of its isolation to send instructions directly to the Debian system's Docker engine. This allows it to list other containers and display their logs or stats in real-time.
* **Automatic Authentication**: The use of the `--admin-password-file` flag in the entrypoint allows defining the administrator password from the first launch via a **Docker Secret**. This avoids having to manually configure the admin account during the first web connection.

### 📜 Entrypoint Logic
The script launches the Portainer executable with parameters specific to the Inception environment:
2. **`--data /data`**: Defines the location of Portainer's internal database (users, settings, history) on a persistent volume.
3. **`-H unix:///var/run/docker.sock`**: Connects Portainer to the local Docker API via the unix socket.
4. **`--admin-password-file`**: Retrieves the secret stored in `/run/secrets/portainer_pass` to secure the instance.

### 🐳 Docker Compose Integration
* **Volumes**: 
    * `/var/run/docker.sock:/var/run/docker.sock`: Critical mount for host control.
    * `portainer_data`: Ensures persistence of Portainer configuration.
* **Reverse Proxy (NGINX)**: Served by NGINX on `https://sabansac.42.fr/portainer/`. NGINX manages WebSockets Upgrade to allow the use of container terminals in the Portainer interface.

### 🛠️ Useful Commands (Portainer)
* **Verify that Portainer communicates well with the Socket**:
    ```bash
    docker exec -it portainer ./portainer --version
    ```
* **Verify data persistence**:
    ```bash
    docker exec -it portainer ls -l /data
    ```
* **See interface logs in case of crash**:
    ```bash
    docker logs portainer
    ```

## 8. 📄 Static Site (Presentation Site)

* **Base**: Alpine 3.18 / Nginx.
* **Role**: Host of static content (HTML/CSS) served via a dedicated web server.
* **Internal Port**: 8080.

### ⚙️ Nginx-to-Nginx Architecture
This service uses its own independent Nginx instance from the main proxy:
1. **Listening**: The internal `nginx.conf` file is configured to listen on port **8080** only.
2. **Reverse Proxy**: When a user requests `https://sabansac.42.fr/static/`, the main Nginx (Port 443) relays the request to this container's Nginx (Port 8080) via the `proxy_pass` instruction.
3. **Isolation**: Site content (`index.html`, `styles.css`) is physically stored in `/var/www/static` inside this container, completely separate from WordPress or Adminer volumes.

### 📜 Entrypoint Logic
The script automates the final configuration when the container is launched:
* **Dynamic Server Name**: Uses `sed` to inject the `${DOMAIN_NAME}` environment variable directly into the static site Nginx configuration. This allows keeping the container portable regardless of the domain used.
* **Foreground Execution**: Launches Nginx with the `daemon off;` option to ensure the process remains in the foreground, which is essential so Docker does not consider the container stopped.

### 🐳 Docker Compose Integration
* **Network**: Connected to the `inception` network. As it does not have a `ports` block, it is invisible from the outside (Internet); only the main Nginx container can reach it.
* **Dependency**: Although it is autonomous, `depends_on: - nginx` ensures coherence in the startup order of the bonus stack.

### 🛠️ Useful Commands (Static)
* **Verify that the internal Nginx serves the files correctly**:
    ```bash
    docker exec -it static curl localhost:8080
    ```
* **Verify the Nginx configuration generated by the entrypoint**:
    ```bash
    docker exec -it static cat /etc/nginx/nginx.conf
    ```
* **Verify the presence of static assets**:
    ```bash
    docker exec -it static ls -l /var/www/static
    ```
---
## 🛠️ Maintenance & Development

### ⚠️ Data Criticality (Volume Analysis)

Before executing a `make fclean`, it is crucial to understand the impact of deletion on each service. All volumes are not equal:

| Service | Importance | Consequence of a deletion |
| :--- | :--- | :--- |
| **MariaDB** | 🔴 **Critical** | **Total loss** of all content (articles, pages, user accounts, WordPress configuration). Irrecoverable without SQL backup. |
| **WordPress** | 🟠 **High** | Deletes media files (uploaded images) and manually installed plugins. The site structure remains in DB, but files will be absent. |
| **Portainer** | 🟡 **Medium** | Resets the Portainer interface and its history but this does not impact your other containers. |
| **Redis** | 🟢 **Zero** | No severity. Redis is a cache. Data will be automatically reconstructed by WordPress during next visits. |
| **Static / Adminer** | ⚪ **None** | These services are "stateless". Their volumes (if present) only contain temporary files or fixed configuration. |

### 💡 Production Best Practices
* **Before an fclean**: Always perform a database export via Adminer or a `mysqldump` from the MariaDB container.
* **Code modification**: If you only change the static site CSS or a PHP script, prefer a `make up-<service>` rather than an `fclean`. The volume will preserve your data while updating the executed code.

### 🧹 Volume Management & Reset
If you modify the database structure, the initial WordPress installation, or if the infrastructure is corrupted, a simple restart will not be enough because data persists in volumes.
1. Run `make fclean`: This command is radical. It destroys containers, purges the Docker system (`prune -af`), and **physically deletes local data folders** (`/home/$(USER)/data`).
2. Run `make re` to force a clean reset and go through Entrypoint scripts again.

### 🔐 Environment Variables and Secrets
Project security relies on the non-exposure of credentials. All sensitive data is centralized:
* Global variables in `srcs/.env`.
* Passwords in the `./secrets/` folder at the root.

> 💡 **Automatic Generation**: During the first `make`, the Makefile automatically generates these files with **default values** (ex: `db_pass_val`) to test the infrastructure quickly. 
> ⚠️ **In production/evaluation**: You must modify the content of these files to define your own robust passwords. These files and folders are included in the `.gitignore` to ensure they are **never** pushed to the public repository.

### 🔍 Quick Debugging (via Makefile)
The project integrates dynamic Makefile commands to simplify debugging without having to type full Docker commands:

* **Check infrastructure status**: 
    ```bash
    make status
    ```
* **See live logs of a specific service** (ex: nginx, wordpress, ftp):
    ```bash
    make log-<service_name>
    # Example: make log-mariadb
    ```
* **Open a terminal (shell) in an active container**:
    ```bash
    make shell-<service_name>
    # Example: make shell-wordpress
    ```
* **Restart/Rebuild a single service after a modification**:
    ```bash
    make up-<service_name>
    ```