#!/bin/sh

if [ ! -f wp-config.php ]; then
	wp config create \
        --dbname=${SQL_DB} \
        --dbuser=${SQL_USER} \
        --dbpass=$(cat /run/secrets/db_pass) \
        --dbhost=mariadb \
        --allow-root
	wp config set WP_REDIS_HOST redis --allow-root
    wp config set WP_REDIS_PORT 6379 --raw --allow-root
    wp config set WP_CACHE true --raw --allow-root
fi

if ! wp core is-installed --allow-root; then
	wp core install \
		--url=https://${DOMAIN_NAME} \
		--title=${WP_TITLE} \
		--admin_user=$(cat /run/secrets/wp_admin) \
		--admin_password=$(cat /run/secrets/wp_admin_pass) \
		--admin_email=$(cat /run/secrets/wp_admin_email) \
		--skip-email \
		--allow-root

	wp user create \
        $(cat /run/secrets/wp_user) \
        $(cat /run/secrets/wp_user_email) \
        --user_pass=$(cat /run/secrets/wp_user_pass) \
        --role=author \
        --allow-root

		wp plugin install redis-cache --activate --allow-root
		wp redis enable --allow-root
fi

chown -R nobody:nobody /var/www/html
chmod -R 775 /var/www/html
umask 0002

exec php-fpm81 -F