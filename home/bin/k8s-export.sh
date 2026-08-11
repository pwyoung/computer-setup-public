#!/usr/bin/env bash
#
# k8s-export.sh
# Exports the YAML definitions of all standard Kubernetes objects in a
# namespace (everything covered by "kubectl get all", plus ConfigMaps,
# Ingresses, and PVCs) into a directory, then packages it as a .tar.gz.
#
# Secrets:
#   Secret objects can optionally be exported too. Their structure (keys)
#   is preserved, but every value under data:/stringData: is replaced
#   with "REDACTED". The last-applied-configuration annotation (which can
#   also contain secret values) is redacted as well.
#
#   Enable secrets export with either:
#     - the -s / --secrets command-line flag, or
#     - the EXPORT_SECRETS environment variable:  EXPORT_SECRETS=true ./k8s-export.sh
#   Setting EXPORT_SECRETS=false (the default) skips the secrets scan
#   unless the -s/--secrets or -S flag is given.
#
#   -S / --secrets-only exports ONLY the (masked) secrets: it adds or
#   overwrites them in the existing output directory, skips all other
#   resource types, and recreates the tarball from the directory contents.

set -euo pipefail

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------

################################################################################
# TO-DO: CHANGE AS NEEDED
################################################################################

# Used to confirm docker and ngc secret literals were redacted.
NAMESPACE="nim-service"

################################################################################
# These *probably* don't need to be changed
################################################################################

OUTPUT_DIR="./k8s-export-${NAMESPACE}"

# Env var toggle for the secrets scan (default: false / off)
EXPORT_SECRETS="${EXPORT_SECRETS:-false}"

# Internal: set by -S / --secrets-only
SECRETS_ONLY="false"

# Resource types to export:
#  - the types included in "kubectl get all"
#  - plus configmap, ingress, and persistentvolumeclaim
RESOURCE_TYPES=(
  pod
  service
  deployment
  replicaset
  statefulset
  daemonset
  job
  cronjob
  configmap
  ingress
  persistentvolumeclaim
)

# ----------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------
usage() {
  echo "Usage: $0 [-s|--secrets] [-S|--secrets-only]"
  echo ""
  echo "  -s, --secrets        Also export Secret objects (values masked as REDACTED)"
  echo "  -S, --secrets-only   Export ONLY the masked Secret objects: add/overwrite"
  echo "                       them in the output dir and recreate the tarball"
  echo ""
  echo "Environment:"
  echo "  EXPORT_SECRETS=true|false   Same as the -s flag (default: false)"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -s|--secrets)
      EXPORT_SECRETS="true"
      shift
      ;;
    -S|--secrets-only)
      EXPORT_SECRETS="true"
      SECRETS_ONLY="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# ----------------------------------------------------------------------
# Sanity checks
# ----------------------------------------------------------------------
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found in PATH" >&2; exit 1; }

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "ERROR: namespace '$NAMESPACE' not found or not accessible" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ----------------------------------------------------------------------
# Secret masking
# ----------------------------------------------------------------------
# Reads a Secret's YAML on stdin and writes a masked version to stdout:
#   - keeps the overall YAML structure and all keys
#   - replaces every value under data: / stringData: with REDACTED
#     (including multi-line values)
#   - redacts the kubectl.kubernetes.io/last-applied-configuration
#     annotation, which can embed the original secret values
mask_secret_yaml() {
  awk '
    function indent(s,   n) { n = 0; while (substr(s, n + 1, 1) == " ") n++; return n }
    BEGIN { in_data = 0; skip_indent = -1 }
    {
      cur = indent($0)

      # While skipping a multi-line value, drop lines indented deeper
      # than the key that started it (and blank lines inside it).
      if (skip_indent >= 0) {
        if ($0 ~ /^[[:space:]]*$/ || cur > skip_indent) next
        skip_indent = -1
      }

      # Leaving the data:/stringData: block (back to a top-level key)
      if (in_data && cur == 0 && $0 !~ /^[[:space:]]*$/) in_data = 0

      # Entering data: or stringData:
      if ($0 ~ /^(data|stringData):[[:space:]]*$/) { in_data = 1; print; next }

      # A key directly under data:/stringData: -> mask its value
      if (in_data && cur == 2) {
        line = $0
        sub(/:.*$/, ": REDACTED", line)
        print line
        skip_indent = 2        # skip continuation lines of multi-line values
        next
      }

      # The last-applied-configuration annotation can contain the raw
      # secret values, so redact it too.
      if ($0 ~ /kubectl\.kubernetes\.io\/last-applied-configuration/) {
        line = $0
        sub(/:.*$/, ": REDACTED", line)
        print line
        skip_indent = cur      # skip its (possibly multi-line) value
        next
      }

      print
    }
  '
}

# ----------------------------------------------------------------------
# Export each object's YAML (skipped entirely in secrets-only mode)
# ----------------------------------------------------------------------
total=0

if [ "$SECRETS_ONLY" = "true" ]; then
  echo "Secrets-only mode: skipping standard resource types"
else
  for type in "${RESOURCE_TYPES[@]}"; do
    # Get the names of all objects of this type in the namespace
    names=$(kubectl get "$type" -n "$NAMESPACE" \
              -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

    [ -z "$names" ] && continue

    mkdir -p "${OUTPUT_DIR}/${type}"

    for name in $names; do
      outfile="${OUTPUT_DIR}/${type}/${name}.yaml"
      echo "Exporting ${type}/${name} ..."
      kubectl get "$type" "$name" -n "$NAMESPACE" -o yaml > "$outfile"
      total=$((total + 1))
    done
  done
fi

# ----------------------------------------------------------------------
# Secrets scan (opt-in via -s/--secrets, -S/--secrets-only,
# or EXPORT_SECRETS=true)
# ----------------------------------------------------------------------
if [ "$EXPORT_SECRETS" = "true" ]; then
  echo "Secrets scan enabled: exporting Secret objects with masked values"

  secret_names=$(kubectl get secret -n "$NAMESPACE" \
                   -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

  if [ -n "$secret_names" ]; then
    mkdir -p "${OUTPUT_DIR}/secret"
    for name in $secret_names; do
      outfile="${OUTPUT_DIR}/secret/${name}.yaml"
      echo "Exporting secret/${name} (masked) ..."
      kubectl get secret "$name" -n "$NAMESPACE" -o yaml \
        | mask_secret_yaml > "$outfile"
      total=$((total + 1))
    done
  else
    echo "No Secret objects found in namespace '${NAMESPACE}'"
  fi
else
  echo "Secrets scan disabled (use -s/--secrets or EXPORT_SECRETS=true to enable)"
fi

echo "Exported ${total} objects from namespace '${NAMESPACE}' into '${OUTPUT_DIR}'"

# ----------------------------------------------------------------------
# (Re)create the .tar.gz archive of the directory
# ----------------------------------------------------------------------
# tar -czf overwrites any existing archive, so in secrets-only mode this
# rebuilds the tarball from the full directory contents (previously
# exported resources plus the freshly added/overwritten secrets).
ARCHIVE="${OUTPUT_DIR%.tar.gz}.tar.gz"
tar -czf "$ARCHIVE" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")"

echo "Archive (re)created: ${ARCHIVE}"
