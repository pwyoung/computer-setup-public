#!/bin/bash

# Header
printf "%-20s | %-12s | %-12s | %-s\n" "Directory" "Total Files" "Total Size" "Breakdown by Suffix"
printf "%s\n" "------------------------------------------------------------------------------------------"

for dir in */ ; do
    dir_name=${dir%/}

    # Using awk to handle math and formatting
    find "$dir_name" -type f -printf "%s %f\n" 2>/dev/null | awk -v dir="$dir_name" '
    function human(b) {
        if (b < 1024) return sprintf("%d B", b);
        b /= 1024;
        if (b < 1024) return sprintf("%d KiB", int(b + 0.5));
        b /= 1024;
        if (b < 1024) return sprintf("%d MiB", int(b + 0.5));
        b /= 1024;
        return sprintf("%d GiB", int(b + 0.5));
    }
    {
        size = $1;
        file = $0; sub(/^[0-9]+ /, "", file);
        match(file, /\.[^.]+$/);
        ext = (RSTART > 0) ? substr(file, RSTART+1) : "none";

        count++;
        total_size += size;
        ext_count[ext]++;
        ext_size[ext] += size;
    }
    END {
        if (count == "") { exit }
        printf "%-20s | %-12d | %-12s | ", dir, count, human(total_size);
        for (e in ext_count) {
            printf "%s(%d: %s) ", e, ext_count[e], human(ext_size[e]);
        }
        printf "\n";
    }'
done
