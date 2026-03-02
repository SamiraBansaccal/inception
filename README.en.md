# 🏗️ Inception - Docker Infrastructure Project

# I. Description: General 🌐

The **Inception** project aims to design and deploy a complete web infrastructure using Docker exclusively as the containerization technology. This project implements a classic modern web infrastructure stack and aims to introduce the fundamental principles of microservices architectures.

Unlike traditional monolithic architectures, where all application components coexist in a single environment, the microservices approach consists of separating each service into an isolated, independent, and specialized environment. This separation allows for:

* **Better isolation of responsibilities.**
* **Simplified maintenance.**
* **Finer scalability.**
* **Enhanced security.**
* **A better understanding of the layers of a web infrastructure.**

### Summary:

* **I. Description: general**
* **II. Architecture Overview and Docker key-concepts**
* **III. Requirements: Stack, Components, and interactions**
* **IV. Instructions**
* **V. Resources**
* **VI. AI Usage Declaration**

---

# II. 🐳 Docker & Infrastructure Concepts

This project uses Docker to containerize an infrastructure of interconnected services. This section details the internal workings of Docker as well as the architectural choices of the Inception infrastructure.

## A. Docker: An Abstraction of the Linux Kernel 🐧

Docker is a container management tool. Unlike manual management (via `chroot` or `cgroups`), Docker automates the life cycle of isolated environments. **Docker invents nothing.** It does not create a "machine"; it automates features already natively present in the **Linux Kernel**.

### The life cycle of a Docker application:
1. **Dockerfile (The Recipe)**: A text file containing sequential instructions to assemble the environment (`FROM`, `RUN`, `COPY`).
2. **Image (The Mold)**: The immutable result (read-only) of the Dockerfile build. It is composed of superimposed layers.
3. **Container (The Instance)**: A running instance of an image. Docker adds a writable layer on top of the immutable image to allow temporary modifications.

### 💡 Concept: Virtualization vs. Containerization (The illusion of isolation)



A Virtual Machine uses a Hypervisor to simulate hardware and run a full OS, while Docker is isolation at the operating system level. Docker uses three Kernel pillars to isolate processes:

* **Namespaces**: Isolates the system view (each container believes it has its own network interfaces, its own `PID 1` processes, and its own file system).
* **Control Groups (Cgroups)**: Manages resource allocation (CPU, RAM, I/O).
* **chroot & rlimit**: Docker uses evolved versions of `chroot` (such as `pivot_root`) to change the root of the file system, and `rlimit` to prevent a container from saturating host resources.

| Characteristic | Virtual Machine (VM) | Docker (Container) |
| :--- | :--- | :--- |
| **Architecture** | Hardware virtualization. Each VM has its own full OS (Guest OS). | Operating system virtualization. Containers share the host Kernel (Linux). |
| **Isolation** | Strong isolation via a Hypervisor. | Process isolation via Namespaces (system view) and Cgroups (resources). |
| **Performance** | Heavy (GBs), slow to start (OS boot). | Lightweight (MBs), instant start (simple process). |

> **Implication in the project:** The Inception infrastructure is extremely lightweight. Each service (Nginx, MariaDB, etc.) is a simple isolated process running directly on the host machine's Kernel (the 42 school VM), without the overhead of a guest OS.

---

## B. Docker Compose: Micro-services Orchestration 🎼

### ⚙️ Concept: One service = One container
The fundamental principle of Docker is that a container should perform only one main task. This is because you can only debug a single process running as root in the container. **Docker Compose** allows linking these isolated units to form a coherent infrastructure via a `docker-compose.yml` file.

Docker Compose allows you to:
* Define the entire infrastructure in a single YAML file (`docker-compose.yml`).
* Manage startup dependencies (e.g., WordPress waits for MariaDB to be ready via `healthcheck` and `depends_on`).
* Create a dedicated network for service isolation.

> **Implication in the project:** Rather than having an "all-in-one" server, the Inception architecture separates responsibilities.

---

## C. Networking: Isolation and Communication 🌐

### 📡 Concept: NAT Host, Bridge Docker Network & Internal Docker DNS

* **Host Network (NAT)**: 🔌 Port Forwarding (Host -> VM -> Docker)
To access the services from the host machine, a specific port forwarding layer is configured:

| Service | External Port (Host) | Internal Port (Container) | Purpose |
| :--- | :--- | :--- | :--- |
| **SSH** | `4242` | `22` | Remote access to the VM (VS Code / Terminal) |
| **NGINX** | `443` | `443` | Web access (HTTPS) for all web services |
| **FTP** | `21` | `21` | FTP Control commands (FTPS) |
| **FTP Data** | `21100-21110` | `21100-21110` | File transfer (Passive Mode) |

Because of network restriction on the school computers, we could not chose bridge for the host but on a private project, if the host is on bridge, the container shares the IP address and network space of the host machine. No network isolation.

* **Docker Network (Bridge)**: *Used in this project.* Creates a private virtual network.
    * **Isolation**: Containers are not accessible from the outside unless ports are explicitly published.
    * **Internal DNS**: Docker automatically resolves service names. The `wordpress` service can communicate with the database simply by using the host `mariadb` (no IP to manage). If a service is named `mariadb`, any other container on the same network can contact it via the name `mariadb` instead of an unstable IP address.

**Implication in the project:**
* **Exposed Ports**: No MariaDB or WordPress ports are exposed on the host machine. They are only accessible by Nginx inside the Docker network.
* **Published Ports**: Only port **443** (Nginx) and port **21** (FTP) are open on the host machine's IP to allow user access.
* **Inter-service Link**: WordPress communicates with MariaDB via the host `mariadb:3306`. This communication is completely invisible to someone attempting to attack the host machine from the outside.

### 📊 Network Flow Summary (Ports)

| Service | Internal Port (Docker) | External Port (Host) | Why? |
| :--- | :--- | :--- | :--- |
| **Nginx** | 443 | **443** | Standard secure entry point. |
| **WordPress** | 9000 | None | Protected by the Nginx proxy. |
| **MariaDB** | 3306 | None | Maximum data security. |
| **FTP** | 21 + 21100-21110 | **21 + 21100-21110** | Direct access for file transfer. |
| **Adminer** | 8080 | None | Accessible via Nginx (`/adminer`). |

---

## D. Storage: Volumes vs. Bind Mounts 💾

### 📂 Concept: Data Persistence (Stateful vs. Stateless)
A container is "stateless": Since containers are ephemeral, data is lost upon deletion. Two solutions exist:

* **Docker Volumes (Managed)**: Docker manages the location on the disk (`/var/lib/docker/volumes`). This is the most secure and performant method.
* **Bind Mounts**: A direct link to a specific folder on the host (e.g., `/home/user/data`). Less portable and riskier regarding permissions. The host's current folder is "projected" into the container.
    * *Advantage:* If you modify the code on your PC, the container sees it instantly (great for development).

**Implication in the project (Choice of volumes):** We use named Volumes only for essential data:
* **`db-data`**: For MariaDB. Indispensable for not losing users/posts on restart.
* **`wp-data`**: Shared between **WordPress** (writing code), **Nginx** (reading static files), and **FTP** (remote upload). This volume sharing is what allows three distinct containers to work on the same files simultaneously.
* **`certs-data`**: Shared between **Nginx** and **FTP**. This avoids generating two different sets of certificates and guarantees a unique TLS identity for the entire infrastructure.

> **Why not the others?** Services like Adminer or the Static Site do not generate user data. If they restart, starting from scratch guarantees a clean infrastructure ("Clean State").

---

## E. Security: Secret Management 🔐

### 🔑 Concept: Environment vs. Secrets
Managing sensitive data (passwords, API keys) is critical.
* **Environment Variables (ENV)**: Stored in the container configuration and visible via `docker inspect` and in system processes. Useful for non-sensitive configuration (DB name, user).
* **Docker Secrets**: Secure method. Data is encrypted at rest and temporarily mounted into the container (usually in `/run/secrets/`). They are never exposed in plain text in logs or container inspection.

**Implication in the project:** `MYSQL_ROOT_PASSWORD` and database credentials are injected via secret files. They are stored in the `/run/secrets/` folder inside the containers, making them inaccessible to malicious scripts that would only scan the system environment.

---

# III. Requirements: Components and Interactions ⚙️

### a. NGINX – Reverse Proxy and TLS Termination

NGINX is used as the single entry point for the infrastructure.  
Its primary role here is that of a **secure reverse proxy**.  
It receives all HTTPS requests on port 443, then redirects them to the various internal services based on the requested path.

#### 🔁 Interaction with other services

NGINX is the **only container publicly exposed on port 443**.

Actual request flow:

1. The browser establishes a TLS connection to NGINX.
2. NGINX performs **TLS termination** (decryption).
3. Depending on the requested route:
   - `/` → transmitted to `wordpress:9000` via FastCGI
   - `/adminer` → transmitted to the Adminer container
   - `/portainer` → transmitted to the Portainer container
   - `/static` → transmitted to the static site container
4. The response is sent back to the client after potential PHP transformation.

NGINX does not know the IP addresses of the containers.  
It uses the **internal Docker DNS**, which allows targeting a service by its name (`wordpress`, `adminer`, etc.).

This relies on the **Docker Bridge Network**, which provides:
- Network isolation
- Automatic DNS resolution
- Secure inter-container communication

#### General capabilities of NGINX

NGINX is an extremely versatile tool. It can:

- Serve static files
- Act as a load balancer
- Manage HTTP caching
- Perform rate limiting
- Terminate SSL/TLS connections
- Serve as an API gateway

In this project, its role is deliberately limited to:

- TLS termination
- Reverse proxy
- Internal routing to WordPress, Adminer, Portainer, and the static site

#### SSL / TLS – Securing communications

Communications are secured via **TLS 1.2 and TLS 1.3**.

Historically, the protocol used to secure web communications was called **SSL (Secure Sockets Layer)**.  
SSL evolved into **TLS (Transport Layer Security)**, which is its modernized and secure version.

Today, we still talk about "SSL certificates," but in reality, they are TLS certificates.

Old SSL versions (v2, v3) are now considered vulnerable.  
TLS 1.2 and 1.3 are currently the recommended secure versions.

The project uses **OpenSSL**, a widely used open-source implementation for generating self-signed certificates.

Other options include:

- Commercial certification authorities (DigiCert, GlobalSign, etc.)
- Let’s Encrypt (free)
- Proprietary implementations in certain enterprise environments

In this project:

- A self-signed certificate is dynamically generated at the startup of the NGINX container.
- The FTP server reuses these same certificates via a shared volume.
- This guarantees **TLS identity consistency** across the entire infrastructure.

---

### b. WordPress with PHP-FPM

WordPress is a content management system (CMS) written in PHP.  
WordPress represents a significant portion of the world's websites, making it an essential technology despite its sometimes criticized reputation as a "gas factory."

It is not just a framework, but a complete ecosystem allowing:

- Theme management
- Plugin installation
- User management
- Dynamic content creation

#### 🔁 Interaction with other services

WordPress is positioned between:

- **NGINX** (which transmits requests to it)
- **MariaDB** (which stores the data)
- **Redis** (if enabled, for caching)
- **FTP** (which modifies its files via shared volume)

Technical flow:

1. NGINX transmits a request via FastCGI.
2. PHP-FPM interprets the PHP script.
3. If necessary:
   - SQL query to `mariadb:3306`
   - Read/write in Redis
4. HTML generation.
5. Return to NGINX.
6. Sent to the browser.

#### PHP-FPM

WordPress runs on PHP, which means it requires a PHP interpreter to transform PHP code into HTML usable by the browser.

This role is performed by **PHP-FPM (FastCGI Process Manager)**.

PHP-FPM is a PHP process manager.  
It is not a web server, but an interpreter specialized in PHP execution.

- Listens on a FastCGI port
- Receives requests from NGINX
- Executes PHP code
- Returns HTML

It is **not publicly exposed**.  
Only NGINX can communicate with it via the internal Docker network.

---

### c. MariaDB – Database Server

MariaDB is a relational database server, an open-source fork of MySQL.

It allows:

- Creation of databases
- Table management
- Execution of SQL queries
- Data persistence

WordPress uses MariaDB to store:

- Posts
- Users
- Configurations
- Metadata

The language used to interact with MariaDB is **SQL (Structured Query Language)**, a widely used standard in relational databases.

#### 🔁 Network Interaction

- WordPress communicates with MariaDB via `mariadb:3306`
- MariaDB is **not exposed to the outside**
- Access is limited to the internal Docker network
- Credentials are injected via Docker Secrets

This means:

- Impossible to access the database from the outside without going through an authorized container
- Reduction of the attack surface

---

# C. BONUS 🎁

### a. Redis – Caching Service

Redis is an in-memory caching system.  
Its goal is to improve performance by temporarily storing frequently used data, to avoid repeated queries to the database.

Redis functions as an in-memory key-value database.

In this project, it is used to optimize WordPress performance.

#### 🔁 Interaction

- WordPress queries Redis before MariaDB
- If data is found → immediate response
- Otherwise → SQL query → storage in Redis cache

This reduces:

- MariaDB CPU load
- The number of SQL queries
- Overall response time

Redis is not publicly exposed.

---

### b. Secure FTP Server

An FTP server is set up to allow remote access to WordPress files.

It allows:

- Browsing files
- Modifying them
- Transferring them

The FTP server uses TLS to secure exchanges (FTPS).

TLS was not mandatory, but classic FTP communications are in plain text.  
After securing NGINX, the database, and WordPress administration, leaving FTP unencrypted would have created a security inconsistency.

#### 🔁 Interaction

- Shares the same volume as WordPress (`wp-data`)
- Shares TLS certificates with NGINX (`certs-data`)
- Uses the same credentials as the WordPress administrator
- Belongs to the same system group (`nobody`) to avoid permission conflicts

This guarantees:

- Rights consistency
- No file conflicts
- TLS identity consistency

---

### c. Adminer – Database Administration

Adminer is a lightweight web interface for administering MariaDB from a browser.

Adminer does not contain a database itself.  
It acts as a **web client for MariaDB**.

It allows:

- Browsing, creating, and modifying tables
- Executing SQL queries
- User management
- Data import/export

#### 🔁 Interaction

- Accessible via NGINX
- Connects to `mariadb:3306`
- Not directly exposed

---

### d. Static Site

A simple static site is included as a bonus.

Although it could have been served directly by the main NGINX, it is isolated in a dedicated container to respect the principle:

> "One service = one container"

This reinforces the architectural consistency of the project.

---

### e. Portainer

Portainer is a web interface for managing Docker via the browser.

It allows:

- Visualizing containers
- Managing volumes
- Supervising networks
- Starting / stopping services

It is accessible via NGINX.

Although primarily intended for non-technical users, the choice of this administration-oriented third-party service was made to further explore the Docker universe.

By the end of the project, this service seemed less and less indispensable as I became comfortable enough with Docker CLI commands.

Nevertheless:

- Useful tool for non-dev administrators
- Allows visualizing the architecture
- Facilitates technical discussions through a graphical representation

---

# IV. Instructions 🛠️

The project is entirely driven by a `Makefile` located at the root. It automates the creation of local volumes and the orchestration of services via Docker Compose.

### 🚀 Basic Commands
* **Launch the full infrastructure**:  
  `make`  
  *(Creates data folders on the host, builds images, and starts containers).*

* **Stop services** (without deletion):  
  `make down`

* **Clean containers and networks**:  
  `make clean`

* **Total Reset** (Removes images, Docker volumes, and data folders):  
  `make fclean`

### 🔧 Administration and Debug
Thanks to the Makefile's *Pattern Rules*, you can target a specific service (`nginx`, `wordpress`, `mariadb`, `ftp`, `redis`, etc.).

* **Individual Management**:  
  Restart a single container without impacting others:  
  `make up-<service_name>` (e.g., `make up-nginx`)

* **Shell Access**:  
  Open an interactive terminal inside a container:  
  `make shell-<service_name>` (e.g., `make shell-mariadb`)

* **Log Consultation**:  
  * All services: `make logs`  
  * Specific service: `make log-<service_name>` (e.g., `make log-wordpress`)

* **Cluster Status**:  
  `make status`

### 📂 Host Data Structure
Persistent volumes are linked to the following tree on the host machine:
* `~/data/wordpress`: CMS source files and media.
* `~/data/mariadb`: Database binary files.

---

# V. Resources 📚

The realization of this project relied on various official and complementary documentary resources.

### Official Documentation

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

### Complementary Resources

- Technical tutorials on YouTube (Docker infrastructure, NGINX reverse proxy, SSL/TLS configuration, WordPress stack setup).  
  *(Consulted creators will be specified later.)*

- Public GitHub repositories consulted for comparison to analyze different Docker architecture approaches.

- Community technical discussions (Stack Overflow, GitHub issues) to clarify specific behaviors.

- AI (see following section)

---

# VI. AI Usage Declaration 🤖

In the context of the Inception project, artificial intelligence was used as an assistance tool, and not as a substitute for personal understanding or project completion.

Its use mainly focused on four axes:

### 1. Editorial Support and Structuring

AI was used to optimize the formatting of non-code documents (README, DOC, Makefile structuring) to improve their clarity and readability.

The conceptual content, architectural choices, and technical explanations come from my personal reflection. AI served to rephrase, structure, and harmonize the presentation.

This approach aimed to avoid a disproportionate investment of time in editorial formulation, in order to remain focused on the technical challenges of the project.

### 2. Explanatory Technical Support

AI was also used as a conceptual clarification tool.

Some official documentations, notably those for services like Redis, proved to be particularly dense or oriented toward general uses outside the Docker context. AI allowed for:

- Obtaining explanations adapted to a precise use case (containerized infrastructure)
- Clarifying related concepts (FastCGI, TLS, Docker networks, volumes, permission management)
- Rephrasing complex notions when official documentation was difficult to use

AI did not replace official documentation but served as a pedagogical complement.

### 3. Occasional Assistance on Secondary Tasks

For the static site included as a bonus, AI was used to accelerate certain CSS parts (setting up grids, visual structuring). Since the main objective of the project was the Docker architecture and not advanced front-end development, this choice optimized time without compromising overall technical understanding.

A minimal HTML boilerplate was also generated to avoid wasting time on a basic structure.

### 4. Verification and Critical Thinking

AI was used as a critical verification tool:

- Validation of technical hypotheses
- Identification of potential blind spots
- Comparison of approaches found on GitHub or in tutorials
- Rephrasing misunderstood concepts

All final decisions on architecture, security, volume management, networks, and services were understood and implemented autonomously.

In conclusion, artificial intelligence was used as a methodological and pedagogical accompaniment tool, in a logic of saving time and conceptual clarification, without delegation of the fundamental design or implementation of the project.