FROM	alpine:3.18

RUN	apk update && apk add --no-cache vsftpd openssl

COPY	./vsftpd.conf /etc/vsftpd/vsftpd.conf

COPY 	entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]