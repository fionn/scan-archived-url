#!/bin/bash

set -euo pipefail

CURL_OPTS=( --retry 3 --retry-connrefused --retry-delay 0 -fsS )

function log {
    echo -e "\e[2m$1\e[22m" >&2
}

function get_snapshot_urls {
    local -r url="$1"
    local -r archive_url="https://archive.org/wayback/available"
    local -r query=".archived_snapshots.closest.url"
    # We take "late August" to be from the 17th to the 31st.
    for timestamp in {20210817..20210831}; do
        curl "${CURL_OPTS[@]}" "$archive_url?url=$url&timestamp=$timestamp" | jq -r "$query" | sed "s/^http:/https:/"
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
        if [[ -n "$snapshot_url" ]]; then
            log "Scraping $snapshot_url"
            snapshot=$(curl "${CURL_OPTS[@]}" "$snapshot_url")
            for delivery_domain in "${delivery_domains[@]}"; do
                log "Scanning $snapshot_url for IoC \"$delivery_domain"\"
                result="$(grep -F "$delivery_domain" <<< "$snapshot" || true)"
                if [[ -n "$result" ]]; then
                    grep --color -F "$delivery_domain" <<< "$result"
                    exit 0
                fi
            done
        fi
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
