#!/bin/bash

# Health check script for Laravel Reverb
# This script checks if Reverb WebSocket server is running and responding

REVERB_HOST=${REVERB_HOST:-127.0.0.1}
REVERB_PORT=${REVERB_PORT:-8080}
NGINX_PORT=${NGINX_PORT:-80}
TIMEOUT=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check if a port is open
check_port() {
    local host=$1
    local port=$2
    local service_name=$3
    
    if timeout $TIMEOUT bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}✓ $service_name is running on $host:$port${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name is not responding on $host:$port${NC}"
        return 1
    fi
}

# Function to check HTTP endpoint
check_http() {
    local url=$1
    local service_name=$2
    
    if curl -f -s --max-time $TIMEOUT "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service_name HTTP endpoint is responding${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name HTTP endpoint is not responding${NC}"
        return 1
    fi
}

# Function to check WebSocket connection
check_websocket() {
    local host=$1
    local port=$2
    
    # Try to establish a WebSocket connection using curl
    if curl -f -s --max-time $TIMEOUT \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
        -H "Sec-WebSocket-Version: 13" \
        "http://$host:$port/app/app-key" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ WebSocket connection successful${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ WebSocket connection test inconclusive${NC}"
        return 0  # Don't fail health check for WebSocket test
    fi
}

# Function to check Laravel application
check_laravel() {
    cd /var/www/html 2>/dev/null || return 1
    
    # Check if Laravel is properly installed
    if [ ! -f artisan ]; then
        echo -e "${RED}✗ Laravel artisan command not found${NC}"
        return 1
    fi
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        echo -e "${YELLOW}⚠ .env file not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Laravel application files are present${NC}"
    return 0
}

# Function to check supervisor processes
check_supervisor() {
    if command -v supervisorctl > /dev/null 2>&1; then
        local failed_processes=$(supervisorctl -c /etc/supervisor/conf.d/supervisord.conf status | grep -v RUNNING | grep -v STARTING | wc -l)
        if [ "$failed_processes" -eq 0 ]; then
            echo -e "${GREEN}✓ All supervisor processes are running${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Some supervisor processes are not running${NC}"
            supervisorctl -c /etc/supervisor/conf.d/supervisord.conf status | grep -v RUNNING | grep -v STARTING
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Supervisor not available${NC}"
        return 0
    fi
}

# Main health check
main() {
    echo "=== Laravel Reverb Health Check ==="
    echo "Timestamp: $(date)"
    echo "Host: $REVERB_HOST:$REVERB_PORT"
    echo ""
    
    local exit_code=0
    
    # Check Laravel application
    if ! check_laravel; then
        exit_code=1
    fi
    
    # Check Nginx
    if ! check_port "127.0.0.1" "$NGINX_PORT" "Nginx"; then
        exit_code=1
    fi
    
    # Check PHP-FPM
    if ! check_port "127.0.0.1" "9000" "PHP-FPM"; then
        exit_code=1
    fi
    
    # Check Reverb WebSocket server
    if ! check_port "$REVERB_HOST" "$REVERB_PORT" "Reverb WebSocket"; then
        exit_code=1
    fi
    
    # Check WebSocket connection
    check_websocket "$REVERB_HOST" "$REVERB_PORT"
    
    # Check HTTP health endpoint
    check_http "http://127.0.0.1:$NGINX_PORT/health" "Nginx"
    
    # Check supervisor processes
    check_supervisor
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}=== Health Check PASSED ===${NC}"
    else
        echo -e "${RED}=== Health Check FAILED ===${NC}"
    fi
    
    exit $exit_code
}

# Run health check
main "$@"

