---
name: session-lifecycle-manager
description: Manages Claude session state machines, SSE bridge health, and session cleanup across desktop and web clients. Use when sessions timeout unexpectedly, bridge connections drop, or you need to audit and archive stale sessions.
version: 1.0.0
tags:
  - sessions
  - lifecycle
  - bridge
  - timeout
agents:
  - claude-desktop
  - claude-web
  - claude-code
  - claude-api
  - claude-cli
  - claude-mobile
  - claude-plugin
  - claude-embedded
category: claude-desktop
---

# Session Lifecycle Manager

## Overview

Claude sessions follow a state machine governed by activity, timeouts, and bridge connections. Understanding this state machine prevents unexpected disconnects, data loss, and stale session accumulation. The SSE (Server-Sent Events) bridge maintains a persistent connection to `api.anthropic.com` with a 20-second heartbeat interval, acting as the liveness signal between client and server.

Sessions progress through four states: **active**, **idle**, **timed_out**, and **archived**. Transitions are driven by user activity, heartbeat failures, and explicit cleanup actions. Mismanaging these transitions leads to zombie sessions, wasted resources, and degraded performance.

## When to Use

- Application restarts leave orphaned sessions
- Session cleanup or archival is needed
- SSE bridge health checks fail or degrade
- Users report unexpected session terminations
- You need to audit session duration and activity patterns
- Timeout configuration needs adjustment for different use cases
- Reconnection logic after network interruptions

## Session States

### State Definitions

| State | Description | Duration | Resources |
|-------|-------------|----------|-----------|
| `active` | User is interacting; bridge is healthy | Until idle or error | Full allocation |
| `idle` | No user activity; heartbeat still flowing | Up to 900s (15 min) | Reduced allocation |
| `timed_out` | Heartbeat missed or session expired | Until archived or resumed | Minimal allocation |
| `archived` | Session persisted to storage; cleaned up | Permanent | No runtime allocation |

### State Transitions

```
                    ┌──────────────┐
                    │              │
          ┌────────►   active     ◄────────┐
          │         │              │        │
          │         └──────┬───────┘        │
          │                │                │
     user action      idle timeout     user action
          │           (900s)              │
          │                │                │
          │                ▼                │
          │         ┌──────────────┐        │
          │         │              │        │
          │         │     idle     ├────────┘
          │         │              │
          │         └──────┬───────┘
          │                │
          │         heartbeat miss
          │           or manual
          │                │
          │                ▼
          │         ┌──────────────┐
          │         │              │
          └─────────┤  timed_out   │
           resume   │              │
                    └──────┬───────┘
                           │
                    archive action
                      or expiry
                           │
                           ▼
                    ┌──────────────┐
                    │              │
                    │   archived   │
                    │              │
                    └──────────────┘
```

## Bridge Architecture

The SSE bridge maintains a persistent HTTP connection to `api.anthropic.com`:

- **Protocol**: Server-Sent Events over HTTPS
- **Heartbeat interval**: 20 seconds
- **Reconnect backoff**: Exponential (1s → 2s → 4s → 8s → 16s → 30s max)
- **Max reconnect attempts**: 5 before entering `timed_out`

### Bridge Health Indicators

| Indicator | Healthy | Degraded | Failed |
|-----------|---------|----------|--------|
| Heartbeat latency | < 2s | 2–5s | > 5s or missing |
| Last event time | < 20s ago | 20–60s ago | > 60s ago |
| Reconnect count | 0 | 1–3 | ≥ 5 |

## Timeout Configuration

| Timeout | Default | Purpose |
|---------|---------|---------|
| Session timeout | 900s (15 min) | Idle session expiry |
| Preview timeout | 1800s (30 min) | Preview/expired session retention |
| Heartbeat timeout | 60s | Bridge liveness detection |
| Archive delay | 86400s (24 hr) | Time before idle sessions are archived |

Adjust timeouts based on usage patterns. Long-running workflows may need extended session timeouts; high-security environments may need shorter ones.

## Cleanup Workflow

```
1. DISCOVER  → List all sessions with metadata
2. CLASSIFY  → Group by state (active, idle, timed_out, archived)
3. EVALUATE  → Check age, last activity, resource usage
4. DECIDE    → Keep / archive / delete each session
5. EXECUTE   → Archive eligible sessions; delete expired archives
6. VERIFY    → Confirm cleanup results; log actions
```

### Cleanup Script Usage

```bash
# Archive sessions older than 7 days
./scripts/cleanup-sessions.sh --older-than 7d

# Archive sessions older than 30 days with dry-run
./scripts/cleanup-sessions.sh --older-than 30d --dry-run

# Check bridge health before cleanup
./scripts/check-bridge.sh
```

## Reconnection Logic

When a bridge connection drops:

1. **Detect**: Missed heartbeat or SSE stream error
2. **Backoff**: Wait with exponential backoff (1s–30s)
3. **Retry**: Attempt reconnection up to 5 times
4. **Fallback**: If all retries fail, transition session to `timed_out`
5. **Resume**: On next user action, re-establish bridge and restore state

```
connection lost
    │
    ▼
wait 1s → retry ──► success? ──► restore active
    │                   │
    │                  NO
    ▼
wait 2s → retry ──► success? ──► restore active
    │                   │
    │                  NO
    ▼
wait 4s → retry ──► success? ──► restore active
    │                   │
    │                  NO
    ▼
wait 8s → retry ──► success? ──► restore active
    │                   │
    │                  NO
    ▼
wait 16s → retry ──► success? ──► restore active
    │                   │
    │                  NO
    ▼
wait 30s → retry ──► success? ──► restore active
    │                   │
    │                  NO
    ▼
  timeout → transition to timed_out
```

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "I'll just leave the session running" | Idle sessions consume resources and degrade performance for everyone |
| "Timeouts are too aggressive" | Shorter timeouts prevent zombie sessions; adjust only with clear justification |
| "Bridge reconnects automatically" | Automatic reconnection has limits; 5 failures means the session is dead |
| "Archiving deletes data" | Archiving persists session data to storage; it's not deletion |
| "I'll clean up later" | Later becomes never; schedule regular cleanup cycles |
| "The heartbeat handles everything" | Heartbeat detects liveness but doesn't prevent resource waste from idle sessions |

## Red Flags

- Sessions stuck in `active` with no user interaction for > 15 minutes
- Bridge reconnect count increasing rapidly (> 3 in an hour)
- Heartbeat latency consistently > 2 seconds
- Archive queue growing without cleanup runs
- `timed_out` sessions accumulating without archival
- Memory usage climbing proportionally to session count

## Verification

Before declaring session management healthy:

- [ ] All sessions are in expected states (no stuck states)
- [ ] Bridge heartbeat latency < 2s for active sessions
- [ ] No sessions idle for > 15 minutes without timeout
- [ ] Cleanup script runs without errors
- [ ] Archived sessions are accessible for audit
- [ ] Reconnection logic tested with simulated bridge failure
- [ ] Timeout configurations documented and justified
- [ ] Resource usage proportional to active session count
