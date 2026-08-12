# Cloudflare Primitive Selection

Use this catalog to match requirements to products. It is a decision guide, not
a substitute for current official documentation. Verify limits, pricing, feature
status, and regional behavior for the account and deployment date.

## Workers

Use Workers for global HTTP APIs, routing, authorization, transformation,
orchestration of bounded calls, and consumers for platform events.

Design assumptions:

- isolates are ephemeral and process-local memory is only an opportunistic cache,
- execution is event-driven and constrained by CPU, memory, subrequests, and
  product/plan limits,
- wall-clock waiting and CPU consumption are different constraints,
- deployment is global by default, but smart placement or dependency placement
  may matter when the authoritative data store is centralized,
- `waitUntil` extends event-lifecycle work but is not durable job storage,
- service bindings avoid unnecessary public network hops between Workers.

Choose Containers or an external compute platform for unsupported runtimes,
native binaries that do not fit Workers, processes that need a server model, or
resource profiles outside Worker limits.

## Cache And KV

### Cache API and CDN cache

Use for HTTP responses and recomputable data with explicit cache keys, TTLs,
validation, and purge/invalidation behavior. Analyze personalized data and cache
poisoning. Version immutable assets instead of purging when possible.

### Workers KV

Use for read-heavy, globally distributed key-value data where stale reads and
propagation delay are acceptable:

- configuration and feature data with safe rollout semantics,
- localization and content snapshots,
- routing maps that tolerate delayed propagation,
- cache entries and precomputed responses,
- non-critical preferences.

Do not use KV as the authority for:

- uniqueness or compare-and-set invariants,
- inventory, balances, quotas, locks, or exact rate-limit counters,
- immediate session or credential revocation,
- read-after-write flows that must work from another location,
- job ownership or deduplication requiring atomic claims.

Always state stale-read behavior, TTL, invalidation, and fallback.

## D1

D1 is managed SQLite suitable for relational data, SQL queries, indexes, and many
small-to-medium application databases. It is attractive when operational
simplicity and Worker integration matter more than a full Postgres feature set.

Good fits:

- application metadata and CRUD,
- tenant databases when partitioning and lifecycle are explicit,
- moderate relational workloads and joins,
- an outbox written in the same supported atomic batch as business data,
- read-heavy workloads that can use supported read replication semantics.

Validate before choosing D1:

- current per-database size and account limits,
- write throughput, serialization, query and result limits,
- transaction semantics required by the application,
- migration and restore behavior,
- read-replica consistency and session/bookmark requirements,
- cross-database queries or transactions,
- expected database count for database-per-tenant designs.

`batch()` can make a predetermined sequence atomic according to D1's documented
semantics. It does not automatically satisfy a workflow that must read, execute
application logic, and conditionally issue more statements inside one interactive
transaction. Verify current APIs rather than assuming either absence or support.

Choose external PostgreSQL/MySQL when complex transactions, richer extensions,
larger data, mature replication/tooling, or workload shape requires them.

## Durable Objects

Use a Durable Object when requests for one logical key need a single coordination
point with strongly consistent object-local state:

- a chat room or WebSocket session hub,
- collaborative document coordination,
- per-user, per-device, per-tenant, or per-game state machine,
- exact per-key sequencing,
- strong per-key counters and rate limiting,
- SQLite-backed state isolated by object,
- delayed per-object work via alarms.

Design the object ID as a shard key. State the maximum requests, connections,
storage, and CPU for the hottest object, not just the average. A celebrity room or
large tenant can become a serialized hotspot. Split an entity only if ordering and
transaction requirements permit it.

Object storage and transactions are local to the object. Cross-object calls can
fail partially and need sagas, idempotency, or reconciliation. Alarms are
at-least-once style triggers and an object has constrained alarm semantics; they
are not a general-purpose collection of arbitrary timers.

For WebSockets, evaluate hibernation so idle connections do not require an active
isolate, then design attachment/state restoration, reconnect, heartbeat,
backpressure, message persistence, and fan-out limits.

## R2

Use R2 for immutable or versioned blobs, uploads, media, documents, backups,
artifacts, and data-lake files. Prefer direct upload/download with signed URLs
when it avoids routing large bodies through a Worker.

Keep object metadata used for business queries in D1, Durable Objects, or external
SQL. A database row and an R2 object cannot normally be committed in one
cross-product transaction. Design staging keys, status transitions, idempotent
finalization, and orphan cleanup.

Verify multipart, object size, request, lifecycle, jurisdiction, and consistency
behavior in current docs.

## Queues

Use Queues to buffer spikes and decouple bounded background jobs from request
latency. Assume at-least-once delivery:

- assign a stable event/job ID before publishing,
- make the consumer idempotent,
- acknowledge only after required effects complete,
- distinguish retryable from terminal errors,
- use bounded backoff, maximum retries, and a DLQ,
- monitor backlog depth and age of the oldest message,
- provide replay and poison-message procedures.

Do not assume total ordering, exactly-once side effects, or indefinite event-log
retention. Use a replayable broker externally when consumers need independent
offsets, long retention, partition ordering, or stream processing beyond Queues.

## Workflows

Use Workflows for durable multi-step processes that sleep, retry, wait for events,
or continue over long periods:

- onboarding and provisioning,
- approval and human-in-the-loop flows,
- multi-stage imports/exports,
- delayed lifecycle automation,
- sagas with explicit compensation.

Keep steps idempotent because retries and recovery can re-enter work according to
the current execution model. Persist business truth in an authoritative store;
Workflow state coordinates execution but should not silently become the only
business ledger. Define cancellation, versioning across deployments, terminal
failure, compensation, and operator restart behavior.

Use Queues for high-volume independent jobs; use Workflows when an individual
process has durable multi-step state. Combining them is valid.

## Cron Triggers And Alarms

Use Cron Triggers for periodic global sweeps, cleanup, reconciliation, and outbox
relay. Do not rely on exact wall-clock execution or exactly-once invocation.

Use Durable Object alarms when delayed work belongs to one object and object-local
state can make handling idempotent. For large sets of independent delayed jobs,
compare Workflows, Queue delays, or a bucketed scheduling design against one
object per timer.

## Hyperdrive And External SQL

Hyperdrive sits between Workers and a supported external database to reduce
connection setup pressure and, where configured and safe, improve query latency.
The external database remains the source of truth.

Validate:

- database and Worker placement,
- TLS, credentials, rotation, and network exposure,
- transaction/session affinity requirements,
- prepared statement and driver compatibility,
- query caching freshness and invalidation,
- pool limits, database connection limits, and failover,
- latency when a request performs multiple sequential round trips.

Prefer one coarse database operation over many chatty edge-to-database calls.
Smart Placement, regional service placement, or moving compute near the database
may beat executing every database-bound request near the user.

## Containers

Use Containers for Docker-packaged or server-shaped workloads that need runtimes,
binaries, protocols, CPU/memory profiles, or process behavior unavailable in
Workers. Design startup, image rollout, routing, regional placement, concurrency,
state externalization, health, capacity, and scale-to-zero effects.

Do not assume Containers inherit every Workers property. Verify current
availability, scheduling, networking, storage, duration, and autoscaling model.
Keep durable state outside an ephemeral container unless the product explicitly
provides the required persistence guarantees.

## Email

Use Email Routing and Email Workers to receive and process inbound messages. Treat
email as untrusted input: validate sender/authentication signals, cap size, scan
attachments where required, prevent loops, and make processing idempotent.

For outbound email, evaluate Cloudflare's currently available sending capability
and bindings against requirements for deliverability, domains, templates,
analytics, suppression lists, compliance, idempotency keys, and regional support.
Use a specialized provider when it is the better fit. Queue transactional email
unless it must be synchronous, and preserve one stable idempotency key through
outbox, queue, and provider.

## Other Specialized Products

Consider rather than reimplement:

- WAF, DDoS protection, Bot Management, Turnstile, and platform rate limiting for
  ingress abuse controls,
- Images and Stream for managed image/video pipelines,
- Vectorize and AI products for supported vector/AI workloads,
- Analytics Engine or Logpush for suitable analytics and telemetry flows,
- Access and Zero Trust products for internal application access.

Do not make a specialized product authoritative for transactional business state
unless its documented model is designed for that purpose.
