FROM node:16.14.0-alpine

LABEL Name="Mirakurun with recpt1 built for PX-W3PE"
LABEL Version=0.0.1

RUN apk --no-cache add build-base git autoconf automake
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
    rm -rf /tmp/recpt1-*
WORKDIR /app
ENV DOCKER=YES NODE_ENV=production
ADD . .
RUN apk --no-cache add build-base && \
    npm install --production=false && \
    npm run build && \
    npm install -g --unsafe-perm --production && \
    cp -r /usr/local/lib/node_modules/mirakurun /app
RUN echo '@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing/' >> /etc/apk/repositories && \
    apk --no-cache add ccid pcsc-tools@testing dbus openrc && \
    rc-update add dbus default && \
    rc-update add pcscd default && \
    mkdir /run/openrc

EXPOSE 40772
ENTRYPOINT ["/bin/sh"]
CMD ["./docker/container-init.sh"]
