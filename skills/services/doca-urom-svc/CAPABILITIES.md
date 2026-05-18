# DOCA UROM Service — Capabilities

**Where to start:** The pattern overview below names the
recurring DOCA-UROM-Service-class operational patterns. Pick
the pattern first, then drill into the H2 that owns the
substance. For the *how* of executing each pattern, jump to
[TASKS.md](TASKS.md).

This file enumerates the DOCA UROM Service's documented
capabilities, deployment shape, configuration axes, and
operational behaviors as described in the public DOCA UROM
Service Guide. Treat it as a *map of what is documented*, not
a substitute for reading the live page when configuring a real
deployment. For the public URL itself, route through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
— this skill does not duplicate the URL routing.

## Pattern overview

Every DOCA-UROM-Service-class question this skill teaches
resolves into one of SIX patterns. The patterns are CLASSES —
they apply across every service deployment, not just one
BlueField generation or one MPI / UCX consumer.

| Service pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Walk the publisher / executor paired-contract model first | Every UROM deployment has TWO components: host-side `doca-urom` library (publisher) and DPU-side service (executor); both must be present at versions the DOCA Compatibility Policy supports, before the first host enqueue can land | [`## Capabilities and modes`](#capabilities-and-modes) paired-contract table + [`## Version compatibility`](#version-compatibility) paired-version overlay |
| 2. Decide whether to deploy this service at all | Deploy when host nodes use `doca-urom` and want CPU freed for compute; do NOT deploy when hosts don't use the library, when the stack isn't MPI / UCX, or when the BlueField generation is too constrained for the intended offload | [`## Safety policy`](#safety-policy) path-selection rule + [`## Capabilities and modes`](#capabilities-and-modes) deployment shape |
| 3. Pick the service's configuration axes | UCX-component / collective surface (cap-bound to the BlueField generation) + enqueue queue depth + host-endpoint authorization — three axes the operator commits to BEFORE starting the container | [`## Capabilities and modes`](#capabilities-and-modes) configuration-axes table |
| 4. Honor the underlying RDMA transport substrate | The service uses `doca-rdma` (the underlying RDMA / RoCE / IB substrate) to actually move bytes; the service does NOT replace RDMA; substrate failures surface inside the service as stalled operations and at the host as `DOCA_ERROR_IO_FAILED` | [`## Capabilities and modes`](#capabilities-and-modes) substrate row + [`## Error taxonomy`](#error-taxonomy) transport layer |
| 5. Map a service symptom back to its layer | Container-runtime vs service-side authorization vs service-side resource (queue / handler stuck) vs underlying RDMA substrate vs paired-version mismatch — five independent layers, each with its own owner | [`## Error taxonomy`](#error-taxonomy) layered split |
| 6. Read the service's observability before changing config | Container state + service-side logs + DPU-side RDMA counters answer *"is the service actually executing what the host enqueues"* before any config knob is turned | [`## Observability`](#observability) |

Two cross-cutting rules that apply to *every* pattern above:

- **The host-library + DPU-service paired contract is
  load-bearing.** The DOCA UROM Service does nothing on its
  own — its inputs are operations enqueued by the paired
  host-side `doca-urom` library. An agent that walks a user
  through this service in isolation, without naming the
  paired host library and the version-coupling rule, has the
  model wrong for every deployment. The corollary: a
  perfectly healthy service container that does not pair with
  any host's `doca-urom` version is operationally indistinguishable
  from a misconfigured one.
- **Operate the documented path; do not invent one.** The
  service's config schema, container image source, supported
  UCX components / collectives, queue-sizing knobs, and
  authorization model are all documented in the public DOCA
  UROM Service Guide. Quoting config keys, image tags, UCX
  component names, or container-runtime flags not in the
  public guide is the most common hallucination failure mode
  for this skill.

## Capabilities and modes

### Service shape

DOCA UROM Service is a **long-running container** that ships
from NGC and runs on the BlueField Arm cores. The container is
the daemon: it owns the service-side execution state for UROM
offloads, receives enqueued operations from paired host
processes through the DOCA contract, and dispatches them onto
the underlying RDMA substrate. There is no host-side service
binary the user installs — the service is the container; the
host's relationship to the service is to enqueue operations
through the `doca-urom` library.

Three architectural properties the operator must hold
throughout:

- **The service is the EXECUTOR; the library is the
  PUBLISHER.** Per the paired-contract model below, the
  service's purpose is to execute remote memory operations
  that host processes have enqueued through `doca-urom`. The
  service does NOT execute operations the library didn't
  enqueue, does NOT discover work on its own, and does NOT
  drive the host's progress engine. Conflating the two is the
  single most common UROM-deployment design error.
- **The container is the unit of deployment.** Operators do
  not start the service as a host binary; they start the
  service container per the public Container Deployment Guide
  pattern (same shape as every other DOCA service container
  — see the sibling [`doca-dms`](../doca-dms/SKILL.md) and
  [`doca-firefly`](../doca-firefly/SKILL.md) for the same
  shape on different per-service domains).
- **Service behavior is configured by file, not by CLI
  flag.** The container's UCX-component / collective surface,
  enqueue queue depths, and host-authorization list are set
  in the documented service config file the operator mounts
  into the container. The agent should NOT invent CLI flag
  names; the config file is the contract.

### Publisher / executor paired-contract model

DOCA UROM Service is one half of a TWO-component contract. The
host-side `doca-urom` library publishes operations; this
service executes them. Both halves must be present at versions
the DOCA Compatibility Policy supports, before any operation
can flow.

| Side | What runs there | Artifact | What this skill covers |
| --- | --- | --- | --- |
| Host side (publisher) | C / C++ (or any language that can FFI a C library) using `doca-urom` to enqueue remote memory operations, integrated into the user's HPC / UCX / MPI stack on the host | `doca-urom` library — covered by [`doca-urom`](../../libs/doca-urom/SKILL.md); `pkg-config doca-urom` is the build-time anchor on the host | This skill NAMES the library and routes to its skill; it does NOT redefine the library surface. A service running on a BlueField with no host paired through `doca-urom` is operationally idle, not "ready" |
| DPU side (executor) | A long-running container on the BlueField Arm side that receives the host's enqueued operations and EXECUTES them against the remote-side memory and RDMA fabric, freeing the host CPU for compute | DOCA UROM Service container — this skill | All of `## Capabilities and modes` / `## Error taxonomy` / `## Observability` / `## Safety policy` below |

The agent's rule: when the user asks *"how do I write
host-side code that enqueues UROM operations / how do I size
the per-context queue on the host / how do I drive
`doca_pe_progress` for completions"*, that is the host-library
question and the right artifact is
[`doca-urom`](../../libs/doca-urom/SKILL.md). When the user
asks *"how do I deploy / start / stop / scale the service on
the BlueField / how do I configure which UCX components it
exposes / how do I authorize a host endpoint"*, that is this
skill's scope. Two distinct artifacts; two distinct surfaces.

### Deployment shape

The public DOCA UROM Service Guide documents the container
deployment on BlueField Arm. The shape lines up with every
other DOCA service container — pull from NGC, mount the
service config, start under the documented runtime (the
BlueField OS's container manager per the public Container
Deployment Guide). For the canonical container-deployment
recipe shared with the other DOCA service containers, route
through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

Two deployment-shape rules:

- **BlueField Arm only.** The DOCA UROM Service is a
  BlueField-side service; it does not run on the host. The
  host's relationship to the service is via the DOCA contract
  carried over `doca-urom` and the underlying RDMA fabric.
- **One service per BlueField, on the right ports.** The
  service drives the BlueField's UROM execution state for the
  BlueField as a whole; the user picks which RDMA-bearing
  port the underlying `doca-rdma` substrate uses to move
  bytes (typically a wire-side port that the host fleet can
  reach through the inter-node fabric). Running two service
  containers competing for the same execution state on the
  same BlueField is a configuration error, not a redundancy
  strategy.

### Configuration axes

Every DOCA UROM Service deployment must commit to three
configuration axes before starting the container. Get any one
wrong and the service either rejects host enqueues, stalls
them silently, or accepts them but cannot actually execute the
operation family the host intended. The axes are jointly
documented in the public DOCA UROM Service Guide; quote the
exact valid values from there rather than from memory.

| Axis | Class shape | Mismatch symptom | Where to look |
| --- | --- | --- | --- |
| **UCX-component / collective surface** | Which UCX components and collective primitives this service instance exposes for host offload — cap-bound to what the underlying BlueField generation supports, NOT freely selectable | Host's `doca_urom_cap_*` claims the collective is supported (host library + device say yes), but runtime enqueue returns `DOCA_ERROR_NOT_SUPPORTED` because the service was not configured to expose that collective on this deployment | Public DOCA UROM Service Guide's component / collective configuration section |
| **Enqueue queue depth** | The depth of the service-side queue that receives host enqueues; sized to the cluster's intended in-flight depth per host | Host enqueues start succeeding, then return `DOCA_ERROR_AGAIN` after N submits; OR, on the service side, the queue backs up and the host's progress engine sees a stall | Public DOCA UROM Service Guide's queue / sizing section |
| **Host-endpoint authorization** | Which host processes / identities are permitted to offload to this service instance — orthogonal to the host OS's `doca_dev` access; a host that passes `doca_dev` ACLs can still be rejected by the service's own authorization | Host's `doca-urom` `doca_ctx_start` succeeds; first enqueue returns `DOCA_ERROR_NOT_PERMITTED` even though the host user is in the standard DOCA group | Public DOCA UROM Service Guide's authentication / authorization section |
| Underlying RDMA substrate (fourth, configured outside this service) | The service does NOT stand up the RDMA fabric; it consumes it. The BlueField's `doca-rdma` substrate must be healthy on the ports this service will use | Operations enqueued, never complete; or completions surface as `DOCA_ERROR_IO_FAILED` at the host API | Route to [`doca-rdma`](../../libs/doca-rdma/SKILL.md) for the substrate-layer configure / debug |

The agent's rule: **the configuration-axes decision precedes
container start**. A deployment that starts the container
before the operator can name which UCX components / collectives
the service exposes, what queue depth supports the intended
in-flight load, and which host endpoints are authorized is going
to debug the wrong axis first. Force the decision up front.

### Pairing surface — host library plus RDMA substrate

The DOCA UROM Service sits in the middle of two paired
surfaces; neither is optional and the agent must surface both:

| Paired surface | Why this service depends on it | Pairing shape |
| --- | --- | --- |
| Host-side `doca-urom` library | This service has no inputs except what the paired host library enqueues; a service running with no host paired through `doca-urom` is operationally idle. See [`doca-urom`](../../libs/doca-urom/SKILL.md) | Host links `doca-urom` and creates a `doca_urom` Core context against the `doca_dev` mapping to the BlueField running this service; the host enqueues operations, this service receives and executes them, the host's progress engine harvests completions |
| Underlying RDMA transport substrate (`doca-rdma`) | The service moves bytes through the underlying RDMA fabric; the service does NOT replace RDMA. A failing RDMA fabric surfaces inside the service as stalled execution and at the host as `DOCA_ERROR_IO_FAILED`. See [`doca-rdma`](../../libs/doca-rdma/SKILL.md) | The service uses the BlueField's `doca-rdma` substrate on the ports the operator configures; substrate health is the operator's joint responsibility with the network team — the service won't paper over a broken fabric |

The agent's rule: when the user mentions the host `doca-urom`
library or the RDMA fabric in the same breath as this service,
name BOTH paired surfaces in the same response. Naming only
one is how the deployment's actual failure layer gets
misattributed — host symptoms blamed on the service, service
symptoms blamed on the substrate, substrate symptoms blamed on
the library.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-docs
rule, see [`doca-version`](../../doca-version/SKILL.md). The
body lives there; this skill does not duplicate it.

**The DOCA-UROM-Service-specific overlay** is the load-bearing
version-coupling rule:

- **The host-side library version and the DPU-side service
  version must agree per the DOCA Compatibility Policy.** This
  is the single most consequential version axis the agent must
  surface for any UROM deployment: a host-side `doca-urom`
  upgraded without the DPU-side service being upgraded (or vice
  versa) does NOT fail loudly — it fails *subtly*, often as
  `DOCA_ERROR_NOT_SUPPORTED` for an operation family that DOES
  exist on one side but not the other, or as silent stalls on
  collectives that one side believes the pair supports. Surface
  BOTH `pkg-config --modversion doca-urom` on the host AND the
  service container tag on the BlueField; cross-check them
  against the
  [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html).
  This pairing is what the cross-cutting overlay in
  [`doca-urom CAPABILITIES.md ## Version compatibility`](../../libs/doca-urom/CAPABILITIES.md#version-compatibility)
  documents on the host side; this skill documents the same
  pairing from the service side.
- **The service container tag is the runtime version
  anchor.** Same pattern as
  [`doca-dms`](../doca-dms/SKILL.md) and
  [`doca-firefly`](../doca-firefly/SKILL.md): the service
  container ships from NGC with its own tag that may lag the
  BlueField host's DOCA package version, and the relevant
  version anchor for an as-deployed service is the container
  tag pulled, not `pkg-config --modversion` on the BlueField.
  Always quote both versions when the user reports a service
  behavior; if they diverge, route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before diagnosing the service behavior itself.
- **The exposed UCX-component / collective surface is
  version-bound.** Which collective primitives the service can
  expose (all-to-all, all-reduce, broadcast, …) is jointly
  conditional on the service container version, the BlueField
  generation, and the underlying DOCA install. When the user
  asks *"does this collective work on my deployment?"*, the
  authoritative answer is the public DOCA UROM Service Guide
  page whose version matches the container tag pulled — NOT
  agent memory and NOT a guess from a different DOCA release.
- **Read the public DOCA UROM Service Guide version header.**
  The guide is versioned; the on-page version must match the
  container tag the operator is using. A mismatch between the
  docs version and the container tag is the canonical *"my
  config doesn't match what the docs say"* failure mode and
  often masquerades as a paired-version mismatch with the host
  library.

## Error taxonomy

DOCA UROM Service errors fall into five layers, each with its
own owner. The agent's rule: walk the layers in order; do NOT
skip down without clearing the layer above. Notably, the
host-visible `DOCA_ERROR_*` for a service-side cause is
documented on the host side in
[`doca-urom CAPABILITIES.md ## Error taxonomy`](../../libs/doca-urom/CAPABILITIES.md#error-taxonomy);
this table maps each host-visible symptom back to the
service-side layer the operator must touch.

| Layer | Symptom (host-visible) | Root cause class | Where to fix |
| --- | --- | --- | --- |
| 1. Container runtime | Container fails to start, restart-loops, exits immediately, image pull fails. Host symptom: `doca_urom` create or `doca_ctx_start` fails because there is no reachable service | Image tag wrong, registry credentials missing, BlueField container runtime not configured for this container, config file mount path wrong | BlueField container runtime + the public Container Deployment Guide via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) |
| 2. Service-side authentication / authorization | Container green; host's `doca_ctx_start` succeeds; first enqueue returns `DOCA_ERROR_NOT_PERMITTED` even though the host user is in the standard DOCA group | Service's host-authorization list does not include this host endpoint, OR the auth-credential material the host presents does not match what the service is configured to accept | Service config — the authorization-axis row in [`## Capabilities and modes`](#capabilities-and-modes); the public DOCA UROM Service Guide's authentication / authorization section |
| 3. Service-side resource exhaustion | Host enqueues succeed; completions never fire; OR after N successful enqueues every further enqueue returns `DOCA_ERROR_AGAIN` indefinitely | Service-side queue is undersized for the in-flight depth the host workload generates, OR the service is processing operations one at a time when it could batch, OR a service-side handler is stuck on a single in-flight operation | Service config — the queue-depth row in [`## Capabilities and modes`](#capabilities-and-modes); service logs (this skill's [`## Observability`](#observability)) to identify a stuck handler |
| 4. Underlying RDMA substrate | Host sees `DOCA_ERROR_IO_FAILED` from enqueue or completion; or enqueue succeeds but completions never fire and the substrate counters show errors | The underlying RDMA fabric has reported failure (link down, RoCE / IB config skew between BlueFields, routing issue inter-node). The service is NOT the source of truth for the substrate; it is the surface that exposes the failure | Route to [`doca-rdma TASKS.md ## debug`](../../libs/doca-rdma/TASKS.md#debug) for the substrate-layer diagnosis; do NOT mask substrate failures inside the service config |
| 5. Paired-version mismatch | Host's `doca_urom_cap_*` claims an operation family / collective is supported, but runtime enqueue returns `DOCA_ERROR_NOT_SUPPORTED` (despite a healthy container and clean authorization) | Host library and service container are at versions the DOCA Compatibility Policy does not support pairing — the cap query answered for the host's library + device axis, but the running service is at a different version that does not actually execute that variant | Cross-check both versions against the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html) and the four-way-match rule in [`doca-version`](../../doca-version/SKILL.md). The fix is either upgrading the service container or downgrading the host library; do NOT paper over with a retry |

The agent's rule: **never recommend a service config change
without first identifying which of the five layers is the
cause**. The two most common debug failures for this skill
are misreading a layer-2 symptom (host endpoint not authorized
by the service) as a layer-1 problem (container not running)
and rewriting the container start sequence, AND misreading a
layer-5 symptom (host-library / service version mismatch) as
a layer-2 or layer-3 problem and chasing config knobs that
cannot fix it.

## Observability

Documented observability surfaces the agent should reach for,
in order of how cheaply they answer the *"is the service
actually executing what the host enqueued"* question:

1. **Container state.** First — is the service container
   actually running on the BlueField? The BlueField container
   manager reports container status, restart count, and the
   container's stdout / stderr log stream. A restart loop is a
   layer-1 (container runtime) symptom per
   [`## Error taxonomy`](#error-taxonomy); diagnose it before
   touching any service config. A non-running container makes
   every host-side `doca-urom` call meaningless.
2. **Service-side logs.** The container's stdout (and any
   documented log destination the public DOCA UROM Service
   Guide specifies) is the primary service observability
   surface. Look for: (a) authorization-rejection lines (layer
   2); (b) queue-saturation or handler-stuck lines (layer 3);
   (c) underlying-substrate-error lines (layer 4); (d)
   paired-version-mismatch lines if the service detects an
   incompatible host (layer 5). The agent should NOT invent
   log line formats; quote what the live container is
   emitting.
3. **Host-side completion surface.** The host's `doca-urom`
   library reports operation completions through the DOCA
   progress engine. The host-side observability is documented
   in
   [`doca-urom CAPABILITIES.md ## Observability`](../../libs/doca-urom/CAPABILITIES.md#observability);
   the service-side reading of *"how many operations did we
   actually execute"* is read from the service's own logs and
   from the substrate counters below. When the host says
   *"submitted N, completed M"* and the service says it
   executed K, the differences between N / M / K identify
   which layer is dropping work.
4. **Underlying RDMA substrate counters.** When the
   service-side surface shows operations being received but
   the user reports the remote-side memory does not have the
   expected bytes, the right diagnostic is the substrate
   counters per
   [`doca-rdma CAPABILITIES.md ## Observability`](../../libs/doca-rdma/CAPABILITIES.md#observability)
   on each BlueField in the path. The agent must NAME the
   existence of this surface and route the user there; the
   per-counter details belong in the substrate skill.
5. **Version snapshot at deploy time.** The service container
   tag, `pkg-config --modversion doca-urom` on the paired
   host(s), and the BlueField's `doca_caps --version` are the
   baseline of *"which paired-version pair the operator
   deployed"*. Save them; if a runtime failure later looks
   like a layer-5 paired-version mismatch, the diff against
   this baseline (one side upgraded, the other didn't) is the
   bug.

For the cross-library debug-time observability
(`DOCA_LOG_LEVEL`, `--sdk-log-level`, the trace build flavor —
relevant when the service calls into a DOCA library that emits
structured logs), see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

The DOCA UROM Service's safety surface is **path-selection
first**, then the version-contract rule, then the
smoke-before-scale rule, then the operational disciplines
around the container itself.

- **Path-selection rule (load-bearing).** Deploy this service
  ONLY when the HPC environment actually benefits from DPU
  offload of remote memory operations. Concretely:
    - Deploy when the host fleet uses the `doca-urom`
      library AND the workload pattern (MPI / UCX
      collectives, dense remote-memory traffic) is one where
      host-CPU cost of posting RDMA work is the bottleneck
      AND the BlueField generation in use can support the
      intended UCX components / collectives.
    - Do NOT deploy when the host fleet is not using
      `doca-urom`, when the HPC stack is neither MPI nor UCX
      (this service won't help — it executes UROM-shaped
      offloads, not arbitrary networking), or when the
      BlueField generation is too constrained to expose the
      intended offload surface. In those cases the right
      answer is to keep the host's existing communication
      path and explicitly tell the user *"this service is the
      wrong tool here; here's why"* — not to deploy it
      speculatively and end up debugging an offload that was
      never going to help.
- **Version-contract rule (load-bearing).** The host-side
  `doca-urom` library version and this service's container
  tag are a paired contract — see
  [`## Version compatibility`](#version-compatibility). A
  service deployment that does not name the paired-host
  library version, OR that proceeds against a pair the DOCA
  Compatibility Policy doesn't support, will fail subtly: not
  with a loud refusal at deploy time, but with
  `DOCA_ERROR_NOT_SUPPORTED` on operations one side believed
  the pair supports, or with silent stalls on collectives.
  The agent must always surface BOTH versions and the policy
  check up front.
- **Cap-query at deploy time.** Before declaring the service
  ready, the operator must confirm that the BlueField
  generation in use, the DOCA install on the BlueField, and
  this service version actually expose the UCX components /
  collectives the host workload intends to offload. The
  device-side cap surface is the authoritative answer for
  *"can this BlueField even host this offload"* — see the
  device-axis row of the cap query the host runs via
  [`doca-urom CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-urom/CAPABILITIES.md#capabilities-and-modes);
  the answer must agree with the service's exposed surface or
  the deployment is misconfigured before any host enqueue.
- **Smoke before scale.** Before pointing the full HPC
  workload at the service, the operator must walk a smoke:
  service container running on the BlueField; ONE paired
  host's `doca-urom` `doca_ctx_start` succeeds against this
  BlueField; ONE host enqueue (a simple put or get) is
  observed at the service (in logs) AND ONE completion fires
  on the host's progress engine. Only then layer the
  collective patterns on top. A workload that comes up
  before the smoke passes does not isolate which of the five
  layers in [`## Error taxonomy`](#error-taxonomy) is wrong,
  and bisection across container / authorization / queue /
  substrate / version becomes much harder.
- **One service per BlueField.** Two service containers on
  the same BlueField competing for the same UROM execution
  state is a configuration error; the agent must NOT recommend
  it as a redundancy strategy. UROM redundancy is a
  cluster-side concern (multiple BlueFields, multiple service
  instances each owning their own BlueField) that does not
  require multiple service containers on one DPU.
- **Don't paper over a transport-substrate problem from the
  service.** When the symptom is *"operations enqueued, never
  complete"* and the layer is *"underlying RDMA substrate down"*
  per [`## Error taxonomy`](#error-taxonomy), the honest
  answer is *"the RDMA fabric isn't carrying the traffic; the
  fix is at the substrate, not in this service's config"*.
  Silently masking a substrate failure inside the service —
  by, e.g., shortening timeouts to make the host see the
  failure faster — is a user-visible regression dressed up as
  helpfulness.
- **Authentication is per-host-endpoint, not per-stream.** The
  service's authorization model is documented as a
  per-host-endpoint decision: a given host process is either
  permitted to offload to this service or not. The agent must
  NOT propose per-operation authentication schemes that the
  service does not implement; refuse to invent an
  authorization model the public guide doesn't document.

## Public-source pointer

The single canonical public source for the DOCA UROM Service
is the **DOCA UROM Service Guide**, reachable through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
Verify that the version of the guide matches the service
container tag pulled on the BlueField AND that the host-side
`doca-urom` library version pairs with that container tag per
the DOCA Compatibility Policy — the service's config surface,
supported UCX components / collectives, queue knobs, and
observability output are documented to evolve, so config keys
and exposed surfaces can change between releases.
