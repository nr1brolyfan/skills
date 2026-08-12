# Cloudflare System Design Output

Adapt the depth to the request. Do not include empty ceremony, but do not omit a
correctness-relevant section.

## 1. Requirements And Assumptions

- Functional requirements
- Non-functional requirements
- Explicit assumptions and out-of-scope items
- Business invariants
- Consistency, latency, availability, RPO, and RTO targets

## 2. Capacity Estimate

Show simple arithmetic for:

- average and peak requests/events per second,
- storage growth and retention,
- bandwidth and object sizes,
- concurrent WebSockets or active entities,
- job rate, burst, processing time, and expected backlog,
- hottest tenant/key, not only averages.

## 3. Architecture

Provide a Mermaid diagram. Group Cloudflare components and external providers.
Label synchronous HTTP/service-binding calls, Queue delivery, Workflow starts,
WebSockets, and authoritative writes.

## 4. Service Decisions

| Concern | Choice | Why It Fits | Rejected Alternative | Main Risk |
|---|---|---|---|---|

For every state store identify whether it is authoritative, cache, projection,
log, or blob store.

## 5. Data And Consistency

- entities, keys, indexes, and tenant/shard key,
- source of truth and derived projections,
- transaction and serialization boundaries,
- expected stale reads and read-your-writes behavior,
- data lifecycle, deletion, retention, and residency,
- migration and versioning.

## 6. Critical Flows

Show sequence diagrams for important paths. Include success plus at least one
partial-failure path. For asynchronous work specify stable ID, delivery guarantee,
acknowledgment, retry, DLQ/terminal status, and replay.

## 7. Limits And Scaling

| Component | Demand | Verified Current Limit/Behavior | Headroom | Scaling Trigger | Response |
|---|---:|---:|---:|---|---|

Link official documentation when numeric limits materially affect the design.
Never silently use remembered limits.

## 8. Reliability And Operations

- failure-mode table,
- timeouts, backpressure, idempotency, outbox, and reconciliation,
- SLOs, metrics, logs, traces, alerts, and runbooks,
- deployment, rollback, schema changes, backup, restore, RPO, and RTO,
- load, failure, replay, and restore tests.

## 9. Security And Isolation

- authentication and authorization,
- WAF, abuse controls, rate limits, and Turnstile where appropriate,
- secrets and service-to-service trust,
- tenant boundary and noisy-neighbor protection,
- data classification, encryption, retention, deletion, and audit.

## 10. External Services

For every non-Cloudflare component state:

- unmet requirement that justifies it,
- why the closest Cloudflare primitive is insufficient,
- connectivity and authority boundary,
- dependency outage behavior,
- portability, cost, and recovery implications.

## 11. Tradeoffs And Evolution

End with known limitations, first bottlenecks, measurable migration triggers, and
open decisions. Prefer statements such as "move from D1 when measured size/write
load or transaction requirements cross X" over vague future-proofing.

## Architecture Review Variant

When reviewing an existing design, use:

1. Findings ordered by severity.
2. Violated invariant or requirement for each finding.
3. Concrete remediation and its tradeoff.
4. Missing measurements or current-limit verification.
5. Residual risks and tests.

Examples of high-severity findings include KV used for financial authority,
non-idempotent at-least-once consumers, a lossy database-plus-Queue dual write,
or D1 selected despite required interactive ACID semantics.
