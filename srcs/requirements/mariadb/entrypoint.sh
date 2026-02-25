#!/bin/sh
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi
cat << EOSQL > /tmp/init.sql
USE mysql;
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS ${SQL_DB};
CREATE USER IF NOT EXISTS '${SQL_USER}'@'%' IDENTIFIED BY '$(cat /run/secrets/db_pass)';
GRANT ALL PRIVILEGES ON ${SQL_DB}.* TO '${SQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$(cat /run/secrets/db_root_pass)';
FLUSH PRIVILEGES;
EOSQL

exec mysqld --user=mysql --datadir=/var/lib/mysql --init-file=/tmp/init.sql --console