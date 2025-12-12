#!/bin/bash

################################################################################
# Converter: Bidirectional .env <-> .yaml
#
# 1. .yaml input -> outputs .env
#    - Supports nested keys (PARENT__CHILD=value)
#    - Supports block arrays (KEY=["item1","item2"])
# 2. .env input  -> outputs .yaml
#    - Expands double underscores to nesting
#    - Preserves existing values
################################################################################

# Process input args
if [ -z "${1:-}" ]; then
  echo "Usage: $0 <input_file> [optional_root_yaml_key]"
  echo "  <input_file>          : File with .env or .yaml extension (Required)"
  echo "  [optional_root_yaml_key]: Used only when converting .env to .yaml."
  echo "                          If provided, wraps the output in this parent key."
  exit 1
fi

INPUT_FILE="$1"
ROOT_KEY="${2:-}"

# Validate Extension
FILENAME=$(basename -- "$INPUT_FILE")
EXTENSION="${FILENAME##*.}"

if [[ "$EXTENSION" != "yaml" && "$EXTENSION" != "env" ]]; then
    echo "Error: Input file must have a .env or .yaml extension."
    exit 1
fi

# Aggressively catch and report errors
set -euo pipefail
function handle_error {
    local exit_status=$?
    echo "An error occurred on line ${LINENO:-not-defined}: ${BASH_COMMAND:-not-defined}"
    exit $exit_status
}
trap handle_error ERR

################################################################################
#  Utility Functions
################################################################################

_env_to_yaml() {
    local input_string="$1"
    printf "%s\n" "$input_string" | awk '
    BEGIN { split("", prev_parts) }
    /^$/ { print ""; next }
    /^[[:space:]]*#/ {
        indent_str = ""
        for(i=1; i<current_depth; i++) indent_str = indent_str "  "
        clean_comment = $0
        sub(/^[[:space:]]*/, "", clean_comment)
        print indent_str clean_comment
        next
    }
    /=/ {
        eq_index = index($0, "=")
        full_key = substr($0, 1, eq_index - 1)
        value = substr($0, eq_index + 1)
        sub(/^export[[:space:]]+/, "", full_key)
        n = split(full_key, parts, "__")

        divergence = 1
        for (i = 1; i <= n && i <= length(prev_parts); i++) {
            if (parts[i] != prev_parts[i]) {
                divergence = i
                break
            }
            if (i == length(prev_parts)) divergence = i + 1
        }
        if (n < length(prev_parts) && divergence > n) divergence = n

        for (i = divergence; i <= n; i++) {
            indent = ""
            for (j = 1; j < i; j++) indent = indent "  "
            if (i < n) {
                print indent parts[i] ":"
            } else {
                print indent parts[i] ": " value
            }
        }

        delete prev_parts
        for (i = 1; i <= n; i++) prev_parts[i] = parts[i]
        current_depth = n
        next
    }
    { print $0 }
    '
}

_yaml_to_env() {
    local input_string="$1"

    printf "%s\n" "$input_string" | awk '
    BEGIN { depth = 0; in_array = 0; array_key = ""; array_str = "" }

    function flush_array() {
        if (in_array) {
            sub(/,$/, "", array_str) # Remove trailing comma
            print array_key "=[" array_str "]"
            in_array = 0
            array_str = ""
            array_key = ""
        }
    }

    # 1. Skip Empty Lines
    /^$/ { next }

    # 2. Handle Comments
    /^[[:space:]]*#/ {
        flush_array()
        sub(/^[[:space:]]*/, "")
        print "# " $0
        next
    }

    # 3. Main Parsing
    {
        line = $0
        match(line, /^[[:space:]]*/)
        indent_len = RLENGTH
        current_level = int(indent_len / 2)
        sub(/^[[:space:]]*/, "", line)

        # -- CASE A: Array Item (starts with "- ") --
        if (line ~ /^- /) {
            val = substr(line, 3) # Strip "- "

            # Remove surrounding quotes to normalize
            sub(/^"/, "", val); sub(/"$/, "", val)
            sub(/^\047/, "", val); sub(/\047$/, "", val)

            # Initialize array processing if new
            if (!in_array) {
                in_array = 1
                full_key = ""
                # Parent key is at the indent level above this item
                for (i=0; i<current_level; i++) {
                    full_key = full_key stack[i] "__"
                }
                sub(/__$/, "", full_key)
                array_key = full_key
            }

            # Append to buffer with quotes
            array_str = array_str "\"" val "\","
            next
        }

        # If not an array item, flush any pending array
        flush_array()

        # -- CASE B: Key-Value or Parent Key --
        if (line ~ /:/) {
            # Check if it has a value (KEY: Value)
            if (line ~ /:[[:space:]]*.+/) {
                c_idx = index(line, ":")
                key = substr(line, 1, c_idx - 1)
                val = substr(line, c_idx + 1)
                sub(/^[[:space:]]+/, "", val)

                full_key = ""
                for (i=0; i<current_level; i++) {
                    full_key = full_key stack[i] "__"
                }
                full_key = full_key key
                print full_key "=" val
            } else {
                # Parent Key (KEY:)
                sub(/:$/, "", line)
                stack[current_level] = line
            }
        }
    }
    END { flush_array() }
    '
}

_yaml_add_root_key() {
    local yaml_content="$1"
    local root_key="$2"
    echo "${root_key}:"
    printf "%s\n" "$yaml_content" | sed '/./ s/^/  /'
}

run() {
  FILE_CONTENT=$(cat "$INPUT_FILE")

  if [[ "$EXTENSION" == "yaml" ]]; then
      _yaml_to_env "$FILE_CONTENT"
  else
      YAML_DATA=$(_env_to_yaml "$FILE_CONTENT")
      if [ -n "$ROOT_KEY" ]; then
          _yaml_add_root_key "$YAML_DATA" "$ROOT_KEY"
      else
          echo "$YAML_DATA"
      fi
  fi
}

run
