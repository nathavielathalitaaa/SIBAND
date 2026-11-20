FROM php:8.4-apache

# Install system dependencies & PHP extensions for Laravel (PostgreSQL, MySQL, SQLite)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    libpq-dev \
    libzip-dev \
    libsqlite3-dev \
    && docker-php-ext-install -j"$(nproc)" pdo pdo_pgsql pdo_mysql pdo_sqlite bcmath zip \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

# Point Apache DocumentRoot to Laravel /public and allow .htaccess overrides
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && sed -ri -e 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Install PHP dependencies first (cached Docker layer)
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts

# Copy application source
COPY . .

RUN composer dump-autoload --optimize --no-dev \
    && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod +x /var/www/html/docker-entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/var/www/html/docker-entrypoint.sh"]
