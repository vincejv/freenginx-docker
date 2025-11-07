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

reload_nginx() {
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
}

cleanup_tempfiles() {
    log "Cleaning up temporary files"
    rm -f -- "$current_file" "$backup_file"
}

rotate_ech() {
    log "Rotating ECH keys..."
    
    # 1. Backup DNS records for rollback
    log "Backing up current HTTPS DNS records..."
    backup_file=$(mktemp)

    BACKUP_RESP=$(curl -s --fail-with-body --retry 5 --retry-delay 2 --retry-connrefused -X GET \
        "$CF_ZONE_URL/$CF_ZONE_ID/dns_records?type=HTTPS" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" ) || {
            log "Failed to contact Cloudflare for backup"
            cleanup_tempfiles
            return 1
        }

    # Validate JSON and success flag
    if ! jq -e '.success == true and (.result | type=="array")' >/dev/null 2>&1 <<<"$BACKUP_RESP"; then
        log "Backup failed: invalid or unsuccessful Cloudflare response"
        echo "$BACKUP_RESP" | jq -C . >&2 || echo "$BACKUP_RESP" >&2
        cleanup_tempfiles
        return 1
    fi

    # Write only validated data
    echo "$BACKUP_RESP" > "$backup_file"
    log "Backup saved to $backup_file (entries: $(jq '.result | length' "$backup_file"))"

    # 2. Generate ECH key file
    source /usr/local/bin/generate-ech-key.sh
    generate_ech_key

    # 3. Ensure symlinks exist, fill missing ones with latest
    cd "$ECH_DIR" || { cleanup_tempfiles; return 1; }

    # Before rotation, capture current symlinks for rollback
    old_latest=$(readlink -f "$DOMAIN.ech" 2>/dev/null || true)
    old_previous=$(readlink -f "$DOMAIN.previous.ech" 2>/dev/null || true)
    old_stale=$(readlink -f "$DOMAIN.stale.ech" 2>/dev/null || true)

    ln -sf "$(readlink "$DOMAIN.previous.ech")" "$DOMAIN.stale.ech"
    ln -sf "$(readlink "$DOMAIN.ech")" "$DOMAIN.previous.ech"
    ln -sf "$(basename "$NEW_KEY")" "$DOMAIN.ech"
    log "Symlinks rotated: ech -> $(readlink "$DOMAIN.ech"), previous.ech -> $(readlink "$DOMAIN.previous.ech"), stale.ech -> $(readlink "$DOMAIN.stale.ech")"

    # 4. Reload nginx
    reload_nginx

    # 5-6. Update DNS Records
    source /usr/local/bin/update-https-records.sh
    # DNS update
    if ! update_https_records; then
        log "Error: Failed to update HTTPS DNS records, rolling back ECH keys in nginx..."

        # Roll back symlinks to old state
        [[ -n "$old_latest"   ]] && ln -sf "$(basename "$old_latest")"   "$DOMAIN.ech"
        [[ -n "$old_previous" ]] && ln -sf "$(basename "$old_previous")" "$DOMAIN.previous.ech"
        [[ -n "$old_stale"    ]] && ln -sf "$(basename "$old_stale")"    "$DOMAIN.stale.ech"

        # Optionally delete the new key if not needed and reload nginx
        rm -f -- "$NEW_KEY"
        log "Deleted the newly generated key: ${NEW_KEY}"
        reload_nginx

        log "Rolling back DNS updates..."
        # Get current state for rollback comparison
        log "Fetching current HTTPS DNS records before rollback..."
        current_file=$(mktemp)

        CURRENT_RESP=$(curl -s --fail-with-body --retry 5 --retry-delay 2 --retry-connrefused -X GET \
            "$CF_ZONE_URL/$CF_ZONE_ID/dns_records?type=HTTPS" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json") || {
                log "Failed to contact Cloudflare for current state during rollback"
                cleanup_tempfiles
                return 1
            }

        # Validate Cloudflare JSON and success flag
        if ! jq -e '.success == true and (.result | type=="array")' >/dev/null 2>&1 <<<"$CURRENT_RESP"; then
            log "Invalid or unsuccessful Cloudflare response when fetching current state"
            echo "$CURRENT_RESP" | jq -C . >&2 || echo "$CURRENT_RESP" >&2
            cleanup_tempfiles
            return 1
        fi

        # Save only verified response
        echo "$CURRENT_RESP" > "$current_file"
        log "Fetched current state successfully (entries: $(jq '.result | length' "$current_file"))"

        # Collect rollback candidates
        ROLLBACK=()
        while IFS= read -r rec; do
            rec_id=$(jq -r '.id' <<<"$rec")
            cur=$(jq -c --arg id "$rec_id" '.result[] | select(.id==$id)' "$current_file")

            if [[ "$rec" != "$cur" ]]; then
                log "Will restore record $rec_id"
                # Make sure to keep only fields CF accepts, including id
                clean=$(jq '{id, type, name, ttl, proxied, data, comment, tags}' <<<"$rec")
                ROLLBACK+=("$clean")
            fi
        done < <(jq -c '.result[]' "$backup_file")

        if [ "${#ROLLBACK[@]}" -gt 0 ]; then
            # Build batch body with puts
            PUTS_JSON=$(printf '%s\n' "${ROLLBACK[@]}" | jq -s '.')
            BATCH=$(jq -n --argjson puts "$PUTS_JSON" '{puts:$puts}')

            log "Submitting rollback batch with ${#ROLLBACK[@]} records: $BATCH"
            CF_RESULT=$(curl -s --fail-with-body --retry 5 --retry-delay 2 --retry-connrefused -X POST "$CF_ZONE_URL/$CF_ZONE_ID/dns_records/batch" \
                -H "Authorization: Bearer $CF_API_TOKEN" \
                -H "Content-Type: application/json" \
                --data "$BATCH")

            if echo "$CF_RESULT" | grep -q '"success":true'; then
                log "Rollback batch applied successfully"
            else
                log "Rollback batch failed: $CF_RESULT"
            fi
        else
            log "No changes detected, nothing to rollback"
        fi

        cleanup_tempfiles
        log "ECH key rotation failed, rollback successful"
        return 1
    fi

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

    cleanup_tempfiles
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
