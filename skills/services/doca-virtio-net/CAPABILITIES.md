# DOCA Virtio-net Service — Capabilities

**Where to start:** The pattern overview below names the recurring
Virtio-net-Service-class operational patterns. Pick the pattern
first, then drill into the H2 that owns the substance. For the
*how* of executing each pattern, jump to [TASKS.md](TASKS.md).

This file enumerates the service's documented capabilities,
deployment shape, configuration axes, and operational behaviors
as described in the public DOCA Virtio-net Service Guide for the
operator's DOCA release. Treat it as a *map of what is
documented*, not a substitute for reading the live page when
configuring a real deployment. For the public URL itself, route
through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
— this skill does not duplicate the URL routing.

## Pattern overview

Every Virtio-net-Service-class question this skill teaches
resolves into one of SIX patterns. The patterns are CLASSES —
they apply across every deployment, not just one BlueField
generation or one DPU-side networking backend.

| Pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Decide whether the service is the right answer | Network-disaggregation / bump-in-the-wire host-facing NIC / security-isolated NIC presented to the host through the BlueField vs. plain host networking sufficient vs. the user actually wants to shape the BlueField's built-in NIC personality | [`## Safety policy`](#safety-policy) path-selection rule |
| 2. Pin the BF generation FIRST against the public guide | The supported BlueField generations and per-generation feature surface are documented in the public Virtio-net Service Guide for the operator's DOCA release; quoting config knobs, container tags, or capability bounds before pinning the generation is the canonical first-deploy mistake | [`## Capabilities and modes`](#capabilities-and-modes) BF-generation pinning rule + [`## Version compatibility`](#version-compatibility) |
| 3. Confirm the firmware-slot precondition is on | The BlueField firmware virtio-net emulation slot must be enabled BEFORE the service container can stand up an emulated device cleanly; a BlueField reset is typically required after the slot is flipped | [`## Safety policy`](#safety-policy) firmware-slot rule + [`## Error taxonomy`](#error-taxonomy) layer 2 |
| 4. Pick the four configuration axes | BF generation + virtio-net device class (vs. other emulation classes the user might be confusing this with) + emulated device + queue count + DPU-side networking backend — every axis is a mismatch hazard | [`## Capabilities and modes`](#capabilities-and-modes) four-axis table |
| 5. Wire and confirm the DPU-side networking backend | The service container only emulates the host-facing PCIe NIC; the actual frames go through a DPU-side backend (uplink path, OVS bridge, other DPU-side networking). Backend reachability is independent of service container health | [`## Capabilities and modes`](#capabilities-and-modes) backend table + [`## Error taxonomy`](#error-taxonomy) layer 4 |
| 6. Map a symptom back to its layer | Container-runtime vs. firmware-slot vs. service-config vs. backend vs. host-NIC-visibility vs. performance vs. version layers — seven independent layers, each with its own owner | [`## Error taxonomy`](#error-taxonomy) layered split |

Two cross-cutting rules that apply to *every* pattern above:

- **Generation-first, then everything else.** The public
  Virtio-net Service Guide for the operator's DOCA release is
  the authoritative source for which BlueField generations the
  service supports and what their per-generation feature
  surface looks like. An agent that quotes a config knob or a
  container tag before pinning the BF generation against the
  guide will produce answers that may not work, and the
  failure mode is often silent enough that the operator wastes
  long debug cycles. Pin the BF generation BEFORE pinning the
  service version BEFORE quoting any config or container
  detail. This is the same posture the storage-side sibling
  [`doca-snap`](../doca-snap/SKILL.md) enforces, for the same
  reason.
- **Operate the documented path; do not invent one.** The
  service's config schema, container image source, supported
  device-class knobs, sizing bounds, and observability surface
  are all documented in the public DOCA Virtio-net Service
  Guide for the operator's DOCA release. Quoting config keys,
  image tags, PF / VF counts, or CLI flags not in the public
  guide is the most common hallucination failure mode for this
  skill.

## Capabilities and modes

### Service shape

The DOCA Virtio-net Service is a **long-running container** that
ships from NGC and runs on the BlueField Arm cores. The
container is the daemon — it owns the service's control plane,
drives the emulated virtio-net PCIe device (or devices) that the
host sees, and brokers traffic between the host's upstream
`virtio_net` kernel driver and the DPU-side networking backend
running on the BlueField Arm. There is no host-side service
binary the user installs — the service is the container; the
host's relationship to it is to bind the upstream `virtio_net`
kernel driver to the emulated PCIe NIC that the service
exposes.

Three architectural properties the operator must hold throughout:

- **The host sees a real-looking virtio NIC.** The service
  exposes a standard virtio-net device on the BlueField PCIe
  surface; the host enumerates it via `lspci`, the upstream
  `virtio_net` driver binds, and `ip link` shows a new network
  interface. The host does NOT need any service-specific driver
  — that is the load-bearing premise of virtio-net emulation.
  If the host cannot enumerate the device, that is a layer-2
  (firmware-slot) or layer-3 (service-config) symptom, NOT a
  host-driver symptom.
- **The container is the unit of deployment.** Operators do not
  start the service as a host binary; they start the container
  per the public Container Deployment Guide pattern (same shape
  as every other DOCA service container — see the sibling
  [`doca-firefly`](../doca-firefly/SKILL.md) for the same shape
  on a different per-service domain, and the storage-side
  sibling [`doca-snap`](../doca-snap/SKILL.md) for the same
  shape on a *different emulated device class*).
- **The service is built on top of
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  's virtio-net sub-library.** The library is the building
  block; this service is the packaged service. Operators who
  adopt this service get a packaged virtio-net backend and do
  not have to write DPU-side virtio-net code themselves.
  Operators who need a *custom* virtio-net backend that the
  packaged service does not implement should adopt the
  `doca-device-emulation` library's virtio-net sub-library
  directly — see its own
  [`CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-device-emulation/CAPABILITIES.md#capabilities-and-modes)
  for the canonical library-vs-service split.

### BlueField-generation pinning

This is the load-bearing first move. Every deployment must pin
the BlueField generation BEFORE the service version, because the
supported BlueField generations and per-generation feature
surface are documented in the public Virtio-net Service Guide
for the operator's DOCA release. Quoting a service version
before the BF generation is pinned is the single most common
first-deploy mistake — the same anti-pattern documented for the
storage-side sibling [`doca-snap`](../doca-snap/SKILL.md).

| Step | Class shape | Where the answer lives |
| --- | --- | --- |
| 1. Identify the BlueField generation in front of the operator (BlueField-3, BlueField-2, …) | BlueField generation determines which service generation, container-tag namespace, and feature surface apply; routing this *after* picking a version produces silent mismatches | The BlueField identification path in [`doca-setup`](../../doca-setup/SKILL.md) + the operator's hardware inventory |
| 2. Confirm the public Virtio-net Service Guide for the operator's DOCA release names this BlueField generation as supported | Not every BF generation is on the supported list for every DOCA release; the honest answer when the BF generation is unsupported is *"this deployment needs different hardware or a different DOCA release"*, not *"let's try it and see"* | The public DOCA Virtio-net Service Guide for the operator's DOCA release, routed via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services) |
| 3. Quote no config knob, container tag, or capability bound until step 2 is closed | Quoting service-specific detail before pinning the BF generation against the live guide is the canonical first-deploy hallucination failure mode | This skill's own rule, enforced by the safety policy below |

The agent's rule: **never quote a service config knob, container
tag, or per-device sizing bound without first having the
operator confirm the BlueField generation AND reading the
matching public guide entry**. The umbrella URL listed in the
routing table at
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
is the dispatch point — from there, the agent reads the public
Virtio-net Service Guide for the operator's DOCA release to
confirm the supported generations and the per-generation
specifics.

### Deployment shape

The public DOCA Virtio-net Service Guide for the operator's
DOCA release documents the container deployment on BlueField
Arm. The shape lines up with every other DOCA service container
— pull from NGC, mount the config, start under the documented
runtime (the BlueField OS's container manager per the public
Container Deployment Guide). For the canonical
container-deployment recipe shared with the other DOCA service
containers, route through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

Two deployment-shape rules:

- **BlueField Arm only.** The service is a BlueField-side
  artifact; it does not run on the host. The host's
  relationship to the service is via the emulated PCIe NIC
  (which is where the host's `virtio_net` driver binds) and via
  the DPU-side networking backend's own reachability if the
  backend forwards traffic off the BlueField (uplink path).
- **One service container per BlueField, per the documented
  scaling.** The service exposes a documented number of
  emulated virtio-net devices per BlueField — the
  per-deployment scaling lives in the public guide for the
  operator's DOCA release. Running two service containers
  fighting over the same emulated PCIe surface is a
  configuration error, not a redundancy strategy.

### Four-axis configuration

Every deployment must commit to four configuration axes before
starting the container. Get any one wrong and either the
container fails to expose the device, or the host fails to
enumerate it, or every packet fails, or performance is below the
workload's budget. The axes are jointly documented in the public
Virtio-net Service Guide for the operator's DOCA release; quote
the exact valid values from there rather than from memory.

| Axis | Class shape | Mismatch symptom | Where to look |
| --- | --- | --- | --- |
| **Generation** | The BlueField generation (per the BF-generation pinning rule above); determines the supported feature surface, the container-tag namespace, and the per-generation config knobs | Config keys from one generation are silently ignored on another; container appears to start but never exposes a working device | The BF-generation pinning rule above + the public Virtio-net Service Guide for the operator's DOCA release |
| **Emulated device class is virtio-net** | The service emulates virtio-net devices specifically; if the user wants a different emulated class (NVMe namespace, virtio-blk, virtio-fs, raw PCIe), this is the wrong service. Storage classes are owned by [`doca-snap`](../doca-snap/SKILL.md); virtio-fs and PCI Generic are owned by the underlying [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md) library when the user needs a custom backend | Host kernel attempts to bind the wrong driver; or `lspci` shows the wrong device class; or the user is talking about storage but reading networking docs | The library-vs-service split in [`doca-device-emulation CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-device-emulation/CAPABILITIES.md#capabilities-and-modes); the path-selection rule in [`## Safety policy`](#safety-policy) below |
| **Emulated device + queue count** | Number of emulated virtio-net devices and per-device queue depths; bounded by the generation's documented limits in the public guide for the operator's DOCA release | Container runs but exposes a different shape than the operator expected; or performance is below budget because the queue count is wrong for the workload | The public Virtio-net Service Guide for the operator's DOCA release — quote the supported bounds from the live page, not from memory |
| **DPU-side networking backend** | What the emulated NIC's frames actually traverse on the DPU side — the BlueField's uplink path, an OVS bridge owned by the operator on the BlueField, or other DPU-side networking the operator owns | Host sees the NIC but every packet fails because the backend is not wired, the OVS bridge is missing the expected port, or the uplink is down | The public guide's backend section + the backend pairing table below |

The agent's rule: **the four-axis decision precedes everything
else**. A deployment that starts the container before the
operator can name the generation, confirm the emulated class is
actually virtio-net, name the device + queue count, and name
the backend is going to debug the wrong axis first. Force the
decision up front.

### DPU-side networking-backend pairing

The service only emulates the host-facing PCIe NIC; the actual
frames go through a DPU-side backend on the BlueField Arm. Both
sides must be wired; the service alone is not a finished
deployment.

| Backend class | Where the frames physically travel | Reachability surface to confirm |
| --- | --- | --- |
| BlueField uplink path | The BlueField's own uplink interface to the upstream network | The BlueField's uplink reports link-up and reaches its expected upstream peer independently of the service (e.g. an `ip link` + ping from the BlueField Arm itself); the service's config wires the emulated NIC to the documented uplink-facing destination |
| OVS bridge on the BlueField | An Open vSwitch bridge the operator runs on the BlueField Arm, stitching the emulated NIC to other ports the operator owns on the BlueField | The OVS bridge exists, has the expected ports attached, and forwards frames between them independently of the service (the operator's OVS-side `ovs-vsctl show` / `ovs-ofctl dump-flows` reads as expected); the service's config wires the emulated NIC to the documented OVS-facing destination |
| Other DPU-side networking the operator owns | Any other DPU-side dataplane the operator has stood up that the emulated NIC's frames should traverse (e.g. a user-managed forwarding agent on the BlueField Arm) | The operator can confirm the backend processes frames independently of the service container being healthy — service and backend are independent layers; the failure of one does not imply the other is broken |

The agent's rule: when a host-side traffic failure is reported,
check backend reachability *independently* of service container
health before changing any service config. A service container
can be perfectly healthy and the backend can be entirely
unreachable — those are two different layers and conflating them
is the most common runtime debug failure for this service. This
is the same posture the storage-side sibling
[`doca-snap`](../doca-snap/SKILL.md) enforces against its own
backend layer.

### Configuration model

The service container is configured by a documented config file
(or config surface) that the operator mounts into the container
at the path the public guide for the operator's DOCA release
names. The config declares the four-axis configuration (the
emulated device + queue count, the DPU-side backend wiring) plus
any generation-specific advanced knobs the public guide lists.
Quote config keys from the live public DOCA Virtio-net Service
Guide for the operator's DOCA release; do *not* infer them from
generic upstream virtio knowledge — the service's config schema
is documented in the guide and is *not* 1:1 with the upstream
virtio specification.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-
docs rule, see [`doca-version`](../../doca-version/SKILL.md).
The body lives there; this skill does not duplicate it.

**The service-specific overlay** is:

- **The version anchor is generation-bound.** The supported
  BlueField generations and per-generation feature surface
  flow from the public Virtio-net Service Guide for the
  operator's DOCA release. Routing through
  [`doca-version`](../../doca-version/SKILL.md) without first
  pinning the BF generation against the live guide will
  produce mismatched answers.
- **The service is an NGC container; the container tag is the
  runtime version anchor.** Same pattern as the sibling
  [`doca-snap`](../doca-snap/SKILL.md) and the sibling
  [`doca-firefly`](../doca-firefly/SKILL.md) — the container
  ships from NGC with its own tag that may lag the host's DOCA
  package version, and the relevant version anchor for an
  as-deployed service is the container tag pulled, not
  `pkg-config --modversion` on the host. Always quote both
  versions when the user reports a behavior; if they diverge,
  route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before diagnosing the service behavior itself.
- **Read the public DOCA Virtio-net Service Guide version
  header against the container tag.** The on-page version must
  match the container tag the operator is using AND must be
  the right guide for the operator's DOCA release. A mismatch
  between the docs version and the container tag is the
  canonical *"my config does not work even though it matches
  the docs"* failure mode.

## Error taxonomy

Errors fall into seven layers, each with its own owner. The
agent's rule: walk the layers in order; do NOT skip down without
clearing the layer above.

| Layer | Symptom | Root cause class | Where to fix |
| --- | --- | --- | --- |
| 1. Container runtime | Container fails to start, restart-loops, exits immediately, image pull fails | Image tag wrong, registry credentials missing, BlueField runtime not configured to run this container, config file mount path wrong | BlueField container runtime + the public Container Deployment Guide via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md), plus the public Virtio-net Service Guide for the operator's DOCA release for the right tag |
| 2. Firmware-slot precondition | Container starts cleanly on the BlueField, but the host's `lspci` shows no virtio NIC of the expected class | The BlueField firmware virtio-net emulation slot is not enabled, OR was enabled but the BlueField has not been reset since. This is the most common second-time-deploy failure for emulated-device services | [`doca-setup`](../../doca-setup/SKILL.md) for the firmware-side slot enable; the BlueField typically requires a reset after the slot is flipped before the new state takes effect. The agent must surface this as a *firmware-level precondition*, NOT a casual setting |
| 3. Service-config layer | Container green; firmware slot on; host enumerates *something* but it is the wrong shape (wrong number of NICs, wrong queue count, wrong virtio feature subset) | One or more of the four configuration axes (device + queue count, generation-specific schema keys, virtio feature surface) is wrong for the operator's intent | [`## Capabilities and modes`](#capabilities-and-modes) four-axis table; the fix is a config edit + container restart, not a firmware-slot change |
| 4. DPU-side networking-backend reachability | Host enumerates the virtio NIC, host kernel driver binds, but no traffic forwards (or some traffic forwards and some drops) | The DPU-side backend is not wired (OVS bridge missing the port, uplink down, user-managed backend not running), OR the backend type declared in the service config does not match what is actually wired on the BlueField | The backend's own surface — confirm reachability *independently* of the service per the backend pairing table in [`## Capabilities and modes`](#capabilities-and-modes); the service is the conduit, NOT the source of truth for the backend's failures |
| 5. Host-NIC visibility / driver bind | Container green; firmware slot on; service-config correct; backend reachable; but host `lspci` does not see the virtio NIC OR sees it but the `virtio_net` driver does not bind | Either the host kernel does not ship the upstream `virtio_net` driver (or its module is not loaded), OR a virtio feature negotiation between the host driver and the emulated device failed. This layer is host-side, not service-side | Host-kernel fix — load the matching kernel module, or align the feature surface per the public guide for the operator's DOCA release; the service does not provide a host driver |
| 6. Performance layer | Traffic forwards correctly, but throughput / packet rate / latency is below the workload's budget | Wrong queue count for the workload, MTU mismatch between the emulated NIC and the upstream backend, or a backend bottleneck (the uplink saturates first, the OVS bridge's forwarding limit is the cap) | Re-walk the queue-count sizing decision in the four-axis table AND the backend's own performance characteristics; the service cannot exceed the backend's intrinsic ceiling |
| 7. Version / generation mismatch | Behavior diverges from what the documentation says, even though the config *matches* the docs | The docs being read are for a different DOCA release than the running container, OR the container tag is not the one the docs describe, OR the BF generation does not match what the docs were written against | Walk [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 (partial install / version mismatch) and re-confirm the BF-generation pinning in [`## Capabilities and modes`](#capabilities-and-modes) |

The agent's rule: **never recommend a service config change
without first identifying which of the seven layers is the
cause**. The most common debug failures for this skill are
misreading a layer-2 symptom (host does not see the NIC because
firmware slot is off) as a layer-3 problem (service config),
misreading a layer-4 symptom (backend unreachable) as a layer-3
problem, and misreading a layer-5 symptom (host kernel missing
the upstream `virtio_net` driver) as a service-side bug.

## Observability

Documented observability surfaces the agent should reach for,
in order of how cheaply they answer the *"is the service
actually working"* question:

1. **Container state.** First — is the service container
   actually running? The BlueField container manager reports
   container status, restart count, and the container's stdout
   / stderr log stream. A restart loop is a layer-1 (container
   runtime) symptom per [`## Error taxonomy`](#error-taxonomy);
   diagnose it before touching service config.
2. **Host-side `lspci` enumeration.** Does the host see the
   emulated virtio NIC after the service container started?
   `lspci` on the host is the cheapest confirmation that the
   firmware-slot precondition AND the service-side device
   exposure both worked. An empty `lspci` for the expected
   class is *almost always* a layer-2 symptom (firmware slot
   off, or BlueField not reset since the slot was flipped); a
   present-but-wrong-shape device is *almost always* a layer-3
   symptom (service-config wrong).
3. **Host-side `ip link` and `virtio_net` driver bind state.**
   Once `lspci` sees the device, did the host's upstream
   `virtio_net` kernel driver bind to it? `ip link` enumerates
   the resulting network interface; the driver's sysfs /
   debugfs entries plus host `dmesg` around the moment the
   service started are the primary host-side observability. A
   device enumerated but not bound is *almost always* a
   host-kernel issue (driver module not loaded, kernel does not
   ship the matching driver, or virtio feature negotiation
   failed) — that is a host-side fix, NOT a service-side fix.
4. **Service container logs.** The container's stdout (and any
   documented log destination the public guide for the
   operator's DOCA release specifies) is the service's primary
   internal observability surface. Look for the documented
   device bring-up lines and any documented error / warning
   lines. The agent should NOT invent log line formats; quote
   what the live container is emitting.
5. **Backend-side observability.** The service layer logs
   *that* a forwarding operation failed; the backend layer
   logs *why*. For an OVS bridge, that means the operator's
   OVS-side observability (`ovs-vsctl show`,
   `ovs-ofctl dump-flows`, `ovs-appctl dpctl/dump-flows`);
   for the BlueField uplink path, the BlueField Arm's own
   `ip link` / `ethtool` and any operator-side switch reads on
   the upstream port; for a user-managed backend, the
   operator's own observability for that backend. A traffic
   failure that lacks a matching backend-side error is *itself*
   a clue — the frame likely never reached the backend, which
   is usually a layer-3 service-config error rather than a
   layer-4 backend error.
6. **Host-side ICMP round-trip smoke.** Per the smoke-before-
   bulk rule in [`## Safety policy`](#safety-policy), a single
   ICMP round-trip from the host through the emulated NIC to
   a known reachable destination via the DPU-side backend is
   the cheapest end-to-end confirmation that all seven layers
   are wired before any traffic load is layered on top. Defer
   to upstream Linux tooling (`ping`, `ip link`, `ip addr`) for
   the exact form.

For the cross-library debug-time observability
(`DOCA_LOG_LEVEL`, `--sdk-log-level`, the trace build flavor —
relevant when the service calls into a DOCA library that emits
structured logs), see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).

## Safety policy

The safety surface is **path-selection first, generation-first
second, firmware-slot-precondition third, then the
smoke-before-bulk rule, then the operational disciplines around
the container itself**.

- **Path-selection rule (load-bearing).** This service is the
  right answer only when an emulated virtio-net device exposed
  to the host through the BlueField is *actually* required.
  Concretely: use it when the deployment is network
  disaggregation (the host should see a virtio NIC whose
  forwarding is owned by the DPU), bump-in-the-wire host-
  facing NICs whose dataplane runs on the BlueField, or
  security-isolated NICs presented to the host through the
  BlueField PCIe surface. Do NOT reach for it when the host's
  existing networking already meets the workload's needs, when
  the user actually wants standard NIC behavior on the
  BlueField's built-in NIC personality (route to
  [`doca-flow`](../../libs/doca-flow/SKILL.md) and
  [`doca-eth`](../../libs/doca-eth/SKILL.md) instead), or when
  the user needs a *custom* virtio-net backend the packaged
  service does not implement (route to
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  instead). Speculative deployments are how operators end up
  debugging an emulation stack they never needed.
- **Generation-first rule (load-bearing).** Pin the BlueField
  generation BEFORE pinning the service version BEFORE quoting
  any config or container detail. The supported BF generations
  and per-generation feature surface are documented in the
  public Virtio-net Service Guide for the operator's DOCA
  release; an agent that quotes specifics before pinning the
  generation against the live guide will produce answers that
  may not work, and the failure mode is silent enough that the
  operator may waste long debug cycles. This is the same rule
  the storage-side sibling [`doca-snap`](../doca-snap/SKILL.md)
  enforces.
- **Firmware-slot precondition is high-stakes.** The BlueField
  firmware virtio-net emulation slot MUST be enabled before
  the service container can stand up an emulated device
  cleanly. This is *not* a casual setting — flipping the slot
  is firmware-level configuration AND a BlueField reset is
  typically required before the new state takes effect. The
  reset has the usual reset implications (every BlueField
  service hosted on that DPU is restarted; any host workload
  that depends on the BlueField is interrupted). The agent
  must surface the firmware-slot step explicitly and frame the
  reset as a scheduled-maintenance-class operation, not a
  casual command. Routing for the actual firmware-side enable
  lives in [`doca-setup`](../../doca-setup/SKILL.md).
- **Smoke before bulk.** Before pointing any traffic load at
  the emulated NIC, the agent must walk the user through a
  smoke — service container running, host's `lspci` shows the
  virtio NIC, `ip link` enumerates the resulting interface,
  host's upstream `virtio_net` driver bound (no `dmesg` bind
  error), one ICMP from the host through the emulated NIC to
  a known reachable destination via the DPU-side backend
  round-trips successfully. Only then layer the traffic
  workload on top. A workload that comes up before the smoke
  passes silently uses a wrong configuration or a half-wired
  backend, and the bisection across service / backend / host
  is much harder.
- **One service container per BlueField, per the documented
  scaling.** Two service containers fighting over the same
  emulated PCIe surface is a configuration error; the agent
  must NOT recommend it as a redundancy strategy. The
  documented scaling per BlueField is in the public Virtio-net
  Service Guide for the operator's DOCA release; redundancy at
  the network layer is owned by the backend (uplink
  multipathing, OVS-side load distribution, upstream switch
  ECMP), not by spinning up extra service containers.
- **Do not paper over a backend bottleneck.** When the symptom
  is *"traffic works but performance is past spec"* and the
  layer is *"backend is the limit"* per
  [`## Error taxonomy`](#error-taxonomy), the honest answer is
  *"the backend does not deliver the throughput / latency the
  workload asked for; the fix is on the backend, not in the
  service config"*. Silently turning down the user's
  performance expectation, or pretending a service queue-count
  knob can fix a saturated backend, is a user-visible
  regression dressed up as helpfulness.

## Public-source pointer

The single canonical public source for this service is the
**DOCA Virtio-net Service Guide** for the operator's DOCA
release, reachable through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
Verify that the version of the guide matches both the
container tag pulled on the BlueField AND the BlueField
generation in front of the operator — the service's config
surface, supported device classes, and observability output are
documented per DOCA release, so config keys can change between
releases and the supported BF-generation set is pinned by the
guide rather than by the agent's memory.
