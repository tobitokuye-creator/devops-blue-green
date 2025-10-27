#!/usr/bin/env bash
set -e


# This script runs inside the nginx container at startup (mounted into /docker-entrypoint.d)
# It renders the nginx.conf from template using ACTIVE_POOL to choose primary/backup mapping.


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


# Populate template
envsubst '\$PRIMARY_HOST \$SECONDARY_HOST' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/conf.d/default.conf


# Ensure permissions
chown -R nginx:nginx /var/cache/nginx /var/run


# Let the official entrypoint continue (nginx -g 'daemon off;')
