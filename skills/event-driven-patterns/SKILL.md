---
name: event-driven-patterns
description: >-
  Designs reliable event-driven systems with message queues. Use when adding
  message queues, event publishing, async processing between services, or
  background job pipelines. Use when events are lost, duplicated, or processed
  out of order. Use when designing dead letter queues, consumer groups, or
  event schema versioning.
version: 1.0.0
tags: [architecture, messaging, queues, events]
agents: [opencode, claude, codex, cursor, windsurf, copilot, cline, aider]
---

# Event-Driven Patterns

## Overview

Event-driven systems decouple producers from consumers, enabling scalable async processing. But unreliable event delivery causes silent data loss, duplicate processing, and cascading failures. This skill covers delivery guarantees, schema versioning, dead letter queues, outbox patterns, and consumer lag monitoring — the infrastructure that makes async systems trustworthy.

## When to Use

- Adding a message queue (Kafka, RabbitMQ, Bull, SQS, NATS) to a system
- Publishing events from a service that other services consume
- Designing background job pipelines (email sends, data imports, batch processing)
- Events are being lost, duplicated, or processed out of order
- Consumer lag is growing and messages are piling up
- Need to add dead letter queues for poison messages
- Implementing event schema versioning for backward compatibility

**When NOT to use:**
- Simple request-response between services — use a synchronous API instead
- Logging or audit trails — use `observability-and-instrumentation` skill
- Real-time streaming analytics — use a stream processing framework directly
- Cron-triggered tasks with no inter-service communication — use `cron-job-reliability` skill

## Process

### 1. Classify the delivery guarantee

Before writing any code, decide what the system actually requires. Wrong guarantee = wrong trade-offs.

| Guarantee | What It Means | When It's Required | Cost |
|---|---|---|---|
| **At-most-once** | Message may be lost, never duplicated | Metrics, logs, non-critical notifications | Lowest — fire and forget |
| **At-least-once** | Message may be duplicated, never lost | Financial transactions, user actions, data sync | Moderate — idempotent consumers required |
| **Exactly-once** | Message delivered exactly one time | Rarely achievable end-to-end; typically at-least-once + idempotent dedup | Highest — requires transactional outbox or idempotency keys |

```markdown
DECISION:
- What happens if this message is lost? [Nothing critical / Data inconsistency / Financial loss]
- What happens if this message is processed twice? [OK / Needs dedup / Unacceptable]
→ Guarantee: [at-most-once / at-least-once / exactly-once via dedup]
```

**Never promise exactly-once without transactional outbox or idempotent consumers.** Most systems that claim exactly-once are actually at-least-once with deduplication.

### 2. Design the event schema with versioning

Event schemas evolve. Without versioning, schema changes break consumers silently.

```json
{
  "eventId": "uuid-v4",
  "eventType": "order.created",
  "eventVersion": "1.2.0",
  "timestamp": "2026-07-18T10:30:00Z",
  "source": "order-service",
  "correlationId": "request-uuid",
  "payload": {
    "orderId": "ord_123",
    "customerId": "cust_456",
    "amount": 99.99,
    "currency": "USD"
  },
  "metadata": {
    "traceId": "jaeger-trace-id",
    "schemaVersion": "1.2.0"
  }
}
```

**Schema rules:**
- Every event MUST include `eventId`, `eventType`, `eventVersion`, `timestamp`, `source`
- Use semantic versioning for `eventVersion` (MAJOR = breaking, MINOR = additive, PATCH = fix)
- New fields are additive (MINOR bump) — consumers ignore unknown fields
- Removing or renaming fields is breaking (MAJOR bump) — requires consumer migration
- Keep old field versions alongside new ones during transition periods

**Backward compatibility contract:**
- Consumers MUST ignore unknown fields (forward compatibility)
- Producers MUST NOT remove fields without a deprecation period (MINOR version skip)
- Use `eventVersion` to route consumers to the correct schema handler

### 3. Implement the outbox pattern for reliable publishing

The "publish event after DB write" pattern has a race condition: DB write succeeds, event publish fails, system is inconsistent. The outbox pattern fixes this.

**Outbox pattern (transactional outbox):**
1. In the same DB transaction as your business write, insert an event into an `outbox` table
2. A separate process (poller or CDC) reads from `outbox` and publishes to the message queue
3. After successful publish, mark the outbox entry as sent (or delete it)

```sql
-- Outbox table schema
CREATE TABLE outbox_events (
  id UUID PRIMARY KEY,
  event_type VARCHAR(255) NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  published BOOLEAN DEFAULT FALSE,
  published_at TIMESTAMP NULL
);
```

**Why this works:**
- Business write and event creation are atomic (same transaction)
- Event publishing is async and retryable
- No dual-write problem (DB + queue are independent, outbox bridges them)

**When to use polling vs CDC:**
- **Polling** — simpler, higher latency (100ms-1s), works with any DB
- **CDC (Change Data Capture)** — lower latency (ms), requires DB-specific tooling (Debezium, Maxwell)

### 4. Build the dead letter queue (DLQ)

Poison messages (malformed, unprocessable) will block a consumer forever without a DLQ. Every consumer MUST have one.

**DLQ implementation:**
1. Consumer tries to process the message
2. If processing fails after N retries (typically 3-5), move the message to DLQ
3. DLQ messages are logged, alerted on, and available for manual inspection
4. Do NOT automatically reprocess DLQ messages — fix the root cause first

```
CONSUMER FLOW:
  Message arrives
    → Process attempt 1 (fail) → requeue with increment retry_count
    → Process attempt 2 (fail) → requeue
    → Process attempt 3 (fail) → move to DLQ + alert
    → DLQ: log event_type, payload, error, timestamp
```

**DLQ monitoring:**
- Alert when DLQ depth > 0 (or > threshold)
- Dashboard showing DLQ messages by event_type
- Weekly review of DLQ contents to identify systemic issues

### 5. Instrument consumer lag and processing time

You can't fix what you can't see. Every consumer MUST emit these metrics:

| Metric | What It Tells You | Alert Threshold |
|---|---|---|
| **Consumer lag** | Messages behind the producer | Growing lag = consumer too slow |
| **Processing time** (per message) | How long each message takes | p99 > SLA = consumer bottleneck |
| **Success rate** | % of messages processed successfully | < 99% = consumer errors |
| **DLQ depth** | Messages in dead letter queue | > 0 = poison messages exist |

```markdown
INSTRUMENTATION CHECKLIST:
- [ ] Consumer lag metric emitted every N seconds
- [ ] Processing time histogram per event_type
- [ ] Success/failure counter per consumer
- [ ] DLQ depth metric with alert
- [ ] Consumer startup/shutdown logged
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We'll add the DLQ later" | The first poison message will block your queue. Add it before the first consumer ships. |
| "Exactly-once is required" | You probably need at-least-once + idempotent consumers. True exactly-once requires transactional outbox. |
| "Schema versioning is overkill" | The first schema change will break every consumer silently. Version from day one. |
| "Polling the outbox is too slow" | CDC is faster but adds operational complexity. Polling with 100ms interval is sufficient for most systems. |
| "We don't need metrics for async processing" | Consumer lag is invisible until users complain. Instrument proactively. |

## Red Flags

- Publishing events directly to the queue without transactional outbox
- No dead letter queue on a consumer
- Schema changes without version bumps
- Consumer lag growing monotonically (never recovering)
- Retry logic without exponential backoff
- Logging full event payloads in production (PII risk)
- Consumer that modifies shared state without idempotency

## Verification

Before declaring done:

- [ ] Delivery guarantee classified and documented
- [ ] Event schema includes `eventId`, `eventType`, `eventVersion`, `timestamp`, `source`
- [ ] Outbox pattern implemented (or explicit justification for direct publish)
- [ ] DLQ configured for every consumer with alert on depth > 0
- [ ] Consumer metrics: lag, processing time, success rate, DLQ depth
- [ ] Schema versioning contract documented (backward/forward compatibility rules)
- [ ] Consumer idempotency verified (replay same message twice = same result)
- [ ] No PII in event payloads logged in production

Base directory for this skill: relative to this file.
Relative paths in this skill (e.g., scripts/, references/) are relative to this base directory.
