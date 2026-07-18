# Contributing to Agent Skillpack

## Adding a New Skill

### 1. Copy the Template

```bash
cp -r skills/_template skills/<your-skill-name>
```

### 2. Fill in SKILL.md

The canonical format uses YAML frontmatter:

```yaml
---
name: my-skill-name
description: >-
  One-line description of what this skill does.
  Use when [trigger condition].
version: 1.0.0
tags: [category1, category2]
agents: [opencode, claude, codex, cursor, windsurf, copilot, cline, aider]
---
```

Then follow the skill anatomy:

1. **Overview** — What this skill does and why
2. **When to Use / When NOT to Use** — Trigger conditions
3. **Process** — Step-by-step workflow
4. **Common Rationalizations** — Excuses to skip the process
5. **Red Flags** — Warning signs
6. **Verification** — How to confirm it worked

### 3. Fill in meta.json

```json
{
  "name": "my-skill-name",
  "version": "1.0.0",
  "description": "One-line description",
  "tags": ["category1", "category2"],
  "agents": ["opencode", "claude", "codex", "cursor", "windsurf", "copilot", "cline", "aider"],
  "category": "workflow",
  "dependencies": [],
  "scripts": [],
  "references": []
}
```

### 4. Add Supporting Files

- `references/` — Detailed reference docs
- `scripts/` — Executable helpers (Bash, PowerShell, Python)
- `agents/` — Sub-agent definitions (for multi-agent skills)

### 5. Build and Validate

```bash
npm run build     # Generate adapters
npm run validate  # Check all skills
```

## Skill Naming Convention

- Use `kebab-case` for skill names
- Be descriptive: `error-pattern-resolver` not `error-fix`
- Avoid generic names: `git-helper` is bad, `git-workflow-and-versioning` is good

## Versioning

Skills use semantic versioning (semver):

- **MAJOR** — Breaking change to skill process or output format
- **MINOR** — New capability, additional references, expanded process
- **PATCH** — Bug fixes, typo corrections, clarification

## Writing Style

- Be direct and opinionated
- Show code examples, not just descriptions
- Include "Common Rationalizations" — address the excuses
- Include "Red Flags" — help agents recognize when to stop
- Keep under 500 lines per SKILL.md

## File Size Limits

| Agent | Limit | Strategy |
|-------|-------|----------|
| Codex | 32KB total | Priority-rank skills |
| Windsurf | 6K tokens | Most-used skills first |
| Others | No hard limit | Keep reasonable (<200 lines per skill) |
