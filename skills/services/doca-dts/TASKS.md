# DOCA Telemetry Service — Tasks

**Where to start:** The order is `configure → build → modify → run
→ test → debug`. The `## test` verb is an iterative loop, not a
one-shot pass — see the eval-loop overlay in `## test` below. For
DTS, `build` and `modify` are about *deployment configuration*
(container-runtime invocation, YAML/JSON config file, mount
contracts), not about compiling source.

These verbs cover the in-scope DTS operational workflows for an
external operator deploying and using DTS. Every step assumes the
operator has consulted the live public DTS guide on
`docs.nvidia.com` (and the DOCA Container Deployment Guide for the
container-runtime path) and is using them as the authoritative
reference; this file prescribes the *order* and *what to look up
where*, not a copy-paste runbook.

## configure

Preparing the BlueField target and picking a deployment path.

1. **Confirm the env is healthy first.** This skill expects DOCA
   to be installed on the BlueField target and a container
   runtime to be available. If that has not been verified, run
   [`doca-setup ## test`](../../doca-setup/TASKS.md#test) first.
   If the user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path.
2. **Surface the triple-skill split BEFORE any deploy step.**
   Read the role split in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   The user MUST understand which artifact they want: publishers
   ([`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md))
   emit events INTO DTS; DTS aggregates and re-publishes onto
   the configured sinks; downstream consumers (Prometheus /
   NetFlow / IPFIX / Grafana / the DOCA Log Service / custom
   analyzers) receive the aggregate. If the user actually wants
   to PUBLISH events from their own app, the right artifact is
   the exporter. If the user actually wants a CUSTOM in-process
   collector, the right artifact is
   [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md). DTS
   is the pre-baked aggregator the operator *deploys* — not the
   right answer to either of the other two needs.
3. **Pick the container-runtime path and route to the canonical
   deployment guide.** Per the deployment-shape table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the documented runtime paths are `crictl` / `kubelet` (when
   BlueField runs k8s), a SystemD container unit (when
   BlueField runs standalone), or manual container-runtime
   invocation (lab use only). The canonical deployment pattern
   for each path lives in the **DOCA Container Deployment
   Guide** at
   [`https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html`](https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html),
   reached through
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
   Do NOT re-invent the deployment pattern; quote from the
   guide.
4. **Identify the container image source.** Per the public DTS
   guide, the container image is published to the NGC catalog.
   The agent MUST route through
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
   for the current image string + tag; do NOT invent an image
   name (e.g. `nvcr.io/nvidia/doca/doca-telemetry-service:latest`)
   from memory. Wrong image string is the most common
   first-app failure for this skill.
5. **Plan the sources DTS will pull from.** Identify the
   publishers feeding this DTS instance: which DOCA-using
   applications on the same DPU link
   [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md);
   what host telemetry sockets they write to; what system
   metrics and DPU hardware counters DTS should also pull. The
   socket paths must be reachable from inside the DTS
   container, which means they must be mounted in at container
   start.
6. **Plan the sinks DTS will forward to.** Identify the
   downstream consumers: Prometheus scrape endpoint, NetFlow
   collector, IPFIX collector, custom dashboard, the DOCA Log
   Service. For each, confirm the protocol the consumer
   expects and that the consumer is reachable from the
   BlueField over the network.
7. **Identify the version anchors.** Per
   [`CAPABILITIES.md ## Version compatibility`](#version-compatibility),
   record BOTH the host DOCA install version (via
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure))
   AND the DTS container tag pulled. The schema-version
   contract between publishers (host DOCA install) and DTS
   (container tag) is the silent ingest-loss trap; align the
   two sides explicitly.

## build

DTS is a service, not a library. There is no DTS *application*
artifact for the operator to build — the container image ships
from the public catalog and the operator pulls it; clients of
DTS's downstream sinks are standard Prometheus / NetFlow / IPFIX
tooling that the operator already has.

If the user is asking how to build a **publisher application**
that emits events INTO DTS, that is *not* a DTS question — route
to [`doca-telemetry-exporter ## build`](../../libs/doca-telemetry-exporter/TASKS.md#build)
for the exporter's build slot. If the user is asking how to build
a **custom collector** that receives events directly (without DTS
in the middle), route to
[`doca-telemetry ## build`](../../libs/doca-telemetry/TASKS.md#build).

If the user is asking how to build a **downstream consumer** in
their own language (a custom Prometheus scraper, a NetFlow
analyzer), that is governed by the downstream-consumer ecosystem
and out of scope here. The DTS-specific contribution is the sink
protocol and field shape DTS forwards; consult the public DTS
guide for the sink documentation, then build against the
downstream-consumer ecosystem's own client surface.

If the user is asking about building **a DOCA application** in
the general sense (linking against `libdoca-*`), that is *not* a
DTS question — route to
[`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
and the matching `libs/<library>` skill.

## modify

DTS does not have a "modify a sample program" workflow analogous
to DOCA libraries; there is no DTS sample source a user starts
from. The DTS analog of "modify" is **adapt the documented
container-deployment + YAML/JSON config recipe to the user's
environment**:

1. **Start from the documented recipe.** Identify the public
   DTS guide's recipe (and the matching DOCA Container
   Deployment Guide section) that matches the user's
   container-runtime path. Quote it; do not author a new one.
2. **Diff against the user's environment.** Note the specific
   substitutions the user must make: BlueField PCIe address,
   host telemetry socket paths the publishers write to, the
   downstream consumer's protocol / endpoint / port, the
   schema-version pinning the publisher's installed DOCA
   version dictates, the sampling rate appropriate to the
   downstream consumer's ingest rate.
3. **Apply minimum-change.** Change only what the user's
   environment forces. Every additional deviation from the
   documented recipe widens the surface for an unintended
   ingest-loss / sink-mismatch / start-order failure.
4. **Re-validate against the start-order rule.** Per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   DTS must come up BEFORE the publishers, every time the
   recipe is applied. Bake this into the SystemD unit
   dependency graph, the k8s pod ordering, or the manual
   bring-up runbook — not into the operator's memory.
5. **Re-validate the schema-version pin against the
   publisher's installed DOCA.** Per
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   schema-version drift between publisher and DTS is silent
   ingest loss; the modify step is the right place to surface
   the contract, not debug time.

## run

Bringing up DTS and exercising it.

1. **Pull the documented container image.** Per
   [`## configure`](#configure) step 4, the image string comes
   from the public DTS guide and the NGC catalog reached
   through
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
   Confirm the pull succeeds and the tag matches what the user
   recorded in the version-anchor step.
2. **Invoke the documented container-runtime path.** Per
   [`## configure`](#configure) step 3, the runtime invocation
   (`crictl` / `kubelet` pod manifest, SystemD container unit,
   manual container runtime) lives in the DOCA Container
   Deployment Guide. Apply the DTS-specific mounts: the
   YAML/JSON config file mount and the host telemetry socket
   mounts so publishers can write to them and DTS can read.
3. **Verify DTS is up.** Use the documented runtime probe:
   `crictl ps` for `crictl` / `kubelet`, `systemctl status
   <unit>` for the SystemD container unit, or the matching
   container-runtime command for the manual path. Healthy =
   the container is in `Running` / `active (running)` with no
   restart loop. If DTS is in a restart loop, drop to
   [`## debug`](#debug) layer Container BEFORE proceeding.
4. **Verify DTS's per-source counter advances when a
   publisher starts.** This is the documented liveness signal
   on the DTS side. Start ONE publisher (an app linking
   [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md))
   and have it emit ONE event with a schema DTS is pinned to
   accept. Watch the matching per-source counter in DTS's
   exposed counters surface advance. If it does not, the
   publisher socket is not mounted into the container or the
   schema is mismatched — drop to
   [`## debug`](#debug) layer Publisher-ingest.
5. **Verify the downstream consumer receives the forwarded
   event.** This is the load-bearing end-to-end check. The
   consumer (Prometheus scrape / NetFlow collector / IPFIX
   collector / Grafana / custom analyzer) must independently
   show the event with the schema DTS forwards. If DTS's
   per-sink counter advances but the consumer is empty, the
   failure is on the consumer side or in the sink-config field
   pointing at the wrong endpoint — drop to
   [`## debug`](#debug) layer Downstream-sink.

For multi-publisher deployments: bring publishers up ONE AT A
TIME and verify each per-source counter advances before adding
the next. Multi-publisher bring-up that batches everything
together makes ingest-failure attribution much harder.

## test

DTS has no "compile and unit-test" workflow — testing is
operational and end-to-end.

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation (config field, sink endpoint, schema pin, socket mount,
container tag) re-opens the smoke sweep. Skipping the re-run
after a mutation is the failure mode this loop replaces.

The eval-loop overlay (rows apply to every DTS deployment, not
just one topology):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | Per-sink counter advances at DTS but the downstream consumer (step 4) is empty — the sink config is wrong, loop back to step 1 and re-walk the config | [`## test`](#test) step 1 |
| 2 → ## debug | When the single-event smoke does NOT show the event on the downstream consumer, the deployment is unproven — escalate to `## debug` immediately, do not run later steps | [`## debug`](#debug) |
| 3 → ## configure → 3 | When a publisher restarted later still has no events arriving at DTS, the start-order rule was broken or the socket mount is wrong — loop back to `## configure` and re-walk the mount + start-order plan | [`## configure`](#configure) |
| 1..4 → ## run | Each loop iteration ends with a documented smoke; if all four pass, hand off to live `## run` traffic | [`## run`](#run) |

The agent's rule: every mutation re-opens the sweep. A config
change followed by "it probably still works" is exactly the
failure mode the iterative loop is here to prevent.

1. **Smoke-test the DTS container alone.** After launch
   (`## run` step 3), confirm `crictl logs <id>` (or the
   matching runtime command) shows DTS healthy, the config file
   parsed successfully, the configured sources registered, and
   the configured sinks initialized. NO publishers attached
   yet; DTS should run cleanly waiting for ingest.
2. **Single-event publisher + DTS smoke.** Start ONE publisher
   (a [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)-using
   application) on the same DPU, registering the exact schema
   DTS is pinned to accept; have it emit ONE event; confirm
   DTS's per-source counter advances and the event appears in
   DTS's per-sink forwarding lane. This validates the socket
   mount, the schema-version pin, and the DTS ingest pipeline
   end-to-end on the DPU side BEFORE pulling the downstream
   consumer into the picture.
3. **Single-event end-to-end smoke (the load-bearing
   check).** Confirm the configured downstream consumer
   (Prometheus / NetFlow / IPFIX / Grafana / custom analyzer)
   independently shows the event with the schema DTS forwards.
   This is the cheapest end-to-end proof that the entire
   pipeline (publisher emit → socket → DTS ingest → DTS
   forward → consumer reception) is correct. Skipping this
   step and going straight to bulk traffic is the most common
   reason "everything looks healthy but the dashboard is
   flat".
4. **Capability + config snapshot.** Save the *as-deployed*
   answer to: which container tag is running, which YAML/JSON
   config fields are set, which sources are registered, which
   sinks are configured, what schema-version pin is active.
   This snapshot is the artifact that lets future debug
   sessions skip rediscovery — and the artifact that lets the
   operator confirm a later mutation actually changed what
   they think it changed.
5. **Multi-event smoke.** Loop a small N (say, 100) emits on
   the publisher with DTS forwarding to the consumer; confirm
   the consumer's count matches the publisher's count (modulo
   the documented sampling rate). Catches lost events that
   the per-event smoke alone would not surface.

Loop termination: stop iterating once two consecutive
iterations of the same kind don't change anything — that means
the cause is below DTS (publisher / transport / driver / host).
Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured layer evidence and both the publisher-side
and DTS-side log state.

## debug

Layered diagnosis. Walk the layers in this order; do not skip
down without clearing the layer above.

1. **Container layer.** Is the DTS container even up? Symptoms:
   `crictl ps` shows the container exited or restarting;
   `journalctl -u <unit>` shows the SystemD container unit
   failing to start; manual `docker run` (or equivalent) exits
   with a non-zero status. Causes: image not present / wrong
   tag / unreachable registry; mounted config file missing or
   malformed; mounted socket path does not exist on the host;
   image version incompatible with installed DOCA per
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
   Resolution: walk the runtime's own logs first (`crictl logs
   <id>` or `journalctl -u <unit>`); if the failure is at the
   image-pull or runtime layer, route to env-class debug at
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug).
2. **Publisher-ingest layer.** DTS is running but no telemetry
   is arriving. Symptoms: DTS healthy in `crictl logs`; the
   per-source counter stays at zero; the downstream consumer
   is empty. Causes: the publisher's socket is NOT mounted
   into the DTS container (the most common case); the
   publisher's user cannot write to the mounted socket; the
   publisher and DTS disagree on schema version (silent decode
   loss); the publisher has not started yet (start-order
   rule). Resolution: walk the publisher-side per-emit return
   (per
   [`doca-telemetry-exporter CAPABILITIES.md ## Observability`](../../libs/doca-telemetry-exporter/CAPABILITIES.md#observability))
   AND DTS's per-source counter together; the smoke loop in
   [`## test`](#test) step 2 is the cheapest way to surface
   this BEFORE bulk traffic.
3. **Downstream-sink layer.** DTS is forwarding but the
   consumer is empty. Symptoms: DTS's per-sink counter
   advances; the Prometheus / NetFlow / IPFIX / Grafana /
   custom-analyzer consumer is flat. Causes: the consumer-side
   config does not point at the correct port / endpoint /
   auth; the consumer-side scrape protocol does not match
   DTS's sink protocol; the consumer-side schema expectation
   does not match what DTS forwards; network egress from
   BlueField to the consumer is blocked. Resolution: confirm
   reception on the consumer side independently (consumer
   logs / counters / scrape endpoint); the downstream consumer
   ecosystem owns the resolution from there, but the agent
   should walk the user through confirming the sink config in
   DTS matches the consumer's expectation before blaming the
   consumer.
4. **Schema-version layer.** DTS ingests AND forwards, but
   the consumer decodes garbage. Symptoms: events appear at
   the consumer but field values are wrong / missing / nonsense.
   Causes: schema-version drift between publisher (host DOCA
   install) and DTS (container tag); or between DTS and the
   downstream consumer's expected schema. Resolution: re-walk
   the version-anchor step in
   [`## configure`](#configure) step 7; align the
   publisher's installed DOCA version, the DTS container tag,
   and the consumer's expected schema.
5. **Library-level errors.** If DTS is acting as a thin
   wrapper over a DOCA library call (the ingest path
   internally calls into the collector library; the
   forwarding path may call into other DOCA primitives) and
   that library returned `DOCA_ERROR_*`, the relevant
   cross-library taxonomy lives in
   [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
   The collector-library overlay for `DOCA_ERROR_AGAIN`
   (consumer queue full) is in
   [`doca-telemetry CAPABILITIES.md ## Error taxonomy`](../../libs/doca-telemetry/CAPABILITIES.md#error-taxonomy);
   the publisher-side hot-path-drop-not-block rule lives in
   [`doca-telemetry-exporter CAPABILITIES.md ## Safety policy`](../../libs/doca-telemetry-exporter/CAPABILITIES.md#safety-policy).
   Under-load loss is a two-sided concern and not solvable
   inside DTS alone.

## Command appendix

DTS-specific commands the verbs above reach for, grouped by
purpose so the agent picks the right family without searching
prose. Every row is a class — the agent must not invent flags
beyond what the row names; flag discovery is `--help` on the
installed binary or the container runtime's documented options,
not prose recall.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env
   --json` for version + devices + libraries + drivers +
   hugepages in one shot; `doca-capability-snapshot` for
   per-device capability flags; `version-matrix.json` for
   *"available since"* lookups).
2. If the probe succeeds, the structured tool's output is the
   authoritative answer and the agent SHOULD NOT also run the
   manual command in the row below. Report *"using structured
   `<tool>`"*.
3. If the probe fails, fall back to the manual command in the
   row. Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Purpose | Command (class shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Container lifecycle (`crictl` / `kubelet`) | `crictl ps` / `crictl logs <id>` / `crictl inspect <id>` | [`## run`](#run) step 3; [`## debug`](#debug) layer Container | Container is in `Running` with no recent restart loop; logs show config parsed and sources/sinks initialized. |
| Container lifecycle (SystemD unit) | `systemctl status <unit>` / `journalctl -u <unit> --since "5 min ago"` | [`## run`](#run) step 3; [`## debug`](#debug) layer Container | `active (running)` with no recent restart; journal shows config parsed and DTS ready. |
| Container lifecycle (manual runtime, lab) | The documented container runtime's `ps` / `logs` / `inspect` commands | [`## run`](#run) step 3; [`## debug`](#debug) layer Container | Container running; logs show DTS healthy. Manual runtime is lab-only — not production. |
| Image pull verification | The documented container runtime's image-list command after pulling the image string from the public DOCA Container Deployment Guide | [`## configure`](#configure) step 4; [`## run`](#run) step 1 | The pulled image tag matches what was quoted from the public guide; the image is present locally. |
| Config file mount verification | `crictl inspect <id>` (or the equivalent runtime command) showing the mount list | [`## run`](#run) step 2; [`## debug`](#debug) layer Container | The YAML/JSON config file is mounted at the path DTS expects; the host telemetry sockets are mounted in. |
| Publisher socket check | `ls -l <socket-path>` on the host, then `ls -l` inside the container via the runtime's `exec` command | [`## configure`](#configure) step 5; [`## debug`](#debug) layer Publisher-ingest | The socket exists on both sides; the publisher's user can write to it; the container's user can read it. |
| DTS per-source counter check | The documented DTS counter-readout command (per the public DTS guide) | [`## run`](#run) step 4; [`## test`](#test) step 2; [`## debug`](#debug) layer Publisher-ingest | The counter for the active publisher advances when the publisher emits. Zero counter with the publisher healthy = socket / schema mismatch. |
| DTS per-sink counter check | The documented DTS counter-readout command (per the public DTS guide) | [`## run`](#run) step 5; [`## test`](#test) step 3; [`## debug`](#debug) layer Downstream-sink | The counter for each configured sink advances when DTS has events to forward. |
| Downstream-consumer reception check | The consumer's own observability surface (Prometheus scrape endpoint hit, NetFlow / IPFIX collector log, Grafana panel populated, custom analyzer record) | [`## test`](#test) step 3 (load-bearing end-to-end); [`## debug`](#debug) layer Downstream-sink | The consumer independently shows the event with the schema DTS forwards. This is the only true success signal. |
| Version anchor (host DOCA) | `pkg-config --modversion doca-common` and `doca_caps --version` on the BlueField | [`## configure`](#configure) step 7; [`## debug`](#debug) layer Schema-version | Semver strings match each other; align with the DTS container tag for the schema contract. |
| Version anchor (DTS container) | The container runtime's image-list command showing the tag of the pulled DTS image | [`## configure`](#configure) step 7; [`## debug`](#debug) layer Schema-version | The tag matches what was quoted from the public DTS guide / NGC catalog; align with the publisher's host DOCA version per the schema contract. |

Three cross-cutting rules for this appendix:

- **Never invent a DTS image name / tag.** The public DOCA
  Container Deployment Guide and the NGC catalog reached
  through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  are the contract; prose-derived image strings are the most
  common hallucination failure for this skill.
- **Container-runtime logs before in-DTS logs.** When
  triaging, read `crictl logs <id>` (or `journalctl -u
  <unit>`) first; only drop to DTS's own in-container log
  surface once the runtime confirms the container is up.
- **Cross-link instead of duplicate.** Cross-cutting commands
  (the read-only triple, `dmesg`, the version-detection
  chain) live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  this appendix names only the DTS-specific ones.

## Deferred task verbs

- **Installing DOCA on the BlueField target** — out of scope
  here. Route to
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  for env preparation and
  [`doca-setup ## test`](../../doca-setup/TASKS.md#test) for
  install health verification, or
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container Path 0 if there is no
  DOCA install yet.
- **Authoring the canonical container-deployment pattern** —
  not owned here. The DOCA Container Deployment Guide at
  [`https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html`](https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html)
  (reached through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md))
  is the single source of truth for the runtime invocation,
  pod manifest shape, and SystemD unit shape. This skill
  cross-links there.
- **Building a publisher application** (emitting events INTO
  DTS) — not a DTS question. Route to
  [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)
  for the publisher library and its
  [`## build`](../../libs/doca-telemetry-exporter/TASKS.md#build)
  / [`## modify`](../../libs/doca-telemetry-exporter/TASKS.md#modify)
  workflows.
- **Building a custom in-process collector** (receiving DOCA
  telemetry events directly, without DTS in the middle) — not
  a DTS question. Route to
  [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) for
  the collector library and its
  [`## build`](../../libs/doca-telemetry/TASKS.md#build) /
  [`## modify`](../../libs/doca-telemetry/TASKS.md#modify)
  workflows.
- **Configuring the downstream consumer's own dashboard** —
  out of scope. Prometheus scrape configs, Grafana
  dashboards, NetFlow / IPFIX analyzer rules are governed by
  their own ecosystems. DTS's role ends at the sink protocol
  and field shape it forwards.

## Cross-cutting

- The public DTS guide is the single source of truth for DTS-
  specific config field names, sink protocols, and counter
  names. Any field, protocol, or counter the agent quotes must
  come from there, not from generic Prometheus / NetFlow /
  IPFIX knowledge.
- The public DOCA Container Deployment Guide is the single
  source of truth for the container-runtime invocation,
  mount-spec shape, and image-pull procedure. Do NOT re-invent
  the deployment pattern.
- The triple-skill split (exporter → DTS → downstream
  consumer) is the load-bearing first-app rule. Surface it
  before any deploy step.
- The start-order rule (DTS up BEFORE publishers) is the
  load-bearing operational invariant. Bake it into the
  deployment manifest, not the operator's memory.
- The single-event smoke (one publisher emit → confirmed
  reception at the downstream consumer with the correct
  schema) is the cheapest end-to-end proof; run it BEFORE
  scaling to bulk traffic.
- For URL routing to the DTS guide, the DOCA Container
  Deployment Guide, and the NGC catalog, see
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
