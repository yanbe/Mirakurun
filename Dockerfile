FROM node:16.14.0-alpine
RUN apk add curl autoconf automake make gcc g++ --no-cache --virtual .recpt1-builddeps && \
    curl -s http://aniloc.foltia.com/opensource/recpt1/{recpt1-STZ-20170806.zip} --output "/tmp/#1" && \
    unzip /tmp/recpt1-STZ-20170806.zip -d /tmp && \
    curl -s http://aniloc.foltia.com/opensource/recpt1/recpt1/{Makefile.in,checksignal.c,config.h,configure,pt1_dev.h,px4_ioctl.h,recpt1.c,recpt1.h,recpt1core.c,recpt1core.h,recpt1ctl.c} --output "/tmp/recpt1-master/recpt1/#1" && \
    curl http://plex-net.co.jp/download/linux/{Linux_Driver.zip} --output "/tmp/#1" && \
    unzip /tmp/Linux_Driver.zip -d /tmp && \
    cp /tmp/Linux_Driver/MyRecpt1/MyRecpt1/recpt1/asicen_dtv.c \
       /tmp/Linux_Driver/MyRecpt1/MyRecpt1/recpt1/asicen_dtv.h /tmp/recpt1-master/recpt1 && \
    cd /tmp/recpt1-master/recpt1 && \
    ./autogen.sh && \
    chmod +x configure && \
    ./configure --prefix=/opt && \
    make && \
    make install && \
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
