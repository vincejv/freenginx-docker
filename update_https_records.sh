#!/bin/bash
# update_https_records.sh - Reusable DNS Update function

update_https_records() {
    log "Updating DNS HTTPS records..."
    
    # 1. Extract ECHConfig from new key
    ECHCONFIG=$(awk '/-----BEGIN ECHCONFIG-----/{flag=1;next}/-----END ECHCONFIG-----/{flag=0}flag' "$NEW_KEY" | tr -d '\n')
    if [[ -z "$ECHCONFIG" ]]; then
        log "Failed to extract ECHConfig"
        return 1
    fi
    log "Extracted ECHConfig (length: ${#ECHCONFIG})"

    # 2. Extract subdomains
    IFS=' ' read -r -a SUBDOMAINS_ARR <<< "$SUBDOMAINS"
    if [[ ${#SUBDOMAINS_ARR[@]} -eq 0 ]]; then
        log "No subdomains extracted (SUBDOMAINS was empty) not proceeding with ECH key initialization"
        return 1 
    else
        log "Subdomains extracted: ${SUBDOMAINS_ARR[*]}"
    fi

    # Common curl options
    # 3. Publish HTTPS DNS record to Cloudflare (update only ech field)
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
}