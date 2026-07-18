#!/usr/bin/env bash
# scan-logs.sh — Parse log files and extract error fingerprints
# Usage: bash scan-logs.sh <logfile> [--json] [--verbose]
#
# Scans a log file for known error patterns and outputs fingerprints
# with matched resolution steps.

set -euo pipefail

LOGFILE=""
OUTPUT_JSON=false
VERBOSE=false

# Known error patterns (add new patterns here)
declare -A ERROR_PATTERNS=(
  ["spawn.gh.ENOENT"]="spawn gh ENOENT|spawnSync gh ENOENT"
  ["network.guest-connected.timeout"]="isGuestConnected.*timed out"
  ["network.connection.reset"]="ERR_CONNECTION_RESET|ECONNRESET"
  ["deployment.msix.null"]="Deployment is NULL|Deployment not found"
  ["plugin.scan.command-collision"]="Command.*already registered by"
  ["apify.server.timeout"]="Apify server timeout|Request timed out after"
  ["sse.connection.reset"]="SSE connection reset|EventSource connection lost"
  ["update.windows-store.failed"]="Auto-update failed|Windows Store update"
  ["system.memory.pressure"]="heap out of memory|Allocation failed|out of memory"
  ["session.idle.timeout"]="Session timeout|Connection closed due to inactivity"
  ["system.port.conflict"]="EADDRINUSE|address already in use"
  ["tls.cert.expired"]="certificate has expired|ERR_CERT_DATE_INVALID"
)

# Resolution steps for each fingerprint
declare -A ERROR_FIXES=(
  ["spawn.gh.ENOENT"]="Install GitHub CLI: https://cli.github.com/"
  ["network.guest-connected.timeout"]="Check network connectivity, restart bridge service"
  ["network.connection.reset"]="Check proxy/firewall settings, verify TLS configuration"
  ["deployment.msix.null"]="Re-register MSIX: Add-AppxPackage -Register AppxManifest.xml"
  ["plugin.scan.command-collision"]="Rename conflicting command ID in extension manifest"
  ["apify.server.timeout"]="Verify APIFY_TOKEN environment variable is set"
  ["sse.connection.reset"]="Implement exponential backoff reconnection strategy"
  ["update.windows-store.failed"]="Run wsreset.exe, check Windows Store service"
  ["system.memory.pressure"]="Close other applications, increase Node.js heap size"
  ["session.idle.timeout"]="Increase idle timeout, implement keepalive heartbeat"
  ["system.port.conflict"]="Find and terminate process using the port"
  ["tls.cert.expired"]="Renew SSL certificate, restart services"
)

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <logfile> [--json] [--verbose]"
    echo ""
    echo "Arguments:"
    echo "  logfile    Path to the log file to scan"
    echo ""
    echo "Options:"
    echo "  --json     Output results as JSON"
    echo "  --verbose  Show all scanned lines, not just matches"
    echo ""
    echo "Examples:"
    echo "  $0 /var/log/app.log"
    echo "  $0 ~/logs/claude-desktop.log --json"
    echo "  $0 error.log --verbose"
    exit 1
}

log_info() {
    if [ "$VERBOSE" = false ]; then
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_match() {
    echo -e "${CYAN}[MATCH]${NC} $1"
}

# Parse command line arguments
parse_args() {
    if [ $# -lt 1 ]; then
        usage
    fi

    LOGFILE="$1"
    shift

    while [ $# -gt 0 ]; do
        case "$1" in
            --json)
                OUTPUT_JSON=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Check if required tools are available
check_deps() {
    if ! command -v grep &> /dev/null; then
        log_error "grep is required but not installed"
        exit 1
    fi
    if ! command -v wc &> /dev/null; then
        log_error "wc is required but not installed"
        exit 1
    fi
}

# Validate input file
validate_logfile() {
    if [ ! -f "$LOGFILE" ]; then
        log_error "Log file not found: $LOGFILE"
        exit 1
    fi

    if [ ! -r "$LOGFILE" ]; then
        log_error "Log file is not readable: $LOGFILE"
        exit 1
    fi

    local size
    size=$(wc -c < "$LOGFILE")
    if [ "$size" -eq 0 ]; then
        log_warn "Log file is empty: $LOGFILE"
        exit 0
    fi
}

# Scan log file for known patterns
scan_logs() {
    local total_lines=0
    local match_count=0
    declare -A found_fingerprints=()
    declare -A match_details=()

    total_lines=$(wc -l < "$LOGFILE")
    log_info "Scanning $LOGFILE ($total_lines lines)..."

    while IFS= read -r line; do
        for fingerprint in "${!ERROR_PATTERNS[@]}"; do
            local pattern="${ERROR_PATTERNS[$fingerprint]}"
            if echo "$line" | grep -qEi "$pattern"; then
                match_count=$((match_count + 1))

                if [ -z "${found_fingerprints[$fingerprint]:-}" ]; then
                    found_fingerprints["$fingerprint"]=0
                    match_details["$fingerprint"]=""
                fi
                found_fingerprints["$fingerprint"]=$(( ${found_fingerprints[$fingerprint]} + 1 ))

                # Store first matching line as example
                if [ -z "${match_details[$fingerprint]}" ]; then
                    match_details["$fingerprint"]="$line"
                fi

                if [ "$VERBOSE" = true ]; then
                    log_match "[$fingerprint] $line"
                fi
            fi
        done
    done < "$LOGFILE"

    # Output results
    echo ""
    echo "========================================"
    echo "  Error Pattern Scan Results"
    echo "========================================"
    echo "  File: $LOGFILE"
    echo "  Lines scanned: $total_lines"
    echo "  Matches found: $match_count"
    echo "  Unique patterns: ${#found_fingerprints[@]}"
    echo "========================================"
    echo ""

    if [ ${#found_fingerprints[@]} -eq 0 ]; then
        log_info "No known error patterns found in log file."
        return 0
    fi

    if [ "$OUTPUT_JSON" = true ]; then
        output_json "${!found_fingerprints[@]}" found_fingerprints match_details
    else
        output_text "${!found_fingerprints[@]}" found_fingerprints match_details
    fi
}

# Output results as formatted text
output_text() {
    local fingerprints=("$@")
    shift
    local -n _counts=$1
    shift
    local -n _details=$1

    for fingerprint in "${fingerprints[@]}"; do
        local count="${_counts[$fingerprint]}"
        local detail="${_details[$fingerprint]}"
        local fix="${ERROR_FIXES[$fingerprint]:-No fix documented}"

        echo -e "${CYAN}--- $fingerprint (${count} occurrence(s)) ---${NC}"
        echo -e "  Fix: ${GREEN}$fix${NC}"
        echo -e "  Example: $(echo "$detail" | head -c 120)"
        echo ""
    done

    echo "========================================"
    echo "  Next Steps:"
    echo "  1. Apply fixes for each matched pattern"
    echo "  2. Re-run the failing command"
    echo "  3. If fix fails, escalate to debugging-and-error-recovery"
    echo "========================================"
}

# Output results as JSON
output_json() {
    local fingerprints=("$@")
    shift
    local -n _counts=$1
    shift
    local -n _details=$1

    echo "{"
    echo "  \"file\": \"$LOGFILE\","
    echo "  \"fingerprints\": ["

    local first=true
    for fingerprint in "${fingerprints[@]}"; do
        local count="${_counts[$fingerprint]}"
        local detail="${_details[$fingerprint]}"
        local fix="${ERROR_FIXES[$fingerprint]:-No fix documented}"

        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        # Escape JSON strings
        local escaped_detail
        escaped_detail=$(echo "$detail" | sed 's/"/\\"/g' | head -c 200)

        echo -n "    {"
        echo -n "\"fingerprint\": \"$fingerprint\", "
        echo -n "\"count\": $count, "
        echo -n "\"fix\": \"$fix\", "
        echo -n "\"example\": \"$escaped_detail\""
        echo -n "}"
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Main function
main() {
    parse_args "$@"
    check_deps
    validate_logfile
    scan_logs
}

main "$@"
