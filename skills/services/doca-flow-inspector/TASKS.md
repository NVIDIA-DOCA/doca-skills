# DOCA Flow Inspector Service — Tasks

**Where to start:** The order is `configure → build → modify → run
→ test → debug`. The `## test` verb is an iterative loop, not a
one-shot pass — see the eval-loop overlay in `## test` below. For
Flow Inspector, `build` and `modify` are about *container
deployment adaptation + pipeline mirror-action wiring*, not about
compiling source.

These verbs cover the in-scope Flow Inspector operational
workflows for an external operator pairing the inspector with a
doca-flow / doca-flow-ct pipeline they want to debug. Every step
assumes the operator has consulted the live public
[DOCA Flow Inspector Service Guide](https://docs.nvidia.com/doca/sdk/DOCA-Flow-Inspector-Service-Guide/index.html)
on `docs.nvidia.com` and is using it as the authoritative
reference; this file prescribes the *order* and *what to look up
where*, not a copy-paste runbook.

## configure

Preparing the BlueField, the inspector container, and — critically
— the user's doca-flow / doca-flow-ct pipeline that will MIRROR
traffic to the inspector. The mirror-side wiring is part of
configure, not a follow-up — without it the inspector has nothing
to observe.

1. **Confirm the BlueField env is healthy first.** This skill
   expects DOCA to be installed on the BlueField. If that has not
   been verified, run [`doca-setup ## test`](../../doca-setup/TASKS.md#test)
   first. If the user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path on the host side and
   then bring up DOCA on the BlueField proper.
2. **Confirm the underlying doca-flow (or doca-flow-ct) pipeline
   is up and the user knows what they want to debug.** Per the
   mirror-action contract in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the inspector consumes mirrored traffic; the pipeline is the
   source. If the user's pipeline is not running, route to
   [`doca-flow ## configure`](../../libs/doca-flow/TASKS.md#configure)
   first. The user should arrive at this step with: a known
   doca-flow port handle; the specific pipe(s) they want to
   inspect; a concrete debug hypothesis (*"I expect packet X to
   match entry Y; it isn't, and I want to see why"*); and — if
   the pipeline is CT-aware — the CT context already started per
   `doca-flow-ct ## configure`.
3. **Identify the public guide page version and the container
   image source.** Read the public DOCA Flow Inspector Service
   guide page; cross-link the live NGC catalog entry for the
   container image via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
   Quote the image string from the live catalog — do NOT invent
   an `nvcr.io/...:latest` tag from memory.
4. **Pick the inspection depth that matches the user's debug
   question.** Walk the inspection-depth table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes):
   per-packet metadata for *"is the hardware seeing this exact
   packet"*; per-flow aggregate for *"is the volume / rate of a
   class of flows what I expect"*; raw packet content sampling
   only when the user suspects encapsulation / parsing bugs and
   has accepted the payload-exposure posture per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
   The lightest depth that still answers the question is the
   safe default.
5. **Stand up the single output destination — the downstream
   telemetry consumer.** The inspector has ONE output: the shipped
   binary links `doca-telemetry-exporter` and writes its records
   ONLY to the DOCA Telemetry IPC socket under
   `/opt/mellanox/doca/services/telemetry/ipc_sockets/`. There is
   no Inspector CLI and no standalone JSON export to "pick". To
   *see* the inspector's output, the user must run a paired
   downstream consumer that reads that socket — typically a
   `doca_telemetry_exporter` / DTS container on the same host (the
   canonical pairing is the K8s manifest at
   `doca/services/flow_inspector/internal/doca_telemetry_and_inspector.yaml`).
   Cross-link the output-destination table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
6. **Plan the mirror action the user will add to their doca-flow
   pipeline.** This is the load-bearing step. The agent must
   walk the user through: which pipe will carry the mirror
   action; which match criteria the mirror will key on (narrow
   first — *one* known 5-tuple under controlled traffic — per
   the smoke-before-bulk rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy));
   the inspector's documented mirror-target ingest (the contract
   between the mirror action and the inspector); and the per-
   entry counter the user will attach to the mirror entry so
   [`doca-flow ## debug`](../../libs/doca-flow/TASKS.md#debug)
   counters-first can answer *"is the mirror itself firing"*
   without depending on the inspector being healthy. The mirror
   action itself is a doca-flow modification; route to
   [`doca-flow ## modify`](../../libs/doca-flow/TASKS.md#modify)
   for the pipe-side workflow.

## build

Flow Inspector is a service distributed as a container. There is
no inspector-application artifact for the operator to build — the
inspector image ships from NGC and the user pulls it. The
operator's only build-shaped artifact is the **pipeline-side
change**: extending an existing doca-flow / doca-flow-ct program
to emit a mirror action targeting the inspector. That build is
fully owned by the matching library skill.

| Build target | Where it lives | What the agent does here |
| --- | --- | --- |
| The inspector container itself | NGC catalog, per [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services). No source build — pull the documented image | The agent quotes the image string from the live NGC page, NOT from memory; the agent surfaces that the container tag is paired with the BlueField's DOCA install per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) |
| The user's doca-flow / doca-flow-ct program (the source of the mirror action) | [`doca-flow ## build`](../../libs/doca-flow/TASKS.md#build) for the base pipeline; `doca-flow-ct ## build` when CT wraps it; the canonical `pkg-config` + meson pattern in [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build) | The agent does NOT author pipeline source code here; it cross-links the matching library skill and emphasizes that the mirror action is added via the universal modify-a-sample workflow there |
| A downstream telemetry consumer (reading the inspector's records off the DOCA Telemetry IPC socket) | Outside Flow Inspector scope — that consumer is a `doca_telemetry_exporter` / DTS container (or the user's own program reading the IPC socket), per the DOCA Telemetry documentation in [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services) | The agent does not write the consumer; it points at the canonical pairing manifest (`internal/doca_telemetry_and_inspector.yaml`) and the live DTS docs, and the rule "quote the live guide, don't infer the telemetry schema from prose" |

For non-C consumers asking about reading the inspector's output
in Rust / Go / Python / …, the same answer applies: the
inspector emits ONLY to the DOCA Telemetry IPC socket, so the
consumer reads that socket via the DOCA Telemetry path (typically
the downstream `doca_telemetry_exporter` / DTS container); the
consumer is the user's own program; this skill does not ship a
consumer in any language.

## modify

The Flow Inspector skill's *modify* surface is **two-sided**:

1. **Adapt the documented inspector container deploy recipe to
   the user's BlueField.** Start from the public Container
   Deployment Guide reachable via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
   Quote the documented launch command. Diff against the user's
   BlueField — interface naming, container runtime in use,
   privilege model, where the inspector will write its output.
   Change only what the user's environment forces. Per the
   safety policy in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   running the inspector with looser privileges than the guide
   documents widens exposure; running it with stricter
   privileges typically breaks ingest. Re-validate against the
   documented launch command after every substitution.
2. **Switch inspection depth or narrow / widen the pipeline's
   mirror match.** The depth choice (per-packet vs per-flow
   aggregate vs raw sampling) is the inspector-side modify. The
   mirror's match criteria (which packets the pipeline mirrors
   into the inspector at all) is the pipeline-side modify and
   belongs in
   [`doca-flow ## modify`](../../libs/doca-flow/TASKS.md#modify)
   (or
   `doca-flow-ct ## modify`
   when CT wraps the pipe). The two are independent levers on
   the same pipeline + inspector pair; the agent must surface
   both when the user reports *"my inspector is too noisy"* or
   *"too quiet"*.

A third modify the agent must teach proactively at the end of a
debug session:

3. **Disable the mirror for production once debug is done.** Per
   the mirror-overhead rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   the mirror costs cycles on every matching packet. After the
   debug hypothesis is resolved, walk the user through removing
   the mirror action from the pipeline (or — if the user wants
   the action kept but the mirror dormant — narrowing the
   mirror's match so it does not fire under production traffic).
   Confirm via the mirror-action's per-entry counter that the
   mirror is no longer firing under expected traffic. If the
   user genuinely needs continuous visibility into dataplane
   behaviour, route to DOCA Telemetry Service (DTS) via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
   do NOT leave the inspector hot in production as a substitute.

## run

Bringing the inspector container up, wiring the pipeline's
mirror, and exercising the pair end-to-end.

1. **Start the inspector container on the BlueField Arm side.**
   Use the documented launch command from the public Container
   Deployment Guide (quoted via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)),
   adapted per [`## modify`](#modify) step 1. Confirm with the
   user's container runtime that the inspector entry shows up as
   running.
2. **Confirm the inspector is healthy and its telemetry output
   path is wired** before adding the mirror on the pipeline side.
   Read the inspector container's logs (it should report startup
   and that it opened the DOCA Telemetry IPC socket) and confirm
   the paired downstream `doca_telemetry_exporter` / DTS consumer
   is up and reading that socket. A mirror added while the output
   path is broken produces a silent drop that looks like a
   pipeline bug; eliminate it now.
3. **Add the mirror action to the user's doca-flow / doca-flow-ct
   pipeline.** This is a doca-flow modify; route to
   [`doca-flow ## modify`](../../libs/doca-flow/TASKS.md#modify).
   Stage the mirror narrowly — one match, one representor — per
   the smoke-before-bulk rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy);
   attach a per-entry counter so
   [`doca-flow ## debug`](../../libs/doca-flow/TASKS.md#debug)
   counters-first can answer *"is the mirror firing"* without
   depending on the inspector being healthy.
4. **Send ONE known matching packet from the host.** Per the
   smoke discipline, generate a single controlled packet that
   matches the mirror action's match criteria and confirm:
   the doca-flow mirror-entry counter increments (proves the
   mirror fired); the downstream telemetry consumer shows ONE
   record with the metadata fields the user expects (proves the
   inspector received it and is interpreting it at the chosen
   depth). If either fails, jump to [`## debug`](#debug) before
   sending more traffic.
5. **Capture the structured log on first failure.** Set
   `DOCA_LOG_LEVEL=trace` on the program that drives the
   pipeline-side modify (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability));
   read the inspector container's runtime logs in parallel. If
   the program-side log says *"mirror entry added"* but the
   inspector shows nothing, the symptom is the network path
   between the pipe's mirror target and the inspector's ingest,
   not the API.

## test

Flow Inspector has no "compile and unit-test" workflow — testing
is operational and lives entirely in the pairing between the
user's pipeline and the inspector.

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation to either side (pipe spec, mirror match, mirror rate,
inspection depth, output destination, inspector container
restart) re-opens the smoke sweep. Skipping the re-run after a
mutation is the failure mode this loop replaces.

The eval-loop overlay (rows apply to every Flow Inspector
deployment, not just one topology):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | A passing single-packet smoke (step 1) followed by an empty bulk run (step 4) means the mirror is rate-limited / sampled at scale; loop back to step 1 with rate awareness | [`## test`](#test) step 4 |
| 1 → 2 → 1 | A passing single-packet smoke followed by a wrong-depth interpretation (step 2) means the inspection depth does not match the user's debug question; loop back via [`## modify`](#modify) step 2 | [`## modify`](#modify) |
| 3 → ## debug | When the version-pair smoke (step 3) shows divergence between the inspector container tag and the pipeline's doca-flow version, escalate immediately — interpretation may be silently wrong, do not run later steps | [`## debug`](#debug) |
| 1..4 → ## run | Each loop iteration ends with a documented smoke; if all four pass, hand off to live debug work in [`## run`](#run) | [`## run`](#run) |

The agent's rule: every mutation re-opens the sweep. A mirror
change followed by *"it probably still works"* is exactly the
failure mode the iterative loop is here to prevent.

1. **Single-packet smoke.** After
   [`## run`](#run) step 4, confirm that ONE known matching
   packet produces ONE record in the inspector with the metadata
   fields the user expects (5-tuple, ingress port, action taken
   by the pipe). The single-packet smoke is the cheapest place
   to identify mirror-not-wired bugs, inspection-depth mismatches,
   and version-pair issues before they show up at scale.
2. **Depth-shape smoke.** Confirm the inspector's output shape
   at the chosen inspection depth matches the user's debug
   question. Per-packet metadata MUST surface one record per
   mirrored packet; per-flow aggregate MUST surface roll-ups
   per flow; raw packet sampling MUST surface the documented
   sampled subset. If the shape is wrong, the depth choice from
   [`## configure`](#configure) step 4 was wrong — re-walk it
   via [`## modify`](#modify) step 2.
3. **Version-pair smoke.** Per the inspector-specific overlay
   in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   confirm the inspector container tag pulled, `pkg-config
   --modversion doca-flow` on the BlueField, and (when CT is in
   the picture) `pkg-config --modversion doca-flow-ct` all
   agree on DOCA release. Divergence is a partial-install /
   mixed-version hazard; route to
   [`doca-version ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 before any further inspector work.
4. **Bulk-debug smoke.** Once the single-packet, depth, and
   version smokes are green, scale the mirror to the user's
   actual debug scope (more entries, more matches, longer
   capture). Confirm the inspector still tracks under load: no
   silent drops (cross-check the pipe's mirror-entry counter on
   the doca-flow side against the inspector's record count on
   the Flow Inspector side); no dataplane performance regression
   beyond what the user accepted when wiring the mirror per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
5. **Pre-production-removal smoke.** Before declaring the debug
   session over, confirm the mirror can be removed without
   destabilizing the pipe — disable the mirror per
   [`## modify`](#modify) step 3, confirm the pipe still
   carries production traffic correctly, and confirm the
   mirror-entry counter no longer increments. This catches the
   *"mirror left wired in production"* regression.

## debug

Layered diagnosis. Walk the layers in this order; do not skip
down without clearing the layer above. For symptoms that turn
out to be in the user's doca-flow / doca-flow-ct pipeline
itself (not in the inspector), route to
[`doca-flow ## debug`](../../libs/doca-flow/TASKS.md#debug) or
`doca-flow-ct ## debug`
and stop. For symptoms that turn out to be cross-cutting (env,
version, build, link), route to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug).

1. **Container lifecycle layer.** Is the inspector container
   actually running? Symptoms: the container runtime shows
   no inspector entry, OR shows it as Restarting / Exited.
   Resolution: read the container runtime's logs (`docker logs
   <name>` or the BlueField host's equivalent); confirm the
   image tag matches the public NGC catalog entry routed via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
   confirm the documented runtime privileges per the public
   Container Deployment Guide are in place.
2. **Mirror-not-wired layer.** Container is healthy but the
   inspector reports no traffic. **This is the most common
   first-app failure** and the layer the agent must check
   BEFORE re-examining inspector config. Resolution: ask the
   user to show the mirror action in their doca-flow /
   doca-flow-ct pipeline spec; read the mirror-entry counter
   in the pipeline (per
   [`doca-flow ## debug`](../../libs/doca-flow/TASKS.md#debug)
   counters-first) to confirm the mirror is *firing*; if the
   counter is zero, the mirror's match is wrong on the
   *pipeline* side and the fix is in
   [`doca-flow ## modify`](../../libs/doca-flow/TASKS.md#modify),
   not in the inspector. Do NOT re-deploy the inspector without
   first clearing this layer.
3. **Inspection-depth-wrong layer.** Traffic is visible but
   does not answer the user's debug question. Symptoms: per-
   packet output is overwhelming when the question was about
   rate, or per-flow aggregate is summary-shaped when the
   question was about a specific packet. Resolution: re-walk
   the depth choice in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes);
   apply the change via [`## modify`](#modify) step 2; re-loop
   through [`## test`](#test).
4. **Sampling / overload layer.** Traffic is visible but at a
   much lower volume than the user expects, OR the BlueField's
   dataplane starts showing performance regression that began
   when the mirror was wired. Resolution: lower the mirror
   rate on the pipeline side (rate-limit the mirror action),
   OR drop the inspector to a lighter inspection depth, OR
   narrow the mirror's match so only the traffic of interest
   is mirrored. Per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   the cap on what is sustainable per-depth is documented in
   the live guide; quote it rather than guessing.
5. **Version-pair layer.** Inspector reports traffic but the
   metadata is unreliable (fields the user expects are missing
   or do not parse). Resolution: cross-check the inspector
   container tag pulled, `pkg-config --modversion doca-flow`
   on the BlueField, and (when CT is wrapping the pipe)
   `pkg-config --modversion doca-flow-ct`. Per
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   divergence is a partial-install hazard; route to
   [`doca-version ## debug`](../../doca-version/TASKS.md#debug)
   layer 2.
6. **Cross-cutting / driver / firmware layer.** When the
   symptom is *"the BlueField device itself is misbehaving"*
   (kernel `dmesg` shows `mlx5_core` errors; the pipe and the
   inspector both behave oddly), the layer is below the
   inspector. Route to
   [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug)
   layer 7 (driver / firmware) and
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   layer 5. The inspector cannot fix what the driver below it
   reports.

For program-side debug of the pipeline that programs the mirror
(lifecycle order, validate-before-commit on the mirror-aware
pipe, `DOCA_ERROR_*` interpretation from `doca_flow_*` calls),
route to
[`doca-programming-guide ## debug`](../../doca-programming-guide/TASKS.md#debug).
The inspector itself does not return DOCA error codes.

## Command appendix

Flow Inspector-specific commands the verbs above reach for,
grouped by purpose so the agent picks the right family without
searching prose. Every row is a class — the agent must not
invent flags beyond what the row names; flag discovery is the
public Flow Inspector guide and the inspector container's own
`--help`, not prose recall.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should probe for the matching structured helper first
(`doca-env --json` for the host + BlueField version snapshot;
`collect-dpu-state` for the BlueField's side of the version /
device / driver picture). If the probe succeeds, the structured
tool's output is authoritative; otherwise, fall back to the
manual command in the row. Report which path was taken. The
schemas the structured tools emit are defined in
[`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas).

| Purpose | Command (class shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Container lifecycle | Container-runtime `ps` / `start` / `stop` / `logs` on the inspector entry (the agent does NOT prescribe a specific runtime command; quote what the user's runtime uses) | [`## run`](#run) step 1; [`## debug`](#debug) layer 1 | Inspector container shows as running, no recent restart loops, no auth / image-pull errors in the runtime logs. |
| Container image source | Per the live NGC catalog entry routed via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services) | [`## configure`](#configure) step 3; [`## build`](#build) inspector-container row | Image string matches the live catalog; container tag is paired with the BlueField's doca-flow version per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility). |
| Inspector record output (telemetry) | Read the inspector's per-record output from the paired downstream `doca_telemetry_exporter` / DTS consumer that reads the DOCA Telemetry IPC socket under `/opt/mellanox/doca/services/telemetry/ipc_sockets/` (the inspector has NO CLI and NO JSON export) | [`## run`](#run) step 4; [`## test`](#test) step 1 | A single known-matching packet from the host produces ONE record at the chosen inspection depth, with the metadata fields the user expects, on the downstream consumer. |
| Inspector container logs | Container-runtime `logs` on the inspector entry (startup, IPC-socket open, parse events) | [`## run`](#run) step 2; [`## debug`](#debug) layer 1 | Logs show the binary started, opened the DOCA Telemetry IPC socket, and report no parse/config errors against `flow_inspector_cfg.json`. |
| Mirror-entry counter on the pipeline side | The doca-flow per-entry counter API per [`doca-flow ## debug`](../../libs/doca-flow/TASKS.md#debug) step 1 | [`## run`](#run) step 3; [`## debug`](#debug) layer 2 | Counter increments under expected traffic — proves the mirror is *firing*, independent of whether the inspector is interpreting it correctly. |
| Version pair cross-check | `pkg-config --modversion doca-flow` (and `doca-flow-ct` when present) on the BlueField; the inspector container tag pulled | [`## test`](#test) step 3; [`## debug`](#debug) layer 5 | All anchors agree on the DOCA release; disagreement routes to [`doca-version ## debug`](../../doca-version/TASKS.md#debug) layer 2. |
| Raise inspector / pipeline log verbosity | `DOCA_LOG_LEVEL=trace` on the program that drives the pipe-side modify; the inspector container's documented log-verbosity flag | [`## run`](#run) step 5; [`doca-debug ## configure`](../../doca-debug/TASKS.md#configure) step 2 | TRACE lines describe the mirror lifecycle and (on the inspector side) the per-record interpretation. |
| Cross-cutting BlueField health | The read-only triple from [`doca-debug ## test`](../../doca-debug/TASKS.md#test) step 3 (program output / system view / DOCA view) | [`## debug`](#debug) layer 6 | All three views are captured together; no `mlx5_core` errors in the system view; `doca_caps --version` matches the BlueField's package install. |

Three cross-cutting rules for this appendix:

- **Never invent an inspector container tag.** The public NGC
  catalog entry routed via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
  is the source of truth. Hallucinating `nvcr.io/...:latest` is
  the most common service-shaped failure for this skill.
- **Mirror-entry counter first, inspector output second.** When
  the inspector reports no traffic, the pipe-side counter is the
  cross-check that disambiguates *"mirror not firing"* (layer 2)
  from *"inspector not receiving"* (layer 1 or layer 5). Skipping
  the counter check leads the agent to debug the inspector when
  the bug is in the pipeline.
- **Cross-link instead of duplicate.** The cross-cutting commands
  (the read-only triple, `dmesg`, `mlxconfig -d <pcie> q`,
  `pkg-config`) live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  the pipe-spec / pipe-counter / pipe-inspector-trace commands
  live in [`doca-flow ## debug`](../../libs/doca-flow/TASKS.md#debug);
  this appendix names only the Flow Inspector-specific rows.

## Deferred task verbs

- **Installing DOCA on the BlueField** — out of scope here. Route
  to [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  for env preparation and
  [`doca-setup ## test`](../../doca-setup/TASKS.md#test) for
  install health verification.
- **Authoring the doca-flow / doca-flow-ct pipeline that programs
  the mirror** — not a Flow Inspector question. Route to
  [`doca-flow ## modify`](../../libs/doca-flow/TASKS.md#modify)
  (and
  `doca-flow-ct ## modify`
  when CT wraps the pipe). The mirror action is a doca-flow
  action kind; its mechanics are owned by the doca-flow skill,
  not this one.
- **Steady-state production telemetry** — not what Flow Inspector
  is for. Route to the DOCA Telemetry Service (DTS) via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
- **Container-runtime troubleshooting itself** (Docker / podman /
  Kubernetes lifecycle, image-registry auth, host networking
  inside the runtime) — outside this skill. Quote the public
  Container Deployment Guide via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
  for the documented launch pattern; runtime-vendor questions
  themselves are upstream of this skill.

## Cross-cutting

- The public DOCA Flow Inspector Service guide is the single
  source of truth. Any flag, inspection-depth field name, or
  documented mirror-target ingest detail the agent quotes must
  come from there, not from generic packet-capture or
  observability knowledge.
- The inspector consumes mirrored traffic; it does not capture
  unmirrored traffic. Every workflow above starts from
  *"confirm the mirror is wired in the pipeline"*; the agent's
  first debug move when the inspector reports nothing is to
  check the pipe-side mirror-entry counter, not the inspector
  container.
- Mirror is a debug-time tool. The agent's responsibility at the
  end of a debug session is to remind the user to disable the
  mirror (or narrow it so it does not fire under production
  traffic). For continuous visibility, route to DTS, not a
  permanently-wired inspector.
- For URL routing to the Flow Inspector guide, the NGC catalog
  entry, and other public DOCA documentation, see
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
