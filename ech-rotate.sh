#!/bin/bash
# ech-rotate.sh - Rotate ECH keys, reload nginx, and update Cloudflare DNS

set -uo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ech-rotate.sh: $*" >> "$LOGFILE"
}

error_trap() {
    log "An error occurred at line $1"
}
trap 'error_trap $LINENO' ERR

# Configurable via environment variables
DOMAIN="${DOMAIN:?Must set DOMAIN}"
ECH_DIR="${ECH_DIR:-/etc/nginx/echkeys}"
PIDFILE="${PIDFILE:-/var/run/nginx/nginx.pid}"
LOGFILE="${LOGFILE:-/var/log/nginx/access.log}"
CF_ZONE_URL="https://api.cloudflare.com/client/v4/zones"
CF_ZONE_ID="${CF_ZONE_ID:?Must set CF_ZONE_ID}"
CF_API_TOKEN="${CF_API_TOKEN:?Must set CF_API_TOKEN}"
SUBDOMAINS="${SUBDOMAINS:?Must set SUBDOMAINS (space-separated list)}"
ECH_ROTATION="${ECH_ROTATION:-false}"   # default: disabled
KEEP_KEYS="${KEEP_KEYS:-3}"             # number of old timestamped keys to keep

IFS=' ' read -r -a SUBDOMAINS_ARR <<< "$SUBDOMAINS"
if [[ ${#SUBDOMAINS_ARR[@]} -eq 0 ]]; then
    log "No subdomains extracted (SUBDOMAINS was empty) not proceeding with ECH rotation"
    return 1 
else
    log "Subdomains extracted: ${SUBDOMAINS_ARR[*]}"
fi

rotate_ech() {
    log "Rotating ECH keys..."
    mkdir -p "$ECH_DIR" || log "Failed to create $ECH_DIR"

    # 1. Generate new ECH key
    NEW_KEY="$ECH_DIR/$DOMAIN.$(date +%Y%m%d%H).pem.ech"
    openssl-ech ech -public_name "$DOMAIN" -out "$NEW_KEY"
    log "Generated: $NEW_KEY"

    # 2. Ensure symlinks exist, fill missing ones with latest
    cd "$ECH_DIR" || return 1
    ln -sf "$(readlink "$DOMAIN.previous.ech")" "$DOMAIN.stale.ech"
    ln -sf "$(readlink "$DOMAIN.ech")" "$DOMAIN.previous.ech"
    ln -sf "$(basename "$NEW_KEY")" "$DOMAIN.ech"
    log "Symlinks rotated: ech -> $(readlink "$DOMAIN.ech"), previous.ech -> $(readlink "$DOMAIN.previous.ech"), stale.ech -> $(readlink "$DOMAIN.stale.ech")"

    # 4. Reload nginx
    if [[ -f "$PIDFILE" ]]; then
        PID=$(cat "$PIDFILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill -SIGHUP "$PID"
            log "Reloaded nginx (pid $PID)"
        else
            log "Nginx PID $PID is not yet running"
        fi
    else
        log "PID file not found: $PIDFILE"
    fi

    # 5-6. Update DNS Records
    source /usr/local/bin/update_https_records.sh
    update_https_records || { log "Error: Failed to update HTTPS DNS records"; return 1; }

    # 7. Cleanup old keys (keep latest N timestamped files, skip symlink targets)
    cd "$ECH_DIR" || return 1
    # Resolve symlink targets (absolute paths)
    latest_target=$(readlink -f "$DOMAIN.ech" 2>/dev/null || true)
    prev_target=$(readlink -f "$DOMAIN.previous.ech" 2>/dev/null || true)
    stale_target=$(readlink -f "$DOMAIN.stale.ech" 2>/dev/null || true)
    # Sort timestamped files newest first, drop those beyond KEEP_KEYS
    ls -1t "$DOMAIN".*.pem.ech | tail -n +"$((KEEP_KEYS+1))" | while read -r OLDKEY; do
        fullpath=$(readlink -f "$OLDKEY" 2>/dev/null || true)
        [[ -n "$fullpath" ]] || continue

        if [[ "$fullpath" == "$latest_target" || "$fullpath" == "$prev_target" || "$fullpath" == "$stale_target" ]]; then
            log "Skipping symlink target: $OLDKEY"
        else
            rm -f -- "$OLDKEY"
            log "Removed old timestamped key: $OLDKEY"
        fi
    done

    log "Finished ECH key rotation"
}


# Run once or loop depending on ECH_ROTATION
if [[ "$ECH_ROTATION" == "true" ]]; then
    log "Running in cron mode (ECH_ROTATION=true)"
    ROTATION_INTERVAL="${ECH_ROTATION_INTERVAL:-3600}"

    while true; do
        log "Next ECH key rotation will be in $ROTATION_INTERVAL seconds..."
        sleep "$ROTATION_INTERVAL"
        rotate_ech || log "rotate_ech failed, will retry next round"
    done
else
    log "ECH Rotation is disabled (ECH_ROTATION=false)"
fi
