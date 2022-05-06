#!/bin/bash

export SERVER_CONFIG_PATH=/app-config/server.yml
export TUNERS_CONFIG_PATH=/app-config/tuners.yml
export CHANNELS_CONFIG_PATH=/app-config/channels.yml
export SERVICES_DB_PATH=/app-data/services.json
export PROGRAMS_DB_PATH=/app-data/programs.json
export LOGO_DATA_DIR_PATH=/app-data/logo-data

export PATH=/opt/bin:$PATH
export DOCKER=YES
export INIT_PID=$$

# tweaks for glibc memory usage
export MALLOC_ARENA_MAX=2

# trap
function trap_exit() {
  echo "stopping... $(jobs -p)"
  kill $(jobs -p) > /dev/null 2>&1 || echo "already killed."
  /etc/init.d/pcscd stop
  sleep 1
  echo "exit."
}
trap "exit 0" 2 3 15
trap trap_exit 0

if [ ! -e "/opt/bin" ]; then
  mkdir -pv /opt/bin
fi

# rename wrong filename (migration from <= 3.1.1 >= 3.0.0)
if [ -f "/app-data/services.yml" -a ! -f "$SERVICES_DB_PATH" ]; then
  cp -v "/app-data/services.yml" "$SERVICES_DB_PATH"
fi
if [ -f "/app-data/programs.yml" -a ! -f "$PROGRAMS_DB_PATH" ]; then
  cp -v "/app-data/programs.yml" "$PROGRAMS_DB_PATH"
fi

# custom startup script
if [ -e "/opt/bin/startup" ]; then
  echo "executing /opt/bin/startup..."
  /opt/bin/startup
  echo "done."
fi

# only for test purpose
if !(type "arib-b25-stream-test" > /dev/null 2>&1); then
  apk --update add pkgconfig pcsc-lite-dev 
  npm --prefix /opt install arib-b25-stream-test
  ln -sv /opt/node_modules/arib-b25-stream-test/bin/b25 /opt/bin/arib-b25-stream-test
fi

if !(type "recpt1" > /dev/null 2>&1); then
  set -x
  # install dependenices
  apk add curl autoconf automake 
  # get foltia's recpt1 and generate patch
  mkdir /tmp/recpt1-original
  curl -s http://aniloc.foltia.com/opensource/recpt1/{pt1-b14397800eae.tar.bz2} --output "/tmp/#1"
  tar -jxf /tmp/pt1-b14397800eae.tar.bz2 --strip-components 1 --directory /tmp/recpt1-original
  cp -r /tmp/recpt1-original /tmp/recpt1-foltia
  curl -s http://aniloc.foltia.com/opensource/recpt1/{Makefile.in,pt1_dev.h,recpt1.h,recpt1.c} --output "/tmp/recpt1-foltia/recpt1/#1"
  diff -u /tmp/recpt1-original/recpt1 /tmp/recpt1-foltia/recpt1 > /tmp/recpt1-foltia.patch 
  
  # generate patch for 2018 BS transponder migraiton
  mkdir /tmp/recpt1-bsbase
  curl -s http://hg.honeyplanet.jp/pt1/archive/{d56831676696.tar.bz2} --output "/tmp/pt1-#1"
  tar -jxf /tmp/pt1-d56831676696.tar.bz2 --strip-components 1 --directory /tmp/recpt1-bsbase
  mkdir /tmp/recpt1-bs2018
  curl -s http://hg.honeyplanet.jp/pt1/archive/{17b4f7b5dccb.tar.bz2} --output "/tmp/pt1-#1"
  tar -jxf /tmp/pt1-17b4f7b5dccb.tar.bz2 --strip-components 1 --directory /tmp/recpt1-bs2018
  diff -u /tmp/recpt1-bsbase/recpt1/pt1_dev.h /tmp/recpt1-bs2018/recpt1/pt1_dev.h > /tmp/recpt1-bs2018.patch \
    || perl -MEncode -pe 'Encode::from_to($_, "utf8", "eucjp");' /tmp/recpt1-bs2018.patch > /tmp/recpt1-bs2018-euc-jp.patch
  
  # get official pt1 with latest foltia compatible revision
  mkdir /tmp/recpt1-latest
  curl -s http://hg.honeyplanet.jp/pt1/archive/{61ff9cabf962.tar.bz2} --output "/tmp/pt1-#1"
  tar -jxf /tmp/pt1-61ff9cabf962.tar.bz2 --strip-components 1 --directory /tmp/recpt1-latest
  
  # then patch them
  cd /tmp/recpt1-latest/recpt1
  patch -u < /tmp/recpt1-foltia.patch
  patch -u < /tmp/recpt1-bs2018-euc-jp.patch
  
  # patch for musl environment
  cd /tmp/recpt1-latest/recpt1
  sed -i -E 's!(typedef struct )msgbuf!\1!' recpt1.c
  sed -i -E 's!(typedef struct )msgbuf!\1!' recpt1ctl.c
  sed -i -E 's!(#include <sys/stat.h>)!\1\n#include <sys/types.h>!' tssplitter_lite.c
  
  # get as5220 driver from plex
  curl -s http://plex-net.co.jp/download/linux/{Linux_Driver.zip} --output "/tmp/#1"
  unzip -q /tmp/Linux_Driver.zip -d /tmp
  cp /tmp/Linux_Driver/MyRecpt1/MyRecpt1/recpt1/asicen_dtv.c /tmp/Linux_Driver/MyRecpt1/MyRecpt1/recpt1/asicen_dtv.h /tmp/recpt1-latest/recpt1
  
  # build recpt1 for PX-W3PE dtv tuners
  cd /tmp/recpt1-latest/recpt1
  ./autogen.sh 
  ./configure --prefix /opt 
  make
  make install
  cd /app
fi

if [ -e "/etc/init.d/pcscd" ]; then
  rc-status -a
  touch /run/openrc/softlevel
  echo "starting udev..."
  rc-service udev start
  echo "starting dbus..."
  rc-service dbus start
  echo "starting pcscd..."
  rc-service pcscd start

  while :; do
    sleep 1
    timeout 2 pcsc_scan | grep -A 50 "Using reader plug'n play mechanism"
    if [ $? = 0 ]; then
      break;
    fi
    echo "failed!"
  done
fi

function start() {
  if [ "$DEBUG" != "true" ]; then
    export NODE_ENV=production
    node -r source-map-support/register lib/server.js &
  else
    npm run debug &
  fi

  wait
}

function restart() {
  echo "restarting... $(jobs -p)"
  kill $(jobs -p) > /dev/null 2>&1 || echo "already killed."
  sleep 1
  start
}
trap restart 1

start
