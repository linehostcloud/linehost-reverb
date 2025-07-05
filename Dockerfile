# Multi-stage build for optimized Laravel Reverb Docker image
FROM php:8.3-fpm-alpine AS base

# Set environment variables
ENV WORKDIR="/var/www/html"
ENV RUNNER_USER="www-data"
ENV RUNNER_GROUP="www-data"
ENV RUNNER_UID=82
ENV RUNNER_GID=82
ENV PHP_MEMORY_LIMIT=512M
ENV PHP_MAX_EXECUTION_TIME=0
ENV REVERB_PORT=8080
ENV NGINX_PORT=80

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    nodejs \
    npm \
    redis \
    curl \
    bash \
    git \
    zip \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    postgresql-dev \
    mysql-dev \
    sqlite-dev \
    autoconf \
    g++ \
    make \
    linux-headers

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        mbstring \
        zip \
        exif \
        pcntl \
        bcmath \
        intl \
        opcache \
        sockets

# Install Redis extension
RUN pecl install redis \
    && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# Create application directory
WORKDIR $WORKDIR

# Copy configuration files
COPY config/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/default.conf /etc/nginx/http.d/default.conf
COPY config/supervisor.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/healthcheck-reverb.sh /usr/local/bin/healthcheck-reverb.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/healthcheck-reverb.sh

# Set up directories and permissions
RUN mkdir -p /var/log/supervisor \
    && mkdir -p /var/log/nginx \
    && mkdir -p /run/nginx \
    && mkdir -p /var/cache/nginx \
    && chown -R $RUNNER_USER:$RUNNER_GROUP /var/log/supervisor \
    && chown -R $RUNNER_USER:$RUNNER_GROUP /var/log/nginx \
    && chown -R $RUNNER_USER:$RUNNER_GROUP /run/nginx \
    && chown -R $RUNNER_USER:$RUNNER_GROUP /var/cache/nginx \
    && chown -R $RUNNER_USER:$RUNNER_GROUP $WORKDIR

# Set file limits for WebSocket connections
RUN mkdir -p /etc/security \
    && echo "www-data soft nofile 65536" >> /etc/security/limits.conf \
    && echo "www-data hard nofile 65536" >> /etc/security/limits.conf

# Switch to www-data user for Laravel installation
USER $RUNNER_USER

# Install Laravel with Reverb
RUN composer create-project laravel/laravel . --prefer-dist --no-dev \
    && composer require laravel/reverb pusher/pusher-php-server

# Remove default .env file (will be provided via volume or environment)
RUN rm -f .env

# Set proper permissions
RUN chmod -R 775 storage bootstrap/cache \
    && chown -R $RUNNER_USER:$RUNNER_GROUP storage bootstrap/cache

# Switch back to root for final setup
USER root

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck-reverb.sh

# Expose ports
EXPOSE $NGINX_PORT $REVERB_PORT

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

