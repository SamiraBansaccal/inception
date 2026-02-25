FROM	alpine:3.18

RUN	apk update && apk add --no-cache \
	php81 \
	php81-fpm \
	php81-mysqli \
    php81-json \
    php81-dom \
    php81-openssl \
    php81-zip \
    php81-curl \
    php81-fileinfo \
    php81-mbstring \
	php81-phar \
	php81-tokenizer \
    wget \
    tar \
	php81-pecl-redis \
	php81-ctype

WORKDIR /var/www/html
RUN	wget https://wordpress.org/latest.tar.gz
RUN tar -xzf latest.tar.gz --strip-components=1 && rm latest.tar.gz
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

RUN sed -i 's|listen = 127.0.0.1:9000|listen = 9000|' /etc/php81/php-fpm.d/www.conf
RUN sed -i 's|;daemonize = yes|daemonize = no|' /etc/php81/php-fpm.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]