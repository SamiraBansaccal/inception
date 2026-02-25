
FROM alpine:3.18

RUN	apk update && apk add --no-cache wget tar

RUN wget https://github.com/portainer/portainer/releases/download/2.33.7/portainer-2.33.7-linux-amd64.tar.gz
RUN tar xvf portainer-2.33.7-linux-amd64.tar.gz && rm portainer-2.33.7-linux-amd64.tar.gz

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]