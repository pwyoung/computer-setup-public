#!/usr/bin/env bash
set -euo pipefail

REGISTRY=""
OUTPUT_FORMAT="table"

# Accept all manifest types so the registry returns whatever format it has stored
MANIFEST_ACCEPT="application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json"

usage() {
  cat >&2 <<'EOF'
Usage: list-registry-images.sh -r|--registry <url> [OPTIONS]

Fetch and display metadata for all images in a Docker registry.

Options:
  -r|--registry  Registry URL, e.g. localhost:5000   [required]
  -f|--format    Output format: table|json           (default: table)
  -h|--help      Show this help

Examples:
  list-registry-images.sh --registry localhost:5000
  list-registry-images.sh --registry localhost:5000 --format json | jq -s '.'
EOF
  exit 1
}

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--registry) REGISTRY="${2:-}";      shift 2 ;;
    -f|--format)   OUTPUT_FORMAT="${2:-}"; shift 2 ;;
    -h|--help)     usage ;;
    *)             echo "Error: unknown option: $1" >&2; usage ;;
  esac
done

[[ -z "$REGISTRY" ]]      && { echo "Error: --registry is required" >&2; usage; }
[[ -z "$OUTPUT_FORMAT" ]] && { echo "Error: --format requires a value" >&2; usage; }

case "$OUTPUT_FORMAT" in
  table|json) ;;
  *) echo "Error: --format must be 'table' or 'json'" >&2; exit 1 ;;
esac

REGISTRY="${REGISTRY%/}"

reg_get() {
  curl -sf -H "Accept: ${2:-application/json}" "http://${REGISTRY}${1}"
}

get_digest() {
  curl -sf -I -H "Accept: ${MANIFEST_ACCEPT}" \
    "http://${REGISTRY}/v2/${1}/manifests/${2}" \
    | grep -i "^docker-content-digest:" | tr -d '\r' | awk '{print $2}'
}

human_size() {
  awk -v b="${1:-0}" 'BEGIN {
    if      (b >= 1073741824) printf "%.1f GB", b/1073741824
    else if (b >= 1048576)    printf "%.1f MB", b/1048576
    else if (b >= 1024)       printf "%.1f KB", b/1024
    else                      printf "%d B",    b
  }'
}

# Fetch config blob and extract metadata fields into globals
# Sets: g_created, g_arch, g_os, g_version
fetch_config_meta() {
  local repo="$1" config_digest="$2"
  g_created="" g_arch="" g_os="" g_version=""
  [[ -z "$config_digest" ]] && return
  local cfg
  cfg=$(reg_get "/v2/${repo}/blobs/${config_digest}" 2>/dev/null || echo '{}')
  g_created=$(echo "$cfg" | jq -r '.created // ""' | cut -c1-19 | tr 'T' ' ')
  g_arch=$(echo "$cfg"    | jq -r '.architecture // ""')
  g_os=$(echo "$cfg"      | jq -r '.os // ""')
  g_version=$(echo "$cfg" | jq -r '
    (.config.Labels // {}) |
    .["org.opencontainers.image.version"] //
    .["version"] //
    .["app.version"] //
    ""')
}

print_row() {
  local name="$1" tag="$2" digest="$3" size="$4" arch="$5" os="$6" created="$7" version="$8"
  local short_digest="${digest:7:12}"
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    jq -cn \
      --arg  name    "$name"    \
      --arg  tag     "$tag"     \
      --arg  digest  "$digest"  \
      --argjson size "$size"    \
      --arg  created "$created" \
      --arg  arch    "$arch"    \
      --arg  os      "$os"      \
      --arg  version "$version" \
      '{name:$name, tag:$tag, digest:$digest, size_bytes:$size,
        created:$created, arch:$arch, os:$os, version:$version}'
  else
    printf '%-42s %-15s %-10s %-7s %-7s %-20s %s\n' \
      "${name}:${tag}" "$short_digest" "$(human_size "$size")" \
      "$arch" "$os" "$created" "$version"
  fi
}

repos=$(reg_get "/v2/_catalog" | jq -r '.repositories // [] | .[]') || {
  echo "Error: cannot reach registry at http://${REGISTRY}" >&2
  exit 1
}

if [[ -z "$repos" ]]; then
  echo "No repositories found in registry ${REGISTRY}"
  exit 0
fi

[[ "$OUTPUT_FORMAT" == "table" ]] && \
  printf '%-42s %-15s %-10s %-7s %-7s %-20s %s\n' IMAGE DIGEST SIZE ARCH OS CREATED VERSION

while IFS= read -r repo; do
  tags=$(reg_get "/v2/${repo}/tags/list" | jq -r '.tags // [] | .[]') || continue
  [[ -z "$tags" ]] && continue

  while IFS= read -r tag; do
    manifest=$(reg_get "/v2/${repo}/manifests/${tag}" "$MANIFEST_ACCEPT") || continue
    [[ -z "$manifest" ]] && continue

    digest=$(get_digest "$repo" "$tag")
    media_type=$(echo "$manifest" | jq -r '.mediaType // ""')

    case "$media_type" in
      *index*|*list*)
        # Multi-platform image: one row per platform, fetching each sub-manifest
        while IFS= read -r entry; do
          sub_digest=$(echo "$entry" | jq -r '.digest')
          plat_arch=$(echo "$entry"  | jq -r '.platform.architecture // ""')
          plat_os=$(echo "$entry"    | jq -r '.platform.os // ""')

          sub_manifest=$(reg_get "/v2/${repo}/manifests/${sub_digest}" \
            "application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json") || continue
          [[ -z "$sub_manifest" ]] && continue

          config_digest=$(echo "$sub_manifest" | jq -r '.config.digest // empty')
          total_size=$(echo "$sub_manifest"    | jq -r '[.layers[].size] | add // 0')

          fetch_config_meta "$repo" "$config_digest"
          # Platform info from the index entry is more reliable than the config blob
          [[ -n "$plat_arch" ]] && g_arch="$plat_arch"
          [[ -n "$plat_os"   ]] && g_os="$plat_os"

          print_row "$repo" "$tag" "$sub_digest" "$total_size" "$g_arch" "$g_os" "$g_created" "$g_version"
        done <<< "$(echo "$manifest" | jq -c '.manifests[]')"
        ;;
      *)
        # Single-platform image
        config_digest=$(echo "$manifest" | jq -r '.config.digest // empty')
        total_size=$(echo "$manifest"    | jq -r '[.layers[].size] | add // 0')

        fetch_config_meta "$repo" "$config_digest"
        print_row "$repo" "$tag" "$digest" "$total_size" "$g_arch" "$g_os" "$g_created" "$g_version"
        ;;
    esac
  done <<< "$tags"
done <<< "$repos"
