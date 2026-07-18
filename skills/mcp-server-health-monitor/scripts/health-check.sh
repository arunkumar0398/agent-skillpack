#!/usr/bin/env bash
# health-check.sh — Probe each MCP server and return status
# Usage: ./health-check.sh [mcp-info.json path] [--verbose]

set -euo pipefail

MCP_INFO="${1:-mcp-info.json}"
VERBOSE="${2:-}"
DEFAULT_TIMEOUT=60
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

SERVER_COUNT=$(jq '.servers | length' "$MCP_INFO")
log "Checking $SERVER_COUNT servers defined in $MCP_INFO"

FAILED_SERVERS=()
PASSED=0
FAILED=0

for i in $(seq 0 $((SERVER_COUNT - 1))); do
    NAME=$(jq -r ".servers[$i].name" "$MCP_INFO")
    COMMAND=$(jq -r ".servers[$i].command" "$MCP_INFO")
    ARGS=$(jq -r ".servers[$i].args // [] | .[]" "$MCP_INFO" | tr '\n' ' ')
    TIMEOUT=$(jq -r ".servers[$i].healthCheck.timeout // $DEFAULT_TIMEOUT" "$MCP_INFO")

    if [[ "$VERBOSE" == "--verbose" ]]; then
        log "Probing: $NAME (timeout: ${TIMEOUT}s)"
    fi

    # Check if the server process is already running
    PID=$(pgrep -f "$COMMAND.*$NAME" 2>/dev/null || true)

    if [[ -z "$PID" ]]; then
        # Server not running — attempt to start it
        if [[ "$VERBOSE" == "--verbose" ]]; then
            log "Starting $NAME..."
        fi

        timeout "$TIMEOUT" $COMMAND $ARGS &>/dev/null &
        START_PID=$!
        sleep 2

        if kill -0 "$START_PID" 2>/dev/null; then
            ok "$NAME — started successfully (PID: $START_PID)"
            PASSED=$((PASSED + 1))
        else
            fail "$NAME — failed to start"
            FAILED_SERVERS+=("$NAME")
            FAILED=$((FAILED + 1))
        fi
    else
        # Server running — check if responsive via tool list request
        RESPONSE_TIME=$(timeout "$TIMEOUT" bash -c \
            "start=\$(date +%s%N); echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' | nc -w $TIMEOUT localhost $(jq -r ".servers[$i].port // 3000" "$MCP_INFO") 2>/dev/null; end=\$(date +%s%N); echo \$(( (end - start) / 1000000 ))" \
            2>/dev/null || echo "-1")

        if [[ "$RESPONSE_TIME" != "-1" ]]; then
            if [[ "$RESPONSE_TIME" -lt "$((TIMEOUT * 1000 / 2))" ]]; then
                ok "$NAME — responsive (${RESPONSE_TIME}ms)"
                PASSED=$((PASSED + 1))
            else
                warn "$NAME — slow response (${RESPONSE_TIME}ms)"
                PASSED=$((PASSED + 1))
            fi
        else
            fail "$NAME — not responding (timeout: ${TIMEOUT}s)"
            FAILED_SERVERS+=("$NAME")
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
log "Results: $PASSED passed, $FAILED failed out of $SERVER_COUNT servers"

if [[ ${#FAILED_SERVERS[@]} -gt 0 ]]; then
    echo ""
    log "Failed servers:"
    for s in "${FAILED_SERVERS[@]}"; do
        echo "  - $s"
    done
    exit 1
fi

exit 0
