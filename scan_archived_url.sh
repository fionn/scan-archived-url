#!/bin/bash

set -euo pipefail

function log {
    echo -e "\e[2m$1\e[22m" >&2
}

function get_snapshot_urls {
    local -r url="$1"
    local -r archive_url="https://archive.org/wayback/available"
    local -r query=".archived_snapshots.closest.url"
    # We take "late August" to be from the 17th to the 31st.
    for timestamp in {20210817..20210831}; do
        curl -fsS "$archive_url?url=$url&timestamp=$timestamp" | jq -r "$query" | sed "s/^http:/https:/"
    done
}

function main {
    # Delivery domains are from the TAG report. Only the first element, the IP
    # address, is likely to be relevant for the first stage.
    delivery_domains=( "103.255.44.56" "appleid-server.com" "apple-webservice.com" "amnestyhk.org" )

    url="$1"

    log "Collecting metadata for $url"
    mapfile -t snapshot_urls < <(get_snapshot_urls "$url")
    mapfile -t snapshot_urls < <(for v in "${snapshot_urls[@]/null}"; do echo "$v"; done | sort -u)

    for snapshot_url in "${snapshot_urls[@]}"; do
        log "Scraping $snapshot_url"
        snapshot=$(curl -fsS "$snapshot_url")
        for delivery_domain in "${delivery_domains[@]}"; do
            log "Checking $snapshot_url for IoC \"$delivery_domain"\"
            result="$(grep "$delivery_domain" <<< "$snapshot" || true)"
            [[ -n "$result" ]] \
                && grep --color "$delivery_domain" <<< "$result"\
                && exit 0
        done
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
