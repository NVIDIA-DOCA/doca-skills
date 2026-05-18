---
name: doca-snap
description: NVIDIA DOCA SNAP Service — long-running container on the BlueField DPU that exposes emulated NVMe / virtio-blk storage to the host while the backend (local NVMe, NVMe-oF, S3, or custom DPU code) runs on the DPU side. Built on doca-device-emulation; targets storage-disaggregation. The agent MUST pin the BF generation FIRST (BF-3 → SNAP-4 / BF-2 → SNAP-3 / BF-1 unsupported; different config schemas and image tags). Container-shaped deployment on BlueField Arm from NGC; firmware-level emulation slot enable is a HIGH-STAKES precondition (a BlueField reset is typically required). Four-axis configuration — generation, emulated device type (NVMe namespace vs virtio-blk), controller / queue count, and storage backend. Layered error taxonomy — container-runtime / firmware-slot / SNAP-config / backend-reachability / performance / version. Smoke-before-bulk — host `lspci` sees the device, the host driver binds, a trivial I/O round-trips, before any production workload.
kind: library
---

# DOCA SNAP Service

**Where to start:** This skill is for *operating* the DOCA SNAP
Service container, not for *linking against* a library. SNAP is the
storage-emulation service that drives an NVMe or virtio-blk device
on the BlueField PCIe surface so the host sees a *standard* storage
device while the actual backend (local NVMe, NVMe-over-Fabrics,
S3, custom DPU code) runs on the BlueField Arm. SNAP is *not* a
host-side daemon, *not* a library a user links against, and *not*
the host kernel driver for NVMe / virtio-blk (the host kernel ships
those). If the user wants to *deploy* the container, open
[`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what
shape of service is SNAP and what storage emulation surfaces does
it speak*, start at [`CAPABILITIES.md`](CAPABILITIES.md). If DOCA
is not installed on the BlueField yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. **Before anything
else, the agent MUST resolve which BlueField generation is in
play** — BlueField-3 runs the SNAP-4 generation; BlueField-2 runs
the earlier SNAP-3 generation; the two have *different* config
schemas and API surfaces, and pinning a SNAP version before pinning
the BF generation is the single most common SNAP first-deploy
mistake. The generation-routing rule lives in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).

## Example questions this skill answers well

The CLASSES of SNAP questions this skill is built to answer, each
with one worked example. The class is the load-bearing piece; the
worked example is one instance.

- **"Do I actually need SNAP, or is plain local NVMe / a non-emulated
  remote target good enough?"** — worked example: *"my host has a
  local NVMe drive that meets my IOPS budget; should I be running
  SNAP at all?"*. Answered by the SNAP-vs-direct-NVMe path-selection
  rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the env-prep checklist in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"Which SNAP version do I pin — SNAP-3 or SNAP-4 — and how does
  that decision flow from the BlueField in front of me?"** — worked
  example: *"I have a BlueField-3 in DPU mode; which SNAP generation
  am I deploying and what does its config look like?"*. Answered by
  the BF-generation routing rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the version-pinning step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"What four configuration axes do I have to decide before starting
  the SNAP container?"** — worked example: *"a storage-disaggregation
  deployment that wants the host to see one NVMe namespace backed by
  an NVMe-oF target on a remote storage node"*. Answered by the
  four-axis configuration table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the SNAP-config step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"My SNAP container starts but the host's `lspci` shows no
  emulated device — what did I miss?"** — worked example: *"container
  reports healthy on the BlueField but the host still doesn't enumerate
  the NVMe namespace"*. Answered by the firmware-slot-precondition
  rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the layered debug ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Host sees the emulated device but every I/O fails — is the
  backend wrong or is the SNAP config wrong?"** — worked example:
  *"`lspci` shows the device, the host's NVMe driver bound, but every
  read returns an error"*. Answered by the storage-backend-vs-config
  split in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"How does SNAP relate to the doca-device-emulation library? Am
  I supposed to write the backend myself, or does SNAP provide it?"**
  — worked example: *"I keep seeing both names; which one do I
  deploy?"*. Answered by the SNAP-vs-device-emulation
  service-vs-library distinction in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the related-skills routing below.

## Audience

This skill serves **external operators and platform teams who deploy
the DOCA SNAP Service container** to provide NVMe-emulation or
virtio-blk-emulation storage to a host whose actual storage backend
runs on the BlueField DPU side. Concretely: people running the SNAP
container on BlueField Arm, choosing the SNAP generation per the
BlueField in front of them (SNAP-3 on BF-2 vs SNAP-4 on BF-3),
configuring the emulated device type (NVMe namespace vs virtio-blk),
sizing emulated controllers and queues, wiring the storage backend
on the DPU side (local NVMe, NVMe-over-Fabrics, S3, custom code),
ensuring the BlueField firmware has the storage-emulation slot
enabled, and validating end-to-end (host enumerates the device, host
driver binds, basic I/O round-trips) before scaling to a production
storage workload.

It is **not** for NVIDIA developers contributing to SNAP itself,
and it is **not** a programming guide for *building applications on
top of* DOCA libraries. SNAP is a **service**, not a library: the
operator runs a container and configures storage emulation via the
documented config surface; they do not link against a `libsnap.so`
to write their own program. If the user wants to *write a custom
storage backend* against the underlying DOCA library rather than
adopt SNAP's packaged backends, the right artifact is
[`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
— SNAP is built on top of that library and is a *separate artifact*
from it.

**Path selection up front.** Use SNAP when the user wants
storage-disaggregation (compute and storage on different nodes;
exposing remote storage as a local PCIe device; security-isolated
storage devices presented to the host through the BlueField PCIe
surface). Do **not** reach for SNAP when a simple local NVMe drive
already meets the host's storage needs (the host can use that local
NVMe directly without any BlueField emulation in the path), when the
deployment is pure compute with no storage emulation requirement,
or when the BlueField is BlueField-1 (BF-1 is not on the supported
list for SNAP). In those cases the right answer is to *not* deploy
SNAP and explicitly tell the user why; deploying SNAP speculatively
is how operators end up debugging a storage emulation stack they
never needed.

## When to load this skill

Load this skill when the user is doing **hands-on SNAP deployment
work** on a BlueField where DOCA is already installed. Concretely:

- Deciding *whether* SNAP is the right answer for the user's
  storage requirement (vs. a direct local NVMe, a host-side
  NVMe-oF initiator with no emulation, or another DOCA service).
- Resolving which BF generation is in play (BlueField-2 vs
  BlueField-3) and therefore which SNAP generation the deployment
  will use (SNAP-3 vs SNAP-4) — *before* pinning a version or
  pulling an image.
- Deploying the SNAP container on BlueField Arm — choosing image
  source per the public DOCA SNAP Service Guide for the operator's
  generation, mounting the SNAP config, starting / stopping the
  container.
- Choosing the four configuration axes — generation, emulated
  device type (NVMe namespace vs virtio-blk), emulated controller
  / queue count, and storage backend (local NVMe / NVMe-oF / S3 /
  custom) — for the user's deployment.
- Verifying the BlueField firmware has the storage-emulation slot
  enabled (this is a *precondition* the agent must surface as
  high-stakes; a BlueField reset is typically required after the
  slot is flipped before the container can be started cleanly).
- Wiring the storage backend on the DPU side so the SNAP container
  has something to back the emulated device with — without this
  step the host enumerates the device but every I/O fails.
- Reading the SNAP container's logs, the emulated device's host-
  side enumeration via `lspci`, the matching kernel driver's bind
  state, or any other documented observability surface.
- Debugging a SNAP deployment where the container is healthy but
  the host does not see the device, or the host sees the device
  but I/O fails, or I/O works but performance is below the
  workload's budget.

Do **not** load this skill for general DOCA orientation, install of
DOCA itself, host-side NVMe / virtio-blk kernel-driver topics
(those ship with the host kernel), the underlying
device-emulation library API (use
[`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
when the user is writing a *custom* backend rather than adopting
SNAP), or non-storage emulation. For those, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or the matching
`libs/<library>` skill.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — SNAP's architecture (container that drives
  an emulated NVMe / virtio-blk PCIe device on the BlueField, with
  the storage backend running on the DPU side), the BF-generation
  to SNAP-version routing rule (BF-2 → SNAP-3, BF-3 → SNAP-4 — the
  two generations have different config schemas), the four
  configuration axes (generation / device type / count / backend),
  the deployment shape (container on BlueField Arm per the public
  Container Deployment Guide), the firmware-slot precondition (the
  BlueField firmware emulation slot must be enabled before any
  SNAP container can stand up an emulated device cleanly; a reset
  is typically required), the relationship to the
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  library that SNAP is built on top of, the storage-backend pairing
  surface (local NVMe / NVMe-oF / S3 / custom), the observability
  surface (container logs + host-side `lspci` + kernel driver bind
  + I/O smoke), the error taxonomy (container-runtime / firmware-
  slot / SNAP-config / backend-reachability / performance / version
  layers), and the safety policy (path selection, generation-first
  rule, firmware-slot reset hazard, smoke-before-bulk).
- `TASKS.md` — step-by-step workflows for the in-scope SNAP verbs:
  `configure`, `build`, `modify`, `run`, `test`, `debug`, plus a
  `Deferred task verbs` block routing out-of-scope questions and a
  `Command appendix` of recurring commands.

The skill assumes a BlueField where DOCA is already installed and
the operator has the privileges the public SNAP Service Guide
expects to pull, run, and configure containers on BlueField Arm.
It does not cover installing DOCA, flipping firmware-level
configuration, or installing host-side kernel drivers — those paths
go through [`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or sample-config
bundle. To keep the boundary clean, it deliberately does not contain
— and pull requests should not add:

- **Pre-baked SNAP configuration files** (full controller / namespace
  config blocks, ready-to-run NVMe-oF subsystem definitions, S3
  bucket bindings, ready-to-run virtio-blk descriptor bundles)
  intended to be copy-pasted into production. SNAP configuration
  is deployment-specific (per the operator's generation, device
  type, controller plan, backend topology, and security posture);
  the safe answer for an external operator is to derive the config
  from the public DOCA SNAP Service Guide for their generation
  against their own deployment. The agent's job is to prescribe
  the *procedure* and the *four-axis decision*, not to ship a
  config the user might run unmodified.
- **Container image names, tags, or registry paths.** The
  authoritative image source is the public DOCA SNAP Service Guide
  for the operator's generation, reachable through
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
  SNAP's image tag is version-bound and changes between DOCA
  releases, AND differs between the SNAP-3 and SNAP-4 generations.
  Inventing or memorizing a tag is the canonical hallucination
  failure mode for a service skill — and is doubly so here because
  the wrong-generation tag will *not* fail loudly: it may pull,
  start, and even appear to load against a BlueField it was not
  intended for, only to misbehave under real workload.
- **Storage-backend bodies** — the SPDK config the DPU side runs,
  the NVMe-oF initiator stanza connecting the DPU to a remote
  target, S3 endpoint credentials, custom backend code. Those are
  user-environment-specific and live outside the SNAP container's
  config surface; the skill names *that* the backend must be wired
  and *what its reachability surface looks like*, not the backend's
  own implementation body.
- **Host-side NVMe / virtio-blk kernel driver configuration.**
  Those drivers ship with the host kernel; the host operator owns
  module loading and tuning. The skill names *that* the host kernel
  must ship and bind the matching driver, and how to read the bind
  state, but it does not author host-kernel config bodies.
- **A `samples/`, `templates/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled *"reference"*, is misleading: operators will read it
  as production-ready.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in
   scope **and** that SNAP is the right answer at all (vs. direct
   local NVMe, a host-side NVMe-oF initiator without emulation, or
   the underlying device-emulation library for a custom backend).
2. **For SNAP's deployment shape, the BF-generation to SNAP-version
   routing rule, the four configuration axes, the firmware-slot
   precondition, the storage-backend pairing surface, the error
   taxonomy, the observability surface, and the safety policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public DOCA SNAP Service Guide and
  the rest of the public DOCA documentation set. SNAP's umbrella
  URL is listed under
  [`## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
  the generation-specific guides (the SNAP-3 user guide and the
  SNAP-4 service guide) live as siblings of that umbrella entry.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation and
  install verification on the BlueField where the SNAP container
  will run, including the *I have no install yet* path via the
  public NGC DOCA container, plus the BlueField-firmware-side
  emulation-slot enable workflow that is SNAP's load-bearing
  precondition. This skill assumes its preconditions are satisfied
  on BlueField Arm and that the firmware emulation slot is on (or
  routes the user there to flip it before continuing).
- [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  — the foundational library SNAP is built on top of. SNAP is the
  *packaged service* a user adopts when they want NVMe / virtio-blk
  storage emulation without writing the backend themselves;
  `doca-device-emulation` is the *building block* a user adopts
  when they want a *custom* backend. The two are intentionally
  different artifacts; do not collapse them. See the library's own
  [`CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-device-emulation/CAPABILITIES.md#capabilities-and-modes)
  library-vs-service path-selection table for the canonical split.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. SNAP's container tag is version-bound
  AND generation-bound; this skill's `## Version compatibility`
  cross-links the four-way match rule and adds the
  generation-vs-version overlay (BF generation pins SNAP
  generation; SNAP generation pins config schema and image tag).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in [TASKS.md](TASKS.md)
  honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA patterns. SNAP is service-shaped not library-
  shaped, so the build / modify / first-app pattern there does
  not apply directly, but the cross-library debug discipline
  (env-before-program; layered diagnosis) remains useful when
  SNAP reports an error that originated in the container runtime
  or in a DOCA library it called internally.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). SNAP-specific debug (host does not see the
  emulated device, host sees device but I/O fails, performance
  below budget) overlays on top of that ladder.
- [`doca-dms`](../doca-dms/SKILL.md) and
  [`doca-firefly`](../doca-firefly/SKILL.md) — sibling service
  skills. The agent reading any of these skills should see the
  *same service-skill shape* (container shipped from NGC, runs on
  BlueField Arm, deployed per the public Container Deployment
  Guide, env preconditions checked first, config mounted as a
  file, smoke-before-bulk applies, container tag is the version
  anchor — not host `pkg-config`) layered on top of a different
  per-service domain (DMS = device management via gNMI / gNOI;
  Firefly = time synchronization via PTP; SNAP = storage
  emulation via NVMe / virtio-blk). The shape generalizes;
  the per-service domain does not.
