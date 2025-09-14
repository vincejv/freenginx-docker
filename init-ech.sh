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

# 3-4. Update DNS Records
source ./update_https_records.sh
update_https_records || { log "Error: Failed to update HTTPS DNS records"; exit 1; }

log "Initial ECH setup complete"
