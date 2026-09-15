#!/bin/sh
set -e

# Ensure writable runtime directories
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Ensure the SQLite database exists (respect DB_DATABASE override, else default path)
if [ -n "${DB_DATABASE:-}" ]; then
    DB_PATH="$DB_DATABASE"
else
    DB_PATH="/var/www/html/database/database.sqlite"
fi
mkdir -p "$(dirname "$DB_PATH")"
touch "$DB_PATH"
chown -R www-data:www-data "$(dirname "$DB_PATH")"

# First run / deploy setup
if [ -z "$APP_KEY" ]; then
    export APP_KEY="base64:$(php -r 'echo base64_encode(random_bytes(32));')"
fi
php /var/www/html/artisan package:discover --ansi --no-interaction
php /var/www/html/artisan migrate --force --no-interaction
php /var/www/html/artisan config:cache --no-interaction
php /var/www/html/artisan view:cache --no-interaction

# Render nginx config with the port provided by the platform (defaults to 8080)
export PORT="${PORT:-8080}"
envsubst '${PORT}' < /etc/nginx/conf.d/nginx.conf.template > /etc/nginx/conf.d/default.conf

# Start php-fpm + nginx + queue worker
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf