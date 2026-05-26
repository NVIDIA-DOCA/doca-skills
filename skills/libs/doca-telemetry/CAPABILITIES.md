# DOCA Telemetry capabilities, version overlay, errors, observability, safety

> **CRITICAL framing correction (Run-12).** The DOCA Telemetry
> library is a **per-domain hardware-counter READER** surface,
> NOT a NetFlow / IPFIX / local-socket *collector* framework. The
> public header exposes six per-domain sub-libraries —
> `doca_telemetry_pcc` (Programmable Congestion Control counters),
> `doca_telemetry_dpa` (DPA counters), `doca_telemetry_diag`
> (DIAG counters), `doca_telemetry_adp_retx` (adaptive-retransmit
> counters), `doca_telemetry_phy` (PHY-layer counters),
> `doca_telemetry_pci` (PCI-layer counters) — each with its own
> `_cap_is_supported(devinfo)` capability query, context
> create on a `doca_dev`, `doca_ctx_start()`, and per-domain
> read / sample call. The rest of this file talks about a
> generic "collector / schema-query / NetFlow / IPFIX" surface
> that does NOT exist in the public header; treat that prose as
> a known bug and route any NetFlow / IPFIX / schema-collector
> question to a non-DOCA framework. The accurate per-domain
> capability discovery is `doca_telemetry_<domain>_cap_is_supported(devinfo)`
> against the active device, BEFORE creating the per-domain
> context. The reader-vs-exporter split (this library reads
> hardware counters; `doca-telemetry-exporter` publishes
> structured telemetry / labeled metrics / OTLP logs) is still
> correct.

**Where to start:** Pick the H2 anchor that matches your question
(role-split / object family / capability discovery / path
selection / version / errors / observability / safety) and read
that section end-to-end. The tables in each section are the
load-bearing content; the prose around them is interpretation.
Where the existing prose says "collector / NetFlow / IPFIX /
schema-query," treat it as the bundle's previous framing — the
real per-domain reader surface is documented in the framing
correction above and in the per-domain header pages.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern
(the verbs `configure / build / modify / run / test / debug`),
jump to [TASKS.md](TASKS.md). For the canonical DOCA version-
handling rules that this skill layers a collector overlay on top
of, see [`doca-version`](../../doca-version/SKILL.md).

## Pattern overview

Every telemetry-collection question this skill teaches resolves
into one of SEVEN patterns. The patterns are CLASSES — they
apply across every collector release and every DOCA-using
publisher the collector receives from, not just the worked
examples shown.

| Pattern | When it applies (class shape) | Where the substance lives |
| --- | --- | --- |
| 1. Pick the collector, not the exporter | The application is the RECEIVER of telemetry events (collector / aggregator / monitoring agent); the publishing side is a separate library out of this skill's scope | [`## Capabilities and modes`](#capabilities-and-modes) role-split table |
| 2. Decide the collector is the right tool | The need is structured event consumption / aggregation FROM the DOCA telemetry ecosystem; it is NOT publishing (that is [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)), NOT plain stdout logging, NOT a non-DOCA Prometheus / OTLP source | [`## Capabilities and modes`](#capabilities-and-modes) path-selection bullet |
| 3. Honor the schema-must-match contract with the publisher | Every event the collector receives is shaped by a schema the publisher registered; the collector MUST consume against the same schema (or version-compatible) or it loses events / mis-interprets them | [`## Capabilities and modes`](#capabilities-and-modes) schema-contract table + [TASKS.md ## configure](TASKS.md#configure) step 4 |
| 4. Stand up the collector context + schema-query + consume loop | DOCA Core lifecycle: create collector context → set transport configuration → init → start → discover schemas via the schema-query family → drain incoming events → stop → destroy | [`## Capabilities and modes`](#capabilities-and-modes) object table + [TASKS.md ## configure](TASKS.md#configure) |
| 5. Discover capabilities before assuming ingest shape | `doca_telemetry_*_cap_*` family for supported incoming transports (local socket / NetFlow / IPFIX), max in-flight events, sampling policy, supported schema versions — call BEFORE assuming a particular ingest shape fits this install | [`## Capabilities and modes`](#capabilities-and-modes) capability-query rule + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 6. Drain the consumer queue (back-pressure policy) | `DOCA_ERROR_AGAIN` on consume means the consumer queue is full; the collector's correct response is to drain faster or accept loss — back-pressure to the publisher is a policy the collector OWNS, not a default | [`## Safety policy`](#safety-policy) consumer-queue-full rule + [`## Error taxonomy`](#error-taxonomy) `AGAIN` row |
| 7. Diagnose a collector error | Map symptom (`BAD_STATE`, `INVALID_VALUE`, `AGAIN`, `NOT_PERMITTED`, `NOT_FOUND`, `IO_FAILED`) to root cause; in particular recognise `NOT_FOUND` on schema query as "no publisher has registered this schema yet" rather than "library bug" | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **The collector is the receiver; the exporter is the
  publisher.** `doca-telemetry` is the library the user's
  application links to *consume* telemetry events. The
  publishing side is
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md),
  a sibling library with its own skill. Wiring the exporter's
  API into a collector (or this library's API into a publisher)
  is the load-bearing first-app failure and the agent must
  surface the distinction BEFORE any code-level guidance.
- **Publisher and collector MUST agree on the schema.** Every
  event the collector receives is shaped by a schema the
  publisher registered. A schema mismatch is silent: the
  collector either drops the event or interprets it as garbage
  (wrong field types, missing required fields). Schema-version
  drift between publisher and collector is the canonical
  *"events appear to flow but nothing makes sense"* failure;
  the agent must teach this contract as soon as both sides are
  on the table.

## Capabilities and modes

DOCA Telemetry is a **DOCA Core Context** with one collector
context object that owns the configured incoming transport(s),
the discovered schema set, and the per-consume event delivery
surface. Every collector instance follows the universal
`cfg-create → cfg-set-* → init → start → use → stop → destroy`
lifecycle (see
[`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes)).
On top of that lifecycle, the collector layers an asymmetric
collector / exporter role split, a small object family, a
schema-discovery surface, and a capability-query family.

**Role split — collector (receiver) vs exporter (publisher).**
The telemetry path is asymmetric and the asymmetry is the #1
first-app confusion (mirror image of the same confusion the
exporter skill calls out).

| Side | What it does | What it does NOT do | Where it lives |
| --- | --- | --- | --- |
| Collector (this library, `doca-telemetry`) | Application-side **consumption** of structured telemetry events: bind / listen on an incoming transport, discover the schemas publishers have registered, drain incoming events, dispatch them into the application's aggregation / downstream-forwarding logic | Publish telemetry events itself; define the schema of events that arrive (the publisher owns the schema) | Linked INTO the user's collector / aggregator / monitoring-agent application; runs as that application's user, in that application's process. Often attaches to the DOCA Telemetry Service (DTS) as the canonical aggregator on BlueField |
| Exporter (sibling library, `doca-telemetry-exporter`) | Application-side **publishing** of structured telemetry events: register schemas, create sources, emit values | Aggregate, persist, query, or fan-out telemetry; consume events from another publisher | A separate library with its own skill at [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md). Wiring its API into a collector application is the load-bearing first-app failure this skill exists to prevent |

**Object family.** The collector exposes ONE root context plus
a small set of cooperating object types. The agent must not
invent additional ones; the public surface is closed. Exact
symbol names are install-bound — confirm against the user's
installed headers under
the install's actual include directory (resolved via `pkg-config --variable=includedir`, commonly `/opt/mellanox/doca/include/` or `/opt/mellanox/doca/infrastructure/include/` depending on profile) per the headers-
win-over-docs rule in
[`doca-version`](../../doca-version/SKILL.md).

| Object | What it represents | Per-instance scope | Notes |
| --- | --- | --- | --- |
| Collector context | The local telemetry-consumption endpoint: configured incoming transport(s), discovered schema set, per-consume event delivery surface | One per logical collector inside the application; the application MAY run multiple collector contexts for transport / scope separation | Owns the DOCA Core lifecycle: cfg-create → cfg-set transport → init → start → use → stop → destroy. Out-of-order calls return `DOCA_ERROR_BAD_STATE` |
| Schema-query objects | A handle on the shape of telemetry events arriving from publishers — field names + field types + schema version | Per discovered schema the collector decides to consume against | The collector DISCOVERS these from incoming traffic; it does NOT register them itself (that is the publisher's job). A query that returns `DOCA_ERROR_NOT_FOUND` means no publisher has registered this schema yet — wait or check the publisher staging, do not invent a registration call on the collector side |
| Event consumption / sampling primitives | The per-event delivery surface (and the sampling-policy knobs the install supports) by which the collector receives events from the transport into the application | One delivery loop per collector context | Drives the application's drain loop. `DOCA_ERROR_AGAIN` on the consume call means the collector's local queue is full — the application must drain faster or accept loss; see [`## Safety policy`](#safety-policy) |

**Schema-must-match contract with the publisher.** This is the
load-bearing interop rule between this skill and
[`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md).

| Side | What it owns about the schema | What goes wrong on mismatch |
| --- | --- | --- |
| Publisher ([`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)) | Defines schema (field names, field types, schema version); registers it with the exporter context BEFORE the first emit referencing it | Emits events that the collector cannot decode at all (transport-layer drop) or that the collector decodes against a different schema (silent type / field corruption) |
| Collector (this library) | Discovers the schema via the schema-query family AFTER it appears in the incoming traffic; consumes events strictly against the discovered schema (or a version-compatible one per the install's compatibility rule) | Treats incoming events as garbage (wrong field types), misses required fields, or sees zero events because none match its expected schema |
| Both | Agree on schema NAME, schema VERSION, and the per-field type set | Mismatch is silent. The end-to-end signal is "events appear to flow on the publisher side but the collector either sees nothing or sees nonsense" — the smoke loop in [TASKS.md ## test](TASKS.md#test) is the cheapest way to surface this BEFORE bulk traffic |

**Capability discovery — the only rule.** Before assuming a
particular incoming transport, a particular max in-flight event
count, a particular sampling policy, or a particular schema
version is on this install, call the matching
`doca_telemetry_*_cap_*` query family (per the cross-cutting
cap-query rule in
[`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability)).
The query is the runtime authority for *"is this collector
shape supported on this install"*. Quoting *"the collector
supports transport X"* from memory without the cap query is the
silent-fail case — when the install's actual transport set is
narrower, the program returns `DOCA_ERROR_NOT_SUPPORTED` (or
the matching install-specific code) at transport configuration
time and the user has no idea why. The agent MUST quote the
queried values back to the user; the canonical list of
`_cap_*` queries that exist on a particular install is in the
public collector headers (per the headers-win-over-docs rule
in [`doca-version`](../../doca-version/SKILL.md)).

**Path selection — collector vs the adjacent options.** The
collector is for structured telemetry consumption FROM the
DOCA telemetry ecosystem. It is not the answer for every "I
want to receive an event" question; the agent must walk this
rule before recommending collector setup.

| Use DOCA Telemetry (this skill) when … | Use a different primitive when … |
| --- | --- |
| The user is building a local collector / aggregator / monitoring agent that **consumes** DOCA telemetry events from one or more publishers (typically [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)-using applications), or attaching to the DOCA Telemetry Service (DTS) as the canonical aggregator on BlueField | The user actually wants to **PUBLISH** telemetry from their app — that is [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md), the sibling publisher library. Wiring this collector library into a publishing application is the load-bearing first-app failure |
| The user is building a custom downstream consumer of DOCA telemetry (NetFlow / IPFIX ingest into a custom analyzer, Prometheus-style scrape endpoint backed by DOCA-sourced events) | The user wants plain structured stdout / per-line logging from their own program — use `doca-log`; the collector's schema-aware discipline is overhead the user does not need |
| The DOCA telemetry ecosystem is the SOURCE the user is consuming from | The source is a **non-DOCA** program (a regular Linux daemon, a Kubernetes pod's instrumentation surface) — use a Prometheus client library, an OpenTelemetry collector, or another non-DOCA-aware ingest tool directly; this collector library only understands DOCA-shape telemetry |

**Configuration shape.** *Mandatory* configurations before
`doca_ctx_start()` on the collector context: at least one
incoming transport configured (the actual transport options
surface — local domain socket / NetFlow listener / IPFIX
listener / on-host telemetry agent — is install-bound and the
agent MUST route the user to the public collector guide
reachable via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
for the current matrix), and the consumer queue / drain
configuration appropriate to the install's max-in-flight cap.
*Optional* configurations (sampling policy, per-schema filters,
attachment to DTS as the canonical aggregator) follow the
standard DOCA Core surface; defaults come from the library and
the active install.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The collector-specific overlay** is:

- **Use `pkg-config --modversion doca-telemetry` as the build-time anchor.** Per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure), this MUST match the other version sources in the four-way match. The set of incoming transports / max in-flight events / supported schema versions that the collector actually supports on a given install is bound to BOTH the DOCA version AND the active `doca_devinfo`; agent-memory limits are not authoritative and MUST be replaced with a `doca_telemetry_*_cap_*` query at runtime (per the cross-cutting cap-query rule in [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability)).
- **The collector is distinct from the exporter across every release.** When the user reports *"I'm reading guides about doca-telemetry-exporter — is that this library?"*, the answer is no: that is the publishing side, with its own skill at [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md). The two `.pc` files coexist on a normal install; using the wrong one for the user's intent is the load-bearing first-app failure and the agent must walk the role split (per [`## Capabilities and modes`](#capabilities-and-modes)) BEFORE picking a `pkg-config` module.
- **`doca-telemetry.pc` plus `doca-common.pc` must both match `doca_caps --version`** at the four-way-match check (per [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)). A common partial-install pattern after a DOCA upgrade is that `doca-telemetry.pc` lingers from the previous release while `doca-common.pc` was refreshed; route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) ladder step 2 before any collector-layer diagnosis.
- **Schema-version drift across upgrades is a cross-side concern.** When the publisher and collector are on different DOCA versions, a schema the publisher registered may carry fields the collector's version does not know about (or vice versa). The schema-must-match contract in [`## Capabilities and modes`](#capabilities-and-modes) still applies; the agent must surface that *aligning the two sides' DOCA versions* (or explicitly running them at versions the install's compatibility policy guarantees) is the only safe way out of a schema-drift symptom.

## Error taxonomy

Collector-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *collector surface* meaning that the
agent must disambiguate before falling back to the cross-
library response.

| Error | Collector context where it shows up | Collector-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | Consume call before `doca_ctx_start()` on the collector context; schema-query call against a context not yet started; reconfigure call after the context reached `RUNNING` and the library does not allow late reconfiguration on this install | Lifecycle violation. Walk the call sequence against the lifecycle in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); the most common case is calling consume before the collector context reaches `RUNNING`. |
| `DOCA_ERROR_NOT_PERMITTED` | Collector context create; transport bind / listen call; first consume | The collector cannot bind to the configured transport endpoint (e.g. the local socket is already owned by another process / different user, the port the network listener wants is below 1024 and the user lacks `CAP_NET_BIND_SERVICE`, the on-host telemetry agent's socket is owned by another user). The collector itself does NOT need sudo as a universal rule; the lock-down is at the **transport endpoint**. Route to [`## Safety policy`](#safety-policy) permission matrix BEFORE any code change. |
| `DOCA_ERROR_INVALID_VALUE` | Schema query with a malformed selector; consume call asked to receive into a buffer smaller than the install's max-event-size cap; oversized event arrived on the transport | A type / size mismatch against the install's caps. Re-read the relevant `doca_telemetry_*_cap_*` query against the active install; if the event itself is oversized the publisher is to blame (route to [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md) caps). |
| `DOCA_ERROR_AGAIN` | Consume call | The local consumer queue is full — events are arriving faster than the application drains them. This is a back-pressure signal, NOT a transport error. The collector's correct response is to: (a) drain faster (widen the drain loop, dispatch to a worker pool); (b) increase the queue cap if the install allows; (c) accept the loss bounded by policy. Back-pressuring the publisher (asking it to slow down) is a **policy decision the collector owns**, not a library default — and the publisher's own hot-path-drop-not-block rule (per [`doca-telemetry-exporter CAPABILITIES.md ## Safety policy`](../doca-telemetry-exporter/CAPABILITIES.md#safety-policy)) means publishers MAY simply drop instead of slowing down. See [`## Safety policy`](#safety-policy) consumer-queue rule. |
| `DOCA_ERROR_NOT_FOUND` | Schema-query call for a named schema; consume call referencing a schema selector | No publisher has registered this schema with any source the collector is currently consuming from. The collector is functioning correctly; the staging is the issue. Walk the publisher-up staging in [`## Safety policy`](#safety-policy); if the publisher *is* up, walk the schema-must-match contract in [`## Capabilities and modes`](#capabilities-and-modes) (different schema name / version than the publisher registered). |
| `DOCA_ERROR_IO_FAILED` | Collector context create; transport bind / listen call; ongoing consume | The transport layer below DOCA reported failure (socket read failed, network listener disconnected, on-host telemetry agent went away). Capture state and route to env-class debug ([`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)) — the layer below DOCA is the suspect, not the collector program. |

The agent's rule: **never recommend a retry loop on
`DOCA_ERROR_*` without first identifying which of the rows
above is the cause**. None of the collector rows wants a blind
retry: `AGAIN` wants a drain-faster / queue-widen / accept-
loss policy decision at the collector layer; `NOT_FOUND` wants
the publisher staging or the schema contract investigated;
the others want investigation, not retry.

## Observability

The collector's observability surface is per-consume status +
capability snapshot + the publisher side. There is no PE-based
external completion stream on the collector that names *"event
loss inside the transport"* — visibility comes from inspecting
each consume's return value, the configure-time cap snapshot,
the schema-query results, and the publisher's own per-emit
status.

Three primary signals the agent should reach for:

1. **Per-consume return.** Every `doca_telemetry_*` consume
   call returns a `doca_error_t`. The agent must inspect it on
   every consume: success means an event was delivered into
   the application; `DOCA_ERROR_AGAIN` means the local
   consumer queue was full and the application's drain policy
   has to absorb the gap (per [`## Safety policy`](#safety-policy));
   `DOCA_ERROR_NOT_FOUND` on the schema query means no
   publisher has registered this schema yet (publisher staging
   or schema contract); `DOCA_ERROR_*` of any other shape
   means the consume did not yield an event and the row in
   [`## Error taxonomy`](#error-taxonomy) names the fix.
2. **Capability snapshot at configure time.** The output of
   every `doca_telemetry_*_cap_*` query is a snapshot of *what
   the collector said was supported on this install* before
   any consume. Save it as the baseline; if a later consume
   returns `DOCA_ERROR_INVALID_VALUE` (oversized event) or
   `DOCA_ERROR_NOT_SUPPORTED` (transport the install does not
   advertise) the diff against this snapshot is the bug, not
   the consume call itself. Cap-query at configure time is the
   cheapest way to make a later capability-related error self-
   explanatory.
3. **Publisher-side per-emit status (end-to-end).** The
   collector's *true* observability is at the publisher: did
   the publisher's emit calls return success for the events
   the collector is supposed to be receiving? A collector that
   sees nothing while the publisher's emit returns success on
   every call is the canonical *"transport-level mismatch or
   schema mismatch"* failure — route via the publisher skill
   ([`doca-telemetry-exporter CAPABILITIES.md ## Observability`](../doca-telemetry-exporter/CAPABILITIES.md#observability))
   to compare both ends. The smoke loop in
   [`TASKS.md ## test`](TASKS.md#test) (start collector, start
   publisher, verify one event arrives intact) is the
   bundle's end-to-end check before any bulk traffic.

For the cross-cutting observability primitives
(`--sdk-log-level`, the `doca-<lib>-trace` build flavor, the
`DOCA_LOG_LEVEL` env var) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the install-tree observability (logger names, package
layout) defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

The collector's safety surface is **transport-endpoint
permissions + publisher-up-or-collector-up staging + consumer-
queue back-pressure policy**. Each one is the source of a
specific first-app failure the agent must prevent.

The **permission + staging matrix** the agent must walk for
any new collector setup:

| Prerequisite | Required state | How the agent verifies | Where to fix |
| --- | --- | --- | --- |
| Collector user can bind / listen on the configured transport endpoint | The collector runs as a user that can: bind the local domain socket the publishers are configured to write to (socket permissions); bind the TCP / UDP port the network listener (NetFlow / IPFIX) wants (sub-1024 ports require `CAP_NET_BIND_SERVICE` or sudo); attach to the on-host telemetry agent's socket | `id` (confirm the running user); inspect the configured transport endpoint (socket ownership, port range, agent-socket permissions); the collector's first start returns success rather than `DOCA_ERROR_NOT_PERMITTED` | If the user thinks the collector needs sudo across the board, that is the bug — sudo is only needed for sub-1024 port binding or for specific endpoint-ownership cases. Fix on the env / endpoint side via [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure) or by re-pointing the collector at an endpoint its user CAN bind |
| Publisher and collector both running for end-to-end smoke | For end-to-end verification, the publisher (typically a [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)-using app) is up AND the collector is up. Either order is acceptable in steady state — the collector may receive from publishers that start later — but the smoke loop in [`TASKS.md ## test`](TASKS.md#test) requires both | Independently confirm both processes are running and the transport endpoint is reachable; the first consume yields one event matching the publisher's emit | If only one side is up, the staging is incomplete. A `DOCA_ERROR_NOT_FOUND` on schema query against a collector running alone is the canonical *"no publisher has connected yet"* signal, NOT a bug in the collector |
| Consumer-queue back-pressure policy is decided explicitly | When `DOCA_ERROR_AGAIN` appears on consume, the collector application has an explicit policy: drain faster (widen the drain loop), increase the queue cap if the install allows, or accept bounded loss. The collector does NOT default to slowing the publisher down | Code review at modify-time per [`TASKS.md ## modify`](TASKS.md#modify); structured log shows incoming-event drops accounted for rather than silently absorbed | Decide a policy at the collector layer. Asking the publisher to slow down is a non-default cross-process choice — and many publishers (per [`doca-telemetry-exporter CAPABILITIES.md ## Safety policy`](../doca-telemetry-exporter/CAPABILITIES.md#safety-policy)) WILL drop on `AGAIN` rather than slow their hot path. Plan for both halves of the contract |

- **The collector does NOT need sudo as a universal rule.** It
  needs whatever capability lets it bind / listen on the
  specific transport endpoint configured. If the user's first
  reaction to `DOCA_ERROR_NOT_PERMITTED` is to add `sudo`
  globally, walk them back: the cause is almost always the
  specific endpoint's permission set, not a missing capability
  on the collector process as a whole.
- **The collector is one-way receive.** Do not invent a
  `_publish()` or `_emit()` shape on it; the library is
  consume-only. If the user wants the collector application to
  ALSO publish telemetry of its own (e.g. re-forwarding to a
  downstream sink), that requires a SEPARATE
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
  context inside the same application — not a method on the
  collector context.
- **Validate with a one-event smoke before any bulk traffic.**
  A single emit on the publisher side + a single consume on
  the collector side, with the same schema, is the cheapest
  way to prove the transport endpoint + permission + schema
  contract are all correct. If the smoke passes, bulk traffic
  inherits that confidence; if the smoke says the publisher
  emitted but the collector saw nothing, the schema contract
  or the transport mismatch is the prime suspect. The loop is
  described in [`TASKS.md ## test`](TASKS.md#test).

## Deferred topic boundaries

This skill scopes itself to the DOCA Telemetry collection
library. Adjacent topics the agent will get asked but should
route elsewhere:

- **The publishing side** —
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
  is the sibling skill for the application-side publisher
  library. This skill is consumer-side only; any "how do I
  emit an event" question routes there.
- **The DOCA Telemetry Service (DTS) — operating / deploying
  the service itself** — DTS is a separate DOCA service with
  its own public guide. Reach via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  This skill **uses** DTS as one of the aggregators a
  collector can attach to, but does not re-document operating
  the service.
- **DOCA Core context and progress engine internals** —
  owned by
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  This skill *uses* the Core context lifecycle; it does not
  redefine it.
- **Downstream telemetry rendering / dashboards** — out of
  scope. Once events reach the collector's drain loop, the
  downstream sinks (NetFlow analyzer, IPFIX collector,
  Prometheus / Grafana, OpenTelemetry pipeline) are governed
  by their own ecosystems.
- **Plain structured logging from the collector's own
  program** — use `doca-log`; the
  collector's schema-aware discipline is overhead the user
  does not need for plain logs.
- **Non-DOCA telemetry sources** — a regular Linux daemon's
  metrics, a Kubernetes pod's instrumentation surface — use a
  Prometheus client library, an OpenTelemetry collector, or
  another non-DOCA-aware ingest tool directly. This collector
  library only understands DOCA-shape telemetry.
- **Cross-cutting `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the collector overlay (including the
  `AGAIN`-means-consumer-queue-full rule and the `NOT_FOUND`-
  means-no-publisher-registered-this-schema rule), not the
  taxonomy itself.
- **Cross-cutting debug ladder** (install / version / build /
  link / runtime / program / driver) — owned by
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug).
  This skill's `## debug` overlays the runtime + program
  layers.
