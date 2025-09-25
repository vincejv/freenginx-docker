#!/bin/bash
# generate-ech-key.sh - Reusable ECH Key generator function

generate_ech_key() {
    log "Generating ECH Key..."
    mkdir -p "$ECH_DIR" || log "Failed to create $ECH_DIR"

    # 1. Generate new ECH key
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
    
    log "Generated: $NEW_KEY"
}