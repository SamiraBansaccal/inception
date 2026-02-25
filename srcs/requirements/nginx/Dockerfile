
FROM alpine:3.18

RUN	apk update && apk add --no-cache nginx openssl

COPY ./nginx.conf /etc/nginx/nginx.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
