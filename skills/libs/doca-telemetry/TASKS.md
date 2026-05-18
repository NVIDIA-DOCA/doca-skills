# DOCA Telemetry collector workflows

**Where to start:** The verbs run `configure → build → modify →
run → test → debug`. Skip ahead only when the user is already
past a verb. The `## test` verb is an iterative loop (smoke
collector alone → smoke collector + one publisher → schema
contract check → multi-event smoke → under-load drain behavior →
loop back if the publisher staging or the schema changes), not
a one-shot pass — see the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the collector capability surface, the
collector-vs-exporter role split, the object family, the
schema-must-match contract with the publisher, the capability-
query rule, the error taxonomy (including the `AGAIN`-means-
consumer-queue-full rule and the `NOT_FOUND`-means-no-publisher-
registered-this-schema rule), observability, and safety policy,
see [CAPABILITIES.md](CAPABILITIES.md). For where to find docs,
the installed DOCA layout, or release notes, route through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through
the steps in order, verifying preconditions before recommending
the next call.

## configure

Goal: stand up a `doca_telemetry` collector context inside the
user's application, with at least one incoming transport
configured and the schema-must-match contract with the
publisher made explicit, before any event is consumed.

Steps the agent should walk the user through:

1. **Confirm the role: this is the COLLECTOR (consume) side.**
   Before any code change, surface the collector-vs-exporter
   distinction per the role-split table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   `doca-telemetry` is what the user's application links to
   **receive / aggregate** telemetry events; the publishing
   side is
   [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md),
   a separate sibling library. An agent that walks the user
   toward the exporter skill when they wanted to consume is
   wrong; an agent that recommends linking this collector when
   the user actually wanted to publish is wrong. State the
   role first, before any `pkg-config` mention or any code
   sketch.
2. **Verify the transport endpoint is bindable.** Walk the
   permission + staging matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
   (a) the collector runs as a user that can bind / listen on
   whichever incoming transport the collector is configured
   for (local socket permissions, TCP / UDP port range,
   on-host telemetry agent socket ownership); (b) sudo is NOT
   required across the board — it is only required for sub-
   1024 port binding or for specific endpoint-ownership cases;
   (c) the user knows independently how to confirm the
   endpoint is reachable from the publisher side. If the
   endpoint is locked down, route to
   [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure)
   or to re-pointing the collector at an endpoint its user
   CAN bind.
3. **Confirm the installed DOCA version and run capability
   discovery.** Use the procedure in
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
   Quote the version observed (`pkg-config --modversion
   doca-telemetry`, then `doca_caps --version`); do not
   assume "latest". Then run the matching
   `doca_telemetry_*_cap_*` queries (which incoming transports
   are supported, max in-flight events, sampling policy,
   supported schema versions) — per the capability-query rule
   in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the queried value is the runtime authority, not the
   agent's memory. Quote the values back to the user.
4. **Make the schema-must-match contract with the publisher
   explicit.** Per the schema-contract table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the collector consumes against the schema the publisher
   registered. Establish with the user: which publisher
   application(s) will feed this collector; what schema
   name(s), schema version, and per-field type set the
   publisher registers; how the collector will discover those
   via the schema-query family AFTER the publisher starts
   emitting. A collector configured against an assumed schema
   that the publisher does not actually register is the
   silent-failure case the agent must prevent here, not at
   debug time.
5. **Configure the collector's incoming transport.** Pick the
   transport from the install's cap-queried set (per step 3),
   set the transport endpoint the publisher will write to,
   and size the consumer queue against the install's max in-
   flight cap. The agent should NOT default to one transport
   without asking — the right transport is workload-bound
   (local socket for same-host publisher / collector; NetFlow
   or IPFIX listener for network-shipped telemetry; attach to
   DTS as the canonical aggregator on BlueField).
6. **Confirm the collector is the right tool.** Walk the
   path-selection rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes):
   if the user really wanted to PUBLISH telemetry from their
   app, route to
   [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
   instead; if the user wanted plain stdout / structured-log
   shipping from their own program, use
   [`doca-log`](../doca-log/SKILL.md); if the source is a
   non-DOCA program, use a Prometheus client library or
   OpenTelemetry collector directly. Picking the collector
   *for* the user when the path-selection rule rules it out
   is a wrong answer regardless of how cleanly the rest of
   the configure step goes.
7. **Start the collector context.** `doca_ctx_start()` on
   the collector; per the universal lifecycle in
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure),
   nothing consumes cleanly until the context is in
   `RUNNING`. If start fails, route through the error
   taxonomy in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   before retrying.

If any step fails with a `DOCA_ERROR_*`, route through the
error taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying. In particular, `DOCA_ERROR_NOT_FOUND` on a
schema query is *not* a configure-time bug — it is the
canonical *"no publisher has registered this schema yet"*
signal and routes to the publisher-up staging in
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).

## build

Goal: produce a collector binary that links DOCA Telemetry
against the user's installed DOCA, using the canonical cross-
library build pattern.

The build pattern for any DOCA C/C++ consumer is **identical**
across libraries — `pkg-config` for include + link flags, meson
or CMake as the build system — and is fully documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the collector-specific overlay:

| Slot | Value for the collector | Why it matters |
| --- | --- | --- |
| `pkg-config` module name | `doca-telemetry` | The collector's `.pc` file installed by the DOCA host packages. **Wrong module name = wrong direction** — `doca-telemetry-exporter` is the SIBLING publisher library, with its own `.pc` and its own skill at [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md). Picking `doca-telemetry-exporter` when the user wanted to consume (or `doca-telemetry` when the user wanted to publish) is the load-bearing first-app failure, NOT a typo — re-check the role per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) |
| Include flags | `pkg-config --cflags doca-telemetry` | Resolves to collector headers under `/opt/mellanox/doca/infrastructure/include/` for the collector subset |
| Link flags | `pkg-config --libs doca-telemetry` | Pulls in `-ldoca-telemetry -ldoca-common` plus the transitive set the resolver computes against this install |
| Header check | A collector header (per the install's layout) resolvable under `/opt/mellanox/doca/infrastructure/include/` on the host | If `pkg-config --cflags doca-telemetry` resolves but the include is missing, the install is partial — route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| Minimum required DOCA version | Query with `pkg-config --modversion doca-telemetry`; never hardcode in build files | Cross-version build / runtime mixing breaks per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility); the schema-must-match contract with the publisher across versions is the extra trap to surface |

For non-C consumers (Rust, Go, Python), the link surface is
the same `*.so` files; the FFI wrapper layer is the language-
specific binding and is out of scope for this skill — but the
slots above are still the load-bearing inputs the wrapper
needs.

## modify

Goal: take a shipped DOCA Telemetry collector sample as the
verified starting point and apply a **minimum-diff
modification** to express the user's intent.

The universal modify-a-shipped-sample workflow lives in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify).
Use it as-is. The collector-specific overlay is the *modify-
from-sample contract fill* — the slots the agent must elicit
from the user before recommending any code-level edit:

| Slot | What the agent asks the user | Collector-specific consideration |
| --- | --- | --- |
| 1. Starting sample | Which sample under `/opt/mellanox/doca/samples/doca_telemetry/`? | Pick the closest in *transport* (local socket / NetFlow / IPFIX / DTS attachment) and *consumption pattern* (single-schema drain vs multi-schema dispatch) to the user's intent. A smaller diff is always safer than a re-architecture |
| 2. Publisher identity | Which application(s) are the publishers feeding this collector? Are they linking [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md) directly, or is the source the DOCA Telemetry Service (DTS)? | The schema-must-match contract per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) depends on knowing the publisher; a collector modified against a publisher the user did not actually name is the canonical *"silent schema mismatch"* trap |
| 3. Schema set the publisher registers | What schema name(s), schema version, and per-field type set does the publisher register? | Re-validate against `doca_telemetry_*_cap_*` per [`## configure`](#configure) step 3; a schema set that works against one install may exceed `max in-flight events` or use a `schema version` the collector's install does not understand |
| 4. Drain-loop behavior on `AGAIN` | What does the modified collector do when a consume returns `DOCA_ERROR_AGAIN`? | Per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) consumer-queue rule, the policy is the collector's to make: drain faster (widen the loop, dispatch to a worker pool), increase the queue cap if the install allows, or accept bounded loss. Asking the publisher to slow down is a non-default cross-process choice; if the sample's existing drain loop silently absorbs `AGAIN` without surfacing the loss count, that is a sample gap that needs to be edited out before the modify lands |
| 5. Publisher staging assumption | Does the modified collector assume the publisher is up first, or does it tolerate the publisher starting later? | Per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) staging row, either is fine in steady state — but a collector that treats the first `DOCA_ERROR_NOT_FOUND` on schema query as a fatal error will fail in the "publisher starts later" case. Decide explicitly which behavior the modified collector wants |
| 6. Build manifest | Keep the sample's existing `meson.build` (which already wires `pkg-config doca-telemetry`)? | Yes. Do not switch to a hand-rolled Makefile for *"simplicity"* — it removes the version-check rail. And do not silently swap the `pkg-config` module to `doca-telemetry-exporter` — that flips the role and is the load-bearing first-app failure |

The agent emits an *intent description + the filled slots*;
the *actual* unified diff against the sample source is
produced by the modify-from-sample renderer (deferred to a
future round, per
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify)).
Until the renderer ships, the agent must walk the user through
the diff line-by-line against the sample source they read on
disk, and have the user paste back the result for validation.

## run

Goal: actually execute the built collector against the user's
installed DOCA, with the transport endpoint bindable, the
schema-must-match contract with the publisher honored, and a
publisher available for the end-to-end smoke.

Steps the agent should walk the user through:

1. **Bind the transport endpoint cleanly.** The collector's
   first start either succeeds in binding the configured
   transport endpoint or returns `DOCA_ERROR_NOT_PERMITTED`.
   Per the permission row in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   `NOT_PERMITTED` is almost always the specific endpoint
   (socket owner, port range, agent socket) — fix on the
   env / endpoint side, not by adding `sudo` globally.
2. **Run the collector as a user that can bind the endpoint
   (typically NOT sudo as a universal rule).** Per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   sudo is required only for sub-1024 port binding or
   specific endpoint-ownership cases. Resist the reflex to
   add `sudo` to the collector process; re-point the
   collector at an endpoint its user CAN bind instead.
3. **Start a publisher and confirm one event arrives.**
   Before any bulk-traffic run, start ONE publisher (a
   [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)-using
   application, or DTS as the canonical aggregator on
   BlueField) and have it emit ONE event with the schema the
   collector is expecting. Confirm the collector's consume
   loop yields exactly that one event with the field values
   the publisher emitted intact. Skipping this step is the
   most common reason *"the collector runs without errors
   but never sees anything"* (the silent schema-mismatch
   trap from [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)).
4. **Capture the structured log.** Set `DOCA_LOG_LEVEL=trace`
   for the first run (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability)).
   This is the cheapest way to make the collector lifecycle
   transitions, the schema discovery, and the per-consume
   calls visible on first failure.
5. **Watch for `DOCA_ERROR_AGAIN` only when bulk traffic
   starts.** `AGAIN` shows up under transport load on the
   consume call, not at the first consume. When it appears,
   the collector application's correct response is per the
   policy decided in
   [`## modify`](#modify) slot 4 (drain faster / widen queue
   / accept bounded loss) — not a blind retry. See
   [`## debug`](#debug) layer 6 for the per-consume pattern.

## test

Goal: prove the configured collector context can actually
receive structured telemetry from a publisher, end-to-end,
before claiming the *"build a first telemetry-collecting
app"* journey is done.

This is **a loop, not a one-shot pass.** Each iteration
narrows either the transport endpoint, the schema contract
with the publisher, the consumer-queue back-pressure
behavior, or the publisher's staging. The loop terminates
when either (a) the user's intended ingest rate runs end-to-
end with the expected events arriving at the collector, the
schema decoded correctly, and the under-load behavior matches
the policy decided in [`## modify`](#modify) slot 4, or (b)
the agent has narrowed the failure cause to a layer outside
the collector itself (publisher / transport / driver) and
escalated to the matching skill.

Iteration shape:

1. **Collector-alone smoke.** Start the collector with no
   publisher attached; confirm `doca_ctx_start()` succeeds
   and that the schema-query family returns
   `DOCA_ERROR_NOT_FOUND` (the expected *"no publisher
   yet"* signal per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)),
   not `BAD_STATE` or `NOT_PERMITTED`. Validates the
   collector's lifecycle and the transport-endpoint
   permission BEFORE pulling the publisher into the picture.
2. **Capability re-check.** Re-run the
   `doca_telemetry_*_cap_*` queries. If the proposed
   transport / max in-flight / schema version exceeds a
   queried cap, that *is* the answer for this install;
   update the configuration (or update the install) before
   adding publishers.
3. **Single-event publisher + collector smoke.** Start ONE
   publisher (a [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)-using
   application, or DTS) registering the exact schema the
   collector is expecting; have it emit ONE event; confirm
   the collector receives exactly that event with the field
   values intact. If the smoke says the publisher emitted
   but the collector saw nothing, the schema-must-match
   contract per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   is the prime suspect, not the collector call.
4. **Schema-contract pass.** Confirm explicitly that the
   schema name, schema version, and per-field type set the
   publisher registered match what the collector discovers
   via the schema-query family. A mismatch is the silent-
   loss trap; the canonical *"events appear to flow on the
   publisher side but the collector sees nonsense or
   nothing"* failure.
5. **Multi-event smoke.** Loop a small N (say, 100) emits
   on the publisher with the collector draining
   concurrently; confirm the collector's count matches the
   publisher's count and every event decodes correctly.
   Catches lost events that the per-consume return alone
   would not surface.
6. **Under-load `AGAIN` behavior.** Push the publisher's
   emit rate up until the collector's consume queue
   saturates and the consume call starts returning
   `DOCA_ERROR_AGAIN`. The collector MUST behave per the
   policy decided in [`## modify`](#modify) slot 4 (drain
   faster / widen queue / accept bounded loss) — confirm
   the policy's behavior matches expectations. Remember the
   publisher may simply drop on its own `AGAIN` per
   [`doca-telemetry-exporter CAPABILITIES.md ## Safety policy`](../doca-telemetry-exporter/CAPABILITIES.md#safety-policy);
   the under-load loss is a two-sided concern.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| `DOCA_ERROR_NOT_PERMITTED` on collector start | Transport endpoint permission wrong (socket owner, port range, agent socket), OR user is trying to run with sudo unnecessarily | Re-walk the permission row in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy); fix on the env / endpoint side or re-point the collector at a bindable endpoint, not by adding global sudo |
| `DOCA_ERROR_NOT_FOUND` on schema query AFTER a publisher is up | Schema name / version the collector queried does not match what the publisher actually registered | Walk the schema-must-match contract in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes); align the publisher's registered schema with what the collector queries before re-running |
| Publisher emits return success but collector sees nothing | Transport mismatch (publisher writing to one endpoint, collector listening on another), OR schema mismatch (collector expecting a different schema name / version) | Re-walk the transport configuration in [`## configure`](#configure) step 5 AND the schema contract in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes); confirm both sides independently before suspecting the collector |
| `DOCA_ERROR_AGAIN` appears under bulk load | Consumer queue saturated — events arrive faster than the collector drains | This is by design — the collector applies its decided drain-faster / widen-queue / accept-loss policy. If the loss rate is unacceptable, decide whether to widen the collector (drain workers) or ask the publisher to slow down (cross-process policy, not a default) |
| Same code receives on host A, drops on host B | Different DOCA version (schema version drift across upgrades), different transport endpoint permission, or different publisher running | Re-narrow to the per-host state; the collector's behavior is the same on both, the variance is at the version / endpoint / publisher layer |

Loop termination: stop iterating once two consecutive
iterations of the same kind don't change anything — that means
the cause is below the collector (transport, publisher,
driver). Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured layer-1-through-5 evidence and both the
publisher-side and collector-side log state.

## debug

Goal: when a DOCA Telemetry collector call returns a
`DOCA_ERROR_*` (or events do not show up at the collector),
narrow the cause to a specific layer and act on it.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
Walk through it in order — install → version → build → link →
runtime → program → driver — *before* recommending collector-
specific fixes. This skill's overlay names the collector-
specific manifestation at layers 5 (runtime) and 6 (program):

**Layer 5 (runtime) — collector overlay.**

- Walk the role rule: did the user actually want the
  collector (consumer) and not the publisher? If the user is
  reading guides about emitting events, the answer is to
  route them to
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
  via the role-split table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
  not to debug the collector further.
- Walk the publisher-up question: is a publisher actually
  registering the schema the collector is querying? A
  `DOCA_ERROR_NOT_FOUND` on schema query against a collector
  with no publisher attached is the expected staging signal;
  with a publisher attached, it is a schema-mismatch signal.
  Both routes are in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
- Walk the transport-endpoint permission state: the
  collector does NOT need sudo as a universal rule. A
  `DOCA_ERROR_NOT_PERMITTED` on start means the specific
  transport endpoint (socket owner, port range, agent
  socket) is wrong for the running user — fix the endpoint
  or re-point the collector; resist adding global `sudo`.

**Layer 6 (program) — collector overlay.**

- The schema-must-match trap: a consume that yields zero
  events while the publisher reports successful emits is the
  silent schema-mismatch failure — different schema name,
  different schema version, or different field-type set.
  Walk the schema-contract table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  with both sides on the table; the publisher's registered
  schema must match what the collector is querying.
- Lifecycle order: configure (set transport, schema-query
  surface ready) → start → consume → stop → destroy. Out-of-
  order returns `DOCA_ERROR_BAD_STATE`. The most common case
  is calling consume before the collector context reached
  `RUNNING`.
- Consumer-queue back-pressure policy: a drain loop that
  silently absorbs `DOCA_ERROR_AGAIN` and never accounts for
  the dropped events is a sample gap, not a library bug. The
  fix is at the drain loop in the collector application:
  surface the loss count, decide drain-faster vs widen-queue
  vs accept-loss, and remember the publisher may simply drop
  on its own `AGAIN` per
  [`doca-telemetry-exporter CAPABILITIES.md ## Safety policy`](../doca-telemetry-exporter/CAPABILITIES.md#safety-policy).
- Value-vs-schema mismatch: a `DOCA_ERROR_INVALID_VALUE` on
  consume is a type mismatch against the discovered schema,
  a buffer smaller than the install's max-event-size cap, or
  an oversized event from a misbehaving publisher. Re-read
  the schema-query result against the matching
  `doca_telemetry_*_cap_*` caps; the fix is at the consume
  call (or at the publisher, if the event itself is
  oversized) — not by widening the cap (it is install-bound).

Once the layer is identified, route to the matching debug
verb on the matching skill: install / build / link / driver
to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug);
version to [`doca-version ## debug`](../../doca-version/TASKS.md#debug);
cross-cutting runtime to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug);
program-layer Core-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug);
publisher-side concerns to
[`doca-telemetry-exporter ## debug`](../doca-telemetry-exporter/TASKS.md#debug).

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them as
follows so the agent does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-
  install verification, `pkg-config` wiring — defer to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the
  install-tree layout in
  [doca-public-knowledge-map ## Layout of an installed DOCA package](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed.
- **publish telemetry.** Wiring up the application-side
  publishing of telemetry events — out of scope for this
  skill. Route to
  [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md)
  for the sibling publisher library. This skill is consumer-
  side only.
- **operate the DOCA Telemetry Service (DTS) itself.** DTS
  is a separate DOCA service with its own public guide;
  reach it via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  This skill **uses** DTS as one of the aggregators a
  collector can attach to, but does not re-document
  operating the service.
- **deploy.** Deploying telemetry-collecting applications at
  scale across many hosts, Kubernetes operator workflows
  with collector sidecars — out of scope for Phase 1 and
  reserved for a future platform skill.
- **firmware burn / reset.** The collector does not depend
  on firmware-layer state directly; if the debug ladder
  lands on a driver-layer issue (`DOCA_ERROR_IO_FAILED`
  from a collector call), the fix is via the env-side
  skill: [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
  layer 5, then upstream documentation reachable through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Command appendix

Every command below is **cross-cutting on DOCA Telemetry
(collection)** — it answers a recurring class of question that
comes up in the verbs above. The agent should treat the
*class* as load-bearing; the worked example is a single
instance. Run-as user is the collector application's normal
unprivileged user unless noted; sudo is called out per row
(and is rarely needed for the collector itself as a universal
rule, per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
— it is required only for sub-1024 port binding or specific
endpoint-ownership cases).

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST
   (`doca-env --json` for version + devices + libraries +
   drivers + hugepages in one shot; `doca-capability-snapshot`
   for per-device capability flags; `version-matrix.json` for
   *"available since"* lookups).
2. If the probe succeeds, the structured tool's output is
   the authoritative answer and the agent SHOULD NOT also
   run the manual command in the row below. Report *"using
   structured `<tool>`"*.
3. If the probe fails, fall back to the manual command in
   the row. Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Command (worked example) | Owning step | Class of question it answers | What healthy output looks like |
| --- | --- | --- | --- |
| `pkg-config --modversion doca-telemetry` | `## configure` step 3; `## build` slot 1 | What is the build-time DOCA Telemetry (collector) version? | A semver string matching `doca_caps --version`. Disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2). If the command returns *"Package 'doca-telemetry' was not found"* and the user actually wanted the publisher, route to [`doca-telemetry-exporter`](../doca-telemetry-exporter/SKILL.md) — wrong direction is the load-bearing first-app failure, not a typo |
| `pkg-config --cflags --libs doca-telemetry` | `## build` | What include + link flags does the linker need? | Includes resolve under `/opt/mellanox/doca/infrastructure/include/`; libs include `-ldoca-telemetry -ldoca-common` |
| `ls /opt/mellanox/doca/samples/doca_telemetry/` | `## modify` slot 1 | Which collector samples ship in this install, and which is the closest starting point? | A list of sample directories named after the transport / consumption pattern they demonstrate |
| `doca_caps --version` | `## configure` step 3; `## test` step 2 | What is the *runtime* DOCA version? | A semver string matching `pkg-config --modversion doca-telemetry` |
| `id` | `## configure` step 2; `## run` step 2 | Is the collector user the one the configured transport endpoint expects to allow? | The user's id matches what owns / can write the transport endpoint (socket owner; permitted port range; agent-socket owner). Mismatch = `DOCA_ERROR_NOT_PERMITTED` on first start — fix on the env / endpoint side, not by adding global sudo |
| `cat /opt/mellanox/doca/applications/VERSION` | `## configure` step 3; `## debug` layer 1 | What does the install tree itself claim its version is? | A semver string matching the other two version sources |
| `dmesg \| tail -n 40` (sudo) | `## debug` layer 7 | What did the kernel / driver log around the last collector call? | Empty or recent benign messages. Repeated mlx5 / network / socket errors → driver / env-layer bug; route to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) |
| `DOCA_LOG_LEVEL=trace ./<binary>` | `## run` step 4 | What did the structured DOCA logger emit for the first failing consume? | A trace-level line on every lifecycle transition, every schema-query call, and every consume. Per-consume `AGAIN` traces under load = consumer queue full — apply the policy decided in [`## modify`](#modify) slot 4, not a blind retry |

For commands shared across libraries (`pkg-config
--modversion`, `doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the collector-specific rows on top.
