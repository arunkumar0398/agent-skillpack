# Agent Skillpack

Universal AI agent skill pack — **70+ engineering skills** compatible with 8 coding agents.

## What Is This?

A single source of truth for reusable engineering workflows, auto-adapted to your agent's format. Write once, use everywhere.

## Supported Agents

| Agent | Format | Adapter Location |
|-------|--------|-----------------|
| **OpenCode** | `SKILL.md` (native) | `dist/opencode/skills/` |
| **Claude Code** | `CLAUDE.md` + `.claude/rules/` | `dist/claude/` |
| **Codex** | `AGENTS.md` | `dist/codex/` |
| **Cursor** | `.cursor/rules/*.mdc` | `dist/cursor/` |
| **Windsurf** | `.windsurfrules` | `dist/windsurf/` |
| **GitHub Copilot** | `.github/copilot-instructions.md` | `dist/copilot/` |
| **Cline** | `.clinerules/` | `dist/cline/` |
| **Aider** | `CONVENTIONS.md` + `.aider.conf.yml` | `dist/aider/` |

## Quick Start

### 1. Build Adapters

```bash
npm install   # (no deps, but sets up node)
npm run build
```

### 2. Install for Your Agent

**OpenCode** — symlink into config:
```bash
mklink /D "C:\Users\YOU\.config\opencode\skills\agent-skillpack" "D:\agent-skillpack\skills"
```

**Claude Code** — copy to project:
```bash
cp -r D:\agent-skillpack\dist\claude\* /path/to/your/project/
```

**Codex** — copy AGENTS.md:
```bash
cp D:\agent-skillpack\dist\codex\AGENTS.md /path/to/your/project/
```

**Cursor** — copy rules:
```bash
cp -r D:\agent-skillpack\dist\cursor\.cursor /path/to/your/project/
```

**Windsurf** — copy rules file:
```bash
cp D:\agent-skillpack\dist\windsurf\.windsurfrules /path/to/your/project/
```

**GitHub Copilot** — copy instructions:
```bash
cp -r D:\agent-skillpack\dist\copilot\.github /path/to/your/project/
```

**Cline** — copy rules:
```bash
cp -r D:\agent-skillpack\dist\cline\.clinerules /path/to/your/project/
```

**Aider** — copy conventions:
```bash
cp D:\agent-skillpack\dist\aider\* /path/to/your/project/
```

## Skill Categories

### Workflow & Process
- `spec-driven-development` — Write specs before code
- `planning-and-task-breakdown` — Decompose into tasks
- `incremental-implementation` — Ship changes incrementally
- `test-driven-development` — Red-green-refactor cycle
- `code-review-and-quality` — Multi-axis review
- `debugging-and-error-recovery` — Systematic root-cause debugging

### Git & Versioning
- `git-workflow-and-versioning` — Branch, commit, release
- `worktree-orchestrator` — Parallel git worktrees
- `deprecation-and-migration` — Remove old systems safely

### Architecture & Design
- `api-and-interface-design` — Stable API contracts
- `frontend-ui-engineering` — Production-quality UI
- `system-design` — Technology decisions
- `design-philosophy-first` — Philosophy-driven visuals

### Operations
- `ci-cd-and-automation` — Pipeline setup
- `shipping-and-launch` — Production deployment
- `observability-and-instrumentation` — Logging, metrics, tracing
- `performance-optimization` — Core Web Vitals, profiling

### Security & Quality
- `security-and-hardening` — Vulnerability prevention
- `code-simplification` — Reduce complexity
- `quality-enforcement` — Lint, type, coverage gates

### Claude Desktop Specific
- `session-lifecycle-manager` — Session state machine
- `mcp-server-health-monitor` — MCP server health
- `dual-runtime-coordinator` — Native + VM execution
- `config-drift-detector` — Config validation
- `error-pattern-resolver` — Known error database
- `skill-evaluation-pipeline` — A/B test skills

### Agent Meta
- `using-agent-skills` — Skill discovery
- `context-engineering` — Context optimization
- `interview-me` — Extract user intent
- `idea-refine` — Refine raw ideas

## Development

### Adding a New Skill

1. Copy `skills/_template/` to `skills/<your-skill-name>/`
2. Fill in `SKILL.md` following the template
3. Add `meta.json` with metadata
4. Add scripts in `scripts/` if needed
5. Run `npm run build` to generate adapters
6. Run `npm run validate` to verify

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

### Project Structure

```
skills/           → Canonical skills (source of truth)
dist/             → Generated adapters (do not edit)
build.js          → Adapter generator
validate.js       → Schema validator
```

## License

MIT
