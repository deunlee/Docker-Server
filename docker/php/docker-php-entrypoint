#!/bin/sh

if [ -n "$TZ" ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
    {
        echo "[PHP]";
        echo "date.timezone = \"$TZ\"";
        echo;
    } > /usr/local/etc/php/conf.d/timezone.ini
else
    >&2 echo "The timezone environment variable is not set. Please set TZ in docker."
fi


# https://github.com/docker-library/php/blob/master/7.3/alpine3.14/fpm/docker-php-entrypoint
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- php-fpm "$@"
fi

exec "$@"
