FROM node:16.14.0-alpine

RUN set -x \
    apk update && \
    apk add build-base git autoconf automake --no-cache --virtual .recpt1-builddeps
RUN git clone https://github.com/nativeshoes/px_drv.git /tmp/recpt1-nativeshoes && \
    git clone https://github.com/stz2012/recpt1.git /tmp/recpt1-stz2012 && \
    cp /tmp/recpt1-stz2012/recpt1/pt1_dev.h /tmp/recpt1-nativeshoes/recpt1/pt1_dev.h && \
    cd /tmp/recpt1-nativeshoes/recpt1 && \
    sed -i -e 's!\(typedef struct\) msgbuf!\1!' recpt1core.h && \
    sed -i -e 's!\(#define _RECPT1_H_\)!\1\n#include <sys/types.h>\n!' recpt1.h && \
    sed -i -e 's!\(#include "pt1_dev.h"\)!\1\n#include "asicen_dtv.h"\n!' recpt1core.c && \
    chmod +x autogen.sh && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    apk del .recpt1-builddeps && \
    rm -rf /tmp/recpt1-*
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
