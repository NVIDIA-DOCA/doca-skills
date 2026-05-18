# DOCA SNAP Service — Capabilities

**Where to start:** The pattern overview below names the recurring
SNAP-class operational patterns. Pick the pattern first, then drill
into the H2 that owns the substance. For the *how* of executing each
pattern, jump to [TASKS.md](TASKS.md).

This file enumerates SNAP's documented capabilities, deployment
shape, configuration axes, and operational behaviors as described
in the public DOCA SNAP Service Guide for the operator's
generation. Treat it as a *map of what is documented*, not a
substitute for reading the live page when configuring a real
deployment. For the public URL itself, route through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
— this skill does not duplicate the URL routing.

## Pattern overview

Every SNAP-class question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
SNAP deployment, not just one BlueField generation or one storage
backend.

| SNAP pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Decide whether SNAP is the right answer | Storage-disaggregation / remote-storage-as-local-PCIe / security-isolated storage devices vs. direct local NVMe sufficient or pure compute | [`## Safety policy`](#safety-policy) path-selection rule |
| 2. Pin the BF generation FIRST, then the SNAP version | BlueField-3 → SNAP-4; BlueField-2 → SNAP-3; BlueField-1 → not supported. Different config schemas / API surfaces between generations | [`## Capabilities and modes`](#capabilities-and-modes) BF-generation routing table + [`## Version compatibility`](#version-compatibility) |
| 3. Confirm the firmware-slot precondition is on | The BlueField firmware emulation slot for the chosen device class (NVMe and/or virtio-blk) must be enabled BEFORE the SNAP container can stand up the emulated device cleanly; a BlueField reset is typically required after the slot is flipped | [`## Safety policy`](#safety-policy) firmware-slot rule + [`## Error taxonomy`](#error-taxonomy) layer 2 |
| 4. Pick the four configuration axes | Generation + emulated device type (NVMe namespace vs virtio-blk) + emulated controller / queue count + storage backend type (local NVMe / NVMe-oF / S3 / custom) — every axis is a mismatch hazard | [`## Capabilities and modes`](#capabilities-and-modes) four-axis table |
| 5. Wire and confirm the storage backend | The SNAP container only emulates the host-facing PCIe device; the actual blocks come from a backend on the DPU side (local NVMe behind the BF, NVMe-over-Fabrics initiator on the DPU, S3, custom DPU code). Backend reachability is independent of SNAP container health | [`## Capabilities and modes`](#capabilities-and-modes) backend table + [`## Error taxonomy`](#error-taxonomy) layer 4 |
| 6. Map a SNAP symptom back to its layer | Container-runtime vs. firmware-slot vs. SNAP-config vs. backend-reachability vs. performance vs. version layers — six independent layers, each with its own owner | [`## Error taxonomy`](#error-taxonomy) layered split |

Two cross-cutting rules that apply to *every* pattern above:

- **Generation-first, then everything else.** SNAP-3 and SNAP-4 are
  not interchangeable: they have different config schemas, different
  container tags, different feature surfaces, and run on different
  BlueField generations. An agent that quotes a SNAP-4 config knob
  to a BF-2 operator (or vice versa) will produce a config that
  cannot work, regardless of how careful the rest of the answer is.
  Pin the BF generation BEFORE pinning the SNAP version BEFORE
  quoting any config or container detail.
- **Operate the documented path; do not invent one.** SNAP's config
  schema, container image source, supported device types,
  controller-sizing bounds, and observability surface are all
  documented in the generation-specific public DOCA SNAP Service
  Guide. Quoting config keys, image tags, or CLI flags not in the
  public guide for the operator's generation is the most common
  hallucination failure mode for this skill.

## Capabilities and modes

### Service shape

DOCA SNAP Service is a **long-running container** that ships from
NGC and runs on the BlueField Arm cores. The container is the
daemon: it owns the SNAP control plane, drives the emulated NVMe
or virtio-blk PCIe device that the host sees, and brokers I/O
between the host's kernel driver and the storage backend running
on the DPU side. There is no host-side SNAP binary the user
installs — SNAP is the container; the host's relationship to SNAP
is to bind its standard NVMe (or virtio-blk) kernel driver to the
emulated PCIe device that the SNAP container exposes.

Three architectural properties the operator must hold throughout:

- **The host sees a real-looking storage device.** SNAP exposes an
  NVMe namespace (or virtio-blk device) on the BlueField PCIe
  surface; the host enumerates it via `lspci` and binds its
  upstream kernel driver. The host does NOT need any SNAP-specific
  driver — that is the load-bearing premise of NVMe / virtio-blk
  emulation. If the host cannot enumerate the device, that is a
  layer-2 (firmware-slot) or layer-3 (SNAP-config) symptom, NOT a
  host-driver symptom.
- **The container is the unit of deployment.** Operators do not
  start `snap` as a host binary; they start the SNAP container
  per the public Container Deployment Guide pattern (same shape
  as every other DOCA service container — see the sibling
  [`doca-firefly`](../doca-firefly/SKILL.md) for the same shape on
  a different per-service domain).
- **SNAP is built on top of `doca-device-emulation`.** The library
  is the building block; SNAP is the packaged service. Operators
  who adopt SNAP get a packaged backend (the SNAP-implemented set
  of storage backends) and do not have to write DPU-side
  device-emulation code themselves. Operators who need a *custom*
  backend that SNAP does not implement should adopt the
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  library instead — see its own
  [`CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-device-emulation/CAPABILITIES.md#capabilities-and-modes)
  for the canonical library-vs-service split.

### BlueField-generation to SNAP-version routing

This is the load-bearing first move. Every SNAP deployment must
pin the BlueField generation BEFORE the SNAP version, because the
SNAP generation flows from the BF generation and the two SNAP
generations have different config schemas and image tags. Quoting
a SNAP version before the BF generation is pinned is the single
most common SNAP first-deploy mistake.

| BlueField generation | SNAP generation | Public guide | Notes |
| --- | --- | --- | --- |
| BlueField-3 (primary platform) | SNAP-4 | DOCA-SNAP-4-Service-Guide (route via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)) | The primary supported combination for new deployments. Container tag, config schema, and feature surface come from the SNAP-4 guide |
| BlueField-2 | SNAP-3 (earlier generation) | DOCA-SNAP-3-User-Guide (route via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)) | The earlier generation; config schema and image tag differ from SNAP-4. Operators on BF-2 hardware use SNAP-3, NOT SNAP-4 |
| BlueField-1 | not supported | n/a | BF-1 is not on the supported list for SNAP. The honest answer when the user has BF-1 is *"SNAP does not run on BF-1; the deployment needs different hardware or a different solution"* |

The agent's rule: **never quote a SNAP config knob, container tag,
or API symbol without first having the operator confirm the
BlueField generation**. The two SNAP generations are documented on
*separate guide pages*; the umbrella URL listed in the routing
table at
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
is the dispatch point — from there, the agent picks the
generation-specific guide that matches the operator's BF generation.

### Deployment shape

The public DOCA SNAP Service Guide for the operator's generation
documents the container deployment on BlueField Arm. The shape lines
up with every other DOCA service container — pull from NGC, mount
the config, start under the documented runtime (the BlueField OS's
container manager per the public Container Deployment Guide). For
the canonical container-deployment recipe shared with the other
DOCA service containers, route through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

Two deployment-shape rules:

- **BlueField Arm only.** SNAP is a BlueField-side service; it
  does not run on the host. The host's relationship to SNAP is
  via the emulated PCIe device (which is where the host's NVMe
  or virtio-blk driver binds) and via the storage backend's
  network reachability if the backend is remote (NVMe-oF / S3).
- **One SNAP container per BlueField, per the documented
  scaling.** SNAP exposes a documented number of emulated
  controllers / namespaces / virtio-blk devices per BlueField;
  the per-deployment scaling lives in the generation-specific
  public guide. Running two SNAP containers fighting over the
  same emulated PCIe surface is a configuration error, not a
  redundancy strategy.

### Four-axis configuration

Every SNAP deployment must commit to four configuration axes
before starting the container. Get any one wrong and either the
container fails to expose the device, or the host fails to
enumerate it, or every I/O fails, or performance is below the
workload's budget. The axes are jointly documented in the public
SNAP Service Guide for the operator's generation; quote the exact
valid values from there rather than from memory.

| Axis | Class shape | Mismatch symptom | Where to look |
| --- | --- | --- | --- |
| **Generation** | SNAP-3 (BF-2) vs SNAP-4 (BF-3); the generation determines the config schema, the image tag, and the feature surface | Config keys from one generation are silently ignored by the other; container appears to start but never exposes a working device | The BF-generation routing table above + the generation-specific public SNAP guide |
| **Emulated device type** | NVMe namespace (host sees a standard NVMe device) vs virtio-blk (host sees a virtio block device) | Host kernel attempts to bind the wrong driver; or `lspci` shows the wrong device class; or the controller config keys do not match the device type | The generation-specific public guide's device-type section |
| **Emulated controller / queue count** | Number of emulated NVMe controllers / namespaces / virtio-blk devices and their queue depths; bounded by the generation's documented limits | Container runs but exposes a different shape than the operator expected; or performance is below budget because the queue count is wrong for the workload | The generation-specific public guide's controller-sizing section |
| **Storage backend** | What the emulated device's blocks actually live on: a local NVMe behind the BlueField, an NVMe-over-Fabrics initiator on the DPU pointing at a remote target, an S3 endpoint, custom DPU-side code | Host sees the device but every I/O fails because the backend is unreachable, mistyped (NVMe-oF declared but not connected; S3 credentials missing), or returns a class of error the SNAP layer cannot translate | The generation-specific public guide's backend section + the storage-backend pairing table below |

The agent's rule: **the four-axis decision precedes everything
else**. A deployment that starts the container before the operator
can name the generation, device type, controller count, and backend
is going to debug the wrong axis first. Force the decision up front.

### Storage-backend pairing

SNAP only emulates the host-facing PCIe device; the actual storage
blocks come from a backend that runs on the DPU side. Both sides
must be wired; SNAP alone is not a finished deployment.

| Backend class | Where the data physically lives | Reachability surface to confirm |
| --- | --- | --- |
| Local NVMe behind the BlueField | An NVMe drive physically attached to the DPU | The DPU sees the local NVMe (e.g. via `lsblk` on the BlueField); SNAP's backend config points at that device |
| NVMe-over-Fabrics (NVMe-oF) initiator on the DPU | A remote NVMe target reachable over the network from the DPU | The DPU can reach the remote NVMe-oF target (network layer + NVMe-oF discovery / connect succeeds independently of SNAP); the SNAP container is configured with the documented NVMe-oF subsystem identity |
| S3 endpoint | An S3-compatible object store reachable from the DPU | The DPU can reach the S3 endpoint (network + DNS + auth); the SNAP container is configured with the documented S3 endpoint, bucket, and credentials |
| Custom DPU-side code | A user-implemented backend running on the DPU | The custom backend is running and reachable to the SNAP container per the documented integration surface; this typically implies the operator is *very* close to the [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md) library boundary |

The agent's rule: when a host-side I/O failure is reported, check
backend reachability *independently* of SNAP container health
before changing any SNAP config. A SNAP container can be perfectly
healthy and the backend can be entirely unreachable — those are
two different layers and conflating them is the most common SNAP
runtime debug failure.

### Configuration model

The SNAP container is configured by a documented config file (or
config surface) that the operator mounts into the container at the
path the public guide for the operator's generation names. The
config declares the four-axis configuration (device type,
controller count, backend specification) plus any
generation-specific advanced knobs the public guide lists. Quote
config keys from the live public SNAP Service Guide for the
operator's generation; do *not* infer them from generic NVMe /
virtio-blk knowledge or from the other SNAP generation — the
schemas are documented per generation and are *not* 1:1 between
SNAP-3 and SNAP-4.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The SNAP-specific overlay** is:

- **The version anchor is generation-bound.** SNAP-3 and SNAP-4
  are independently versioned. The operator's BF generation pins
  the SNAP generation; the SNAP generation pins which guide
  page, which container tag namespace, and which config schema
  apply. Routing through
  [`doca-version`](../../doca-version/SKILL.md) without first
  pinning the generation will produce mismatched answers.
- **SNAP is a NGC container; the container tag is the runtime
  version anchor.** Same pattern as the sibling
  [`doca-firefly`](../doca-firefly/SKILL.md): the SNAP container
  ships from NGC with its own tag that may lag the host's DOCA
  package version, and the relevant version anchor for an
  as-deployed SNAP is the container tag pulled, not
  `pkg-config --modversion` on the host. Always quote both
  versions when the user reports a SNAP behavior; if they
  diverge, route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before diagnosing the SNAP behavior itself.
- **Read the public DOCA SNAP Service Guide version header for the
  operator's generation.** Each generation's guide is independently
  versioned; the on-page version must match the container tag the
  operator is using AND must be the right *generation* of guide
  for the BF in front of them. A mismatch between the docs version
  and the container tag — or between the docs *generation* and the
  BF generation — is the canonical *"my config doesn't work even
  though it matches the docs"* failure mode.

## Error taxonomy

SNAP errors fall into six layers, each with its own owner. The
agent's rule: walk the layers in order; do NOT skip down without
clearing the layer above.

| Layer | Symptom | Root cause class | Where to fix |
| --- | --- | --- | --- |
| 1. Container runtime | Container fails to start, restart-loops, exits immediately, image pull fails | Image tag wrong (or wrong-generation tag pulled on a BF the tag was not built for), registry credentials missing, BlueField runtime not configured to run this container, config file mount path wrong, generation-vs-image mismatch on pull | BlueField container runtime + the public Container Deployment Guide via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md), plus the generation-specific public SNAP guide for the right tag |
| 2. Firmware-slot precondition | Container starts cleanly on the BlueField, but the host's `lspci` shows no emulated NVMe / virtio-blk device | The BlueField firmware emulation slot for the chosen device class is not enabled, OR was enabled but the BlueField has not been reset since. This is the most common second-time-deploy failure | [`doca-setup`](../../doca-setup/SKILL.md) for the firmware-side slot enable; the BlueField typically requires a reset after the slot is flipped before the new state takes effect. The agent must surface this as a *firmware-level precondition*, NOT a casual setting |
| 3. SNAP-config layer | Container green; firmware slot on; host enumerates *something* but it's the wrong shape (wrong number of namespaces, wrong device class, wrong queue count) | One or more of the four configuration axes (device type, controller / queue count, generation-specific schema keys) is wrong for the operator's intent | [`## Capabilities and modes`](#capabilities-and-modes) four-axis table; the fix is a config edit + container restart, not a firmware-slot change |
| 4. Storage-backend reachability | Host enumerates the device, host kernel driver binds, but every I/O fails (or fails after a short delay) | The DPU-side backend is not reachable (NVMe-oF target down, S3 endpoint unauthenticated, local NVMe path wrong, custom backend not running), OR the backend type declared in SNAP config does not match what is actually wired | The backend's own surface — confirm reachability *independently* of SNAP per the storage-backend pairing table in [`## Capabilities and modes`](#capabilities-and-modes); SNAP is the conduit, NOT the source of truth for the backend's failures |
| 5. Performance layer | I/O works correctly, but throughput / IOPS / latency is below the workload's budget | Wrong queue count for the workload (queue depth too shallow for the IOPS profile), or a backend bottleneck (the NVMe-oF target is the limit; the local NVMe is saturated; the S3 endpoint's per-request latency is the limit) | Re-walk the controller / queue sizing decision in the four-axis table AND the backend's own performance characteristics; SNAP cannot exceed the backend's intrinsic performance ceiling |
| 6. Version / generation mismatch | Behavior diverges from what the documentation says, even though the config "matches" the docs | The docs being read are for the other SNAP generation than the one running, OR the container tag is not the one the docs describe | Walk [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 (partial install / version mismatch) and re-confirm the BF-generation → SNAP-generation routing in [`## Capabilities and modes`](#capabilities-and-modes) |

The agent's rule: **never recommend a SNAP config change without
first identifying which of the six layers is the cause**. The most
common debug failure for this skill is misreading a layer-2
symptom (host doesn't see the device because firmware slot is off)
as a layer-3 problem (SNAP config) and rewriting the SNAP config
when the fix is in firmware. The second most common is misreading
a layer-4 symptom (backend unreachable) as a layer-3 problem and
rewriting SNAP config when the fix is on the backend.

## Observability

Documented observability surfaces the agent should reach for, in
order of how cheaply they answer the *"is SNAP actually working"*
question:

1. **Container state.** First — is the SNAP container actually
   running? The BlueField container manager reports container
   status, restart count, and the container's stdout / stderr log
   stream. A restart loop is a layer-1 (container runtime) symptom
   per [`## Error taxonomy`](#error-taxonomy); diagnose it before
   touching SNAP config.
2. **Host-side `lspci` enumeration.** Does the host see the
   emulated NVMe / virtio-blk device after the SNAP container
   started? `lspci` on the host is the cheapest confirmation that
   the firmware-slot precondition AND the SNAP-side device
   exposure both worked. An empty `lspci` for the expected class
   is *almost always* a layer-2 symptom (firmware slot off, or
   BlueField not reset since the slot was flipped); a present-but-
   wrong-shape device is *almost always* a layer-3 symptom
   (SNAP-config wrong).
3. **Host kernel driver bind state and `dmesg`.** Once `lspci`
   sees the device, did the host's standard NVMe (or virtio-blk)
   kernel driver bind to it? The matching driver's sysfs / debugfs
   entries plus host `dmesg` around the moment SNAP started are
   the primary host-side observability. A device enumerated but
   not bound is *almost always* a host-kernel issue (driver module
   not loaded; kernel does not ship the matching driver) — that
   is a host-side fix, NOT a SNAP-side fix.
4. **SNAP container logs.** The container's stdout (and any
   documented log destination the public guide for the operator's
   generation specifies) is SNAP's primary internal observability
   surface. Look for the documented controller / namespace
   bring-up lines and any documented error / warning lines. The
   agent should NOT invent log line formats; quote what the live
   container is emitting.
5. **Backend-side observability.** The SNAP layer logs *that* a
   backend operation failed; the backend layer logs *why*. For
   NVMe-oF, that means the DPU-side initiator's logs and the
   remote target's logs; for S3, the DPU-side HTTP / auth log
   and the endpoint's request log; for local NVMe, the DPU-side
   `dmesg` for the local NVMe. A SNAP I/O failure that lacks a
   matching backend-side error is *itself* a clue: the request
   never reached the backend, which is usually a layer-3 SNAP-
   config error rather than a layer-4 backend error.
6. **Host-side I/O round-trip smoke.** Per the smoke-before-bulk
   rule in [`## Safety policy`](#safety-policy), a single trivial
   I/O (e.g. `dd if=/dev/<nvme-namespace> of=/dev/null bs=4k
   count=1` on the host) is the cheapest end-to-end confirmation
   that all six layers are wired before any production workload
   is layered on top.

For the cross-library debug-time observability (`DOCA_LOG_LEVEL`,
`--sdk-log-level`, the trace build flavor — relevant when SNAP
calls into a DOCA library that emits structured logs), see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).

## Safety policy

SNAP's safety surface is **path-selection first, generation-first
second, firmware-slot-precondition third, then the smoke-before-bulk
rule, then the operational disciplines around the container itself**.

- **Path-selection rule (load-bearing).** SNAP is the right answer
  only when storage emulation is *actually* required. Concretely:
  use SNAP when the deployment is storage-disaggregation
  (compute and storage on different nodes; remote storage exposed
  as a local PCIe device to the host; security-isolated storage
  devices presented through the BlueField). Do NOT reach for
  SNAP when a simple local NVMe drive already meets the host's
  storage needs (the host can use that local NVMe directly), when
  the deployment is pure compute, or when the BlueField is
  BlueField-1 (BF-1 is not on the supported list for SNAP). In
  those cases the right answer is to *not* deploy SNAP and tell
  the user explicitly why — speculative SNAP deployments are how
  operators end up debugging an emulation stack they never needed.
- **Generation-first rule (load-bearing).** SNAP-3 and SNAP-4 are
  not interchangeable. Pin the BlueField generation BEFORE pinning
  the SNAP version BEFORE quoting any config or container detail.
  An agent that quotes SNAP-4 config to a BF-2 operator (or vice
  versa) will produce a config that cannot work, and the failure
  mode is silent enough that the operator may waste a long time
  debugging the wrong layer.
- **Firmware-slot precondition is high-stakes.** The BlueField
  firmware emulation slot for the chosen device class (NVMe and/or
  virtio-blk) MUST be enabled before the SNAP container can stand
  up the emulated device cleanly. This is *not* a casual setting:
  flipping the slot is firmware-level configuration AND a BlueField
  reset is typically required before the new state takes effect.
  The reset has the usual reset implications (every BlueField
  service hosted on that DPU is restarted; any host workload that
  depends on the BlueField is interrupted). The agent must surface
  the firmware-slot step explicitly and frame the reset as a
  scheduled-maintenance-class operation, not a casual command.
  Routing for the actual firmware-side enable lives in
  [`doca-setup`](../../doca-setup/SKILL.md).
- **Smoke before bulk.** Before pointing a production storage
  workload at the emulated device, the agent must walk the user
  through a smoke: SNAP container running, host's `lspci` shows
  the device, host kernel driver bound (no `dmesg` bind error), a
  trivial I/O round-trips to the backend (a single 4 KiB read or
  write that returns success). Only then layer the production
  workload on top. A workload that comes up before the smoke
  passes silently uses a wrong configuration or a half-wired
  backend, and the bisection across SNAP / backend / host is
  much harder.
- **One SNAP container per BlueField, per the documented scaling.**
  Two SNAP containers fighting over the same emulated PCIe surface
  is a configuration error; the agent must NOT recommend it as a
  redundancy strategy. The documented scaling per BlueField is in
  the generation-specific public SNAP guide; redundancy at the
  storage layer is owned by the backend (NVMe-oF multipathing,
  S3-side replication, etc.), not by spinning up extra SNAP
  containers.
- **Don't paper over a backend bottleneck.** When the symptom is
  *"I/O works but performance is past spec"* and the layer is
  *"backend is the limit"* per
  [`## Error taxonomy`](#error-taxonomy), the honest answer is
  *"the backend doesn't deliver the throughput / latency you asked
  for; the fix is on the backend, not in SNAP config"*. Silently
  turning down the user's performance expectation, or pretending
  a SNAP queue-count knob can fix a saturated backend, is a
  user-visible regression dressed up as helpfulness.

## Public-source pointer

The single canonical public source for SNAP is the **DOCA SNAP
Service Guide** for the operator's generation, reachable through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
The umbrella entry there points at the SNAP-Services umbrella page;
the generation-specific guides (the SNAP-3 user guide for BF-2 and
the SNAP-4 service guide for BF-3) are the actual content the agent
must read. Verify that the version of the guide matches both the
SNAP container tag pulled on the BlueField AND the BlueField
generation in front of the operator — SNAP's config surface,
supported device types, and observability output are documented
per generation, so config keys can change between the two
generations and between releases within a generation.
