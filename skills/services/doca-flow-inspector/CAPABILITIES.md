# DOCA Flow Inspector Service — Capabilities

**Where to start:** The pattern overview below names the recurring
Flow Inspector-class operational patterns. Pick the pattern first,
then drill into the H2 that owns the substance. For the *how* of
executing each pattern, jump to [TASKS.md](TASKS.md).

This file enumerates the Flow Inspector Service's documented
capabilities, deployment shape, inspection-depth surface, output
destinations, and operational behaviors as described in the
public DOCA Flow Inspector Service guide on `docs.nvidia.com`.
Treat it as a *map of what is documented*, not a substitute for
reading the live page when configuring a real deployment.

## Pattern overview

Every Flow Inspector-class question this skill teaches resolves
into one of FIVE patterns. The patterns are CLASSES — they apply
across every doca-flow / doca-flow-ct pipeline an operator might
want to debug, not just one specific pipe spec.

| Flow Inspector pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Confirm the user's pipeline is set up to MIRROR to the inspector | The inspector consumes mirrored traffic; it does NOT capture unmirrored traffic on its own. Every workflow starts by verifying the mirror action exists in the user's doca-flow / doca-flow-ct pipeline | [`## Capabilities and modes`](#capabilities-and-modes) mirror-action contract |
| 2. Pick the deployment shape | Long-running container on BlueField Arm, per the Container Deployment Guide pattern. The inspector consumes traffic locally; it is not a host-side tool | [`## Capabilities and modes`](#capabilities-and-modes) deployment shape |
| 3. Pick the inspection depth | Per-packet metadata vs per-flow aggregate vs raw packet-content sampling — three different debug questions, three different output shapes | [`## Capabilities and modes`](#capabilities-and-modes) inspection-depth table |
| 4. Pick the output destination | Inspector CLI for interactive debug; JSON export for offline / scripted analysis; downstream consumer (e.g. DTS) when long-term retention is wanted | [`## Capabilities and modes`](#capabilities-and-modes) output-destination table |
| 5. Map a *"no traffic visible"* symptom back to its layer | Container not running vs mirror not wired in the pipeline vs inspection depth wrong vs mirror rate too high (samples dropped) | [`## Error taxonomy`](#error-taxonomy) layer split |

Two cross-cutting rules that apply to *every* pattern above:

- **The inspector does not capture unmirrored traffic, ever.**
  The most common first-app failure is *"container is up, no
  traffic appears"* — the cause is almost always that the user's
  doca-flow / doca-flow-ct pipeline does not have a mirror
  action wired to the inspector target. The agent's first
  diagnostic move on this symptom must be *"show me the mirror
  action in your pipeline spec"*, NOT *"let me check the
  inspector config"*.
- **Mirror is a debug-time tool, not steady-state.** Every
  mirrored packet costs cycles on the device; leaving the mirror
  wired in production silently degrades dataplane throughput.
  The agent's job after a debug session is to remind the user to
  remove the mirror, or — if the user genuinely needs continuous
  visibility — to route them to DTS instead of leaving Flow
  Inspector hot in production.

## Capabilities and modes

### Architecture

DOCA Flow Inspector Service is a **long-running container /
daemon** that runs on BlueField and consumes traffic that another
DOCA Flow program has explicitly mirrored to it. Three things
follow from that:

- The inspector is **service-shaped**, not library-shaped. The
  user does not link against a `libdoca_flow_inspector.so`; they
  deploy the container and observe its output.
- The inspector is **passive on the data plane**. It does not
  insert itself into the user's doca-flow pipeline; it does not
  rewrite the pipe; it does not see traffic the pipeline has not
  been programmed to mirror to it.
- The inspector is **paired**. The contract between the user's
  doca-flow pipeline (with a mirror action) and the inspector
  (consuming the mirrored copy) is what makes the inspector
  meaningful. A pipeline without a mirror action + an inspector
  is a container running with nothing to watch.

### The mirror-action contract

This is the load-bearing capability of the entire skill. Read
it before anything else.

| Side | What it does | Where the substance lives |
| --- | --- | --- |
| User's doca-flow / doca-flow-ct pipeline | Programs a **mirror action** on the pipe(s) the user wants to inspect. The mirror action duplicates matching packets and forwards the copy to the Flow Inspector's documented ingest target. Without this step, the inspector sees nothing — regardless of how healthy the inspector container is | The mirror action is a doca-flow action kind documented in [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-flow/CAPABILITIES.md#capabilities-and-modes); the pipe-spec workflow lives in [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify) |
| Flow Inspector container | Consumes the mirrored copy and exposes it at the configured inspection depth on the configured output destination. Does NOT pull traffic the pipeline did not push to it | This skill's [`## Capabilities and modes`](#capabilities-and-modes) sections below and [`TASKS.md ## configure`](TASKS.md#configure) |

The agent's rule: when the user asks *"how do I set up Flow
Inspector?"*, the FIRST conceptual move is to surface the two-
sided contract. *"Yes — and step one is to add a mirror action
to your existing pipeline; without that, the inspector has
nothing to look at."* Skipping straight to the container deploy
walks the user into the most common failure mode.

### Inspection depths

The inspector exposes mirrored traffic at one of several
documented depths. Each depth answers a different debug question;
quote the live public guide for the exact depth names and field
sets per release.

| Depth | What the inspector exposes | When the agent should pick it |
| --- | --- | --- |
| Per-packet metadata | A record per mirrored packet: 5-tuple, ingress port, action taken by the pipe, sequence-style metadata as documented per release | *"Is the hardware even seeing this specific packet, and what does the pipe say it did with it?"* — the highest-resolution debug view, also the highest overhead |
| Per-flow aggregate | Counters / state rolled up per flow (e.g. per 5-tuple); fewer records, summary-shaped output | *"Is a class of flows reaching the pipe in the volume I expect?"* — useful when individual packets are too noisy, or when the user is debugging rate / volume rather than per-packet correctness |
| Raw packet content sampling | A sampled stream of the actual packet bytes the pipe saw (subset, per documented sampling cadence) | *"Are the bytes on the wire what I think they are?"* — used when the user suspects encapsulation / parsing bugs in upstream code rather than in the pipe spec; highest overhead and the only depth that touches actual payload, so it carries the strongest privacy posture from [`## Safety policy`](#safety-policy) |

The depth choice is a debug-question choice. The agent must not
default a user to per-packet *"because it's most detailed"*; if
the user's question is per-flow, per-packet wastes cycles AND
buries the answer in noise. Walk the choice deliberately.

### Output destinations

The inspector can expose its observation to one of several
documented destinations. The destination choice is independent
of the inspection depth; pick both.

| Destination | When to pick it | Cross-link |
| --- | --- | --- |
| Inspector CLI | Interactive debug — a human is actively reading the output to test a hypothesis. The "live debug session" default | The inspector's own CLI surface, per the public guide |
| JSON export | Scripted or offline analysis — pipe the inspector output into a separate tool or script that the user wants to write | The public Flow Inspector guide for the documented export format |
| Downstream consumer (e.g. DTS) | The user wants the inspector's signal to land in a longer-term store. This is NOT a substitute for steady-state telemetry — see [`## Safety policy`](#safety-policy); for steady-state monitoring, route to DTS *directly* instead of going through the inspector | [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services) for the DTS entry |

The agent's rule: if the user wants the destination to be *"DTS,
permanently"* and the use case is monitoring rather than debug,
the right answer is *"point your monitoring at DTS directly; do
not stand the inspector up as a permanent forwarder"* — see
[`## Safety policy`](#safety-policy) mirror-overhead rule.

## Deployment shape

The public guide documents one canonical deployment shape:

- **Container on BlueField Arm.** The inspector runs as a long-
  running container on the BlueField Arm cores using the canonical
  DOCA Container Deployment Guide pattern (the public guide
  documents the exact image source on NGC, the container launch
  command, and the runtime privileges required — quote from the
  live page, do not invent). The container observes mirrored
  traffic from doca-flow pipelines running on the same BlueField.

The agent's rule: the inspector consumes traffic *locally* on the
BlueField. There is no documented host-side deployment shape and
no documented *"inspect a remote BlueField's pipeline from a
different host"* pattern. If the user asks about either, surface
that the documented shape is BlueField-local and route the user
back to the live public guide before promising any alternative.

### Path selection — Flow Inspector vs other observability

Flow Inspector is one entry in DOCA's broader observability
surface. Before quoting any inspector flag, the agent should
confirm Flow Inspector is the right artifact for the user's
question at all.

| User intent | Right artifact | Why this skill is / isn't it |
| --- | --- | --- |
| Debug a doca-flow / doca-flow-ct pipeline that is NOT behaving as the user expects, at the hardware level (counters are too coarse; reading the pipe spec is not enough) | Flow Inspector (this skill) on top of doca-flow / doca-flow-ct | This is the use case Flow Inspector exists for: see what the steering plane is *actually* doing to the traffic the user mirrors into it |
| Capture host-visible packets on a representor for a quick sanity check | `tcpdump` (or `tshark`) on the representor | When the question is just *"did the packet leave / arrive on this representor"*, `tcpdump` is faster, cheaper, and adds zero on-device overhead. Flow Inspector is for HARDWARE-LEVEL inspection beyond what `tcpdump` can show; do not pull it in for a host-side packet sanity check |
| Read pipe counters / pipe statistics in the user's program | [`doca-flow ## debug`](../../libs/doca-flow/TASKS.md#debug) counters-first workflow | Per-pipe / per-entry counters are documented as the *first* debug move for any *"my pipe isn't doing what I think"* symptom; reach for them before standing the inspector up. If the counter for the suspected entry is zero, the spec is wrong and the inspector won't change that diagnosis |
| Imperative-only flow programming with `DOCA_LOG_*` for diagnostics | [`doca-debug`](../../doca-debug/SKILL.md) + the structured DOCA logger | If the program-side logger plus pipe counters answer the question, the inspector is unnecessary overhead. The inspector is for symptoms that survive the cheaper observability already in place |
| Steady-state production telemetry on dataplane behaviour | DOCA Telemetry Service (DTS), via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services) | Flow Inspector is a **debug tool**, not a telemetry tool. Every mirrored packet costs cycles; running it permanently silently degrades production. DTS is the documented surface for long-term retention; route there for the steady-state question |

When the user has not yet read pipe counters and is asking about
the inspector, the right first move is to walk them through
[`doca-flow TASKS.md ## debug`](../../libs/doca-flow/TASKS.md#debug)
counters-first — not to stand up the inspector container.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-
docs rule, see [`doca-version`](../../doca-version/SKILL.md).
The body lives there; this skill does not duplicate it.

**The Flow Inspector-specific overlay** is:

- **The inspector container tag is paired with the doca-flow /
  doca-flow-ct version that programmed the mirror.** The
  inspector interprets the mirror metadata using the same
  on-the-wire shape the pipeline emitted; if the inspector
  container and the doca-flow that programmed the mirror are at
  different DOCA releases, the inspector may quietly mis-decode
  the metadata even when traffic does reach it. The agent must
  cross-check `pkg-config --modversion doca-flow` (the build /
  runtime of the user's pipeline) AND `pkg-config --modversion
  doca-flow-ct` (when CT is wrapping the pipe) AND the
  inspector container tag pulled from NGC, AND surface any
  divergence per the four-way match rule owned by
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
- **The inspector's inspection-depth surface and per-depth field
  set can evolve between DOCA releases.** Quote the per-depth
  field names and the documented sampling cadence from the live
  public DOCA Flow Inspector Service guide page whose version
  corresponds to the DOCA release installed on the BlueField;
  do not infer them from older releases. Route through
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
  for the live guide URL.
- **Container-tag-vs-host-package mismatch is the most common
  partial-install hazard for service-shaped DOCA artifacts.**
  When the user is using the inspector container, the relevant
  version anchor for the inspector itself is the container tag
  pulled, not the BlueField's `pkg-config --modversion`; confirm
  both and route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 if they diverge.

## Error taxonomy

Flow Inspector's outward surface is the container's behavior plus
the inspector CLI / JSON export — it does not return
`DOCA_ERROR_*` to a user-program caller (the user is not a
caller; the user is an operator). The agent should treat
inspector errors as a four-layer taxonomy when deciding what to
ask the user next:

1. **Container lifecycle layer.** The Flow Inspector container is
   not running, crashed at startup, or restart-looping. Symptoms:
   `docker ps` (or the user's container runtime equivalent) shows
   no inspector entry, OR shows it as Restarting / Exited.
   Resolution: read the container runtime's logs (`docker logs
   <name>`, `journalctl`, or whatever the host's runtime uses);
   confirm the image tag pulled matches the public NGC catalog
   entry routed via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
   confirm the documented runtime privileges per the public
   Container Deployment Guide are in place.
2. **Mirror-not-wired layer (the most common first-app failure).**
   The container is healthy but the inspector reports no traffic.
   Symptoms: inspector CLI is silent / JSON export is empty even
   under traffic the user is actively generating. Resolution: ask
   the user to *show the mirror action* in their doca-flow /
   doca-flow-ct pipeline spec. If there is no mirror action wired
   to the inspector target, the symptom is in the pipeline, not
   the inspector — route to
   [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify)
   to add the mirror. Do NOT debug the inspector's own config
   first; this layer is upstream.
3. **Inspection-depth-wrong layer.** Traffic is visible but does
   not answer the user's question — typically because the user
   picked per-packet when they wanted per-flow aggregate (output
   is overwhelming and the per-flow shape they wanted is buried),
   or vice versa (output is summary-shaped and the per-packet
   detail they wanted is rolled up). Resolution: re-walk the
   inspection-depth choice in [`## Capabilities and modes`](#capabilities-and-modes);
   restart the inspector at the right depth.
4. **Sampling / overload layer.** The pipeline's mirror rate
   exceeds what the inspector (or the device) can sustain at the
   chosen inspection depth, so samples are silently dropped.
   Symptoms: the inspector shows traffic but the volume is much
   lower than the user expects, OR the device starts reporting
   performance regression that began when the mirror was wired.
   Resolution: lower the mirror rate (rate-limit the mirror
   action on the pipeline side), OR drop to a lighter inspection
   depth (per-flow aggregate instead of per-packet), OR — if the
   user only needs a short snapshot — narrow the mirror's match
   criteria so only the traffic of interest is mirrored.

The agent's rule: **never recommend re-deploying the container
without first eliminating layer 2** (mirror not wired). The
inspector container is a stable, documented artifact; tearing it
down and re-deploying does not fix a missing mirror action in the
user's pipeline.

## Observability

Documented observability surfaces for Flow Inspector itself
(separate from the observability of the user's pipeline, which
lives in the matching library skill):

- **Inspector CLI live view.** The interactive view of mirrored
  traffic at the configured inspection depth. This is the
  *primary* observability surface during a debug session; reach
  for it before any export or downstream consumer.
- **JSON export.** Per the public guide, the inspector can emit
  its observation in a documented JSON shape for offline /
  scripted analysis. The exact schema is documented per release;
  quote from the live page rather than paraphrasing.
- **Container runtime logs.** The inspector container's own
  logs (via `docker logs <name>`, `journalctl`, or the BlueField
  host's container-runtime equivalent) tell the agent whether
  the container is healthy. These are container-side; they do
  NOT describe mirrored traffic.
- **The user's doca-flow pipeline counters.** Per-pipe / per-
  entry counters on the mirror-action entry in the user's
  pipeline tell the agent whether the mirror is actually firing.
  This is a doca-flow surface, not a Flow Inspector surface, and
  it lives in
  [`doca-flow CAPABILITIES.md ## Observability`](../../libs/doca-flow/CAPABILITIES.md#observability).
  When the inspector reports no traffic, the mirror-action's
  per-entry counter is the cross-check that disambiguates
  layer 2 (mirror not wired) from layer 1 (container not
  running).

For cross-cutting observability primitives (`--sdk-log-level`,
the `DOCA_LOG_LEVEL` env var, the trace build flavor that the
*pipeline* the user is debugging may be linked against), see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the broader picture on what counts as a *"reproducible
debug capture"* — Flow Inspector output is one of the pieces
that goes in — see
[`doca-debug TASKS.md ## test`](../../doca-debug/TASKS.md#test).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

Flow Inspector's safety surface is **mirror-overhead-driven**
and **payload-sensitive**. The documented posture:

- **Mirror is a debug tool, not steady-state.** Every mirrored
  packet costs cycles on the device that the doca-flow pipeline
  would otherwise spend on production work. The agent's rule:
  enable the mirror at the start of a debug session, disable it
  at the end. If the user genuinely needs continuous visibility,
  the right destination is the DOCA Telemetry Service (DTS) per
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services),
  not a permanently-wired Flow Inspector. The agent must not
  leave a session without reminding the user to remove the mirror
  action — silently leaving it wired is the load-bearing
  production-regression failure for this skill.
- **Mirror rate must be matched to the inspector's chosen
  inspection depth.** Per-packet metadata is the most expensive
  depth; high-rate mirror at per-packet depth will drop samples
  AND degrade dataplane throughput. The cap on what is sustainable
  per-depth is documented in the public guide; quote it. The
  agent's safe default for a first debug run is the *lowest*
  inspection depth that can still answer the user's question,
  not the *highest*.
- **Raw packet content sampling exposes payload bytes.** The
  raw-sampling inspection depth is the only depth that surfaces
  actual on-wire packet contents (the per-packet and per-flow
  depths surface metadata, not payload). Treat any artifact the
  user captures at raw depth as confidential by default: do not
  paste it into public forum posts without redaction, and do
  not export it to a destination the user has not explicitly
  authorized for payload data. This is the same posture as core
  dumps per
  [`doca-debug CAPABILITIES.md ## Safety policy`](../../doca-debug/CAPABILITIES.md#safety-policy).
- **The mirror action must be staged before bulk debug.** Per
  the safety policy in
  [`doca-flow CAPABILITIES.md ## Safety policy`](../../libs/doca-flow/CAPABILITIES.md#safety-policy),
  any change to a doca-flow pipe's action set must be validated
  before commit. Adding a mirror action is such a change. Stage
  the mirror on a controlled match (one known 5-tuple, one
  representor) and confirm via the inspector CLI that the
  expected packet appears in the expected shape *before*
  widening the mirror to bulk debug. Skipping this step
  produces *"the mirror is wired but I'm not sure if the
  inspector is interpreting it correctly"* — the canonical
  smoke-before-bulk failure mode for paired pipeline + inspector
  setups.
- **Container deployment follows the public Container
  Deployment Guide.** The runtime privileges, image source, and
  launch flags the inspector container requires are documented
  per release on the public Container Deployment Guide reachable
  via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
  Do not invent runtime flags; quote from the live page. The
  inspector is a privileged BlueField-side service — running it
  with looser privileges than the guide documents widens the
  exposure surface; running it with stricter privileges than the
  guide documents typically breaks ingest.

## Public-source pointer

The single canonical public source for DOCA Flow Inspector
Service is the
[DOCA Flow Inspector Service Guide](https://docs.nvidia.com/doca/sdk/DOCA-Flow-Inspector-Service-Guide/index.html)
on `docs.nvidia.com`, reachable through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
Verify that the version of the guide matches the DOCA install on
the BlueField — the inspector's inspection-depth surface and the
documented mirror-target ingest format are documented to evolve,
so per-depth field sets and per-release mirror semantics can
change between releases.

## Deferred topic boundaries

This skill scopes itself to **Flow Inspector as a debug-time
observability tool paired with doca-flow / doca-flow-ct**.
Adjacent topics the agent will get asked but should route
elsewhere:

- **Authoring the doca-flow / doca-flow-ct pipeline itself**
  (port bring-up, pipe spec, validate-before-commit, the
  mirror action's mechanics on the pipeline side). Owned by
  [`doca-flow`](../../libs/doca-flow/SKILL.md) and
  `doca-flow-ct`. This skill
  assumes a pipeline exists (or is about to) and prescribes how
  to wire it to the inspector; it does not redefine pipe-spec
  rules.
- **Steady-state production telemetry.** Out of scope here;
  Flow Inspector is debug-time only. Route to the DOCA Telemetry
  Service (DTS) via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
- **General DOCA cross-cutting debug** (install / version /
  build / link / runtime / program / driver). Owned by
  [`doca-debug`](../../doca-debug/SKILL.md). This skill is one
  entry in that ladder; it does not replace it.
- **Container-runtime troubleshooting itself** (Docker /
  container runtime install, image registry auth, host
  networking inside the runtime) — out of scope. Route to the
  Container Deployment Guide reached via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
  for the documented launch pattern; runtime-vendor questions
  themselves are upstream of this skill.
- **Cross-library `DOCA_ERROR_*` taxonomy.** Owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  The inspector itself does not return DOCA error codes to the
  user, but the doca-flow pipeline programming the mirror does;
  when those calls fail, escalate to the cross-library taxonomy
  there.
