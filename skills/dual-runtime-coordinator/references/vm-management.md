# VM Management

This document covers VM bundle lifecycle management, warm starts, compression, and operational procedures.

## Bundle Format

VM bundles use a layered format:

```
bundle.vmbundle (Zstandard compressed)
├── rootfs.tar.zst          # Base Linux filesystem
├── runtime-overlay.tar.zst # Language runtimes (Node, Python, Rust, Go)
├── cache-layer.tar.zst     # Pre-warmed package caches
├── snapshot/               # Memory state (for hibernation)
│   ├── memory.zst
│   └── device-state.json
└── manifest.json           # Bundle metadata, version, checksums
```

## Lifecycle States

### 1. Load

Decompress the bundle from disk into an active VM instance.

```bash
# Triggered by:
vmbundle load --name project-x

# Internally performs:
# 1. Verify bundle integrity (checksum)
# 2. Decompress with Zstandard (zstd -d)
# 3. Mount rootfs as overlay filesystem
# 4. Initialize VM kernel and init process
# 5. Wait for guest agent readiness
```

**Latency:** 2–8 seconds (depends on bundle size and disk I/O)

**Resource impact:** 512MB–2GB memory allocation depending on bundle configuration.

### 2. Warm

Pre-load common packages and caches to reduce first-execution latency.

```bash
# Triggered by:
vmbundle warm --name project-x --profile standard

# Internally performs:
# 1. Start package manager cache refresh (npm cache, pip cache)
# 2. Pre-load commonly used libraries into memory
# 3. Pre-compile bytecode for Python packages
# 4. Build module resolution cache for Node.js
```

**Latency reduction:** 40–70% for first execution after warm.

**When to warm:**
- Before a batch of related tasks
- After loading a bundle that will be used repeatedly
- As part of scheduled maintenance (cron job)

### 3. Execute

Active task execution state. The VM accepts and processes work.

```bash
# Tasks are routed through the coordinator:
coordinator exec --runtime vm --command "pytest tests/"

# The coordinator:
# 1. Verifies VM is in Execute state
# 2. Routes command to guest agent
# 3. Streams stdout/stderr back to caller
# 4. Reports exit code
```

**Resource constraints during execution:**
- CPU: Configurable (default: 2 cores)
- Memory: Fixed allocation from Load phase
- Disk: Overlay writes go to scratch space (deleted on Unload)
- Network: Configurable (default: NAT, outbound only)

### 4. 休眠 (Hibernate)

Serialize VM state to disk for fast resume.

```bash
# Triggered automatically:
# After idle timeout (default: 5 minutes)
# Or manually:
vmbundle hibernate --name project-x

# Internally performs:
# 1. Pause all running processes (SIGSTOP)
# 2. Serialize memory pages to disk
# 3. Compress memory dump with Zstandard
# 4. Save device state (registers, file descriptors)
# 5. Release physical memory allocation
```

**Resume latency:** 0.5–2 seconds (faster than cold Load).

**When hibernation is triggered:**
- Idle timeout (configurable, default 5 min)
- Memory pressure on host (reclaim resources)
- Manual invocation before host sleep/lock

### 5. Unload

Full teardown and resource release.

```bash
# Triggered by:
vmbundle unload --name project-x

# Or automatically:
# - When disk space is needed
# - During bundle updates
# - On host shutdown
```

**After Unload:**
- All scratch space is deleted
- Memory is fully released
- Requires full Load → Warm cycle to restart

## Compression with Zstandard

All bundle compression uses Zstandard (zstd) for optimal speed-to-ratio balance.

### Compression Profiles

| Profile | Level | Ratio | Speed | Use Case |
|---------|-------|-------|-------|----------|
| fast | 1 | 2.1:1 | ~500 MB/s | Development, frequent rebuilds |
| balanced | 3 | 2.8:1 | ~300 MB/s | Default for most bundles |
| max | 9 | 3.5:1 | ~100 MB/s | Distribution, archival |
| ultra | 19 | 4.0:1 | ~20 MB/s | Long-term storage, rarely used |

### Compression Commands

```bash
# Compress a bundle
zstd -3 --rm rootfs.tar -o rootfs.tar.zst

# Decompress a bundle
zstd -d rootfs.tar.zst -o rootfs.tar

# Verify integrity
zstd -t rootfs.tar.zst
```

### Incremental Updates

For frequently updated bundles, use delta compression:

```bash
# Create delta between bundle versions
zstd --patch-from=v1.0.bundle v1.1.tar -o v1.1.patch.zst

# Apply delta
zstd --patch-from=v1.0.bundle v1.1.patch.zst -o v1.1.tar
```

## Monitoring and Health Checks

### VM Health Check

```bash
#!/bin/bash
# check-vm.sh — Verify VM is running and responsive

VM_NAME="${1:-default}"
TIMEOUT=5

# Check if VM process exists
if ! pgrep -f "qemu.*$VM_NAME" > /dev/null 2>&1; then
    echo "ERROR: VM '$VM_NAME' is not running"
    exit 1
fi

# Check if guest agent responds
if ! timeout $TIMEOUT virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' > /dev/null 2>&1; then
    echo "WARNING: VM '$VM_NAME' is running but guest agent is unresponsive"
    exit 2
fi

echo "OK: VM '$VM_NAME' is running and responsive"
exit 0
```

### Warm Bundle Script

```bash
#!/bin/bash
# warm-bundle.sh — Pre-load VM bundle for faster startup

BUNDLE_NAME="${1:-default}"
PROFILE="${2:-standard}"

echo "Warming bundle: $BUNDLE_NAME (profile: $PROFILE)"

# Load the bundle
vmbundle load --name "$BUNDLE_NAME"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to load bundle"
    exit 1
fi

# Run warm-up tasks
case "$PROFILE" in
    standard)
        vmbundle exec --name "$BUNDLE_NAME" -- "npm cache verify 2>/dev/null; pip cache info 2>/dev/null"
        ;;
    node)
        vmbundle exec --name "$BUNDLE_NAME" -- "npm install --prefer-offline"
        ;;
    python)
        vmbundle exec --name "$BUNDLE_NAME" -- "pip install --cache-dir /cache -r requirements.txt 2>/dev/null"
        ;;
    full)
        vmbundle exec --name "$BUNDLE_NAME" -- "npm cache verify; pip cache info; cargo fetch 2>/dev/null"
        ;;
esac

echo "Bundle warmed successfully"
```

## Troubleshooting

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| Load fails with checksum error | Corrupted bundle | Re-download or rebuild bundle |
| Load is slow (>10s) | Disk I/O bottleneck | Move bundle to SSD; reduce bundle size |
| Warm doesn't improve latency | Cache misses | Check package manifest; update warm profile |
| Hibernate fails | Insufficient disk space | Free space or reduce memory allocation |
| Resume is slow | Large memory dump | Reduce memory allocation; use faster compression |
| Guest agent unresponsive | VM kernel panic | Restart VM; check guest agent logs |
