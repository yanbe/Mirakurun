FROM node:16.14.0-alpine
RUN echo '@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing/' >> /etc/apk/repositories
RUN apk --update add ccid pcsc-tools@testing dbus udev openrc
WORKDIR /app
ENV DOCKER=YES
ADD . .
RUN apk add build-base && \
    npm install && \
    npm run build && \
    npm install -g --unsafe-perm --production && \
    cp -r /usr/local/lib/node_modules/mirakurun /app
RUN rc-update add udev default && \
    rc-update add dbus default && \
    rc-update add pcscd default && \
    mkdir /run/openrc
ENTRYPOINT ["/bin/sh"]
CMD ["./docker/container-init.sh"]
EXPOSE 40772 9229
