FROM alpine:3.18

RUN apk update && apk add --no-cache nginx

RUN mkdir -p /var/www/static
COPY ./www/index.html /var/www/static/index.html
COPY ./www/styles.css /var/www/static/styles.css

COPY nginx.conf /etc/nginx/nginx.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]