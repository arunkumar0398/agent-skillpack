---
name: worktree-orchestrator
description: >-
  Creates, tracks, and cleans up git worktrees with naming conventions.
  Use when parallel feature work needs isolation, when cleaning up old
  worktrees, or when managing worktrees across multiple projects.
version: 1.0.0
tags: [git, worktrees, parallel-work, cleanup]
agents: [opencode, claude, codex, cursor, windsurf, copilot, cline, aider]
---

# Worktree Orchestrator

## Overview

Git worktrees let you check out multiple branches simultaneously without stashing or switching. This skill manages the full worktree lifecycle: creation with naming conventions, tracking across projects, and cleanup of stale worktrees.

## When to Use

- Working on multiple features in the same repo simultaneously
- Need to switch context without committing half-done work
- Debugging an issue on `main` while feature branch is in progress
- Cleaning up worktrees from previous sessions
- Managing worktrees across multiple repositories

**When NOT to use:** Single-feature work, short tasks (<30 min), or when branches are shared with others who don't use worktrees.

## Naming Convention

Use the pattern: `<adjective>-<famous-person>`

Examples:
```
pedantic-khorana        (from apex-board, main)
priceless-hypatia       (from career-ops, main)
reverent-feynman        (from autonomous-qa-agent, codex/create-blueprint)
flamboyant-bhaskara     (from superset, fix/duplicate-tooltip)
```

Generate names using:
```bash
# Random adjective + random scientist/mathematician
ADJECTIVES=(pedantic priceless quirky reverent agitated vibrant flamboyant adoring pensive sweet sharp youthful amazing)
PEOPLE=(khorana hypatia napier feynman wilbur bhaskara noether varahamihira shockley brown saha snyder)
echo "${ADJECTIVES[$RANDOM % ${#ADJECTIVES[@]}]}-${PEOPLE[$RANDOM % ${#PEOPLE[@]}]}"
```

## Process

### Step 1: Create Worktree

```bash
# From the main repo directory
cd /path/to/repo

# Generate worktree name
WT_NAME=$(ADJECTIVES=(pedantic priceless quirky); PEOPLE=(khorana hypatia napier); echo "${ADJECTIVES[$RANDOM % 3]}-${PEOPLE[$RANDOM % 3]}")

# Create worktree with new branch
git worktree add -b "claude/$WT_NAME" "../$WT_NAME" main

# Or checkout existing branch
git worktree add "../$WT_NAME" feature/branch-name
```

### Step 2: Register in Tracking File

Maintain a `git-worktrees.json` at your workspace root:

```json
{
  "worktrees": [
    {
      "name": "pedantic-khorana",
      "repo": "apex-board",
      "sourceBranch": "main",
      "worktreeBranch": "claude/pedantic-khorana",
      "path": "D:\\repos\\apex-board\\..\\pedantic-khorana",
      "created": "2026-03-27T10:00:00Z"
    }
  ]
}
```

### Step 3: Check Status

```bash
# List all worktrees
git worktree list

# Check if worktree is locked
git worktree list --porcelain
```

### Step 4: Cleanup

```bash
# Remove merged worktree
git worktree remove /path/to/worktree

# Prune stale references
git worktree prune

# Force remove if stuck
git worktree remove --force /path/to/worktree
```

**Cleanup heuristics:**
- Branch merged into main → remove
- Worktree inactive >30 days → archive, then remove
- Branch deleted remotely → remove
- More than 5 active worktrees → prioritize and clean

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "I'll remember which worktree is which" | You won't. Track them in `git-worktrees.json`. |
| "Stale worktrees don't hurt anything" | They consume disk and confuse `git worktree list`. |
| "I'll just stash and switch" | Stashes get lost. Worktrees are explicit. |
| "One more worktree won't hurt" | >5 per repo becomes unmanageable. Clean first. |

## Red Flags

- More than 5 active worktrees in one repo
- Worktree name doesn't follow convention
- `git worktree list` shows orphaned entries
- Worktree exists but isn't tracked in `git-worktrees.json`

## Verification

Before declaring done:

- [ ] `git worktree list` shows only intended worktrees
- [ ] `git-worktrees.json` is updated with new entry
- [ ] Worktree directory exists and has correct branch
- [ ] No orphaned worktrees from previous sessions
