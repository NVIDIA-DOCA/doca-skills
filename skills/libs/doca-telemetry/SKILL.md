---
name: doca-telemetry
description: >
  Use this skill when the user is building a DOCA telemetry collector
  — consuming structured telemetry events via `pkg-config
  doca-telemetry`. Covers the collector context lifecycle,
  schema-query discovery of publisher event shapes, capability
  discovery for incoming transports (local socket / NetFlow / IPFIX),
  the schema-must-match contract, the AGAIN-means-consumer-queue-full
  back-pressure rule, transport-endpoint permissions, DOCA Telemetry
  Service (DTS) attachment on BlueField, and debugging DOCA_ERROR_*
  from collector calls. Trigger even when the user does not say "DOCA
  Telemetry" or "collector" — typical implicit phrasings include
  "publisher emits but agent sees nothing", "AGAIN on consume / queue
  fills", "NOT_FOUND on schema query", "daemon to receive counter
  events from my BlueField app", or "ingest NetFlow/IPFIX into my
  analyzer". Refuse and route elsewhere for the publishing side
  (doca-telemetry-exporter), DTS deployment, plain stdout logging,
  and non-DOCA sources — those belong to other skills.
metadata:
  kind: library
compatibility: >
  Requires DOCA SDK installed at /opt/mellanox/doca on Linux (Ubuntu
  22.04/24.04 or RHEL/SLES) with a BlueField DPU or ConnectX NIC
  attached. Reads the user's local install via `pkg-config
  doca-telemetry` and inspects
  /opt/mellanox/doca/{lib,include,samples,applications}.
---

# DOCA Telemetry

**Where to start:** This skill assumes DOCA is already installed and
the user is doing **hands-on telemetry-collection work** — building
a local collector / aggregator / monitoring agent that **consumes**
structured telemetry events from one or more DOCA-using publishers.
Open [`TASKS.md`](TASKS.md) if the user wants to *do* something
(configure / build / modify / run / test / debug); open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
incoming telemetry shape can this collector accept* on this install.
If the user has not installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user is
confused about whether they want this library or
[`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
(the publisher side) — read the collector-vs-exporter role split in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
BEFORE configuring anything; mixing the two is the load-bearing
first-app failure for this skill.

## Example questions this skill answers well

The CLASSES of telemetry-collection questions this skill is built
to answer, each with one worked example. The agent should treat
the *class* as the load-bearing piece — the worked example is a
single instance.

- **"Which library do I want — the telemetry collector or the
  telemetry exporter?"** — worked example: *"I want a small daemon
  on the host that RECEIVES per-second counter events from a
  doca-telemetry-exporter-using application and aggregates them —
  which DOCA artifact do I link?"*. Answered by the collector-vs-
  exporter rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  role-split table + the path-selection bullet, both of which
  name `doca-telemetry` as the consumer / aggregator the user
  links and route the publishing side to
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md).
- **"How do I stand up a collector that consumes events from a
  DOCA application?"** — worked example: *"start a collector
  process on the same host where my doca-telemetry-exporter app
  is publishing, and have it print every incoming
  packets_processed event"*. Answered by the collector-context
  lifecycle in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  object table + the workflow in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`TASKS.md ## run`](TASKS.md#run) step 3 (single-event smoke
  before bulk).
- **"My publisher emits but my collector sees nothing — where do
  I start?"** — worked example: *"the exporter app reports each
  emit as success, but my collector's incoming-event count stays
  at zero"*. Answered by the schema-must-match contract in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the collector-up-before-publisher staging rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the publisher-collector smoke loop in
  [`TASKS.md ## test`](TASKS.md#test) (start collector, start
  exporter, verify one event arrives intact).
- **"My collector returns `DOCA_ERROR_AGAIN` — should I retry?"** —
  worked example: *"once incoming event rate climbs, my collector
  starts seeing `AGAIN` on the consume call"*. Answered by the
  `AGAIN` row in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the consumer-queue-full back-pressure rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
  the collector's correct response is to drain faster (or accept
  the loss); back-pressure to publishers is a policy decision the
  collector owns, not a default.
- **"My collector returns `DOCA_ERROR_NOT_FOUND` querying a
  schema — what did I forget?"** — worked example: *"my schema
  query returns `NOT_FOUND` before any publisher has connected"*.
  Answered by the `NOT_FOUND` row in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (no publisher has registered the schema yet) + the publisher-
  first staging in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  for the case where the collector is up but no producer has
  joined.
- **"Is `doca_telemetry_*` on my installed DOCA, and is the
  incoming transport / schema version I need supported here?"** —
  worked example: *"is the NetFlow ingest transport on DOCA 3.3
  against my install?"*. Answered by the version-compatibility
  overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
  which cross-links the canonical detection chain in
  [`doca-version`](../../doca-version/SKILL.md), plus the
  capability-query rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).

## Audience

This skill serves **external developers building applications
that consume structured telemetry through DOCA Telemetry** —
i.e., users whose application code calls `doca_telemetry_*`
(directly in C/C++, or through FFI/bindings from another
language) to receive, sample, and aggregate counters, gauges,
and events published by one or more DOCA-using producers (often
applications linking
[`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md),
sometimes the
[DOCA Telemetry Service (DTS)](https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Service-Guide/index.html)
as the canonical aggregator on BlueField). It is *not* for
NVIDIA developers contributing to DOCA Telemetry itself, and it
is *not* for users writing the **publishing** side — that is
[`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md),
a separate skill.

**Language scope.** DOCA Telemetry ships as a C library with
`pkg-config` module name `doca-telemetry`. The shipped samples
are written in C. C and C++ consumers are the canonical case;
the worked examples in `TASKS.md` assume that path. Other-
language consumers (Rust, Go, Python, …) consume the same
`*.so` through FFI or language-specific bindings; the skill's
contribution in that case is to keep the collector-vs-exporter
distinction, the schema-must-match contract with the publisher,
the capability-discovery rule, the transport-endpoint permission
rule, the consumer-queue-full back-pressure rule, and the error-
taxonomy guidance language-neutral, and to route the agent to
the public C ABI as the authoritative surface that any wrapper
will eventually call.

## When to load this skill

Load this skill when the user is doing hands-on DOCA Telemetry
collection / consumption work, in any language. Concretely:

- Standing up a collector context that listens on one of the
  supported incoming transports (local socket, NetFlow, IPFIX —
  the actual set is install-bound and confirmed by the
  capability-query family per
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)).
- Discovering the shape of incoming events via the schema-query
  primitives BEFORE writing consumption code that assumes a
  particular event layout.
- Driving the event-consumption / sampling loop (drain incoming
  events, dispatch into the application's aggregation /
  downstream-forwarding logic) and handling the consumer-queue-
  full back-pressure case on `DOCA_ERROR_AGAIN`.
- Integrating with the DOCA Telemetry Service (DTS) as the
  canonical aggregator on BlueField — for the host-side or
  agent-side consumer view of telemetry already flowing through
  DTS.
- Reading the device + library capability surface for the
  collector via the `doca_telemetry_*_cap_*` query family
  before assuming a particular ingest shape (which transports,
  max in-flight events, supported schema versions) is available
  on this install.
- Debugging a `DOCA_ERROR_*` returned from a collector call
  (lifecycle vs. transport-endpoint permission vs. consumer-
  queue-full vs. unknown schema vs. transport / driver) and the
  per-consume status reported back to the application.
- Choosing between DOCA Telemetry and an adjacent option
  ([`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
  when the user actually wanted to PUBLISH, not consume;
  `doca-log` when plain structured
  stdout logging is enough; a Prometheus or OpenTelemetry
  client / collector when the source is a non-DOCA program).
- Designing or extending non-C bindings (Rust, Go, Python, …)
  that wrap the collector C ABI — for the collector-vs-exporter
  distinction, the schema-must-match contract, the transport-
  endpoint permission rule, the consumer-queue-full back-
  pressure rule, and the capability + error rules the wrapper
  must honor.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, the **publishing** side
([`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
has its own skill), or non-collector library questions. For
those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive
collector-specific material lives in two companion files:

- `CAPABILITIES.md` — what the collector can express on this
  install: the collector-vs-exporter role-split rule, the
  object family (collector context + schema-query objects +
  event-consumption / sampling primitives, with the DOCA Core
  lifecycle), the schema-must-match contract with the
  publisher (the load-bearing interop rule), the capability-
  query surface (`doca_telemetry_*_cap_*`), the collector
  error taxonomy (mapped onto the cross-library `DOCA_ERROR_*`
  set, with the `AGAIN`-means-consumer-queue-full rule called
  out explicitly), the observability surface (per-consume
  status + capability snapshot at configure time + the
  publisher side as the end-to-end signal), the safety policy
  that gates transport-endpoint permissions (socket / port-
  binding) and the publisher-up-or-collector-up staging, and
  the path-selection rule against
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md),
  `doca-log`, and standalone
  Prometheus / OTLP collectors.
- `TASKS.md` — step-by-step workflows for the six in-scope
  collector verbs: `configure`, `build`, `modify`, `run`,
  `test`, `debug`. Plus a `Deferred task verbs` block that
  points out-of-scope questions at the right next skill.

The skill assumes a host where DOCA is already installed at
the standard location, the collector runs as a user that can
bind / listen on whichever incoming telemetry transport the
collector is configured for, and a publishing telemetry source
(typically a `doca-telemetry-exporter`-using application, or
DTS on BlueField) is reachable. It does not cover installing
DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md) — and it does not
cover writing the publishing side, which is
[`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA Telemetry collector source code, in any
  language.** The verified collector source code is the
  shipped C samples at
  `/opt/mellanox/doca/samples/doca_telemetry/`. The agent's
  job is to route the user to those files and prescribe a
  minimum-diff modification on them via the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the collector-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **A publishing telemetry application.** The publisher side
  lives in
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md);
  cross-link there for any "how do I emit an event from my
  app" question.
- **A DOCA Telemetry Service (DTS) deployment / configuration
  guide.** DTS is a separate DOCA service with its own public
  guide; reach it via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  This skill **uses** DTS as one possible aggregator a
  collector can attach to, but does not re-document DTS itself.
- **Standalone build manifests** (`meson.build`,
  `CMakeLists.txt`, `Cargo.toml`, …) parked inside the skill.
  The agent constructs the build manifest *in the user's
  project directory* against the user's installed DOCA, where
  `pkg-config --modversion doca-telemetry` is the source of
  truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of
  any kind. A mock or incomplete artifact in this skill's
  tree, even one labeled "reference", is misleading: users
  will read it as buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (specifically, that the user is on the
   CONSUMING side of the telemetry path — not the publishing
   side, which is
   [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)).
2. **For the collector-vs-exporter rule, the object family,
   the DOCA Core lifecycle on the collector context, the
   schema-must-match contract with the publisher, the
   capability-query surface, the error taxonomy (including
   the `AGAIN`-means-consumer-queue-full rule),
   observability, the safety policy, and the path-selection
   rule, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify,
   run, test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-version`](../../doca-version/SKILL.md) for the canonical
version-handling rules, and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or
the installed package layout" rather than "collector-specific
guidance".

## Related skills

- [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md) —
  the **publishing** side of the same telemetry path. This
  skill (the collector) and `doca-telemetry-exporter` (the
  publisher) form a complementary pair: an application that
  wants to EMIT events links the exporter; an application that
  wants to RECEIVE / aggregate those events links this skill.
  Wiring the wrong direction's API into the user's app is the
  #1 first-app failure for both skills, and the load-bearing
  rule the agent must surface before any code-level guidance.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source
  and the on-disk layout of an installed DOCA package. The
  collector's public guide URL is
  `https://docs.nvidia.com/doca/sdk/DOCA-Telemetry/index.html`
  (distinct from the publisher's guide at
  `https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Exporter/index.html`);
  the on-disk samples live under
  `/opt/mellanox/doca/samples/doca_telemetry/`. The DOCA
  Telemetry Service (DTS — the canonical aggregator on
  BlueField that a collector can attach to) is a separate
  service guide reachable through that same routing table.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, transport-side reachability checks,
  and the *I have no install yet* path with the public NGC
  DOCA container. This skill assumes its preconditions are
  satisfied (in particular, the collector user can bind /
  listen on whichever incoming transport the collector is
  configured for).
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule +
  detection chain and adds the collector-specific overlay
  rules (the schema-version contract with the publisher
  matters across upgrades).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect /
  prefer / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library:
  the canonical `pkg-config` + meson build pattern, the
  universal modify-a-shipped-sample first-app workflow, the
  universal lifecycle, the cross-library `DOCA_ERROR_*`
  taxonomy, and the program-side debug order. This skill
  layers collector specifics on top.
- `doca-log` — the right primitive
  when the user actually wanted plain structured stdout
  logging from their own program rather than a structured
  event-consumption surface. The collector's schema-aware
  discipline is overhead the user does not need for plain
  logs; this skill's path-selection rule routes there when
  log shipping is the actual requirement.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-
  cutting debug ladder (install / version / build / link /
  runtime / program / driver). Collector-specific debug
  (publisher not up, schema mismatch, transport endpoint
  locked down, consumer queue full) overlays on top of that
  ladder.
