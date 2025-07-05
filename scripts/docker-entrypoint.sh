#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Default environment variables
export APP_ENV=${APP_ENV:-production}
export APP_DEBUG=${APP_DEBUG:-false}
export DB_CONNECTION=${DB_CONNECTION:-mysql}
export DB_HOST=${DB_HOST:-mysql}
export DB_PORT=${DB_PORT:-3306}
export DB_DATABASE=${DB_DATABASE:-laravel}
export DB_USERNAME=${DB_USERNAME:-laravel}
export DB_PASSWORD=${DB_PASSWORD:-secret}
export REDIS_HOST=${REDIS_HOST:-127.0.0.1}
export REDIS_PORT=${REDIS_PORT:-6379}
export REVERB_APP_ID=${REVERB_APP_ID:-app-id}
export REVERB_APP_KEY=${REVERB_APP_KEY:-app-key}
export REVERB_APP_SECRET=${REVERB_APP_SECRET:-app-secret}
export REVERB_HOST=${REVERB_HOST:-0.0.0.0}
export REVERB_PORT=${REVERB_PORT:-8080}
export REVERB_SCHEME=${REVERB_SCHEME:-http}

log "Starting Laravel Reverb Docker Container..."
log "Environment: $APP_ENV"

# Function to wait for service
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1

    log "Waiting for $service_name at $host:$port..."
    
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            error "$service_name is not available after $max_attempts attempts"
            return 1
        fi
        
        warn "Attempt $attempt/$max_attempts: $service_name not ready, waiting..."
        sleep 2
        ((attempt++))
    done
    
    log "$service_name is ready!"
    return 0
}

# Wait for database if using external database
if [ "$DB_CONNECTION" != "sqlite" ] && [ "$DB_HOST" != "127.0.0.1" ] && [ "$DB_HOST" != "localhost" ]; then
    wait_for_service "$DB_HOST" "$DB_PORT" "Database ($DB_CONNECTION)"
fi

# Wait for Redis if using external Redis
if [ "$REDIS_HOST" != "127.0.0.1" ] && [ "$REDIS_HOST" != "localhost" ]; then
    wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis"
fi

# Change to application directory
cd /var/www/html

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    log "Creating .env file..."
    cat > .env << EOF
APP_NAME="Laravel Reverb"
APP_ENV=$APP_ENV
APP_KEY=
APP_DEBUG=$APP_DEBUG
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=$DB_CONNECTION
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

BROADCAST_DRIVER=reverb
CACHE_DRIVER=redis
FILESYSTEM_DISK=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_HOST=$REDIS_HOST
REDIS_PASSWORD=null
REDIS_PORT=$REDIS_PORT

REVERB_APP_ID=$REVERB_APP_ID
REVERB_APP_KEY=$REVERB_APP_KEY
REVERB_APP_SECRET=$REVERB_APP_SECRET
REVERB_HOST=$REVERB_HOST
REVERB_PORT=$REVERB_PORT
REVERB_SCHEME=$REVERB_SCHEME

VITE_REVERB_APP_KEY=\${REVERB_APP_KEY}
VITE_REVERB_HOST=\${REVERB_HOST}
VITE_REVERB_PORT=\${REVERB_PORT}
VITE_REVERB_SCHEME=\${REVERB_SCHEME}
EOF
fi

# Generate application key if not set
if ! grep -q "APP_KEY=base64:" .env; then
    log "Generating application key..."
    php artisan key:generate --force
fi

# Set proper permissions
log "Setting file permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Install/update Composer dependencies if composer.json exists and vendor doesn't
if [ -f composer.json ] && [ ! -d vendor ]; then
    log "Installing Composer dependencies..."
    composer install --no-dev --optimize-autoloader --no-interaction
fi

# Run Laravel optimizations for production
if [ "$APP_ENV" = "production" ]; then
    log "Running production optimizations..."
    
    # Clear and cache configurations
    php artisan config:clear
    php artisan config:cache
    
    # Clear and cache routes
    php artisan route:clear
    php artisan route:cache
    
    # Clear and cache views
    php artisan view:clear
    php artisan view:cache
    
    # Cache events
    php artisan event:cache
else
    log "Development mode - clearing caches..."
    php artisan config:clear
    php artisan route:clear
    php artisan view:clear
    php artisan cache:clear
fi

# Run database migrations if AUTO_MIGRATE is set
if [ "${AUTO_MIGRATE:-false}" = "true" ]; then
    log "Running database migrations..."
    php artisan migrate --force
fi

# Seed database if AUTO_SEED is set
if [ "${AUTO_SEED:-false}" = "true" ]; then
    log "Seeding database..."
    php artisan db:seed --force
fi

# Create storage link if it doesn't exist
if [ ! -L public/storage ]; then
    log "Creating storage link..."
    php artisan storage:link
fi

# Start services based on command
case "$1" in
    "supervisord")
        log "Starting all services with Supervisor..."
        exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
        ;;
    "reverb")
        log "Starting only Reverb server..."
        exec php artisan reverb:start --host="$REVERB_HOST" --port="$REVERB_PORT"
        ;;
    "queue")
        log "Starting only queue worker..."
        exec php artisan queue:work --sleep=3 --tries=3 --max-time=3600
        ;;
    "schedule")
        log "Starting only schedule worker..."
        exec php artisan schedule:work
        ;;
    "migrate")
        log "Running migrations and exiting..."
        php artisan migrate --force
        exit 0
        ;;
    "bash"|"sh")
        log "Starting interactive shell..."
        exec /bin/bash
        ;;
    *)
        log "Starting with custom command: $*"
        exec "$@"
        ;;
esac

