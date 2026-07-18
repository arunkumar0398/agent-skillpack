---
name: cron-job-reliability
description: >-
  Makes scheduled jobs and background tasks reliable. Use when adding cron
  jobs, scheduled tasks, or recurring background workers. Use when cron jobs
  are failing silently, running twice, or blocking each other. Use when
  implementing idempotent job execution, distributed locking, or dead job
  detection for scheduled tasks.
version: 1.0.0
tags: [operations, cron, reliability, scheduling]
agents: [opencode, claude, codex, cursor, windsurf, copilot, cline, aider]
---

# Cron Job Reliability

## Overview

Cron jobs are the silent backbone of production systems — data imports, report generation, cleanup tasks, notifications. But unreliable cron jobs fail silently, run twice, corrupt data, or block each other. This skill covers idempotent execution, distributed locking, structured error handling, and dead job detection — the patterns that make scheduled tasks trustworthy.

## When to Use

- Adding a new cron job or scheduled task to the system
- Cron jobs are failing silently (no alerts, no logs, no one notices)
- Jobs are running twice (duplicate execution, data corruption)
- Multiple instances of the same job are running simultaneously
- Job history is lost or not tracked
- Need to add retry logic with backoff for failing jobs
- Implementing dead job detection (job hasn't run in N hours)

**When NOT to use:**
- Event-driven background processing (use `event-driven-patterns` skill)
- Real-time streaming or websocket handlers
- Long-running processes that aren't scheduled (use process managers)
- One-off data migrations (use `deprecation-and-migration` skill)

## Process

### 1. Add idempotency key to job payload

Every job MUST be idempotent — running it twice with the same input produces the same result. This is non-negotiable for reliable scheduling.

**Idempotency pattern:**

```javascript
// Generate idempotency key from job parameters
function generateJobId(jobType, params) {
  return `${jobType}:${hashObject(params)}:${dateBucket(params)}`;
}

// Example: daily report for tenant X
// jobId = "daily_report:tenant_abc:2026-07-18"
// Running it twice on the same day produces the same report
```

**Where to enforce idempotency:**

| Layer | Implementation |
|---|---|
| **Job entry** | Check if jobId exists in `completed_jobs` table before starting |
| **Job execution** | Use DB transactions — if job already modified data, roll back |
| **Job output** | Write output to temp location, then atomically move to final location |

```javascript
async function runJob(jobType, params) {
  const jobId = generateJobId(jobType, params);

  // Check if already completed
  const existing = await CompletedJobs.findOne({ jobId });
  if (existing) {
    console.log(`Job ${jobId} already completed, skipping`);
    return existing.result;
  }

  // Execute job
  const result = await executeJob(jobType, params);

  // Mark completed (same transaction as job execution)
  await CompletedJobs.create({ jobId, result, completedAt: new Date() });

  return result;
}
```

### 2. Wrap execution in distributed lock

Multiple instances (servers, containers, processes) will run the same cron job simultaneously without distributed locking. This causes duplicate execution and data corruption.

**Lock strategy:**

```
ACQUIRE LOCK:
  1. Try to acquire lock with TTL (e.g., 300 seconds)
  2. Lock key: "cron_lock:{jobType}:{dateBucket}"
  3. If lock acquired → execute job
  4. If lock not acquired → another instance is running, skip

RELEASE LOCK:
  1. After job completes (success or failure), release lock
  2. Use atomic release (compare-and-delete) to avoid releasing someone else's lock
```

**Redis implementation (Redlock recommended for multi-node):**

```javascript
const Redlock = require('redlock');
const redlock = new Redlock([redisClient], { retryCount: 3 });

async function withLock(jobType, ttl, fn) {
  const lockKey = `cron_lock:${jobType}:${dateBucket()}`;
  let lock;

  try {
    lock = await redlock.acquire([lockKey], ttl);
    return await fn();
  } catch (err) {
    if (err.name === 'LockError') {
      console.log(`Lock ${lockKey} held by another instance, skipping`);
      return null;
    }
    throw err;
  } finally {
    if (lock) await lock.release();
  }
}
```

**Lock TTL rule:** Set TTL to 2x expected job duration. If job takes 5 minutes, lock TTL = 10 minutes. If job exceeds TTL, lock auto-expires and another instance can pick it up.

### 3. Implement structured error handling with retry

Cron jobs MUST fail loudly. Silent failures are the #1 cause of data drift in production.

**Error handling pattern:**

```javascript
async function runWithRetry(jobType, params, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const result = await executeJob(jobType, params);
      await emitEvent('job.completed', { jobType, params, attempt });
      return result;
    } catch (err) {
      const isLastAttempt = attempt === maxRetries;

      // Log with structured context
      console.error(JSON.stringify({
        event: 'job.failed',
        jobType,
        attempt,
        maxRetries,
        error: err.message,
        stack: err.stack,
        params
      }));

      if (isLastAttempt) {
        await emitEvent('job.permanently_failed', { jobType, params, error: err.message });
        await alertOpsTeam(jobType, err);
        throw err;
      }

      // Exponential backoff: 1s, 2s, 4s
      await sleep(Math.pow(2, attempt - 1) * 1000);
    }
  }
}
```

**Retry rules:**
- **Transient errors** (network timeout, rate limit): retry with backoff
- **Permanent errors** (validation error, permission denied): don't retry, alert immediately
- **Unknown errors**: retry once, then alert

### 4. Emit start/complete/fail events

Every job MUST emit lifecycle events so you can track what's running, what succeeded, and what failed.

```json
{
  "event": "job.started",
  "jobType": "daily_report",
  "jobId": "daily_report:tenant_abc:2026-07-18",
  "timestamp": "2026-07-18T02:00:00Z",
  "instanceId": "server-3"
}
```

```json
{
  "event": "job.completed",
  "jobType": "daily_report",
  "jobId": "daily_report:tenant_abc:2026-07-18",
  "duration": 45000,
  "timestamp": "2026-07-18T02:00:45Z",
  "instanceId": "server-3"
}
```

```json
{
  "event": "job.failed",
  "jobType": "daily_report",
  "jobId": "daily_report:tenant_abc:2026-07-18",
  "error": "Database connection timeout",
  "attempt": 3,
  "timestamp": "2026-07-18T02:01:30Z",
  "instanceId": "server-3"
}
```

**Events to emit:**
- `job.started` — job began execution
- `job.completed` — job finished successfully (include duration)
- `job.failed` — job failed (include error, attempt number)
- `job.permanently_failed` — all retries exhausted (alert threshold)
- `job.skipped` — job skipped due to lock or idempotency

### 5. Add dead job detection and alerting

A "dead job" is one that should have run but didn't (or ran and failed silently). Dead job detection catches failures before users do.

**Detection pattern:**

```javascript
// Run every 5 minutes
async function detectDeadJobs() {
  const jobs = await getCronSchedule();

  for (const job of jobs) {
    const lastRun = await getLastRunTime(job.type);
    const expectedInterval = job.schedule; // e.g., 'daily', 'hourly'

    if (isOverdue(lastRun, expectedInterval)) {
      await alertOpsTeam({
        alert: 'dead_job',
        jobType: job.type,
        lastRun,
        expectedInterval,
        message: `Job ${job.type} has not run in ${expectedInterval}`
      });
    }

    // Also check: job ran but produced no output
    const lastResult = await getLastResult(job.type);
    if (lastRun && !lastResult) {
      await alertOpsTeam({
        alert: 'job_no_output',
        jobType: job.type,
        lastRun,
        message: `Job ${job.type} ran but produced no output`
      });
    }
  }
}
```

**Alerting rules:**
| Condition | Alert Level | Action |
|---|---|---|
| Job missed schedule by 1x interval | Warning | Log + dashboard |
| Job missed schedule by 2x interval | Critical | Page on-call |
| Job failed all retries | Critical | Page on-call + create incident |
| DLQ depth > 0 | Warning | Investigate poison messages |
| Job duration p99 > threshold | Warning | Profile and optimize |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We only have one server, no need for distributed lock" | You have one server today. The next deploy adds a second. Design for it now. |
| "Idempotency is overkill for this simple job" | The first time the job runs twice and corrupts data, you'll wish you had it. |
| "We'll add monitoring later" | The first silent failure will go unnoticed for weeks. Emit events from day one. |
| "Cron expressions are enough documentation" | The next engineer needs to know WHAT the job does, not just WHEN it runs. |
| "Retries will fix transient failures" | Without structured error handling, retries just multiply the noise. |

## Red Flags

- Cron job with no idempotency key
- Multiple instances running same job without distributed lock
- `try/catch` that swallows errors (`catch(e) {}`)
- No lifecycle events (started/completed/failed)
- Job history not persisted
- No dead job detection
- Retry without exponential backoff
- Lock TTL set too short (job gets interrupted) or too long (blocks other instances)

## Verification

Before declaring done:

- [ ] Job has idempotency key (same input = same output, safe to run twice)
- [ ] Distributed lock implemented (prevents concurrent execution)
- [ ] Structured error handling with retry and backoff
- [ ] Lifecycle events emitted: started, completed, failed, permanently_failed
- [ ] Job history persisted (who ran it, when, result, duration)
- [ ] Dead job detection running (alerts if job misses schedule)
- [ ] Lock TTL is 2x expected job duration
- [ ] Error logging includes job type, attempt, params, error message

Base directory for this skill: relative to this file.
Relative paths in this skill (e.g., scripts/, references/) are relative to this base directory.
