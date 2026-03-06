#!/bin/bash

generate_mac_from_path() {
    local input_path="$1"

    # 1. Replicate the Terragrunt _rel_path_label logic
    # Lowercase, replace / with __, and truncate to 63 chars
    local label=$(echo -n "$input_path" | tr '[:upper:]' '[:lower:]' | sed 's/\//__/g' | cut -c 1-63)

    # 2. Generate MD5 hash of the label
    # (Handling both GNU md5sum and BSD/macOS md5)
    local full_hash
    if command -v md5sum >/dev/null; then
        full_hash=$(echo -n "$label" | md5sum | awk '{print $1}')
    else
        full_hash=$(echo -n "$label" | md5)
    fi

    # 3. Extract first 12 chars and force the 2nd char to '2'
    # This matches the HCL: format("%s2%s", substr(h,0,1), substr(h,2,10))
    local char1=$(echo -n "$full_hash" | cut -c 1)
    local rest=$(echo -n "$full_hash" | cut -c 3-12)
    local mac_seed="${char1}2${rest}"

    # 4. Format with colons (aa:bb:cc:dd:ee:ff)
    echo "$mac_seed" | sed 's/../&:/g; s/:$//'
}

# Example usage:
# gen-mac-from-relpath "production/web-server/network"

generate_mac_from_path "$1"
