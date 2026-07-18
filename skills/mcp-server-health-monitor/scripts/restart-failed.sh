#!/usr/bin/env bash
# restart-failed.sh — Restart MCP servers not in the activeServers list
# Usage: ./restart-failed.sh [mcp-info.json path] [--dry-run]

set -euo pipefail

MCP_INFO="${1:-mcp-info.json}"
DRY_RUN="${2:-}"
DEFAULT_TIMEOUT=60
WAIT_BEFORE_START=3
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo "[$TIMESTAMP] $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

if [[ ! -f "$MCP_INFO" ]]; then
    fail "mcp-info.json not found at: $MCP_INFO"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    fail "jq is required but not installed"
    exit 1
fi

# Build active servers list (those marked active or with no active field)
ACTIVE_SERVERS=()
for i in $(seq 0 $(($(jq '.servers | length' "$MCP_INFO") - 1))); do
    NAME=$(jq -r ".servers[$i].name" "$MCP_INFO")
    IS_ACTIVE=$(jq -r ".servers[$i].active // true" "$MCP_INFO")
    if [[ "$IS_ACTIVE" == "true" ]]; then
        ACTIVE_SERVERS+=("$NAME")
    fi
done

log "Active servers: ${ACTIVE_SERVERS[*]:-none}"

# Get currently running MCP server processes
RUNNING_SERVERS=()
while IFS= read -r line; do
    RUNNING_SERVERS+=("$line")
done < <(ps aux | grep -i "mcp\|modelcontextprotocol" | grep -v grep | awk '{print $NF}' 2>/dev/null || true)

log "Running processes: ${#RUNNING_SERVERS[@]}"

# Find servers that should be running but aren't
RESTART_LIST=()
for SERVER in "${ACTIVE_SERVERS[@]}"; do
    IS_RUNNING=false
    for RUNNING in "${RUNNING_SERVERS[@]+${RUNNING_SERVERS[@]}}"; do
        if [[ "$RUNNING" == *"$SERVER"* ]]; then
            IS_RUNNING=true
            break
        fi
    done

    if [[ "$IS_RUNNING" == "false" ]]; then
        RESTART_LIST+=("$SERVER")
    fi
done

if [[ ${#RESTART_LIST[@]} -eq 0 ]]; then
    ok "All active servers are running. Nothing to restart."
    exit 0
fi

log "Servers needing restart: ${RESTART_LIST[*]}"

# Stop any stale processes
log "Stopping stale MCP processes..."
pkill -f "mcp|modelcontextprotocol" 2>/dev/null || true
sleep "$WAIT_BEFORE_START"

# Restart each failed server
RESTARTED=0
FAILED_RESTART=()

for SERVER in "${RESTART_LIST[@]}"; do
    # Find server config
    IDX=-1
    for i in $(seq 0 $(($(jq '.servers | length' "$MCP_INFO") - 1))); do
        SNAME=$(jq -r ".servers[$i].name" "$MCP_INFO")
        if [[ "$SNAME" == "$SERVER" ]]; then
            IDX=$i
            break
        fi
    done

    if [[ $IDX -eq -1 ]]; then
        fail "Config not found for $SERVER"
        FAILED_RESTART+=("$SERVER")
        continue
    fi

    COMMAND=$(jq -r ".servers[$IDX].command" "$MCP_INFO")
    ARGS=$(jq -r ".servers[$IDX].args // [] | .[]" "$MCP_INFO" | tr '\n' ' ')
    TIMEOUT=$(jq -r ".servers[$IDX].healthCheck.timeout // $DEFAULT_TIMEOUT" "$MCP_INFO")

    if [[ "$DRY_RUN" == "--dry-run" ]]; then
        warn "[DRY RUN] Would restart: $COMMAND $ARGS (timeout: ${TIMEOUT}s)"
        continue
    fi

    log "Restarting $SERVER (timeout: ${TIMEOUT}s)..."
    timeout "$TIMEOUT" $COMMAND $ARGS &>/dev/null &
    START_PID=$!
    sleep 2

    if kill -0 "$START_PID" 2>/dev/null; then
        ok "$SERVER — restarted successfully (PID: $START_PID)"
        RESTARTED=$((RESTARTED + 1))
    else
        fail "$SERVER — restart failed"
        FAILED_RESTART+=("$SERVER")
    fi
done

echo ""
log "Restart summary: $RESTARTED restarted, ${#FAILED_RESTART[@]} failed"

if [[ ${#FAILED_RESTART[@]} -gt 0 ]]; then
    echo ""
    log "Failed to restart:"
    for s in "${FAILED_RESTART[@]}"; do
        echo "  - $s"
    done
    exit 1
fi

exit 0
