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
if command -v openssl-ech >/dev/null 2>&1; then
    log "Detected openssl-ech, using this to generate ECH keys..."
    openssl-ech ech -public_name "$DOMAIN" -out "$NEW_KEY"
else
    log "Detected BoringSSL, using this to generate ECH keys..."
    bssl generate-ech -out-ech-config tmp.echconfig.bin -out-ech-config-list tmp.echconfiglist.bin -out-private-key tmp.echkey.bin -config-id 0 -public-name "$DOMAIN"
    (echo "-----BEGIN PRIVATE KEY-----"; { printf '\060\056\002\001\000\060\005\006\003\053\145\156\004\042\004\040'; cat tmp.echkey.bin; } | openssl base64; echo "-----END PRIVATE KEY-----"; echo "-----BEGIN ECHCONFIG-----"; openssl base64 < tmp.echconfiglist.bin; echo "-----END ECHCONFIG-----") > "$NEW_KEY"
    rm -f tmp.echconfig.bin tmp.echconfiglist.bin tmp.echkey.bin
fi
log "Generated new ECH key: $NEW_KEY"

# 2. Initialize symlinks (all point to the same key initially)
for l in ech previous.ech stale.ech; do
    ln -sf "$(basename "$NEW_KEY")" "$DOMAIN.$l"
done
log "Symlinks initialized: ech -> $(readlink "$DOMAIN.ech"), previous.ech -> $(readlink "$DOMAIN.previous.ech"), stale.ech -> $(readlink "$DOMAIN.stale.ech")"

# 3-4. Update DNS Records
source /usr/local/bin/update_https_records.sh
update_https_records >>"$LOGFILE" 2>&1 &

log "Initial ECH setup complete, DNS records will be updated in the background"
