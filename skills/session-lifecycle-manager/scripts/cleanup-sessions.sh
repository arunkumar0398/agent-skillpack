#!/usr/bin/env bash
# cleanup-sessions.sh - Archive sessions older than N days
# Usage: ./cleanup-sessions.sh --older-than <Nd> [--dry-run] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
OLDER_THAN_DAYS=7
DRY_RUN=false
VERBOSE=false
SESSION_DIR="${SESSION_DIR:-$HOME/.claude/sessions}"
ARCHIVE_DIR="${ARCHIVE_DIR:-$HOME/.claude/sessions/archive}"
LOG_FILE="${LOG_FILE:-$HOME/.claude/sessions/cleanup.log}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Archive Claude sessions older than N days.

Options:
  --older-than <Nd>   Archive sessions older than N days (default: 7d)
  --dry-run           Show what would be archived without doing it
  --verbose           Print detailed output
  --session-dir <dir> Session directory (default: ~/.claude/sessions)
  --archive-dir <dir> Archive directory (default: ~/.claude/sessions/archive)
  --help              Show this help message

Examples:
  $(basename "$0") --older-than 7d
  $(basename "$0") --older-than 30d --dry-run --verbose
  $(basename "$0") --older-than 1d --session-dir /tmp/sessions
EOF
    exit 0
}

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --older-than)
                OLDER_THAN_DAYS="${2#}"
                OLDER_THAN_DAYS="${OLDER_THAN_DAYS%[dD]}"
                if ! [[ "$OLDER_THAN_DAYS" =~ ^[0-9]+$ ]]; then
                    echo "Error: --older-than must be a positive integer" >&2
                    exit 1
                fi
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --session-dir)
                SESSION_DIR="$2"
                shift 2
                ;;
            --archive-dir)
                ARCHIVE_DIR="$2"
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

validate_environment() {
    if [[ ! -d "$SESSION_DIR" ]]; then
        log "ERROR: Session directory does not exist: $SESSION_DIR"
        exit 1
    fi

    if ! command -v find &>/dev/null; then
        log "ERROR: 'find' command not available"
        exit 1
    fi

    if ! command -v date &>/dev/null; then
        log "ERROR: 'date' command not available"
        exit 1
    fi
}

find_stale_sessions() {
    local cutoff_date
    cutoff_date=$(date -d "-${OLDER_THAN_DAYS} days" '+%Y-%m-%d' 2>/dev/null || \
                 date -v"-${OLDER_THAN_DAYS}d" '+%Y-%m-%d' 2>/dev/null || \
                 echo "")

    if [[ -z "$cutoff_date" ]]; then
        log "ERROR: Could not compute cutoff date"
        exit 1
    fi

    if $VERBOSE; then
        log "Looking for sessions older than $cutoff_date ($OLDER_THAN_DAYS days)"
    fi

    find "$SESSION_DIR" -maxdepth 1 -type f -name "*.json" -mtime +"$OLDER_THAN_DAYS" 2>/dev/null || true
}

archive_session() {
    local session_file="$1"
    local session_name
    session_name=$(basename "$session_file" .json)

    local archive_path="$ARCHIVE_DIR/$(date '+%Y-%m')/${session_name}.json"

    if $DRY_RUN; then
        log "DRY-RUN: Would archive $session_name → $archive_path"
        return 0
    fi

    mkdir -p "$(dirname "$archive_path")"

    if mv "$session_file" "$archive_path"; then
        log "Archived: $session_name → $archive_path"
        return 0
    else
        log "ERROR: Failed to archive $session_name"
        return 1
    fi
}

main() {
    parse_args "$@"
    validate_environment

    log "Starting session cleanup (older-than: ${OLDER_THAN_DAYS}d, dry-run: $DRY_RUN)"

    local stale_sessions
    stale_sessions=$(find_stale_sessions)

    if [[ -z "$stale_sessions" ]]; then
        log "No stale sessions found"
        exit 0
    fi

    local count=0
    local errors=0

    while IFS= read -r session_file; do
        if [[ -n "$session_file" ]]; then
            if archive_session "$session_file"; then
                ((count++))
            else
                ((errors++))
            fi
        fi
    done <<< "$stale_sessions"

    log "Cleanup complete: $count archived, $errors errors"

    if [[ $errors -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
