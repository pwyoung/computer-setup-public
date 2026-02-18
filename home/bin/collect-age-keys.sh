#!/bin/bash

collect_all_age_keys() {
    local output_file="keys.txt.collected"
    local search_path="${1:-.}"

    echo "Scanning for all age public and private keys in: $search_path"

    # 1. find: look for all files
    # 2. grep: match both public (age1...) and private (AGE-SECRET-KEY-1...)
    # 3. sed: remove the filename prefix grep adds (filename:key -> key)
    # 4. awk: filter out duplicates without sorting (preserves first discovery)
    find "$search_path" -type f -not -path '*/.*' -exec grep -hE "(age1[a-z0-9]{58}|AGE-SECRET-KEY-1[A-Z0-9]{58})" {} + | \
    awk '!seen[$0]++' > "$output_file"

    echo "Extraction complete."
    echo "Results saved to: $(pwd)/$output_file"
    echo "Keys found: $(wc -l < "$output_file")"
}

collect_all_age_keys
