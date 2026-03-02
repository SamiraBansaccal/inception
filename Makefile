-include srcs/.env
NAME        	= inception
COMPOSE_FILE	= -f srcs/docker-compose.yml
DOCKER      	= sudo docker-compose $(COMPOSE_FILE)
DATA_DIR    	= /home/$(USER)/data
WP_DATA     	= $(DATA_DIR)/wordpress
DB_DATA     	= $(DATA_DIR)/mariadb
SSL_DATA		= $(DATA_DIR)/ssl
ADMINER_DATA	= $(DATA_DIR)/adminer
PORTAINER_DATA	= $(DATA_DIR)/portainer
SECRETS_DIR 	= ./secrets
SECRET_FILES 	= db_pass.txt \
				 db_root_pass.txt \
				 wp_admin.txt \
				 wp_admin_email.txt \
				 wp_admin_pass.txt \
				 wp_user.txt \
				 wp_user_email.txt \
				 wp_user_pass.txt \
				 portainer_pass.txt

all: $(NAME)

$(NAME): setup_env setup_secrets setup_dirs
	@echo "🏗️  Building and starting $(NAME) containers..."
	$(DOCKER) up -d --build
	@echo "🚀 Houston, $(NAME) is up and running!"

setup_env:
	@if [ ! -f srcs/.env ]; then \
		echo "Creating srcs/.env..."; \
		echo "WP_TITLE=Inception" >> srcs/.env; \
		echo "SQL_DB=wordpress" >> srcs/.env; \
		echo "SQL_USER=wp_user" >> srcs/.env; \
		echo "LOGIN=$(USER)" >> srcs/.env; \
		echo "DOMAIN_NAME=$(USER).42.fr" >> srcs/.env; \
	fi

setup_secrets:
	@mkdir -p $(SECRETS_DIR)
	@if [ ! -f $(SECRETS_DIR)/db_pass.txt ]; then echo "db_pass_val" > $(SECRETS_DIR)/db_pass.txt; fi
	@if [ ! -f $(SECRETS_DIR)/db_root_pass.txt ]; then echo "root_pass_val" > $(SECRETS_DIR)/db_root_pass.txt; fi
	@if [ ! -f $(SECRETS_DIR)/portainer_pass.txt ]; then echo "portainer_pass_val" > $(SECRETS_DIR)/portainer_pass.txt; fi
	@if [ ! -f $(SECRETS_DIR)/wp_admin_email.txt ]; then echo "$(USER)@42.fr" > $(SECRETS_DIR)/wp_admin_email.txt; fi
	@if [ ! -f $(SECRETS_DIR)/wp_admin_pass.txt ]; then echo "admin_pass_val" > $(SECRETS_DIR)/wp_admin_pass.txt; fi
	@if [ ! -f $(SECRETS_DIR)/wp_admin.txt ]; then echo "$(USER)" > $(SECRETS_DIR)/wp_admin.txt; fi
	@if [ ! -f $(SECRETS_DIR)/wp_user_email.txt ]; then echo "user@42.fr" > $(SECRETS_DIR)/wp_user_email.txt; fi
	@if [ ! -f $(SECRETS_DIR)/wp_user_pass.txt ]; then echo "user_pass_val" > $(SECRETS_DIR)/wp_user_pass.txt; fi
	@if [ ! -f $(SECRETS_DIR)/wp_user.txt ]; then echo "sb_user" > $(SECRETS_DIR)/wp_user.txt; fi


setup_dirs:
	@echo "📂 Creating data directories..."
	@mkdir -p $(WP_DATA)
	@mkdir -p $(DB_DATA)
	@mkdir -p $(SSL_DATA)
	@mkdir -p $(ADMINER_DATA)
	@mkdir -p $(PORTAINER_DATA)


# Stoppe les conteneurs sans les détruire
down:
	@echo "🛑 Stopping containers..."
	$(DOCKER) down
	@echo "💤 Containers stopped."

# Détruit les conteneurs et les réseaux
clean:
	@echo "🧹 Cleaning up containers and networks..."
	$(DOCKER) down -v

# Nettoyage atomique : détruit tout (images, volumes docker, et dossiers locaux)
fclean: clean
	@echo "🧨 Obliterating all traces (images, docker volumes, data folders)..."
	@sudo docker system prune -af --volumes
	@sudo rm -rf $(DATA_DIR)
	@echo "💥 Boom. Everything is gone."

# Reconstruit tout de zéro
re: fclean all

# -----------------------------------------------------------------------------
# 🔧 Outils de debug (Globaux)
# -----------------------------------------------------------------------------

logs:
	@echo "📜 Tailing all logs..."
	$(DOCKER) logs -f

status:
	@echo "📊 Containers status:"
	$(DOCKER) ps

# -----------------------------------------------------------------------------
# 🎯 Gestion par Conteneur (Pattern Rules)
# Utilisation : make up-<service>, make log-<service>, make shell-<service>
# Exemple : make shell-mariadb, make log-wordpress, make up-nginx
# -----------------------------------------------------------------------------

# (Re)lance un seul conteneur
up-%:
	@echo "🚀 Starting/Rebuilding $*..."
	$(DOCKER) up -d --build $*

# Affiche les logs spécifiques d'un conteneur
log-%:
	@echo "📜 Tailing logs for $*..."
	$(DOCKER) logs -f $*

# Ouvre un shell dans un conteneur spécifique
shell-%:
	@echo "🐚 Opening shell in $*..."
	$(DOCKER) exec -it $* /bin/sh

.PHONY: all down clean fclean re logs status