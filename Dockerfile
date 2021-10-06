FROM php:7.4-fpm-alpine

RUN set -eux; \
  apk --no-cache --update add \
    coreutils \
    perl \
    dcron \
    supervisor \
    fcgi \
    file \
    libmagic \
    dpkg \
    zlib \
    bzip2 \
    libpng \
    libzip \
    libjpeg-turbo \
    freetype \
    libxslt \
    libmcrypt \
    icu \
    libzip \
    libldap \
    libsmbclient \
    oniguruma \
    libpq \
    curl \
    unzip \
    gomplate \
    gmp \
    libgomp \
    imagemagick \
    libwebp \
    libxml2 \
    pcre; \
  apk --no-cache --update --virtual .deps1 add \
    dpkg-dev \
    re2c \
    autoconf \
    gcc \
    g++ \
    make \
    libmemcached-dev \
    zlib-dev \
    bzip2-dev \
    libpng-dev \
    libzip-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxslt-dev \
    libmcrypt-dev \
    icu-dev \
    openldap-dev \
    oniguruma-dev \
    postgresql-dev \
    samba-dev \
    gmp-dev \
    imagemagick-dev \
    libwebp-dev \
    libxml2-dev \
    pcre-dev; \
  yes "" | pecl install smbclient; \
  docker-php-ext-enable smbclient; \
  yes "" | pecl install mcrypt; \
  docker-php-ext-enable mcrypt; \
  yes "" | pecl install apcu; \
  docker-php-ext-enable apcu; \
  yes "" | pecl install redis; \
  docker-php-ext-enable redis; \
  yes "" | pecl install imagick; \
  docker-php-ext-enable imagick; \
  docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
  docker-php-ext-install -j$(nproc) gd; \
  docker-php-ext-enable gd; \
  for module in bcmath opcache bz2 exif fileinfo ldap intl mbstring pdo_pgsql zip sockets xsl pcntl gmp; do \
    docker-php-ext-configure $module; \
    docker-php-ext-install -j$(nproc) $module; \
    docker-php-ext-enable $module; \
  done; \
  apk del .deps1; \
  rm -rf /tmp/pear; \
  rm -rf /usr/share/info/*; \
  rm -rf /usr/share/man/*; \
  rm -rf /usr/share/doc/*

RUN set -eux; \
  addgroup -g 101 -S nginx; \
  adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx; \
  mkdir -p /var/cache/nginx; \
  chmod u=rwx,g=rx,o= /var/cache/nginx; \
  chown nginx:nginx /var/cache/nginx

ARG NEXTCLOUD_VERSION=22.2.0

RUN set -eux; \
  curl -sSL https://download.nextcloud.com/server/releases/nextcloud-$NEXTCLOUD_VERSION.tar.bz2 -o /tmp/nextcloud-$NEXTCLOUD_VERSION.tar.bz2; \
  rm -rf /var/www/*; \
  tar xfj /tmp/nextcloud-$NEXTCLOUD_VERSION.tar.bz2 -C /var/www; \
  rm -f /tmp/nextcloud-$NEXTCLOUD_VERSION.tar.bz2; \
  chown nginx:nginx -R /var/www/nextcloud

COPY crontab.nginx /etc

RUN set -eux; \
  mkdir -p /var/www/nextcloud/apps-custom; \
  mkdir -p /var/www/nextcloud/config; \
  mkdir -p /var/www/nextcloud/data; \
  chmod u=rwx,g=rx,o= /var/www/nextcloud/apps-custom; \
  chmod u=rwx,g=rx,o= /var/www/nextcloud/config; \
  chmod u=rwx,g=rx,o= /var/www/nextcloud/data; \
  chown nginx:nginx /var/www/nextcloud/apps-custom; \
  chown nginx:nginx /var/www/nextcloud/config; \
  chown nginx:nginx /var/www/nextcloud/data; \
  /usr/bin/crontab -u nginx /etc/crontab.nginx

VOLUME /var/www/nextcloud/apps-custom
VOLUME /var/www/nextcloud/config
VOLUME /var/www/nextcloud/data

COPY fpm-config-templates /fpm-config-templates
COPY php-config-templates /php-config-templates

COPY supervisord.conf /etc/supervisord.conf

COPY php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY docker-readiness.sh /usr/local/bin/docker-readiness.sh
COPY docker-liveness.sh /usr/local/bin/docker-liveness.sh

WORKDIR /var/www/nextcloud

ENTRYPOINT ["docker-entrypoint.sh"]
