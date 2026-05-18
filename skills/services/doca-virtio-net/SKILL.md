---
name: doca-virtio-net
description: NVIDIA DOCA Virtio-net Service — long-running container on the BlueField DPU that exposes one or more emulated virtio-net devices to the x86 host on the BlueField PCIe surface, while the DPU-side networking backend (uplink path, OVS bridge, other DPU-side networking) runs on BlueField Arm. The network analog of DOCA SNAP — SNAP emulates storage, this service emulates networking; built on the virtio-net sub-library of doca-device-emulation. Pin the BF generation FIRST against the public DOCA Virtio-net Service Guide for the operator's DOCA release. Container deployment on BlueField Arm from NGC; firmware virtio-net emulation slot enable is a HIGH-STAKES precondition (BlueField reset typically required). Four axes — BF generation, virtio-net device class, device + queue count, DPU-side backend. Error taxonomy — runtime, firmware-slot, config, backend, NIC visibility, performance, version. Smoke-before-bulk — host `lspci` sees the NIC, `ip link` enumerates it, one ICMP round-trips through the DPU.
kind: library
---

# DOCA Virtio-net Service

**Where to start:** This skill is for *operating* the DOCA
Virtio-net Service container, not for *linking against* a library.
The Virtio-net Service is the networking-emulation service that
drives one or more emulated virtio-net devices on the BlueField
PCIe surface so the x86 host sees a *standard* virtio network
device and binds the upstream `virtio_net` kernel driver, while
the actual DPU-side dataplane (uplink port, OVS bridge, other
DPU-side networking) lives on the BlueField Arm. The service is
*not* a host-side daemon, *not* a library a user links against,
and *not* the host kernel driver for virtio-net (the host kernel
ships that driver). If the user wants to *deploy* the container,
open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what
shape of service is this and what network emulation surface does
it speak*, start at [`CAPABILITIES.md`](CAPABILITIES.md). If DOCA
is not installed on the BlueField yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. **Before anything
else, the agent MUST resolve which BlueField generation is in
play** — the public DOCA Virtio-net Service Guide for the
operator's DOCA release is the authoritative source for which
BlueField generations and feature surface this service supports.
Pinning a configuration before pinning the BF generation is the
single most common first-deploy mistake for emulated-device
services, the same way it is for the storage-side sibling
[`doca-snap`](../doca-snap/SKILL.md).

## Example questions this skill answers well

The CLASSES of Virtio-net Service questions this skill is built to
answer, each with one worked example. The class is the load-bearing
piece; the worked example is one instance.

- **"Do I actually need the DOCA Virtio-net Service, or is the
  host's existing networking good enough?"** — worked example:
  *"the host's built-in NIC already reaches the network it needs;
  should I be standing up an emulated virtio NIC on top of the
  BlueField at all?"*. Answered by the path-selection rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the env-prep checklist in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"Which BlueField generation does this service support and how
  does that pin my config?"** — worked example: *"I have a
  BlueField-3 in DPU mode; what does the public Virtio-net Service
  Guide say about supported generations and what does it imply
  for my config?"*. Answered by the BF-generation pinning rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the version-pinning step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"What configuration axes do I have to decide before starting
  the container?"** — worked example: *"I want one emulated
  virtio-net device exposed to the host, backed by the BlueField's
  DPU networking path"*. Answered by the four-axis configuration
  table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the four-axis-config step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"My service container started but the host's `lspci` shows
  no virtio NIC — what did I miss?"** — worked example: *"the
  service container reports healthy on the BlueField, but the
  host still does not enumerate a new virtio network device"*.
  Answered by the firmware-slot-precondition rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the layered debug ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Host sees the emulated NIC and the driver binds, but no
  traffic forwards — is the DPU-side backend wrong or is the
  service config wrong?"** — worked example: *"`lspci` shows the
  virtio NIC, `ip link` enumerates it, but an ICMP from the host
  never reaches anything outside the BlueField"*. Answered by
  the DPU-networking-backend-vs-config split in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"How does this service relate to the doca-device-emulation
  library? Am I supposed to write the backend myself, or does the
  service provide it?"** — worked example: *"I keep seeing both
  names; which one do I deploy?"*. Answered by the
  service-vs-library distinction in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the related-skills routing below + the same library boundary
  documented in
  [`doca-device-emulation CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-device-emulation/CAPABILITIES.md#capabilities-and-modes).

## Audience

This skill serves **external operators and platform teams who
deploy the DOCA Virtio-net Service container** to provide one or
more emulated virtio-net network devices to a host whose
networking is actually driven from the BlueField DPU. Concretely:
people running the service container on BlueField Arm, confirming
the supported BlueField generation per the public Virtio-net
Service Guide for the operator's DOCA release, sizing the
emulated device and queue count, wiring the DPU-side networking
backend (uplink path, OVS bridge, other DPU-side networking),
ensuring the BlueField firmware has the virtio-net emulation slot
enabled, and validating end-to-end (host enumerates the virtio
NIC, the upstream `virtio_net` kernel driver binds, one ICMP
round-trips through the DPU) before scaling to a real network
workload.

It is **not** for NVIDIA developers contributing to the service
itself, and it is **not** a programming guide for *building
applications on top of* DOCA libraries. The Virtio-net Service is
a **service**, not a library — the operator runs a container and
configures virtio-net emulation via the documented config surface;
they do not link against a `libvirtio-net.so` to write their own
program. If the user wants to *write a custom virtio-net backend*
against the underlying DOCA library rather than adopt the
packaged service, the right artifact is
[`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
— this service is built on top of that library's virtio-net
sub-library and is a *separate artifact* from it.

**Path selection up front.** Use the DOCA Virtio-net Service when
the user wants to expose one or more emulated virtio NICs to a
host while the dataplane runs on the BlueField (network
disaggregation, bump-in-the-wire host-facing NICs whose forwarding
is owned by the DPU, security-isolated NICs presented to the host
through the BlueField PCIe surface). Do **not** reach for this
service when the host's existing networking already meets the
deployment's needs (the host can use its built-in NIC directly
without any BlueField emulation in the path) or when the user
actually wants standard NIC behavior on the BlueField's built-in
NIC personality rather than a *new* emulated virtio NIC — for
the built-in-NIC path, route to
[`doca-flow`](../../libs/doca-flow/SKILL.md) and
[`doca-eth`](../../libs/doca-eth/SKILL.md) instead. In those
cases the right answer is to *not* deploy the Virtio-net Service
and explicitly tell the user why; deploying it speculatively is
how operators end up debugging an emulation stack they never
needed.

## When to load this skill

Load this skill when the user is doing **hands-on Virtio-net
Service deployment work** on a BlueField where DOCA is already
installed. Concretely:

- Deciding *whether* the Virtio-net Service is the right answer
  for the user's networking requirement (vs. plain host-side
  networking, vs. shaping the BlueField's built-in NIC with
  `doca-flow` / `doca-eth`, vs. writing a custom virtio-net
  backend on top of `doca-device-emulation`).
- Resolving which BF generation is in play and confirming the
  service supports it per the public DOCA Virtio-net Service
  Guide for the operator's DOCA release — *before* pinning a
  config or pulling a container image.
- Deploying the service container on BlueField Arm — choosing
  image source per the public guide for the operator's DOCA
  release, mounting the service config, starting and stopping
  the container.
- Choosing the four configuration axes — BF generation, the
  fact that the emulated class is virtio-net (vs the storage
  classes that other emulated-device services own), emulated
  device + queue count, and DPU-side networking backend (uplink
  path, OVS bridge, other DPU-side networking) — for the user's
  deployment.
- Verifying the BlueField firmware has the virtio-net emulation
  slot enabled (a *precondition* the agent must surface as
  high-stakes; a BlueField reset is typically required after the
  slot is flipped before the container can stand up the
  emulated device cleanly).
- Wiring the DPU-side networking backend so the emulated virtio
  NIC has somewhere for its traffic to go — without this step
  the host enumerates the NIC and pings never round-trip.
- Reading the service container's logs, the emulated device's
  host-side enumeration via `lspci` and `ip link`, the matching
  kernel driver's bind state, or any other documented
  observability surface.
- Debugging a deployment where the container is healthy but the
  host does not see the device, the host sees the device but
  no traffic forwards, or traffic forwards but performance is
  below the workload's budget.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, host-side `virtio_net` kernel-driver topics
(those ship with the host kernel), the underlying virtio-net
sub-library API (use
[`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
when the user is writing a *custom* backend), or storage
emulation (route to [`doca-snap`](../doca-snap/SKILL.md)
instead — same shape, different per-service domain). For
anything else, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or the matching
`libs/<library>` skill.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — the service's architecture (container that
  drives one or more emulated virtio-net PCIe devices on the
  BlueField, with the DPU-side networking backend running on the
  BlueField Arm), the BF-generation pinning rule, the four
  configuration axes (generation / emulated class is virtio-net /
  device + queue count / DPU-networking backend), the deployment
  shape (container on BlueField Arm per the public Container
  Deployment Guide), the firmware-slot precondition (the
  BlueField firmware virtio-net emulation slot must be enabled
  before any service container can stand up an emulated device
  cleanly; a reset is typically required), the relationship to
  the [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  library that the service is built on top of, the DPU-side
  networking-backend pairing surface (uplink path, OVS bridge,
  other DPU-side networking), the observability surface
  (container logs + host-side `lspci` and `ip link` + kernel
  driver bind + ICMP smoke), the error taxonomy (container-
  runtime / firmware-slot / service-config / DPU-networking-
  backend / host-NIC-visibility / performance / version layers),
  and the safety policy (path selection, generation-first rule,
  firmware-slot reset hazard, smoke-before-bulk).
- `TASKS.md` — step-by-step workflows for the in-scope verbs —
  `configure`, `build`, `modify`, `run`, `test`, `debug` — plus
  a `Deferred task verbs` block routing out-of-scope questions
  and a `Command appendix` of recurring commands.

The skill assumes a BlueField where DOCA is already installed
and the operator has the privileges the public Virtio-net Service
Guide expects to pull, run, and configure containers on
BlueField Arm. It does not cover installing DOCA, flipping
firmware-level configuration, or installing host-side kernel
drivers — those paths go through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or sample-config
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-baked Virtio-net Service configuration files** (full
  per-device manifests, ready-to-run OVS bridge wiring, virtio
  feature-bit bundles, queue-sizing presets) intended to be
  copy-pasted into production. The service's configuration is
  deployment-specific (per the operator's BF generation, device
  count, queue plan, backend topology, and security posture);
  the safe answer for an external operator is to derive the
  config from the public DOCA Virtio-net Service Guide for the
  operator's DOCA release against their own deployment. The
  agent's job is to prescribe the *procedure* and the
  *four-axis decision*, not to ship a config the user might run
  unmodified.
- **Container image names, tags, or registry paths.** The
  authoritative image source is the public DOCA Virtio-net
  Service Guide for the operator's DOCA release, reachable
  through
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
  the service's image tag is version-bound and changes between
  DOCA releases AND is bound to the BlueField generation the
  guide says is supported. Inventing or memorizing a tag is the
  canonical hallucination failure mode for a service skill —
  and is doubly so here because, as in the storage-side sibling
  [`doca-snap`](../doca-snap/SKILL.md), the wrong-generation tag
  may pull and start without failing loudly.
- **DPU-side networking-backend bodies** — the OVS bridge
  topology the DPU side runs, the per-port uplink configuration,
  the per-tenant VLAN handling, the BlueField's built-in NIC
  configuration. Those are user-environment-specific and live
  outside the service's own config surface; the skill names
  *that* the backend must be wired and *what its reachability
  surface looks like*, not the backend's own implementation
  body.
- **Host-side `virtio_net` kernel driver configuration.** That
  driver ships with the host kernel; the host operator owns
  module loading and tuning. The skill names *that* the host
  kernel must ship and bind the upstream `virtio_net` driver,
  and how to read the bind state, but it does not author
  host-kernel config bodies.
- **Specific PCIe function counts or per-deployment device
  sizing.** The supported per-deployment scaling lives in the
  public Virtio-net Service Guide for the operator's DOCA
  release; quoting a specific PF / VF count from memory bakes
  an instance-shaped detail into the skill and risks a
  silent-mismatch failure mode on a real deployment.
- **A `samples/`, `templates/`, or `reference/` subtree** of
  any kind. A mock or incomplete artifact in this skill's tree,
  even one labeled *"reference"*, is misleading — operators
  will read it as production-ready.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope **and** that the Virtio-net Service is the right
   answer at all (vs. plain host networking, vs. shaping the
   BlueField's built-in NIC, vs. the underlying
   device-emulation library for a custom backend).
2. **For the service's deployment shape, the BF-generation
   pinning rule, the four configuration axes, the firmware-slot
   precondition, the DPU-networking-backend pairing surface,
   the error taxonomy, the observability surface, and the
   safety policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify,
   run, test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public DOCA Virtio-net Service
  Guide and the rest of the public DOCA documentation set. The
  service's URL is listed under
  [`## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
  the public Container Deployment Guide that names the
  canonical container-deployment shape for every DOCA service
  is a sibling entry in the same section.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation
  and install verification on the BlueField where the service
  container will run, including the *I have no install yet*
  path via the public NGC DOCA container, plus the
  BlueField-firmware-side emulation-slot enable workflow that
  is this service's load-bearing precondition. This skill
  assumes its preconditions are satisfied on BlueField Arm and
  that the firmware virtio-net emulation slot is on (or routes
  the user there to flip it before continuing).
- [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  — the foundational library this service is built on top of.
  This service is the *packaged service* a user adopts when
  they want emulated virtio-net networking without writing the
  backend themselves; `doca-device-emulation` (specifically its
  virtio-net sub-library) is the *building block* a user adopts
  when they want a *custom* backend. The two are intentionally
  different artifacts; do not collapse them. See the library's
  own
  [`CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-device-emulation/CAPABILITIES.md#capabilities-and-modes)
  for the canonical library-vs-service path-selection table.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. The service's container tag is
  version-bound AND the supported BlueField generation set is
  pinned by the public guide for the operator's DOCA release;
  this skill's `## Version compatibility` cross-links the
  four-way match rule and adds the container-tag-vs-host-
  package overlay and the BF-generation-vs-version overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's structured-tools precedence rule (detect /
  prefer / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA patterns. This service is service-shaped not
  library-shaped, so the build / modify / first-app pattern
  there does not apply directly, but the cross-library debug
  discipline (env-before-program; layered diagnosis) remains
  useful when the service reports an error that originated in
  the container runtime or in a DOCA library it called
  internally.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). Service-specific debug (host does not see
  the emulated NIC, host sees the NIC but no traffic forwards,
  performance below budget) overlays on top of that ladder.
- [`doca-snap`](../doca-snap/SKILL.md),
  [`doca-firefly`](../doca-firefly/SKILL.md),
  [`doca-hbn`](../doca-hbn/SKILL.md), and the other DOCA
  service skills — sibling service skills. The agent reading
  any of these skills should see the *same service-skill shape*
  (container shipped from NGC, runs on BlueField Arm, deployed
  per the public Container Deployment Guide, env preconditions
  checked first, config mounted as a file, smoke-before-bulk
  applies, container tag is the version anchor — not host
  `pkg-config`) layered on top of a different per-service
  domain. The Virtio-net Service is the *network* analog of
  SNAP — SNAP emulates storage; this service emulates
  networking; both share the firmware-slot precondition,
  BF-generation pinning, and host-facing-PCIe-device exposure
  posture, and both pair with the same
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  library underneath. HBN, Firefly, DMS, and BlueMan do *not*
  share those properties; do not collapse this service into
  them.
