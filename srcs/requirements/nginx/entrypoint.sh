#!/bin/sh

sed -i "s/server_name_here/${DOMAIN_NAME}/" /etc/nginx/nginx.conf


if [ ! -f /etc/nginx/ssl/nginx.crt ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/nginx/ssl/nginx.key \
	-out /etc/nginx/ssl/nginx.crt \
	-subj "/C=BE/ST=Brussels/L=Brussels/O=42Belgium/OU=42Belgium/CN=${DOMAIN_NAME}"
fi

exec nginx -g "daemon off;"