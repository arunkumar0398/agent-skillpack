---
name: multi-tenant-architecture
description: >-
  Designs tenant-isolated SaaS architectures. Use when building features
  requiring tenant isolation, data partitioning, per-tenant configuration,
  or RBAC across tenants. Use when adding a new tenant to a shared system,
  or when cross-tenant data leaks are reported.
version: 1.0.0
tags: [architecture, saas, tenancy, isolation]
agents: [opencode, claude, codex, cursor, windsurf, copilot, cline, aider]
---

# Multi-Tenant Architecture

## Overview

Multi-tenancy lets a single system serve multiple customers (tenants) while keeping their data, configuration, and operations completely isolated. Wrong isolation strategy = data leaks, noisy neighbors, and configuration drift. This skill covers tenant isolation strategies, row-level security, per-tenant config, and the tests that prove isolation actually works.

## When to Use

- Building SaaS features that serve multiple customers from one deployment
- Adding a new tenant to an existing multi-tenant system
- Implementing data partitioning or row-level security
- Designing per-tenant configuration (feature flags, branding, limits)
- A cross-tenant data leak is reported (isolation boundary violated)
- Migrating from single-tenant to multi-tenant architecture
- Implementing tenant-scoped RBAC (role-based access control)

**When NOT to use:**
- Single-customer deployment with no isolation needs
- Infrastructure-level isolation (separate DB per tenant) — that's deployment, not architecture
- Tenant onboarding workflows — that's business logic, not isolation design

## Process

### 1. Identify the tenant isolation boundary

The isolation boundary determines WHERE tenant separation is enforced. Choose one strategy per resource — mixing strategies within a resource creates leakage vectors.

| Strategy | How It Works | When to Use | Risk |
|---|---|---|---|
| **Shared DB, shared schema** (row-level) | `WHERE tenant_id = X` on every query | Low tenant count, simple data model | Query漏 = data leak |
| **Shared DB, separate schema** | Separate schema per tenant | Medium isolation, moderate scale | Schema sprawl, migration complexity |
| **Separate DB** | Entirely separate database per tenant | High isolation, compliance requirements | Operational overhead, cost |

```markdown
DECISION:
- Number of tenants: [ < 10 / 10-100 / 100+ ]
- Data sensitivity: [ public / internal / PII / financial / healthcare ]
- Isolation requirement: [ shared-nothing / shared-schema / shared-db ]
→ Strategy: [row-level / schema-per-tenant / db-per-tenant]
```

**For most SaaS applications: row-level security (shared DB, shared schema) is correct.** Separate DBs are overkill unless you have compliance requirements (HIPAA, PCI-DSS) or tenants with strict data residency needs.

### 2. Implement tenant context on every request

Every request MUST carry a tenant identifier that cannot be spoofed by the client. The tenant context flows through the entire request lifecycle.

```
REQUEST FLOW:
  1. Auth middleware extracts tenant_id from token/session
  2. tenant_id is set in request context (not from client input)
  3. Every DB query, cache key, and queue message includes tenant_id
  4. Response is scoped to tenant_id
```

**Implementation pattern:**

```javascript
// Middleware: extract tenant from authenticated session
function tenantContext(req, res, next) {
  req.tenantId = req.session.tenantId; // From auth, NOT from query/body
  if (!req.tenantId) {
    return res.status(403).json({ error: 'No tenant context' });
  }
  next();
}

// Query: always filter by tenant
async function getOrders(req) {
  return Order.find({ tenantId: req.tenantId, status: 'active' });
}
```

**Critical rule: tenant_id NEVER comes from client input.** It comes from the authenticated session or token. If a client can set their own tenant_id, they can access any tenant's data.

### 3. Implement row-level security

Row-level security (RLS) ensures every database query is scoped to the current tenant. This is the most common multi-tenant isolation strategy.

**RLS enforcement layers:**

| Layer | What It Catches | Implementation |
|---|---|---|
| **Query builder** | Missing tenant filter in application code | Tenant-scoped query helper that auto-adds `WHERE tenant_id = X` |
| **DB constraint** | Leaked queries from application code | DB-level row-level security policy (PostgreSQL RLS, MongoDB field-level) |
| **ORM hook** | Queries bypassing the query builder | Pre-save/pre-find hooks that inject tenant_id |

**MongoDB implementation (Mongoose):**

```javascript
// Tenant-scoped base query
function tenantQuery(model, tenantId) {
  return model.find({ tenantId });
}

// Mongoose pre-hook: auto-inject tenant_id
schema.pre('find', function() {
  if (this.getFilter().tenantId === undefined) {
    throw new Error('Query missing tenantId — possible data leak');
  }
});
```

**PostgreSQL implementation:**

```sql
-- Enable RLS on table
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: tenants can only see their own rows
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

### 4. Design per-tenant configuration

Tenants need different settings (feature flags, branding, limits, integrations). Design config that's tenant-scoped without per-tenant code paths.

**Config hierarchy (most restrictive wins):**

```
Default config (system-wide)
  → Tenant config (overrides default)
    → User config (overrides tenant, optional)
```

**Storage pattern:**

```javascript
// Config stored as JSON per tenant
{
  "tenantId": "tenant_abc",
  "config": {
    "features": {
      "analytics": true,
      "advancedReporting": false
    },
    "limits": {
      "maxUsers": 50,
      "maxStorageGB": 100
    },
    "branding": {
      "primaryColor": "#1a73e8",
      "logoUrl": "https://..."
    }
  }
}
```

**Runtime resolution:**

```javascript
function getTenantConfig(tenantId, key) {
  const tenantConfig = cache.get(`config:${tenantId}`) || {};
  const defaultConfig = cache.get('config:default') || {};
  return deepMerge(defaultConfig, tenantConfig)[key];
}
```

### 5. Validate isolation with cross-tenant tests

Isolation is not proven by design — it's proven by tests that attempt to violate it.

```markdown
ISOLATION TEST CHECKLIST:
- [ ] User from Tenant A cannot read Tenant B's data (API test)
- [ ] User from Tenant A cannot write to Tenant B's data (API test)
- [ ] Database query without tenant_id throws error (unit test)
- [ ] Cache keys are namespaced by tenant_id (integration test)
- [ ] Queue messages include tenant_id and consumers scope to it (integration test)
- [ ] File storage paths are tenant-scoped (integration test)
- [ ] Search indexes are tenant-scoped (integration test)
```

**Test pattern:**

```javascript
describe('Tenant isolation', () => {
  it('Tenant A cannot read Tenant B orders', async () => {
    const tenantAResponse = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${tenantAToken}`);

    const tenantBResponse = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${tenantBToken}`);

    // Each tenant only sees their own orders
    expect(tenantAResponse.body.data.every(o => o.tenantId === tenantA.id)).toBe(true);
    expect(tenantBResponse.body.data.every(o => o.tenantId === tenantB.id)).toBe(true);
  });
});
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We trust our users — they won't hack other tenants" | Insider threats and misconfigured API keys are the #1 cause of cross-tenant leaks. |
| "Adding tenant_id to every query is tedious" | One missed filter = data leak. Automate it with ORM hooks or query builders. |
| "We'll use separate DBs for true isolation" | Operational overhead grows linearly with tenant count. Start with row-level; migrate only when compliance demands it. |
| "Feature flags don't need tenant scoping" | Feature flags ARE tenant config. Unscoped flags leak features to unauthorized tenants. |
| "We can add tenant isolation later" | Retrofitting tenant isolation into a single-tenant system is a rewrite. Design it in from day one. |

## Red Flags

- `tenant_id` taken from query parameters or request body instead of session/token
- Any DB query missing `tenant_id` filter
- Cache keys not namespaced by tenant
- File storage paths not tenant-scoped
- No cross-tenant isolation tests
- Config stored globally without tenant scoping
- Queue messages missing tenant_id

## Verification

Before declaring done:

- [ ] Tenant context extracted from auth, never from client input
- [ ] Every DB query includes tenant_id filter (ORM hook or query builder)
- [ ] Row-level security enabled at DB level (if supported)
- [ ] Per-tenant config resolved via hierarchy (default → tenant → user)
- [ ] Cache keys namespaced by tenant_id
- [ ] Queue messages include tenant_id
- [ ] File storage paths tenant-scoped
- [ ] Cross-tenant isolation tests passing
- [ ] No tenant_id in API responses (don't expose internal identifiers)

Base directory for this skill: relative to this file.
Relative paths in this skill (e.g., scripts/, references/) are relative to this base directory.
