#!/usr/bin/env bash

# Ensure env_file entries referenced in a docker-compose YAML exist (touch if missing).
# Usage: ensure_devcontainer_envs_simple.sh [path/to/docker-compose.yaml]

set -euo pipefail

COMPOSE_FILE="${1:-.devcontainer/docker-compose.yaml}"
[ -f "$COMPOSE_FILE" ] || { echo "Compose file not found: $COMPOSE_FILE" >&2; exit 0; }

COMPOSE_DIR="$(cd "$(dirname "$COMPOSE_FILE")" && pwd)"

# Extract env_file entries in three common forms:
#  - env_file: .env
#  - env_file:
#      - .env
#      - .env.sync
#  - env_file: ["a.env","b.env"]
env_files=$(
  awk '
    function strip(s) { gsub(/^[ \t\r\n"\047]+|[ \t\r\n"\047]+$/, "", s); return s }
    /^[[:space:]]*env_file[[:space:]]*:/ {
      line = $0
      sub(/^[[:space:]]*env_file[[:space:]]*:[[:space:]]*/, "", line)
      if (line ~ /^\[/) {
        # inline list: remove brackets then split on commas
        gsub(/^\[|\]$/, "", line)
        n = split(line, parts, ",")
        for (i=1;i<=n;i++) { print strip(parts[i]) }
      } else if (length(line) > 0) {
        print strip(line)
      } else {
        # multiline block - consume subsequent "- item" lines
        inblock=1
      }
      next
    }
    inblock && /^[[:space:]]*-/ {
      v = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", v)
      print strip(v)
      next
    }
    inblock && !/^[[:space:]]*-/ { inblock=0 }
  ' "$COMPOSE_FILE" | sed '/^[[:space:]]*$/d'
)

[ -n "$env_files" ] || { echo "No env_file references found in $COMPOSE_FILE"; exit 0; }

# These env files are just being touched so they exist. They're really just
# placeholders that may not get used.
while IFS= read -r ef; do
  [ -z "${ef// }" ] && continue
  # Resolve relative paths against compose dir.
  if [[ "$ef" = /* ]]; then
    target="$ef"
  else
    ef_nice="${ef#./}"
    target="$COMPOSE_DIR/$ef_nice"
  fi
  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  if [ -f "$target" ]; then
    printf "exists: %s\n" "$target"
  else
    touch "$target"
    printf "touched: %s\n" "$target"
  fi
done <<EOF
$env_files
EOF

exit 0
