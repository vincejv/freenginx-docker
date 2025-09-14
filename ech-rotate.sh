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
    mkdir -p "$ECH_DIR" || log "Failed to create $ECH_DIR"

    # 1. Generate new ECH key
    NEW_KEY="$ECH_DIR/$DOMAIN.$(date +%Y%m%d%H).pem.ech"
    openssl-ech ech -public_name "$DOMAIN" -out "$NEW_KEY"
    log "Generated: $NEW_KEY"

    # 2. Ensure symlinks exist, fill missing ones with latest
    cd "$ECH_DIR" || exit 1
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

    # 5. Extract ECHConfig from new key
    ECHCONFIG=$(awk '/-----BEGIN ECHCONFIG-----/{flag=1;next}/-----END ECHCONFIG-----/{flag=0}flag' "$NEW_KEY" | tr -d '\n')
    if [[ -z "$ECHCONFIG" ]]; then
        log "Failed to extract ECHConfig"
        exit 1
    fi
    log "Extracted ECHConfig (length: ${#ECHCONFIG})"

    # Common curl options
    # 6. Publish HTTPS DNS record to Cloudflare (update only ech field)
    CURL_OPTS=(-s --retry 5 --retry-delay 2 --retry-connrefused)
    for d in "${SUBDOMAINS_ARR[@]}"; do
        RECORD=$(curl "${CURL_OPTS[@]}" -X GET "$CF_ZONE_URL/$CF_ZONE_ID/dns_records?type=HTTPS&name=$d" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json")

        RECORD_ID=$(echo "$RECORD" | jq -r '.result[0].id')
        RECORD_DATA=$(echo "$RECORD" | jq '.result[0].data')

        if [[ "$RECORD_ID" == "null" ]]; then
            log "No HTTPS record found for $d, inserting new HTTPS record"
            UPDATED_DATA=$(jq -n --arg ech "$ECHCONFIG" '{
                value: "ech=\"\($ech)\"",
                priority: "1",
                target: ".",
            }')
            METHOD="POST"
            URL="$CF_ZONE_URL/$CF_ZONE_ID/dns_records"
        else
            log "HTTPS record found for $d, updating ech public key"
            # Replace the ech record in HTTPS DNS record
            UPDATED_DATA=$(echo "$RECORD_DATA" \
            | jq --arg ECH "$ECHCONFIG" '
                if .value | test("ech=")
                then .value |= sub("ech=\"[^\"]*\""; "ech=\"\($ECH)\"")
                else .value += " ech=\"\($ECH)\""
                end
            ')
            METHOD="PUT"
            URL="$CF_ZONE_URL/$CF_ZONE_ID/dns_records/$RECORD_ID"
        fi

        UPDATED_DATA=$(jq -n --arg name "$d" --argjson data "$UPDATED_DATA" '{type:"HTTPS", name:$name, data:$data}')
        log "Pushing updated HTTPS record for $d: $UPDATED_DATA"

        sleep 0.3

        CF_RESULT=$(curl "${CURL_OPTS[@]}" -X "$METHOD" "$URL" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "$UPDATED_DATA") || log "Failed to push DNS record for $d"

        if echo "$CF_RESULT" | grep -q '"success":true'; then
            log "Updated ech for $d (record $RECORD_ID)"
        else
            log "Failed to update ech for $d: $CF_RESULT"
        fi
        sleep 0.3
    done

    # 7. Cleanup old keys (keep latest N timestamped files, skip symlink targets)
    cd "$ECH_DIR" || exit 1
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
    log "Running in loop mode (ECH_ROTATION=true)"
    while true; do
        sleep "${ECH_ROTATION_INTERVAL:-3600}"
        rotate_ech || log "rotate_ech failed, will retry next round"
    done
else
    log "ECH Rotation is disabled (ECH_ROTATION=false)"
fi
