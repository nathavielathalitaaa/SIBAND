#!/usr/bin/env bash
set -euo pipefail

# Sesuaikan port Apache dengan env PORT dari Render (default 8000)
PORT="${PORT:-8000}"
sed -ri "s/^Listen [0-9]+/Listen ${PORT}/g" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/g" /etc/apache2/sites-available/000-default.conf

# Pastikan APP_KEY selalu berformat base64 32-byte yang valid untuk Laravel
if [ -n "${APP_KEY:-}" ] && [[ "${APP_KEY}" != base64:* ]]; then
  export APP_KEY="$(php -r "echo 'base64:' . base64_encode(hash('sha256', getenv('APP_KEY'), true));")"
elif [ -z "${APP_KEY:-}" ]; then
  export APP_KEY="$(php -r "echo 'base64:' . base64_encode(random_bytes(32));")"
fi

# Pastikan izin folder writable untuk www-data
mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Jalankan migrasi otomatis & cache konfigurasi
php artisan migrate --force --no-interaction
php artisan config:cache
php artisan route:cache

exec apache2-foreground
