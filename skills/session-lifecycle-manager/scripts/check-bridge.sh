#!/usr/bin/env bash
# check-bridge.sh - Verify SSE bridge health
# Usage: ./check-bridge.sh [--json] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
BRIDGE_HOST="${BRIDGE_HOST:-api.anthropic.com}"
BRIDGE_PORT="${BRIDGE_PORT:-443}"
HEARTBEAT_INTERVAL=20
HEARTBEAT_TIMEOUT=60
MAX_RECONNECT_ATTEMPTS=5
HEALTH_LOG="${HEALTH_LOG:-$HOME/.claude/sessions/bridge-health.log}"
JSON_OUTPUT=false
VERBOSE=false

# State
STATUS="unknown"
HEARTBEAT_LATENCY="N/A"
LAST_EVENT_AGE="N/A"
RECONNECT_COUNT=0
UPTIME="N/A"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Check SSE bridge health and connection status.

Options:
  --json              Output results as JSON
  --verbose           Print detailed health information
  --bridge-host <h>   Bridge host (default: api.anthropic.com)
  --bridge-port <p>   Bridge port (default: 443)
  --help              Show this help message

Output:
  healthy    - Bridge is connected, heartbeat normal
  degraded   - Bridge connected but heartbeat slow
  failed     - Bridge unreachable or heartbeat missing

Examples:
  $(basename "$0")
  $(basename "$0") --json
  $(basename "$0") --verbose --bridge-host custom.api.com
EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --bridge-host)
                BRIDGE_HOST="$2"
                shift 2
                ;;
            --bridge-port)
                BRIDGE_PORT="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                usage
                ;;
        esac
    done
}

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "$HEALTH_LOG"
}

check_tcp_connectivity() {
    if command -v nc &>/dev/null; then
        nc -z -w 5 "$BRIDGE_HOST" "$BRIDGE_PORT" 2>/dev/null
    elif command -v ncat &>/dev/null; then
        ncat -z -w 5 "$BRIDGE_HOST" "$BRIDGE_PORT" 2>/dev/null
    elif command -v curl &>/dev/null; then
        curl -s --max-time 5 "https://$BRIDGE_HOST" >/dev/null 2>&1
    elif command -v python3 &>/dev/null; then
        python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5)
try:
    s.connect(('$BRIDGE_HOST', $BRIDGE_PORT))
    s.close()
except:
    exit(1)
" 2>/dev/null
    else
        log "WARN: No connectivity check tool available (nc, ncat, curl, python3)"
        return 0
    fi
}

check_heartbeat_latency() {
    local start_time end_time latency_ms

    start_time=$(date +%s%N 2>/dev/null || date +%s)

    if command -v curl &>/dev/null; then
        curl -s -o /dev/null -w "%{time_total}" \
            --max-time "$HEARTBEAT_TIMEOUT" \
            "https://$BRIDGE_HOST/health" 2>/dev/null || echo "timeout"
    else
        echo "N/A"
    fi
}

check_sse_endpoint() {
    if command -v curl &>/dev/null; then
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            -H "Accept: text/event-stream" \
            "https://$BRIDGE_HOST/v1/messages" 2>/dev/null || echo "000")

        case "$http_code" in
            200|201|204)
                return 0
                ;;
            401|403)
                log "WARN: Auth required (HTTP $http_code) - bridge reachable but auth needed"
                return 0
                ;;
            *)
                log "WARN: SSE endpoint returned HTTP $http_code"
                return 1
                ;;
        esac
    else
        log "WARN: curl not available, skipping SSE endpoint check"
        return 0
    fi
}

get_bridge_status() {
    local tcp_ok=true

    check_tcp_connectivity || tcp_ok=false

    if ! $tcp_ok; then
        STATUS="failed"
        return 1
    fi

    local heartbeat_latency
    heartbeat_latency=$(check_heartbeat_latency)

    if [[ "$heartbeat_latency" == "timeout" || "$heartbeat_latency" == "N/A" ]]; then
        STATUS="degraded"
        HEARTBEAT_LATENCY="timeout"
    else
        HEARTBEAT_LATENCY="${heartbeat_latency}s"
        local latency_int
        latency_int=$(echo "$heartbeat_latency" | cut -d. -f1)

        if [[ -n "$latency_int" && "$latency_int" -lt 2 ]]; then
            STATUS="healthy"
        elif [[ -n "$latency_int" && "$latency_int" -lt 5 ]]; then
            STATUS="degraded"
        else
            STATUS="failed"
        fi
    fi

    check_sse_endpoint || STATUS="degraded"

    return 0
}

get_uptime() {
    if command -v uptime &>/dev/null; then
        UPTIME=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//' || echo "N/A")
    fi
}

output_json() {
    cat <<EOF
{
  "status": "$STATUS",
  "host": "$BRIDGE_HOST",
  "port": $BRIDGE_PORT,
  "heartbeat_latency": "$HEARTBEAT_LATENCY",
  "heartbeat_interval": ${HEARTBEAT_INTERVAL}s,
  "heartbeat_timeout": ${HEARTBEAT_TIMEOUT}s,
  "max_reconnect_attempts": $MAX_RECONNECT_ATTEMPTS,
  "last_event_age": "$LAST_EVENT_AGE",
  "reconnect_count": $RECONNECT_COUNT,
  "checked_at": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
}
EOF
}

output_text() {
    echo "Bridge Health Check"
    echo "==================="
    echo ""
    echo "Status:           $STATUS"
    echo "Host:             $BRIDGE_HOST:$BRIDGE_PORT"
    echo "Heartbeat:        $HEARTBEAT_LATENCY (interval: ${HEARTBEAT_INTERVAL}s, timeout: ${HEARTBEAT_TIMEOUT}s)"
    echo "Last Event Age:   $LAST_EVENT_AGE"
    echo "Reconnect Count:  $RECONNECT_COUNT / $MAX_RECONNECT_ATTEMPTS"
    echo "Checked At:       $(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
    echo ""

    case "$STATUS" in
        healthy)
            echo "Bridge is operating normally."
            ;;
        degraded)
            echo "WARNING: Bridge is degraded. Check heartbeat latency and network."
            ;;
        failed)
            echo "CRITICAL: Bridge is unreachable. Sessions may be affected."
            ;;
    esac

    if $VERBOSE; then
        echo ""
        echo "Details:"
        echo "  - TCP connectivity: $(check_tcp_connectivity 2>/dev/null && echo 'OK' || echo 'FAILED')"
        echo "  - SSE endpoint:     $(check_sse_endpoint 2>/dev/null && echo 'OK' || echo 'FAILED')"
        echo "  - System uptime:    $UPTIME"
    fi
}

main() {
    parse_args "$@"

    mkdir -p "$(dirname "$HEALTH_LOG")"

    get_bridge_status
    get_uptime

    if $JSON_OUTPUT; then
        output_json
    else
        output_text
    fi

    case "$STATUS" in
        healthy) exit 0 ;;
        degraded) exit 1 ;;
        failed) exit 2 ;;
        *) exit 3 ;;
    esac
}

main "$@"
