#!/bin/sh

exec /portainer/portainer -p :9000 --data /data -H unix:///var/run/docker.sock --admin-password-file /run/secrets/portainer_pass