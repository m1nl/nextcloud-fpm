#!/bin/sh

set -e

ln -s /proc/$$/fd/1 /dev/docker-stdout
ln -s /proc/$$/fd/2 /dev/docker-stderr

export SAVE_HANDLER="${SAVE_HANDLER:-redis}"
export SAVE_PATH="${SAVE_PATH:-tcp://redis:9999}"

export POST_MAX_SIZE="${POST_MAX_SIZE:-512M}"
export UPLOAD_MAX_FILESIZE="${UPLOAD_MAX_FILESIZE:-512M}"
export MAX_FILE_UPLOADS="${MAX_FILE_UPLOADS:-500}"

export NUM_CORES="`nproc --all`"

export PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-512M}"
export PHP_MAX_CHILDREN="${PHP_MAX_CHILDREN:-$((NUM_CORES * 4 > 32 ? NUM_CORES * 8 : 32))}"
export PHP_START_SERVERS="${PHP_START_SERVERS:-$((NUM_CORES * 4))}"
export PHP_MIN_SPARE_SERVERS="${PHP_MIN_SPARE_SERVERS:-$((NUM_CORES * 2))}"
export PHP_MAX_SPARE_SERVERS="${PHP_MAX_SPARE_SERVERS:-$((NUM_CORES * 4))}"
export PHP_MAX_REQUESTS="${PHP_MAX_REQUESTS:-500}"

GOMPLATE="/usr/bin/gomplate"

PHP_CONFIG_TEMPLATE_DIR="/php-config-templates"
PHP_CONFIG_DIR="/usr/local/etc/php/conf.d"

FPM_CONFIG_TEMPLATE_DIR="/fpm-config-templates"
FPM_CONFIG_DIR="/usr/local/etc/php-fpm.d"

init_config() {
  for PHP_CONFIG_TEMPLATE in ${PHP_CONFIG_TEMPLATE_DIR}/* ; do
    PHP_CONFIG_FILENAME="`basename $PHP_CONFIG_TEMPLATE`"
    $GOMPLATE -f "$PHP_CONFIG_TEMPLATE" -o "$PHP_CONFIG_DIR/$PHP_CONFIG_FILENAME"
  done
  
  for FPM_CONFIG_TEMPLATE in ${FPM_CONFIG_TEMPLATE_DIR}/* ; do
    FPM_CONFIG_FILENAME="`basename $FPM_CONFIG_TEMPLATE`"
    $GOMPLATE -f "$FPM_CONFIG_TEMPLATE" -o "$FPM_CONFIG_DIR/$FPM_CONFIG_FILENAME"
  done
}

init_config

if [ $# -gt 0 ] ; then
  COMMAND="$1"
  shift

  exec "$COMMAND" "$@"
  exit $?
fi

SUPERVISORCTL="/usr/bin/supervisorctl"
SUPERVISORD="/usr/bin/supervisord"

SUPERVISORCTLOPTS="-u dummy -p dummy"
SUPERVISORDOPTS="-c /etc/supervisord.conf"
SUPERVISORDPID="/var/run/supervisord.pid"

COMPONENTS="${COMPONENTS:-php-fpm cron}"

reload() {
  $SUPERVISORCTL $SUPERVISORCTLOPTS reload
}

shutdown() {
  $SUPERVISORCTL $SUPERVISORCTLOPTS shutdown
}

trap reload 1
trap shutdown 2 15

$SUPERVISORD $SUPERVISORDOPTS

sleep 1 && kill -0 `cat $SUPERVISORDPID`

for i in $COMPONENTS ; do
  echo "[docker-entrypoint] $i: starting"
  $SUPERVISORCTL $SUPERVISORCTLOPTS start $i &
  sleep 1
done

EXITCODE=0

while (kill -0 `cat $SUPERVISORDPID 2> /dev/null` > /dev/null 2>&1) ; do
  sleep 5

  NUM_FATAL=`( $SUPERVISORCTL $SUPERVISORCTLOPTS status | grep -c FATAL ) || true`
  if [ $NUM_FATAL -gt 0 ] ; then
    echo "[docker-entrypoint] at least one required component stuck in FATAL state - exiting."
    EXITCODE=1
    shutdown
  fi
done

exit $EXITCODE
