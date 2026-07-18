# Runtime Matrix

This document defines which operations run on each runtime and the rationale behind each decision.

## Operations Table

| Operation | Native (Windows) | VM (Linux) | Notes |
|-----------|:-----------------:|:----------:|-------|
| File read/write/copy | ✅ | ❌ | Host file system is authoritative; VM copies introduce sync overhead |
| File move/delete | ✅ | ❌ | Same rationale as file read/write |
| Git clone | ✅ | ⚠️ | Use VM only if cloning Linux-specific repos with native hooks |
| Git commit/push/pull | ✅ | ⚠️ | Standard operations stay on host; Linux-only workflows route to VM |
| Git merge/conflict resolution | ✅ | ⚠️ | Tooling (IDE integration) is host-native |
| Script execution (Python, Node, Bash) | ⚠️ | ✅ | Host execution requires sandboxing (temp dir, restricted permissions) |
| Compiled language builds (C, C++, Rust) | ⚠️ | ✅ | VM provides consistent toolchain; host builds risk PATH pollution |
| Test suites (pytest, jest, cargo test) | ⚠️ | ✅ | Deterministic results in isolated VM environment |
| npm/yarn install | ⚠️ | ✅ | Host installs risk global pollution; VM keeps dependencies isolated |
| pip/pipx install | ⚠️ | ✅ | Same rationale as npm |
| cargo install | ⚠️ | ✅ | Same rationale as npm |
| Docker build | ❌ | ✅ | Requires Linux kernel; Docker Desktop on Windows adds nested VM overhead |
| Docker run | ❌ | ✅ | Same rationale as Docker build |
| docker-compose up | ❌ | ✅ | Same rationale as Docker build |
| Database queries (psql, mysql) | ⚠️ | ✅ | Client tools may exist on host, but VM provides isolated connection |
| System diagnostics (top, free, df) | ✅ (host) | ✅ (VM) | Each runtime reports its own metrics |
| Network diagnostics (ping, curl) | ✅ | ⚠️ | Host for external connectivity; VM for internal network testing |
| Package manager (apt, brew) | ❌ (N/A) | ✅ | Windows uses winget/choco; VM uses apt |
| Cron/scheduled tasks | ❌ | ✅ | VM provides standard cron; host uses Task Scheduler |
| File watching (inotify, fswatch) | ✅ (native tools) | ✅ | Host for IDE integration; VM for build pipelines |

## Legend

- ✅ = Primary runtime for this operation
- ⚠️ = Conditional — use only when specific requirements are met
- ❌ = Do not use this runtime for this operation
- N/A = Operation does not apply to this runtime

## Decision Principles

1. **Host-native for file I/O** — The host file system is the source of truth. VM file operations create synchronization complexity.
2. **VM for execution** — Code execution, testing, and building happen in the VM to maintain isolation and reproducibility.
3. **Conditional for Git** — Most Git operations are host-native for IDE integration. Route to VM only when Linux-specific hooks or tooling are required.
4. **VM for containers** — Docker and container operations require Linux kernel features. Avoid nested virtualization on Windows.
5. **Sandbox if native** — Any untrusted code running on the host must be sandboxed (temp directory, restricted permissions, cleanup on completion).
