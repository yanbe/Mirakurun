FROM node:16.14.0-alpine
RUN apk add curl --no-cache --virtual .recpt1-builddeps && \
    curl http://plex-net.co.jp/download/linux/{Linux_Driver.zip} --output "/tmp/#1" && \
    unzip /tmp/Linux_Driver.zip -d /tmp && \
    mkdir -pv /opt/bin && \
    cp /tmp/Linux_Driver/MyRecpt1/MyRecpt1/recpt1/recpt1 /opt/bin/recpt1 && \
    chmod +x /opt/bin/recpt1 && \
    apk add gcompat --no-cache && \
    apk del .recpt1-builddeps
WORKDIR /app
ENV DOCKER=YES NODE_ENV=production
ADD . .
RUN apk add build-base --no-cache --virtual .mirakurun-builddeps && \
    npm install --production=false && \
    npm run build && \
    npm install -g --unsafe-perm --production && \
    cp -r /usr/local/lib/node_modules/mirakurun /app && \
    apk del .mirakurun-builddeps
RUN echo '@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing/' >> /etc/apk/repositories && \
    apk add ccid pcsc-tools@testing dbus openrc && \
    rc-update add dbus default && \
    rc-update add pcscd default && \
    mkdir /run/openrc
ENTRYPOINT ["/bin/sh"]
CMD ["./docker/container-init.sh"]
