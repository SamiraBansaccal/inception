#!/bin/sh


adduser -D -h /var/www/html -G nobody "$(cat /run/secrets/wp_admin)"
echo "$(cat /run/secrets/wp_admin):$(cat /run/secrets/wp_admin_pass)" | chpasswd

chown -R nobody:nobody /var/www/html
chmod -R 775 /var/www/html
umask 0002

exec vsftpd /etc/vsftpd/vsftpd.conf