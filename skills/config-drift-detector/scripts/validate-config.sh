#!/usr/bin/env bash
# validate-config.sh — Check a config file against its expected schema
# Usage: validate-config.sh <config-file> [--schema <schema-name>] [--strict] [--fix]
set -euo pipefail

CONFIG_FILE="${1:-}"
SCHEMA_NAME=""
STRICT=false
FIX=false

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema) SCHEMA_NAME="$2"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    --fix) FIX=true; shift ;;
    --help|-h)
      echo "Usage: validate-config.sh <config-file> [--schema <name>] [--strict] [--fix]"
      echo ""
      echo "Options:"
      echo "  --schema <name>   Explicit schema name (auto-detected from filename if omitted)"
      echo "  --strict          Treat warnings as errors"
      echo "  --fix             Attempt automatic fixes for non-critical issues"
      echo "  --help            Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CONFIG_FILE" ]]; then
  echo "Error: No config file specified" >&2
  echo "Usage: validate-config.sh <config-file> [--schema <name>] [--strict] [--fix]" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install via: brew install jq" >&2
  exit 1
fi

# Validate JSON syntax first
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  echo "CRITICAL: Invalid JSON syntax in $CONFIG_FILE" >&2
  echo ""
  echo "Attempting to locate syntax error..."
  python3 -c "
import json, sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        json.load(f)
except json.JSONDecodeError as e:
    print(f'  Line {e.lineno}, Column {e.colno}: {e.msg}')
    sys.exit(1)
" 2>/dev/null || echo "  (install python3 for detailed syntax error reporting)"
  exit 1
fi

# Auto-detect schema from filename if not provided
if [[ -z "$SCHEMA_NAME" ]]; then
  basename=$(basename "$CONFIG_FILE" .json)
  case "$basename" in
    config) SCHEMA_NAME="config" ;;
    claude_desktop_config) SCHEMA_NAME="claude_desktop_config" ;;
    window-state) SCHEMA_NAME="window-state" ;;
    bridge-state) SCHEMA_NAME="bridge-state" ;;
    git-worktrees) SCHEMA_NAME="git-worktrees" ;;
    extensions-installations) SCHEMA_NAME="extensions-installations" ;;
    *)
      echo "Warning: Could not auto-detect schema for $CONFIG_FILE" >&2
      echo "Falling back to basic validation (top-level object check)" >&2
      SCHEMA_NAME="generic"
      ;;
  esac
fi

ERRORS=0
WARNINGS=0

error() {
  echo "CRITICAL: $1"
  ((ERRORS++)) || true
}

warn() {
  if [[ "$STRICT" == "true" ]]; then
    echo "CRITICAL (strict): $1"
    ((ERRORS++)) || true
  else
    echo "WARNING: $1"
    ((WARNINGS++)) || true
  fi
}

info() {
  echo "INFO: $1"
}

# Basic type check
is_type() {
  local val="$1"
  local expected="$2"
  case "$expected" in
    string) [[ "$val" == "string" ]] ;;
    number) [[ "$val" == "number" ]] ;;
    boolean) [[ "$val" == "boolean" ]] ;;
    object) [[ "$val" == "object" ]] ;;
    array) [[ "$val" == "array" ]] ;;
    null) [[ "$val" == "null" ]] ;;
  esac
}

# Validate required fields
check_required() {
  local file="$1"
  shift
  for field in "$@"; do
    if ! jq -e "has(\"$field\")" "$file" &>/dev/null; then
      error "Missing required field: $field"
    fi
  done
}

# Validate field type
check_type() {
  local file="$1"
  local field="$2"
  local expected="$3"

  local actual
  actual=$(jq -r ".[\"$field\"] | type // \"missing\"" "$file" 2>/dev/null)

  if [[ "$actual" == "missing" ]]; then
    return 0  # Not present, skip (check_required handles missing)
  fi

  if ! is_type "$actual" "$expected"; then
    error "Field '$field' expected $expected, got $actual"
  fi
}

# Validate enum
check_enum() {
  local file="$1"
  local field="$2"
  shift 2
  local allowed=("$@")

  local val
  val=$(jq -r ".[\"$field\"] // \"__MISSING__\"" "$file" 2>/dev/null)
  [[ "$val" == "__MISSING__" ]] && return 0

  local found=false
  for a in "${allowed[@]}"; do
    if [[ "$val" == "$a" ]]; then
      found=true
      break
    fi
  done

  if [[ "$found" != "true" ]]; then
    error "Field '$field' must be one of: ${allowed[*]} (got: $val)"
  fi
}

# Validate range
check_range() {
  local file="$1"
  local field="$2"
  local min="$3"
  local max="$4"

  local val
  val=$(jq -r ".[\"$field\"] // \"__MISSING__\"" "$file" 2>/dev/null)
  [[ "$val" == "__MISSING__" ]] && return 0

  if [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    if (( $(echo "$val < $min" | bc -l 2>/dev/null || echo 0) )); then
      error "Field '$field' value $val is below minimum $min"
    fi
    if (( $(echo "$val > $max" | bc -l 2>/dev/null || echo 0) )); then
      error "Field '$field' value $val is above maximum $max"
    fi
  else
    warn "Field '$field' expected numeric value for range check, got: $val"
  fi
}

echo "=== Config Validation ==="
echo "File: $CONFIG_FILE"
echo "Schema: $SCHEMA_NAME"
echo ""

# Run schema-specific validation
case "$SCHEMA_NAME" in
  config|claude_desktop_config)
    check_required "$CONFIG_FILE" "mcpServers"
    check_type "$CONFIG_FILE" "mcpServers" "object"
    check_type "$CONFIG_FILE" "theme" "string"
    check_type "$CONFIG_FILE" "autoUpdate" "boolean"
    check_type "$CONFIG_FILE" "contextWindow" "number"
    check_type "$CONFIG_FILE" "permissions" "object"

    if jq -e 'has("theme")' "$CONFIG_FILE" &>/dev/null; then
      check_enum "$CONFIG_FILE" "theme" "dark" "light" "system"
    fi

    if jq -e 'has("contextWindow")' "$CONFIG_FILE" &>/dev/null; then
      check_range "$CONFIG_FILE" "contextWindow" 1000 10000000
    fi

    # Validate mcpServers structure
    server_count=$(jq '.mcpServers | length // 0' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$server_count" -gt 0 ]]; then
      for server in $(jq -r '.mcpServers | keys[]' "$CONFIG_FILE" 2>/dev/null); do
        if ! jq -e ".mcpServers[\"$server\"].command" "$CONFIG_FILE" &>/dev/null; then
          error "mcpServers.$server missing required 'command' field"
        fi
      done
    fi
    ;;

  window-state)
    check_type "$CONFIG_FILE" "x" "number"
    check_type "$CONFIG_FILE" "y" "number"
    check_type "$CONFIG_FILE" "width" "number"
    check_type "$CONFIG_FILE" "height" "number"
    check_type "$CONFIG_FILE" "maximized" "boolean"
    check_type "$CONFIG_FILE" "panelWidth" "number"

    check_range "$CONFIG_FILE" "width" 400 3840
    check_range "$CONFIG_FILE" "height" 300 2160
    check_range "$CONFIG_FILE" "panelWidth" 50 800
    ;;

  bridge-state)
    check_required "$CONFIG_FILE" "sessionId" "connectedAt" "status"
    check_type "$CONFIG_FILE" "sessionId" "string"
    check_type "$CONFIG_FILE" "connectedAt" "string"
    check_type "$CONFIG_FILE" "status" "string"
    check_type "$CONFIG_FILE" "errorCount" "number"
    check_type "$CONFIG_FILE" "retryCount" "number"

    if jq -e 'has("status")' "$CONFIG_FILE" &>/dev/null; then
      check_enum "$CONFIG_FILE" "status" "connected" "disconnected" "error"
    fi

    # Validate ISO 8601 timestamp
    if jq -e 'has("connectedAt")' "$CONFIG_FILE" &>/dev/null; then
      ts=$(jq -r '.connectedAt' "$CONFIG_FILE" 2>/dev/null)
      if ! echo "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        error "connectedAt is not a valid ISO 8601 timestamp"
      fi
    fi
    ;;

  git-worktrees)
    check_required "$CONFIG_FILE" "worktrees"
    check_type "$CONFIG_FILE" "worktrees" "array"

    if jq -e '.worktrees | type == "array"' "$CONFIG_FILE" 2>/dev/null; then
      count=$(jq '.worktrees | length' "$CONFIG_FILE" 2>/dev/null)
      for i in $(seq 0 $((count - 1))); do
        wt=$(jq -r ".worktrees[$i]" "$CONFIG_FILE" 2>/dev/null)
        wt_type=$(echo "$wt" | jq -r 'type')
        if [[ "$wt_type" == "object" ]]; then
          if ! echo "$wt" | jq -e 'has("path")' &>/dev/null; then
            error "worktrees[$i] missing required 'path' field"
          fi
          if ! echo "$wt" | jq -e 'has("branch")' &>/dev/null; then
            error "worktrees[$i] missing required 'branch' field"
          fi
        fi
      done
    fi
    ;;

  extensions-installations)
    check_required "$CONFIG_FILE" "extensions"
    check_type "$CONFIG_FILE" "extensions" "array"

    if jq -e '.extensions | type == "array"' "$CONFIG_FILE" 2>/dev/null; then
      count=$(jq '.extensions | length' "$CONFIG_FILE" 2>/dev/null)
      for i in $(seq 0 $((count - 1))); do
        ext=$(jq -r ".extensions[$i]" "$CONFIG_FILE" 2>/dev/null)
        ext_type=$(echo "$ext" | jq -r 'type')
        if [[ "$ext_type" == "object" ]]; then
          if ! echo "$ext" | jq -e 'has("id")' &>/dev/null; then
            error "extensions[$i] missing required 'id' field"
          fi
          if ! echo "$ext" | jq -e 'has("version")' &>/dev/null; then
            error "extensions[$i] missing required 'version' field"
          fi
          if ! echo "$ext" | jq -e 'has("enabled")' &>/dev/null; then
            warn "extensions[$i] missing 'enabled' field (will default to true)"
          fi
          # Validate version format
          ver=$(echo "$ext" | jq -r '.version // ""' 2>/dev/null)
          if [[ -n "$ver" ]] && ! echo "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
            warn "extensions[$i].version '$ver' is not valid semver"
          fi
        fi
      done
    fi
    ;;

  generic)
    check_type "$CONFIG_FILE" "" "object"
    info "No specific schema available — performing basic validation only"
    ;;
esac

# Auto-fix mode (limited to safe fixes)
if [[ "$FIX" == "true" && "$ERRORS" -gt 0 ]]; then
  echo ""
  echo "=== Auto-Fix Attempt ==="
  # Only safe to fix: add missing optional fields with defaults
  case "$SCHEMA_NAME" in
    config|claude_desktop_config)
      if ! jq -e '.theme' "$CONFIG_FILE" &>/dev/null; then
        tmp=$(mktemp)
        jq '. + {"theme": "system"}' "$CONFIG_FILE" > "$tmp"
        mv "$tmp" "$CONFIG_FILE"
        info "Added missing 'theme' with default value 'system'"
      fi
      ;;
  esac
fi

# Summary
echo ""
echo "--- Validation Summary ---"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [[ "$ERRORS" -gt 0 ]]; then
  echo "RESULT: INVALID — $ERRORS error(s) found"
  exit 1
else
  echo "RESULT: VALID"
  if [[ "$WARNINGS" -gt 0 ]]; then
    echo "  ($WARNINGS warning(s) present)"
  fi
  exit 0
fi
