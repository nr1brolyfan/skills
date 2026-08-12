# Reliability Patterns On Cloudflare

## Stable Identity And Idempotency

Generate an operation or event ID before the first durable write. Carry the same
ID through every hop:

```text
request idempotency key -> business operation -> outbox event -> Queue message
-> Workflow instance -> provider idempotency key
```

Do not generate a new identity on retry. Deduplicate at the boundary where the
effect occurs, using an atomic unique constraint or object-local transaction when
possible.

For an external effect without provider idempotency, no local marker can fully
close the crash window:

- marker before effect can lose the effect,
- marker after effect can duplicate the effect.

State the compromise, make the business operation tolerant of duplicates, or
choose a provider with idempotency support.

## Dual Writes And Transactional Outbox

This is unsafe:

```text
write business row -> publish Queue message
```

Either action can succeed alone. Prefer writing business data and an outbox event
atomically in the same authoritative database, then relay pending events to a
Queue. With D1, verify that the exact statements fit the currently documented
atomic batch/transaction model. With external SQL, use a real database
transaction.

The relay can publish and crash before marking the event published, so duplicate
messages remain possible. The consumer must still be idempotent.

Monitor:

- oldest unpublished outbox row,
- publishing error rate,
- Queue oldest-message age,
- retries and DLQ,
- difference between business rows and expected downstream projections.

## Queue Consumer

For each message:

1. Validate schema and version.
2. Establish the stable event ID.
3. Atomically claim or deduplicate when needed.
4. Perform the effect with timeouts and an idempotency key.
5. Persist result required for reconciliation.
6. Acknowledge only after success.
7. Retry transient timeout, throttling, and dependency errors with backoff.
8. Send invalid or permanently failing work to terminal handling/DLQ.

Never retry all errors blindly. Authentication errors, malformed payloads, and
permanent business rejection usually require operator action or terminal status.

## Workflow And Saga

For each durable step define:

- input and output persisted across retries,
- idempotency boundary,
- timeout and retry policy,
- compensation when later work fails,
- whether cancellation is safe,
- behavior when code changes while instances are active,
- terminal state and operator action.

A saga gives atomicity of intent, not database isolation. Other requests can see
intermediate states; model statuses such as `provisioning`, `active`, `failed`,
and `cancelling` explicitly.

## Durable Object Coordination

Use one object when one key needs serialization. Within the object:

- restore durable state before serving dependent requests,
- use object-local transactions for state and deduplication where applicable,
- make alarms idempotent and persist the intended deadline,
- avoid outbound calls while holding conceptual critical sections when possible,
- bound queues and WebSocket fan-out to prevent one object from exhausting
  resources,
- expose migration/version fields for stored object state.

Across objects, assume partial failure. Use operation IDs, status records, sagas,
or reconciliation rather than pretending calls form a distributed transaction.

## Cache And Eventual Consistency

For every cache or KV projection define:

- source of truth,
- maximum acceptable staleness,
- TTL,
- invalidation/update path,
- miss and dependency-failure behavior,
- read-your-writes strategy,
- hot-key and stampede control,
- handling of deleted or revoked values.

Never put a cache on a correctness-critical path without deciding what stale data
does. Security revocation, ownership, inventory, and balances usually require an
authoritative check or a deliberately bounded risk window.

## R2 And Database Consistency

For upload flows use a state machine such as:

```text
pending -> uploaded -> ready
             |          |
             +-> failed/corrupt
```

Issue a scoped upload URL, verify object metadata after upload, then mark the
database record ready. Periodically delete stale pending uploads and unreferenced
objects. Make finalization idempotent.

## Timeouts And Backpressure

- Set an explicit deadline for each downstream call shorter than the caller's
  remaining deadline.
- Retry only idempotent operations, with jitter and a bounded attempt count.
- Avoid retry multiplication across Worker, Queue, Workflow, and client layers.
- Use Queues to absorb finite spikes, not to hide permanently insufficient
  consumer or database capacity.
- Shed load or return `429`/`503` before exhausting a constrained authority such
  as a Durable Object, external database, or provider quota.
- Monitor backlog age, not only message count.

## Observability

Propagate `request_id`, `operation_id`, `event_id`, `workflow_id`, `tenant_id`,
and relevant object/database identifiers. Log one structured completion event per
operation with outcome, duration, retry count, dependency timings, and error code.
Never log secrets, tokens, message bodies containing sensitive data, or unbounded
payloads.

Alert on symptoms and exhaustion:

- availability and p95/p99 latency,
- Worker exceptions and CPU/limit terminations,
- dependency timeout/error rate,
- D1/external SQL query errors and saturation,
- Durable Object hotspot latency and overload,
- Queue backlog age, retries, and DLQ growth,
- failed/stuck Workflows,
- reconciliation drift,
- email/provider rejection and throttling.

## Deployment And Recovery

- Make messages and stored state explicitly versioned.
- Use expand-migrate-contract schema changes so old and new Worker versions can
  overlap safely.
- Decide how active Workflows survive code deployment.
- Test rollback when data migrations are not backward compatible.
- Define backup/export and restore for each authoritative store.
- Run restore and replay exercises; a documented but untested path is not a
  recovery strategy.
- Specify RPO and RTO and identify dependencies that dominate them.
