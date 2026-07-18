---
name: mcp-server-health-monitor
description: Manages MCP server lifecycle — health checks, timeout tuning, restart protocol, and inventory awareness
version: "1.0.0"
tags: [mcp, servers, health, monitoring]
agents: [all]
category: operations
---

# MCP Server Health Monitor

## Overview

Manages the lifecycle of Model Context Protocol (MCP) servers across your development environment. Covers health probing, timeout configuration, failure detection, restart sequencing, and server inventory management. Ensures all configured MCP servers remain reachable and responsive.

## When to Use

- Server timeouts or unresponsive behavior detected
- Setting up new MCP servers in a project
- Connectivity issues between agents and MCP servers
- Periodic health verification before critical operations
- After network changes, VPN toggles, or system sleep/wake cycles
- When `mcp-info.json` or server configs change

## Health Check Flow

```
probe → check → log → alert
```

1. **Probe** — Send a lightweight request to each server's endpoint
2. **Check** — Compare response time against configured timeout threshold
3. **Log** — Record status (ok, degraded, failed) with timestamp
4. **Alert** — Trigger restart protocol for any server failing probe

## Timeout Configuration

| Parameter | Default | Range |
|-----------|---------|-------|
| `connectTimeout` | 60s | 10–120s |
| `requestTimeout` | 60s | 10–300s |
| `retryDelay` | 5s | 1–30s |
| `maxRetries` | 3 | 0–10 |

**Per-Server Tuning:** Override defaults in `mcp-info.json` under each server's `healthCheck` object. Heavy servers (Apify, browser tools) may need 90–120s. Lightweight servers (filesystem, memory) typically respond in <5s.

## Restart Protocol

```
stop → wait → start → verify → reconnect
```

1. **Stop** — Gracefully shut down the unresponsive server process
2. **Wait** — Allow 2–5 seconds for port release and cleanup
3. **Start** — Launch the server using its configured command and args
4. **Verify** — Re-run health probe; confirm status is `ok`
5. **Reconnect** — Re-establish MCP session and re-register tool schemas

## Server Inventory

Read `mcp-info.json` to discover:
- All configured server names, commands, and arguments
- Per-server timeout overrides
- Server groupings (production, development, test)
- Active vs. inactive server status

```json
{
  "servers": [
    {
      "name": "filesystem",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path"],
      "healthCheck": { "timeout": 30 }
    }
  ]
}
```

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "It was working a minute ago" | Transient failures still need tracking; patterns matter more than anecdotes |
| "I'll just restart manually" | Manual restarts don't catch cascading failures or log for later analysis |
| "Timeouts are fine at defaults" | Different servers have different latency profiles; one size fits none |
| "I'll skip the health check this time" | Skipping once becomes skipping always; automate it |
| "The server is probably just slow" | Slow is a failure mode; degrade the experience proactively |

## Red Flags

- Same server fails health check repeatedly within an hour
- All servers fail simultaneously (network issue, not server issue)
- Response times trending upward across multiple checks
- Server starts successfully but tool calls return errors
- Health check script itself times out (infrastructure problem)
- `mcp-info.json` has servers not present in active config

## Verification Checklist

- [ ] All servers in inventory respond within their configured timeout
- [ ] Failed servers were restarted and re-verified successfully
- [ ] Health check results logged with timestamps
- [ ] Timeout values reviewed against actual response times
- [ ] No orphaned server processes lingering after restart
- [ ] `mcp-info.json` matches actual running server configuration
- [ ] Reconnected sessions have valid tool schemas registered
