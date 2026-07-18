---
name: error-pattern-resolver
description: "Identifies known errors via fingerprinting and pattern matching, applies pre-verified fixes, and documents resolutions. Reduces debugging time for recurring issues."
version: 1.0.0
tags: [errors, debugging, pattern-matching, known-issues, auto-fix, diagnostics]
agents: [code-reviewer, code-simplifier, debugger, deployer, reviewer, security-auditor, test-engineer, tester]
---

# Error Pattern Resolver

## Overview

This skill implements a systematic approach to error resolution using **fingerprinting** and **pattern matching**. Instead of debugging known errors from scratch, it matches error signatures against a database of pre-fingerprinted issues and applies verified fixes automatically.

**Core principle:** If an error has been solved before, don't debug it — resolve it.

The workflow operates in five phases:
1. **Fingerprint** — Extract a unique signature from the error output
2. **Lookup** — Match the fingerprint against the known errors database
3. **Apply Fix** — Execute the pre-verified resolution steps
4. **Verify** — Confirm the fix resolved the issue
5. **Document** — Record the resolution for future reference

## When to Use

- Error logs contain known error patterns (spawn failures, connection resets, timeouts)
- Recurring build or runtime errors that have been seen before
- Claude Desktop, VS Code, or extension host errors
- Network-related failures (proxy, firewall, SSE drops)
- Deployment or registration errors (MSIX, plugin conflicts)
- Any error where speed of resolution matters more than understanding root cause

## Process

### Phase 1: Fingerprint Extraction

Extract a minimal signature from the error output:

```
FINGERPRINT FORMAT: <component>.<error-type>.<specific-detail>

Examples:
  spawn.gh.ENOENT                    → GitHub CLI not found
  network.guest-connected.timeout    → Guest connection timeout
  network.connection.reset           → Connection reset by peer
  deployment.msix.null                → MSIX deployment is NULL
  plugin.scan.command-collision       → Conflicting command registration
  apify.server.timeout               → Apify server timeout
  sse.connection.reset               → SSE connection reset
  update.windows-store.failed        → Auto-update via Windows Store failed
  system.memory.pressure             → High memory usage
  session.idle.timeout               → Session idle timeout exceeded
```

### Phase 2: Database Lookup

Match the fingerprint against `references/known-errors.md`:

1. Parse error message for known substrings
2. Normalize the error (strip timestamps, paths, variable data)
3. Generate fingerprint
4. Look up in database
5. If match found → proceed to Phase 3
6. If no match → escalate to `debugging-and-error-recovery`

### Phase 3: Apply Fix

Execute the resolution steps from the database entry:

- Run automated fix script if available (check `scripts/` directory)
- Apply manual steps if script not available
- Capture exit codes and output
- If fix fails → escalate to `debugging-and-error-recovery`

### Phase 4: Verify

Confirm resolution:

- Re-run the command that originally failed
- Check that the error no longer appears in logs
- Verify system state matches expected conditions
- If verification fails → escalate to `debugging-and-error-recovery`

### Phase 5: Document

Record the resolution:

- Append to session log with fingerprint, fix applied, and outcome
- If new error encountered (not in database), create a new entry template
- Update known-errors.md if resolution differs from documented fix

## Known Errors Database

Full database is in `references/known-errors.md`. Quick reference:

| Fingerprint | Error | Fix |
|---|---|---|
| `spawn.gh.ENOENT` | `spawn gh ENOENT` | Install GitHub CLI |
| `network.guest-connected.timeout` | `isGuestConnected timeout` | Check network, restart bridge |
| `network.connection.reset` | `ERR_CONNECTION_RESET` | Check proxy/firewall settings |
| `deployment.msix.null` | `Deployment is NULL` | Re-register MSIX package |
| `plugin.scan.command-collision` | `PluginScan command collision` | Rename conflicting command |
| `apify.server.timeout` | `Apify server timeout` | Verify APIFY_TOKEN environment variable |
| `sse.connection.reset` | `SSE connection reset` | Retry with exponential backoff |
| `update.windows-store.failed` | `Auto-update failed` | Check Windows Store status |
| `system.memory.pressure` | `Memory pressure` | Close other applications |
| `session.idle.timeout` | `Session timeout` | Reduce idle time threshold |

## Resolution Workflow

```
Error Occurs
    │
    ▼
Extract Fingerprint
    │
    ▼
┌─────────────────┐     ┌──────────────────────┐
│ Match Found?     │────▶│ No match             │
│                  │     │ → escalate to         │
│                  │     │   debugging-and-      │
│                  │     │   error-recovery      │
└────────┬────────┘     └──────────────────────┘
         │ Yes
         ▼
Apply Pre-Verified Fix
    │
    ▼
┌─────────────────┐     ┌──────────────────────┐
│ Fix Succeeded?   │────▶│ No                   │
│                  │     │ → escalate to         │
│                  │     │   debugging-and-      │
│                  │     │   error-recovery      │
└────────┬────────┘     └──────────────────────┘
         │ Yes
         ▼
Verify Resolution
    │
    ▼
Document & Close
```

## Auto-Fix Scripts

Located in `scripts/`:

| Script | Purpose | Trigger |
|---|---|---|
| `scan-logs.sh` | Parse log files and extract error fingerprints | Run against any log file to identify known errors |
| `fix-gh-cli.ps1` | Install GitHub CLI on Windows | When `spawn gh ENOENT` is detected |

To use a script:
```bash
# Scan logs for known errors
bash scripts/scan-logs.sh /path/to/logfile.log

# Auto-fix GitHub CLI
powershell -ExecutionPolicy Bypass -File scripts/fix-gh-cli.ps1
```

## Escalation

Escalate to `debugging-and-error-recovery` when:

- Fingerprint does not match any known error
- Pre-verified fix fails to resolve the issue
- Verification step confirms the error persists
- Error is a symptom of a deeper systemic issue
- Multiple known errors occur simultaneously (cascade failure)

## Common Rationalizations

| Rationalization | Why It's Wrong |
|---|---|
| "I'll just debug it from scratch" | You're wasting time solving a problem that's already been solved |
| "The fix might not work for my case" | Try the fix first; escalate only if it fails |
| "I should understand the root cause first" | Understanding can come after resolution — speed matters |
| "This error looks different than the database" | Normalize the error; minor formatting differences don't change the root cause |
| "I'll skip the fingerprint and just search" | Fingerprinting is faster and more reliable than text search |
| "The script might be outdated" | Run it anyway; if it fails, escalate with evidence |
| "I should fix the underlying code instead" | This skill is for known errors; code changes go through `code-simplification` |

## Red Flags

- Error message contains **multiple stacked errors** (cascade failure — escalate)
- Fingerprint matches but **fix steps are incomplete** in database (update database first)
- **Permission denied** when running fix scripts (check admin/elevation requirements)
- Error **reoccurs after fix** (deeper issue — escalate to debugging-and-error-recovery)
- **Unknown error type** not in database (document it, then escalate)
- Fix script requires **environment variables** not set (check prerequisites)

## Verification

Before marking a known error as resolved:

- [ ] Fingerprint extracted correctly
- [ ] Match confirmed in known-errors.md database
- [ ] Fix script executed successfully (exit code 0)
- [ ] Original failing command now succeeds
- [ ] Error no longer appears in subsequent log output
- [ ] Resolution documented in session log
- [ ] If new error: database entry created for future reference

## Dependencies

- **debugging-and-error-recovery** — escalation target for unmatched or unresolved errors
- **code-simplification** — if fix requires code changes rather than environment fixes
- **knowledge-capture** — for documenting new error patterns discovered
