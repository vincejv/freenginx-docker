#!/bin/sh
set -e

NGINX_BIN=nginx
ECH_SCRIPT=/usr/local/bin/ech-rotate.sh
LOGFILE="${LOGFILE:-/var/log/nginx/access.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] start-nginx.sh: $*" >> "$LOGFILE"
}

log "Starting nginx..."
# Start nginx in the background
$NGINX_BIN -g 'daemon off;' &
NGINX_PID=$!

# Function to stop nginx and ECH script
cleanup() {
    log "Stopping container..."
    [ -n "$ECH_PID" ] && kill -TERM "$ECH_PID" 2>/dev/null || true
    kill -TERM "$NGINX_PID" 2>/dev/null || true
    wait "$NGINX_PID"
    log "Bye bye..."
    exit 0
}

# Trap signals and forward them
trap 'cleanup' TERM INT

# Wait until nginx is ready (max 10 seconds)
TIMEOUT=10
while ! $NGINX_BIN -t >/dev/null 2>&1; do
    sleep 1
    TIMEOUT=$((TIMEOUT - 1))
    if [ $TIMEOUT -le 0 ]; then
        log "Nginx failed to start, exiting..."
        exit 1
    fi
done

log "Nginx started successfully. Starting ECH rotation..."
$ECH_SCRIPT &
ECH_PID=$!

# Wait for nginx to exit (container main process)
wait "$NGINX_PID"

# If nginx exits, stop ECH script too
[ -n "$ECH_PID" ] && kill -TERM "$ECH_PID" 2>/dev/null || true
wait "$ECH_PID" 2>/dev/null || true
