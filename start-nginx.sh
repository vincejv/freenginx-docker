#!/bin/sh
set -e

NGINX_BIN=nginx
ECH_ROTATE_SCRIPT=/usr/local/bin/ech-rotate.sh
ECH_INIT_SCRIPT=/usr/local/bin/init-ech.sh
ECH_DIR="${ECH_DIR:-/etc/nginx/echkeys}"
DOMAIN="${DOMAIN:?Must set DOMAIN}"
LOGFILE="${LOGFILE:-/var/log/nginx/access.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] start-nginx.sh: $*" >> "$LOGFILE"
}

# Run init-ech if any symlink is missing
if [ ! -L "$ECH_DIR/$DOMAIN.ech" ] || \
   [ ! -L "$ECH_DIR/$DOMAIN.previous.ech" ] || \
   [ ! -L "$ECH_DIR/$DOMAIN.stale.ech" ]; then
    log "One or more ECH symlinks missing. Running init-ech.sh..."
    if ! $ECH_INIT_SCRIPT; then
        log "init-ech.sh failed, stopping container..."
        exit 1
    fi
else
    log "All ECH symlinks exist. Skipping initialization."
fi

log "Starting nginx..."
# Start nginx in the background
$NGINX_BIN -g 'daemon off;' &
NGINX_PID=$!

cleanup() {
    log "Stopping container..."
    [ -n "$ECH_PID" ] && kill -TERM "$ECH_PID" 2>/dev/null || true
    kill -TERM "$NGINX_PID" 2>/dev/null || true
    wait "$NGINX_PID"
    log "Bye bye..."
    exit 0
}

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
$ECH_ROTATE_SCRIPT &
ECH_PID=$!

# Wait for nginx (container main process)
wait "$NGINX_PID"

# Stop ECH script if nginx exits
[ -n "$ECH_PID" ] && kill -TERM "$ECH_PID" 2>/dev/null || true
wait "$ECH_PID" 2>/dev/null || true
