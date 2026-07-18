---
name: config-drift-detector
description: Detects and resolves configuration drift across Claude Desktop and other AI agent installations by comparing current state against known-good schemas
version: 1.0.0
tags: [config, validation, drift, settings]
agents: [all 8]
category:
  name: Meta & Configuration
  description: Skills for managing agent configuration, settings, and system-level concerns
---

# Config Drift Detector

## Overview

Configuration drift occurs when agent config files diverge from their expected state due to partial updates, manual edits, corrupted writes, or version mismatches. This skill systematically detects drift by comparing current configs against known-good schemas, produces actionable diffs, and provides safe sync workflows to restore or migrate configurations.

Covers: `config.json`, `claude_desktop_config.json`, `window-state.json`, `bridge-state.json`, `git-worktrees.json`, `extensions-installations.json`, and any `.opencode/` settings files.

## When to Use

| Trigger | Example |
|---------|---------|
| Unexpected behavior after update | "Claude Desktop won't connect to MCP servers after upgrading" |
| Migration between machines | "I cloned my config from my laptop to desktop and things broke" |
| Periodic integrity check | "I want to verify my configs haven't drifted from defaults" |
| Post-edit verification | "I manually edited config.json—did I break anything?" |
| Multi-agent alignment | "My agents have inconsistent settings across workspaces" |

## Config Inventory

### config.json (Claude Desktop)
- **Location:** `~/Library/Application Support/Claude/config.json` (macOS) or `%APPDATA%\Claude\config.json` (Windows)
- **Purpose:** Core Claude Desktop settings—MCP servers, permissions, UI preferences
- **Critical fields:** `mcpServers`, `permissions`, `theme`, `autoUpdate`

### claude_desktop_config.json
- **Location:** Same directory as config.json, alternate naming convention
- **Purpose:** Legacy or alternate config path for Claude Desktop
- **Schema:** Mirrors config.json with possible field differences across versions

### window-state.json
- **Location:** `~/.claude/window-state.json`
- **Purpose:** Window position, size, panel visibility, editor layout
- **Risk level:** Low—regenerates if deleted, but preferences reset

### bridge-state.json
- **Location:** `~/.claude/bridge-state.json`
- **Purpose:** Connection state for Claude-to-agent bridges, session tokens
- **Risk level:** Medium—stale bridge state causes connection failures

### git-worktrees.json
- **Location:** `~/.claude/git-worktrees.json`
- **Purpose:** Tracks active git worktrees and their associated workspace contexts
- **Risk level:** Medium—stale entries cause phantom workspace references

### extensions-installations.json
- **Location:** `~/.claude/extensions-installations.json`
- **Purpose:** Installed extensions, versions, enabled/disabled state
- **Risk level:** Low—extensions reinstall cleanly, but config overrides lost

## Drift Detection

### Process

1. **Snapshot** current state of all config files
2. **Load** reference schema from `references/config-schemas.md` or baseline snapshot
3. **Compare** field-by-field, flagging additions, removals, and type mismatches
4. **Output** structured diff with severity levels:
   - `CRITICAL` — missing required field, type violation, schema break
   - `WARNING` — unexpected value, deprecated field, future incompatibility
   - `INFO` — cosmetic difference, optional field missing, style divergence

### Diff Output Format

```
[CRITICAL] config.json → mcpServers.missing-server
  Expected: object with "command" and "args"
  Found:    (absent)

[WARNING]  config.json → theme
  Expected: string in ["dark", "light", "system"]
  Found:    "blue"

[INFO]     window-state.json → panelWidth
  Expected: number (50-800)
  Found:    750 (within range, but differs from baseline 400)
```

## Validation Rules

### config.json
| Field | Type | Required | Rule |
|-------|------|----------|------|
| `mcpServers` | object | yes | Each entry must have `command` (string) and `args` (array) |
| `permissions` | object | yes | Keys must be valid permission identifiers |
| `theme` | string | no | Must be one of: `"dark"`, `"light"`, `"system"` |
| `autoUpdate` | boolean | no | — |
| `contextWindow` | number | no | Must be ≥ 1000 |

### window-state.json
| Field | Type | Required | Rule |
|-------|------|----------|------|
| `width` | number | no | Range: 400–3840 |
| `height` | number | no | Range: 300–2160 |
| `x` | number | no | Must be within screen bounds |
| `y` | number | no | Must be within screen bounds |
| `maximized` | boolean | no | — |

### bridge-state.json
| Field | Type | Required | Rule |
|-------|------|----------|------|
| `sessionId` | string | yes | Must be non-empty |
| `connectedAt` | string | yes | Must be valid ISO 8601 timestamp |
| `status` | string | yes | Must be one of: `"connected"`, `"disconnected"`, `"error"` |

### git-worktrees.json
| Field | Type | Required | Rule |
|-------|------|----------|------|
| `worktrees` | array | yes | Each entry must have `path` (string) and `branch` (string) |
| `activeWorktree` | string | no | Must reference a path in `worktrees[].path` if present |

### extensions-installations.json
| Field | Type | Required | Rule |
|-------|------|----------|------|
| `extensions` | array | yes | Each entry must have `id` (string), `version` (string), `enabled` (boolean) |
| `lastChecked` | string | no | Must be valid ISO 8601 timestamp |

## Sync Workflow

```
1. SNAPSHOT    snapshot-configs.sh --output /tmp/configs-before.json
2. COMPARE     diff-configs.sh /tmp/configs-before.json --baseline expected
3. REVIEW      Read diff output, identify CRITICAL/WARNING items
4. FIX         validate-config.sh --fix <config-file> --schema <schema-ref>
5. VERIFY      diff-configs.sh /tmp/configs-before.json --post-fix /tmp/configs-after.json
6. CONFIRM     All CRITICAL items resolved, no new WARNINGs introduced
```

### Safety Rules
- Always snapshot before modifying configs
- Never delete config files—rename to `.bak` first
- Validate after every fix, not just at the end
- If a fix introduces new drift, revert and reassess

## Migration Support

### Export
```bash
# Bundle all configs into a portable archive
tar -czf agent-configs-$(date +%Y%m%d).tar.gz \
  ~/Library/Application\ Support/Claude/config.json \
  ~/.claude/window-state.json \
  ~/.claude/bridge-state.json \
  ~/.claude/git-worktrees.json \
  ~/.claude/extensions-installations.json
```

### Import
```bash
# Extract and validate before applying
tar -xzf agent-configs-20260718.tar.gz -C /tmp/configs/
validate-config.sh /tmp/configs/config.json --strict
# Apply only if validation passes
cp /tmp/configs/config.json ~/Library/Application\ Support/Claude/config.json
```

### Cross-Platform Notes
- Windows paths use `%APPDATA%` instead of `~/Library/Application Support/`
- Path separators differ—normalize before comparing
- Window bounds may need adjustment for different display configurations

## Common Rationalizations

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "My config looks fine to me" | Drift is often invisible—missing optional fields, type coercions, deprecated values that still work but shouldn't |
| "I'll just reconfigure manually" | Manual edits are the #1 cause of drift; you'll forget a field or use an outdated value |
| "It's just window state, who cares" | Corrupted window state can cause startup crashes and blank windows |
| "I backed up my config, so I'm safe" | Backups don't prevent drift—they only help you recover from it after the fact |
| "The tool auto-updates, so it'll fix itself" | Updates can introduce new required fields that don't exist in your config |

## Red Flags

- Config file is empty or contains only `{}`
- File permissions are wrong (world-readable on secrets, or unreadable by the agent)
- JSON contains trailing commas or comments (invalid JSON but some parsers accept it)
- `mcpServers` references commands that don't exist on the system
- Multiple config files with conflicting settings
- Timestamps in bridge-state.json are in the future or extremely old
- Git worktree paths reference deleted directories
- Extensions list contains entries not found in any registry

## Verification

- [ ] All config files pass `validate-config.sh --strict`
- [ ] No CRITICAL drift items in diff output
- [ ] Snapshot saved before any modifications
- [ ] Post-fix diff shows expected state with no regressions
- [ ] Agent starts and connects successfully after fix
- [ ] Bridge-state timestamps are current and consistent
- [ ] MCP server commands are reachable from current environment
