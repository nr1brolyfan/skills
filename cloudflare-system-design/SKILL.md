---
name: cloudflare-system-design
description: Designs and reviews production systems built primarily on Cloudflare Workers, Durable Objects, D1, KV, R2, Queues, Workflows, Hyperdrive, Containers, Email, and the Cloudflare edge. Use when the user asks for Cloudflare architecture, system design on Workers, service selection, scalability, background jobs, WebSockets, multi-tenancy, storage, consistency, reliability, or migration to Cloudflare. Also use for general system design when Cloudflare is a preferred platform. Allows justified external databases and services when Cloudflare primitives do not meet correctness or operational requirements.
license: MIT
metadata:
  version: "1.0.0"
---

# Cloudflare System Design

Design production systems that exploit Cloudflare's global network without
pretending its primitives have capabilities they do not provide.

## Core Principles

1. Start with requirements, scale, invariants, and failure modes, not a product
   list.
2. Prefer the simplest Cloudflare-first architecture that satisfies correctness.
3. Choose every stateful primitive from its consistency, atomicity, locality,
   capacity, and access-pattern requirements.
4. Treat Workers as ephemeral event handlers. Durable work and shared mutable
   state belong in an appropriate durable primitive.
5. Never trade correctness for an all-Cloudflare diagram. Use an external
   database, cache, broker, search engine, or provider when requirements demand
   it.
6. State uncertainty. Product limits, pricing, regional behavior, and feature
   availability change; verify current Cloudflare documentation before relying
   on a numeric limit or plan-specific capability.

Cloudflare is the preferred toolbox, not a constraint that overrides engineering
reality.

## Design Process

### 1. Establish Scope

Identify:

- core user flows and what is explicitly out of scope,
- DAU, average and peak requests per second, payload sizes, storage growth, and
  retention,
- latency targets by geography and availability target,
- consistency and read-after-write expectations for each flow,
- business invariants that must never be violated,
- transaction boundaries and concurrency conflicts,
- synchronous, asynchronous, scheduled, and long-running work,
- residency, privacy, tenant isolation, abuse, and cost constraints,
- RPO, RTO, replay, audit, and data export requirements.

If important values are unknown, ask a small number of targeted questions or
state explicit assumptions. Calculate orders of magnitude rather than saying
"high traffic."

### 2. Classify Each Workload

Before selecting products, classify each component:

| Dimension | Questions |
|---|---|
| Execution | Request-bound, event-driven, scheduled, durable multi-step, or long-running process? |
| State | Stateless, cached, immutable blob, relational, coordinated per key, or globally transactional? |
| Consistency | Eventual, read-your-writes, strong per entity, or serializable across entities? |
| Atomicity | One key, one object, fixed SQL batch, interactive transaction, or distributed workflow? |
| Access | Point lookup, range query, joins, full-text, stream replay, analytics, or object download? |
| Locality | Global reads, single write authority, jurisdiction-bound, tenant-local, or origin-adjacent? |
| Lifecycle | Milliseconds, delayed job, days-long workflow, permanent record, or expiring cache? |
| Scale risk | Hot key, hot tenant, connection count, queue backlog, object size, or database size? |

Do not choose storage until these answers are clear.

### 3. Select Primitives

Use [references/cloudflare-primitives.md](references/cloudflare-primitives.md) for
the full selection guide and product-specific traps.

Default mapping:

| Need | Start With | Do Not Assume |
|---|---|---|
| Global HTTP/API compute | Workers | Unbounded CPU, memory, duration, or process-local state |
| Cache/config/simple key lookup | Workers KV | Strong consistency, atomic counters, locks, or immediate revocation |
| Relational data at moderate scale | D1 | General-purpose Postgres, arbitrary interactive transactions, or unlimited database size |
| Coordination/state per entity | Durable Objects | One object can absorb unlimited hot-key traffic or transact with other objects |
| Object/blob storage | R2 | Relational queries, queue semantics, or an application metadata database |
| At-least-once jobs | Queues | Exactly-once side effects, global ordering, or indefinite event replay |
| Durable multi-step process | Workflows | A replacement for all queues or a database transaction |
| Stateful containerized workload | Containers | Workers-like global execution or zero operational constraints |
| External SQL access | Hyperdrive | It fixes a bad schema, removes database latency, or changes database consistency |
| WebSockets | Durable Objects with hibernation where suitable | A stateless Worker alone can coordinate sessions reliably |
| Delayed per-entity action | Durable Object alarm | Unlimited alarms per object or a general message scheduler |
| Periodic sweep | Cron Trigger | Exact execution time or exactly-once execution |
| Inbound email | Email Routing + Email Workers | A complete mailbox product |
| Outbound email | Cloudflare-supported sending where available, or an email provider | Deliverability, idempotency, templates, and compliance are automatic |

Prefer bindings and service bindings over public HTTP hops between Workers when
the components are within the same Cloudflare application boundary.

### 4. Draw the High-Level Design

Provide a Mermaid diagram with:

- clients and external systems,
- Cloudflare ingress and security controls,
- Worker, Durable Object, Workflow, Queue, and Container boundaries,
- authoritative stores versus caches and derived data,
- synchronous versus asynchronous arrows,
- external providers and why they are external,
- trust, tenant, or residency boundaries when relevant.

Label arrows with protocol, delivery guarantee, or data purpose. Do not draw KV
or a cache as the source of truth unless the consistency analysis supports it.

### 5. Deep Dive on Correctness

Choose the two or three hardest paths and trace:

1. normal execution,
2. duplicate request or message,
3. timeout after a remote side effect,
4. partial success between two durable systems,
5. concurrent updates and hot keys,
6. retry exhaustion and operator recovery,
7. stale reads and cache invalidation,
8. regional or dependency failure.

For every queue or workflow step, define idempotency, retry classification,
backoff, dead-letter or terminal-failure handling, and replay procedure. For every
dual write, either remove it with a transaction/outbox or explain reconciliation.
See [references/reliability-patterns.md](references/reliability-patterns.md).

### 6. Validate Limits and Operations

Create a constraint ledger for every selected product:

| Component | Required | Current Verified Limit/Behavior | Headroom | Mitigation |
|---|---:|---:|---:|---|
| Example: D1 database size | 6 GB in 12 months | Verify current docs | Calculated after verification | Partition, archive to R2, or external SQL |

Check current official documentation for CPU, memory, request duration, subrequest,
message, batch, retention, object/database size, connection, and plan limits.
Distinguish CPU time from wall-clock time. Include cost drivers and scaling
triggers rather than claiming that a product "scales infinitely."

Define:

- structured logs, metrics, traces, request and event IDs,
- SLOs and alerts on user-visible symptoms,
- Queue backlog age, retries, DLQ depth, Workflow failures, Durable Object hot
  spots, D1/SQL latency and errors, and external dependency health,
- deployment, migration, rollback, and backward-compatible schema strategy,
- backups, point-in-time recovery where supported, restore tests, RPO, and RTO,
- reconciliation jobs and operator runbooks.

### 7. Challenge the Cloudflare-Only Design

Explicitly ask whether an external service is required. Use one when Cloudflare
cannot cleanly satisfy requirements such as:

- multi-row interactive ACID transactions or complex relational workloads,
- strong globally shared counters, locks, or low-latency Redis data structures,
- large databases or query patterns beyond D1's practical envelope,
- ordered replayable event logs or richer stream processing,
- specialized search, analytics, graph, time-series, or vector behavior,
- GPU, unsupported runtime, privileged process, or long-lived server needs,
- email deliverability and sending features beyond the available Cloudflare
  offering,
- regulatory, residency, portability, or recovery requirements.

Name the external capability, authority boundary, connection path, failure mode,
and cost. If it is SQL, consider Hyperdrive, but verify whether pooling and query
caching help the actual access pattern. Never describe Hyperdrive as the database.

## Non-Negotiable Cloudflare Checks

- Workers may run near users, but stateful dependencies still determine latency
  and consistency. "Region: Earth" does not make data globally writable without
  coordination.
- Workers can use lifecycle mechanisms such as `waitUntil`, but request-lifetime
  background work is not a durable job system. Use Queues or Workflows when work
  must survive retries, eviction, or deployment.
- KV is eventually consistent across locations. Use it for data that tolerates
  staleness, not uniqueness, locks, balances, inventory, authorization revocation,
  or read-after-write critical state.
- D1 is SQLite-based and useful for many relational workloads, but its supported
  transaction model and current size/write limits must fit the invariant. A fixed
  atomic batch is not equivalent to an arbitrary interactive transaction.
- Durable Objects serialize work per object and provide strongly consistent
  object-local storage. They are a natural coordination and tenant/entity
  isolation boundary, not a globally transactional database.
- Queues are at-least-once. Consumers must be idempotent and tolerate reordering
  unless the current product configuration provides and the design verifies a
  stronger scoped guarantee.
- R2 stores objects. Keep searchable metadata and business invariants in a
  suitable database, and design orphan cleanup around failed multi-system writes.
- Cron, alarms, queues, workflows, and external APIs can all duplicate work or
  fail between effects. Design for retries rather than exactly-once execution.
- A globally distributed ingress does not remove a single-region external
  database's latency, availability, or data residency constraints.

## Common Mistakes

| Mistake | Why It Fails | Better Approach |
|---|---|---|
| Put every data type in KV | Stale reads violate invariants | Classify consistency; use D1, Durable Objects, or external SQL/Redis |
| Use `waitUntil` for critical jobs | Completion is not a durable business guarantee | Queue the job or start a Workflow |
| Publish to Queue after a DB write and call it reliable | A failure between writes loses the event | Transactional outbox where supported, or reconciliation/idempotent repair |
| Claim exactly-once Queue processing | Delivery and remote effects can duplicate | At-least-once plus stable idempotency key and deduplication |
| Use one Durable Object for all users | Creates a hot serial bottleneck | Partition by tenant/entity and analyze skew |
| Use one object/alarm per queued task without sizing | Cardinality and cost can dominate | Compare Queues, Workflows, and bucketed schedulers |
| Treat D1 as drop-in Postgres | Different limits and transaction/runtime model | Validate workload; choose external SQL when needed |
| Add Hyperdrive by default | Pooling/cache can add complexity and stale reads | Identify connection or latency bottleneck first |
| Assume global Worker means global low latency | Database may still be far away | Place authority deliberately, cache safe reads, measure end-to-end |
| Ignore product quotas until implementation | Architecture can be invalid on its target plan | Maintain and verify a constraint ledger during design |
| Force Cloudflare for ideological purity | Hidden correctness and operations debt | Outsource the mismatched capability and document the boundary |

## Output Contract

For a full design, use [references/design-output.md](references/design-output.md).
At minimum provide:

1. requirements, assumptions, invariants, and scale estimates,
2. selected architecture and Mermaid diagram,
3. service-selection table with rejected alternatives,
4. data ownership, schema/keys, consistency, and transaction boundaries,
5. synchronous and asynchronous critical paths,
6. failure modes, retries, idempotency, and reconciliation,
7. verified-limit ledger, bottlenecks, and cost drivers,
8. security, tenant isolation, observability, deployment, and recovery,
9. explicit external services and why Cloudflare alone is insufficient,
10. open questions and evolution triggers.

For an architecture review, lead with findings ordered by severity. Cite the
affected flow and violated invariant, then recommend a concrete replacement or
mitigation. Do not bury correctness issues under a generic architecture summary.
