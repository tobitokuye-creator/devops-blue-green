#!/usr/bin/env bash
set -e

ACTIVE_POOL=${ACTIVE_POOL:-blue}
BLUE_HOST=${BLUE_HOST:-app_blue:3000}
GREEN_HOST=${GREEN_HOST:-app_green:3000}

if [ "$ACTIVE_POOL" = "blue" ]; then
  PRIMARY_HOST="$BLUE_HOST"
  SECONDARY_HOST="$GREEN_HOST"
else
  PRIMARY_HOST="$GREEN_HOST"
  SECONDARY_HOST="$BLUE_HOST"
fi

mkdir -p /etc/nginx/conf.d /var/cache/nginx /var/run

# Render template
envsubst '\$PRIMARY_HOST \$SECONDARY_HOST' \
  < /etc/nginx/templates/nginx.conf.template \
  > /etc/nginx/conf.d/default.conf

nginx -g 'daemon off;'
