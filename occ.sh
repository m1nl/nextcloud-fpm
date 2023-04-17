#!/bin/sh

pushd $PWD
cd /var/www/nextcloud/
/sbin/su-exec nginx:nginx /usr/local/bin/php --define apc.enable_cli=1 occ "$@"
popd
