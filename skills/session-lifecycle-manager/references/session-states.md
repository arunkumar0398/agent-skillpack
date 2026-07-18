# Session States Reference

## State Machine Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SESSION LIFECYCLE STATE MACHINE                  │
└─────────────────────────────────────────────────────────────────────┘

                              ┌─────────────┐
                              │             │
                              │   initial   │
                              │             │
                              └──────┬──────┘
                                     │
                               session created
                                     │
                                     ▼
                            ┌────────────────┐
                            │                │
                ┌──────────►│     active     │◄──────────┐
                │           │                │           │
                │           └───────┬────────┘           │
                │                   │                    │
                │              idle timeout              │
                │              (900s / 15min)            │
                │                   │                    │
          user action               │              user action
                │                   │                    │
                │                   ▼                    │
                │           ┌────────────────┐           │
                │           │                │           │
                │           │      idle      ├───────────┘
                │           │                │
                │           └───────┬────────┘
                │                   │
                │            heartbeat miss
                │            or manual timeout
                │                   │
                │                   ▼
                │           ┌────────────────┐
                │           │                │
                └───────────┤  timed_out     │
                 resume     │                │
                            └───────┬────────┘
                                    │
                             archive action
                            or expiry (24h)
                                    │
                                    ▼
                            ┌────────────────┐
                            │                │
                            │   archived     │
                            │                │
                            └───────┬────────┘
                                    │
                              retention period
                                    │
                                    ▼
                            ┌────────────────┐
                            │                │
                            │    deleted     │
                            │                │
                            └────────────────┘
```

## State Descriptions

### `active`
- **Entry**: Session created or resumed from idle/timed_out
- **Characteristics**: User is interacting; bridge is healthy; full resource allocation
- **Exit conditions**: Idle timeout (900s), bridge failure, explicit user action
- **Resource profile**: Full memory, CPU, network allocation

### `idle`
- **Entry**: No user activity for period < 900s while bridge is healthy
- **Characteristics**: No user interaction; heartbeat still flowing; reduced resources
- **Exit conditions**: User returns (→ active), heartbeat miss (→ timed_out), manual archive
- **Resource profile**: Reduced memory; CPU minimal; network for heartbeat only

### `timed_out`
- **Entry**: Heartbeat missed (> 60s), or idle timeout exceeded (900s)
- **Characteristics**: Session state preserved but not actively maintained
- **Exit conditions**: User resumes (→ active), archive action (→ archived), expiry (→ deleted)
- **Resource profile**: Minimal memory; no CPU; no network

### `archived`
- **Entry**: Explicit archive action or automatic cleanup after 24h idle
- **Characteristics**: Session data persisted to storage; no runtime presence
- **Exit conditions**: Retention period expiry (→ deleted), explicit restore (→ active)
- **Resource profile**: Storage only; zero runtime resources

### `deleted`
- **Entry**: Retention period exceeded for archived sessions
- **Characteristics**: Session data permanently removed
- **Exit conditions**: None (terminal state)
- **Resource profile**: None

## Transition Table

| From | To | Trigger | Condition |
|------|----|---------|-----------|
| initial | active | Session created | Valid credentials; bridge available |
| active | idle | No user activity | 900s timeout not yet reached |
| active | timed_out | Bridge failure | 5 reconnect attempts exhausted |
| active | archived | Manual archive | User or admin action |
| idle | active | User action | User sends message or interacts |
| idle | timed_out | Heartbeat miss | 60s without heartbeat event |
| idle | archived | Cleanup script | Session older than retention threshold |
| timed_out | active | User resume | User reconnects within session window |
| timed_out | archived | Auto-archive | 24h since timed_out |
| timed_out | deleted | Retention expiry | 30 days since archived |
| archived | active | Explicit restore | User or admin restores session |
| archived | deleted | Retention expiry | Configured retention period exceeded |

## Duration Defaults

| Parameter | Value | Configurable |
|-----------|-------|--------------|
| Active → Idle timeout | 900s (15 min) | Yes |
| Idle → Timed_out (heartbeat) | 60s | Yes |
| Timed_out → Archived (auto) | 86400s (24 hr) | Yes |
| Archived → Deleted (retention) | 2592000s (30 days) | Yes |
| Bridge heartbeat interval | 20s | No |
| Max reconnect attempts | 5 | Yes |
| Reconnect backoff max | 30s | No |

## Visual State Legend

```
● active      = Full engagement; resources allocated
◐ idle        = Connected but inactive; resources reduced
○ timed_out   = Disconnected; minimal resources
◌ archived    = Persisted; no runtime resources
✕ deleted     = Permanently removed
```
