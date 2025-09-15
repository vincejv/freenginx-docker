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
    # Common curl options
    # use the DNS batch API schema (posts, patches, puts, deletes)
    CURL_OPTS=(-s --retry 5 --retry-delay 2 --retry-connrefused)

    POSTS=()
    PATCHES=()

    for d in "${SUBDOMAINS_ARR[@]}"; do
        # fetch existing HTTPS record (if any)
        RECORD_RAW=$(curl "${CURL_OPTS[@]}" -G \
            --data-urlencode "type=HTTPS" --data-urlencode "name=$d" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json" \
            "$CF_ZONE_URL/$CF_ZONE_ID/dns_records")

        # no existing record -> create a posts entry
        if [ "$(echo "$RECORD_RAW" | jq -r '.result | length')" = "0" ]; then
            POSTS+=( "$(jq -n --arg name "$d" --arg ech "$ECHCONFIG" '{
            name: $name,
            type: "HTTPS",
            data: { value: ("ech=\"" + $ech + "\""), priority: "1", target: "." }
            }')" )
        else
            # existing record -> produce a patch object by taking the whole record and only updating data.value
            PATCHES+=( "$(echo "$RECORD_RAW" | jq --arg ECH "$ECHCONFIG" '
            .result[0] |
            # ensure .data.value exists and then replace or append ech="..."
            (.data.value // "") as $v |
            if ($v | test("ech=")) then
                .data.value |= sub("ech=\"[^\"]*\""; "ech=\"\($ECH)\"")
            else
                .data.value |= (. + " ech=\"\($ECH)\"")
            end
            ')" )
        fi
    done

    # build JSON arrays (empty arrays if there are no items)
    POSTS_JSON=$(printf '%s\n' "${POSTS[@]}" | jq -s '.' )
    PATCHES_JSON=$(printf '%s\n' "${PATCHES[@]}" | jq -s '.' )

    # final batch body: include only the arrays you need (Cloudflare accepts empty arrays)
    BATCH=$(jq -n --argjson posts "$POSTS_JSON" --argjson patches "$PATCHES_JSON" '{posts:$posts, patches:$patches}')
    log "Submitting API curl batch update: $BATCH"

    # send the batch
    CF_RESULT=$(curl "${CURL_OPTS[@]}" -X POST "$CF_ZONE_URL/$CF_ZONE_ID/dns_records/batch" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$BATCH")

    # show response
    log "$CF_RESULT" | jq -C .
}