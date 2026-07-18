---
name: dual-runtime-coordinator
description: Coordinates native Windows and Linux VM execution for optimal runtime selection and task routing
version: 1.0.0
tags:
  - runtime
  - vm
  - windows
  - linux
agents:
  - opencode
  - claude
  - cursor
  - copilot
  - windsurf
  - cline
  - aider
  - amp
category: operations
---

# Dual-Runtime Coordinator

## Overview

The dual-runtime coordinator manages task execution across two isolated runtimes: the native Windows host and a Linux virtual machine. It ensures each operation runs in the environment best suited for its requirements, balancing safety, performance, and compatibility. The coordinator abstracts runtime selection so agents and users can invoke operations without worrying about which environment handles execution.

## When to Use

Use this skill when:

- **Sandboxed execution** is required — untrusted code, experimental scripts, or third-party packages should run in the VM to protect the host.
- **Cross-platform tasks** involve operations that only work on Linux (e.g., certain build tools, containers, or POSIX utilities).
- **Performance-sensitive workloads** benefit from VM isolation (dedicated resources, snapshot-based rollback).
- **Security boundaries** must separate host file system access from execution environments.
- **Multi-runtime coordination** is needed — tasks that span both host-native operations and VM-bound operations.

Do NOT use this skill when:

- All operations are host-native (no VM involvement required).
- The task is purely file-system manipulation with no execution component.
- The VM is unavailable and no fallback strategy is acceptable.

## Runtime Matrix

| Operation Category | Native (Windows Host) | VM (Linux Guest) |
|-------------------|-----------------------|-------------------|
| File operations (read, write, move) | ✅ Primary | ❌ Avoid |
| Git operations (clone, commit, push) | ✅ Primary | ⚠️ Only for Linux-specific workflows |
| Code execution (scripts, compilers) | ⚠️ Sandboxed only | ✅ Primary |
| Test suites | ⚠️ Sandboxed only | ✅ Primary |
| Package installation (npm, pip, cargo) | ⚠️ Sandboxed only | ✅ Primary |
| Docker / container operations | ❌ Avoid | ✅ Primary |
| System-level diagnostics | ✅ Primary | ⚠️ VM-specific only |
| Build operations (make, cmake) | ⚠️ Sandboxed only | ✅ Primary |

## VM Bundle Lifecycle

The VM bundle follows a five-phase lifecycle to balance startup speed with resource efficiency:

1. **Load** — Decompress the VM bundle from disk using Zstandard. Triggered on first access or explicit warm command. Latency: 2–8 seconds depending on bundle size and disk speed.

2. **Warm** — Pre-initialize the runtime environment. Load common packages, caches, and shared libraries into memory. Reduces first-execution latency by 40–70%.

3. **Execute** — Active execution state. The VM accepts and runs tasks. Resource allocation is fixed during this phase (CPU cores, memory limits, network access).

4. **休眠 (Hibernate)** — VM state is serialized and compressed back to disk. Memory contents are preserved in compressed form. Resume from this state is faster than a cold load. Triggered after configurable idle timeout (default: 5 minutes).

5. **Unload** — VM bundle is fully decompressed and resources are released. Used for cleanup, updates, or emergency resource reclamation. Requires a full Load → Warm cycle to restart.

## Selection Logic

Use the following decision tree to route tasks:

```
START
│
├─ Is this a file operation (read, write, move, copy)?
│   ├─ YES → Run on Native Host
│   └─ NO ↓
│
├─ Is this a Git operation?
│   ├─ YES → Does it require Linux-specific tooling?
│   │   ├─ YES → Run on VM
│   │   └─ NO → Run on Native Host
│   └─ NO ↓
│
├─ Is this code execution, testing, or building?
│   ├─ YES → Run on VM
│   └─ NO ↓
│
├─ Does this require Docker/containers?
│   ├─ YES → Run on VM
│   └─ NO ↓
│
├─ Is the VM currently available?
│   ├─ YES → Run on VM (default for ambiguous cases)
│   └─ NO → Apply Fallback Strategy
```

## Fallback Strategies

When the VM is unavailable or unresponsive:

| Fallback | Trigger | Action |
|----------|---------|--------|
| Retry with timeout | VM responds slowly (latency > 30s) | Restart VM, retry operation with 60s timeout |
| Native fallback | VM unreachable after 2 retries | Run on native host with sandboxing (restricted permissions, temp directory, cleanup on completion) |
| Queue and alert | VM down and native fallback insufficient | Queue task, alert operator, resume when VM is restored |
| Fail fast | Critical operation requiring VM isolation | Report error immediately, do not attempt native fallback |

## Common Rationalizations

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "Just run it on native, it'll be faster" | Speed is irrelevant if it compromises security boundaries or produces inconsistent results |
| "The VM is always up, no need to check" | VMs can fail silently; always verify availability before routing |
| "I'll skip the warm phase, it'll start fast enough" | Cold starts add 2–8 seconds per invocation; warm starts add 0.5–1 second amortized |
| "File operations work fine in the VM" | Cross-boundary file I/O introduces latency, sync issues, and permission complexity |
| "Docker works on Windows now" | Docker Desktop on Windows adds its own VM layer; running inside the Linux VM avoids nested virtualization overhead |
| "I don't need sandboxing if I trust the code" | Trust is not binary; defense-in-depth protects against regressions and supply-chain attacks |

## Red Flags

- ❌ Running untrusted code on the native host without sandboxing
- ❌ Cross-boundary file operations (VM writing directly to host paths)
- ❌ Ignoring VM health checks before routing tasks
- ❌ Skipping the Hibernate phase (causes unbounded memory growth)
- ❌ Running Docker-in-Docker instead of using the VM's native Docker
- ❌ Hardcoding runtime selection instead of using the decision tree

## Verification

Before completing any dual-runtime coordination task, verify:

- [ ] Task was routed to the correct runtime based on the decision tree
- [ ] VM health check passed (if VM was used)
- [ ] No cross-boundary file operations occurred without explicit approval
- [ ] Sandbox constraints were applied for native-hosted untrusted code
- [ ] VM was hibernated or unloaded after task completion (if no further tasks pending)
- [ ] Fallback strategy was documented if native fallback was used
- [ ] Resource usage (CPU, memory, disk) stayed within configured limits
