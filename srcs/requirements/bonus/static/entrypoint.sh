#!/bin/sh

sed -i "s/server_name_here/${DOMAIN_NAME}/" /etc/nginx/nginx.conf

exec nginx -g "daemon off;"