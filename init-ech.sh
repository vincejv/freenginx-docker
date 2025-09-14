#!/bin/bash
# init-ech.sh - Initialize ECH keys, symlinks, and update Cloudflare DNS

set -euo pipefail

DOMAIN="${DOMAIN:?Must set DOMAIN}"
ECH_DIR="${ECH_DIR:-/etc/nginx/echkeys}"
CF_ZONE_URL="https://api.cloudflare.com/client/v4/zones"
CF_ZONE_ID="${CF_ZONE_ID:?Must set CF_ZONE_ID}"
CF_API_TOKEN="${CF_API_TOKEN:?Must set CF_API_TOKEN}"
SUBDOMAINS="${SUBDOMAINS:?Must set SUBDOMAINS (space-separated list)}"
LOGFILE="${LOGFILE:-/var/log/nginx/access.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] init-ech.sh: $*" >> "$LOGFILE"
}

mkdir -p "$ECH_DIR"
cd "$ECH_DIR"

# 1. Generate initial key
NEW_KEY="$ECH_DIR/$DOMAIN.$(date +%Y%m%d%H).pem.ech"
openssl-ech ech -public_name "$DOMAIN" -out "$NEW_KEY"
log "Generated new ECH key: $NEW_KEY"

# 2. Initialize symlinks (all point to the same key initially)
for l in ech previous.ech stale.ech; do
    ln -sf "$(basename "$NEW_KEY")" "$DOMAIN.$l"
done
log "Symlinks initialized: $(ls -l $DOMAIN*.ech | tr '\n' ' | ')"

# 3. Extract ECHConfig
ECHCONFIG=$(awk '/-----BEGIN ECHCONFIG-----/{flag=1;next}/-----END ECHCONFIG-----/{flag=0}flag' "$NEW_KEY" | tr -d '\n')
if [[ -z "$ECHCONFIG" ]]; then
    log "Failed to extract ECHConfig"
    exit 1
fi
log "Extracted ECHConfig (length: ${#ECHCONFIG})"

# 4. Push initial HTTPS DNS record(s) to Cloudflare
CURL_OPTS=(-s --retry 5 --retry-delay 2 --retry-connrefused)
IFS=' ' read -r -a SUBDOMAINS_ARR <<< "$SUBDOMAINS"

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

log "Initial ECH setup complete"
