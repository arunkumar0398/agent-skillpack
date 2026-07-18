#!/usr/bin/env bash
# diff-configs.sh — Compare two config snapshots and output structured differences
# Usage: diff-configs.sh <snapshot-a> <snapshot-b> [--format text|json] [--severity all|critical|warning]
set -euo pipefail

SNAPSHOT_A="${1:-}"
SNAPSHOT_B="${2:-}"
FORMAT="text"
SEVERITY="all"

# Parse flags
shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SNAPSHOT_A" || -z "$SNAPSHOT_B" ]]; then
  echo "Usage: diff-configs.sh <snapshot-a> <snapshot-b> [--format text|json] [--severity all|critical|warning]" >&2
  exit 1
fi

if [[ ! -f "$SNAPSHOT_A" ]]; then
  echo "Error: Snapshot A not found: $SNAPSHOT_A" >&2
  exit 1
fi

if [[ ! -f "$SNAPSHOT_B" ]]; then
  echo "Error: Snapshot B not found: $SNAPSHOT_B" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required for diff comparison. Install via: brew install jq" >&2
  exit 1
fi

# Validate both files are valid JSON
for f in "$SNAPSHOT_A" "$SNAPSHOT_B"; do
  if ! jq empty "$f" 2>/dev/null; then
    echo "Error: $f is not valid JSON" >&2
    exit 1
  fi
done

# Recursive diff function
diff_objects() {
  local path="${1:-.}"
  local a="$2"
  local b="$3"

  # Get keys from both
  local keys_a keys_b
  keys_a=$(jq -r 'if type == "object" then keys[] else empty end' "$a" 2>/dev/null || true)
  keys_b=$(jq -r 'if type == "object" then keys[] else empty end' "$b" 2>/dev/null || true)

  # Check removed keys (in A but not B)
  for key in $keys_a; do
    if ! echo "$keys_b" | grep -qx "$key"; then
      local current_path="${path}.${key}"
      local a_val
      a_val=$(jq -r ".[\"$key\"]" "$a")
      echo "REMOVED|$current_path|$a_val|CRITICAL"
    fi
  done

  # Check added keys (in B but not A)
  for key in $keys_b; do
    if ! echo "$keys_a" | grep -qx "$key"; then
      local current_path="${path}.${key}"
      local b_val
      b_val=$(jq -r ".[\"$key\"]" "$b")
      echo "ADDED|$current_path|$b_val|INFO"
    fi
  done

  # Check modified keys
  for key in $keys_a; do
    if echo "$keys_b" | grep -qx "$key"; then
      local current_path="${path}.${key}"
      local a_type b_type
      a_type=$(jq -r ".[\"$key\"] | type" "$a")
      b_type=$(jq -r ".[\"$key\"] | type" "$b")

      if [[ "$a_type" != "$b_type" ]]; then
        local a_val b_val
        a_val=$(jq -r ".[\"$key\"]" "$a")
        b_val=$(jq -r ".[\"$key\"]" "$b")
        echo "CHANGED|$current_path|$a_val -> $b_val|CRITICAL"
      elif [[ "$a_type" == "object" ]]; then
        # Recurse into nested objects
        local tmp_a tmp_b
        tmp_a=$(mktemp /tmp/diff-a-XXXXXX.json)
        tmp_b=$(mktemp /tmp/diff-b-XXXXXX.json)
        jq ".[\"$key\"]" "$a" > "$tmp_a"
        jq ".[\"$key\"]" "$b" > "$tmp_b"
        diff_objects "$current_path" "$tmp_a" "$tmp_b"
        rm -f "$tmp_a" "$tmp_b"
      elif [[ "$a_type" == "array" ]]; then
        local a_val b_val
        a_val=$(jq -c ".[\"$key\"]" "$a")
        b_val=$(jq -c ".[\"$key\"]" "$b")
        if [[ "$a_val" != "$b_val" ]]; then
          echo "CHANGED|$current_path|$a_val -> $b_val|WARNING"
        fi
      else
        local a_val b_val
        a_val=$(jq -r ".[\"$key\"]" "$a")
        b_val=$(jq -r ".[\"$key\"]" "$b")
        if [[ "$a_val" != "$b_val" ]]; then
          echo "CHANGED|$current_path|$a_val -> $b_val|WARNING"
        fi
      fi
    fi
  done
}

# Run diff
RESULTS=$(diff_objects "" "$SNAPSHOT_A" "$SNAPSHOT_B" || true)

if [[ -z "$RESULTS" ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    echo '{"status":"identical","diffs":[]}'
  else
    echo "No differences found. Configs are identical."
  fi
  exit 0
fi

# Filter by severity
if [[ "$SEVERITY" != "all" ]]; then
  RESULTS=$(echo "$RESULTS" | grep "|${SEVERITY^^}$" || true)
fi

# Output
if [[ "$FORMAT" == "json" ]]; then
  echo '{"status":"drift_detected","diffs":['
  first=true
  while IFS='|' read -r action path value severity; do
    [[ -z "$action" ]] && continue
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo ","
    fi
    printf '{"action":"%s","path":"%s","value":"%s","severity":"%s"}' \
      "$action" "$path" "$(echo "$value" | sed 's/"/\\"/g')" "$severity"
  done <<< "$RESULTS"
  echo ']}'
else
  echo "=== Configuration Drift Report ==="
  echo ""
  echo "Snapshot A: $SNAPSHOT_A"
  echo "Snapshot B: $SNAPSHOT_B"
  echo ""
  echo "--- Differences ---"
  while IFS='|' read -r action path value severity; do
    [[ -z "$action" ]] && continue
    printf "[%s] %s → %s\n" "$severity" "$action" "$path"
    printf "  Value: %s\n\n" "$value"
  done <<< "$RESULTS"
  echo "---"
  echo "Total differences: $(echo "$RESULTS" | grep -c . || echo 0)"
fi
