#!/bin/sh

if [ ! -f /var/www/adminer/adminer.php ]; then
	mkdir -p /var/www/adminer
	mv adminer.php  /var/www/adminer/adminer.php
fi
rm -rf adminer.php
exec php-fpm81 -F