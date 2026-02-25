FROM	alpine:3.18

RUN	apk update && apk add --no-cache redis
RUN mkdir -p /var/lib/redis

CMD ["redis-server", "--protected-mode", "no"]