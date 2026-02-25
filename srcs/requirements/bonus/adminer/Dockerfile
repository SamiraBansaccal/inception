FROM	alpine:3.18

RUN apk update && apk add --no-cache \
    php81 \
    php81-fpm \
    php81-mysqli \
    php81-session \
    php81-json \
    php81-openssl \
    wget

RUN wget https://www.adminer.org/latest.php -O adminer.php

RUN sed -i 's|listen = 127.0.0.1:9000|listen = 9000|' /etc/php81/php-fpm.d/www.conf
RUN sed -i 's|;daemonize = yes|daemonize = no|' /etc/php81/php-fpm.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]