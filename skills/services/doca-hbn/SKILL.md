---
name: doca-hbn
description: NVIDIA DOCA HBN Service (Host-Based Networking) — long-running container on BlueField Arm that runs a routed network virtualization stack (BGP / EVPN / VXLAN) so the BlueField acts as a "host router" between the host and a cloud-DC fabric. BGP advertises the host's IPs to the upstream fabric; EVPN handles tenant overlay networks; VXLAN encapsulates tenant traffic. Container-shaped deployment on BlueField Arm from NGC; four-axis configuration (BGP — ASN, peers, policies; EVPN — VTEPs, RTs, RDs, MAC-VRFs; VXLAN — VNIs, multicast vs head-end replication; host-facing interface — representor mappings, VLAN handling); HIGH-STAKES posture because HBN takes over the BlueField's networking control plane and can break host connectivity if misconfigured; upstream fabric (TOR / route reflector) readiness as a precondition; pairs with doca-flow as the dataplane HBN programs and with doca-switching for the switch topology.
kind: library
---

# DOCA HBN Service (Host-Based Networking)

**Where to start:** This skill is for *operating* the DOCA HBN
Service container, not for *linking against* a library. HBN is the
routed network virtualization stack — BGP, EVPN, VXLAN — that runs
*on* the BlueField and makes the BlueField look like a host router
to the upstream cloud-DC fabric. It is **not** a host-side daemon,
**not** a library you link your own application against, and **not**
a programming surface. If the user wants to *deploy* the container,
open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what
shape of service is HBN and what four-axis configuration does it
expose*, start at [`CAPABILITIES.md`](CAPABILITIES.md). If DOCA
is not installed on the BlueField yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user's
real question is *"can I write doca-flow rules under HBN"*, the
right pairing is this skill **plus**
[`doca-flow`](../../libs/doca-flow/SKILL.md) — HBN programs the
BlueField dataplane via doca-flow internally; the user's own
doca-flow pipes coexist with HBN's programming on the same device
and the coexistence is the part that needs the most care.

## Example questions this skill answers well

The CLASSES of HBN questions this skill is built to answer, each
with one worked example. The class is the load-bearing piece; the
worked example is one instance.

- **"Do I actually need HBN, or is plain host networking good
  enough?"** — worked example: *"my host already speaks BGP on its
  own Linux stack — is there a reason to move that onto the
  BlueField?"*. Answered by the path-selection rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the env-prep checklist in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"What four configuration axes do I have to decide before
  starting the container?"** — worked example: *"a leaf-spine EVPN
  fabric where the BlueField peers BGP with the TOR and carries
  tenant VXLAN overlays for the host"*. Answered by the four-axis
  configuration table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the four-axis-config step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"HBN is running but I have no BGP session — what did I
  miss?"** — worked example: *"container green, but the TOR shows
  the peer as `Idle` / `Active` and the session never comes up"*.
  Answered by the BGP-layer of the error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered debug ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"BGP is up but no EVPN routes are learned — where did the
  overlay break?"** — worked example: *"`show bgp evpn summary` on
  the TOR shows the BlueField as an established peer, but no
  type-2 / type-3 routes are received"*. Answered by the EVPN
  layer of the error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in [`TASKS.md ## debug`](TASKS.md#debug).
- **"EVPN routes are present but tenant traffic doesn't
  forward — what's wrong with the dataplane?"** — worked example:
  *"the BlueField has the right MAC-VRF, VNI, and VTEPs but a
  ping across the overlay drops"*. Answered by the
  VXLAN / underlay-replication layer of the error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in [`TASKS.md ## debug`](TASKS.md#debug).
- **"After I deployed HBN, my host can't reach the network at
  all — how do I roll back safely?"** — worked example: *"host
  interface name collided with the representor mapping HBN took
  over and the host lost its default route"*. Answered by the
  host-connectivity layer of the error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the rollback step in [`TASKS.md ## debug`](TASKS.md#debug) +
  the high-stakes rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).

## Audience

This skill serves **external operators and platform teams who
deploy the DOCA HBN Service container** to put a BlueField into a
modern cloud-DC fabric — leaf-spine, BGP-everywhere, EVPN overlay,
VXLAN-encapsulated tenant traffic. Concretely: people running the
HBN container on BlueField Arm, choosing its BGP / EVPN / VXLAN /
host-interface configuration from the public HBN Service Guide,
wiring the BlueField as a BGP peer of the upstream TOR (or route
reflector), validating one EVPN route and one overlay ping before
they roll the deployment out across a fleet, and recovering when
something goes wrong without losing host connectivity in the
process.

It is **not** for NVIDIA developers contributing to HBN itself,
and it is **not** a programming guide for *building applications
on top of* DOCA libraries (that is
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
plus the matching `libs/<library>` skill). HBN is a **service**,
not a library: the operator runs a container and configures the
routing stack via the documented config surface; they do not link
against a `libhbn.so` to write their own program.

**Path selection up front.** Use HBN when deploying a BlueField in
a cloud-DC fabric that already speaks BGP / EVPN / VXLAN — i.e.,
the TOR is configured to peer BGP with every NIC, the fabric has
an EVPN overlay, and host workloads need to participate in tenant
networks carried over VXLAN. Do **not** reach for HBN when host-
side Linux networking suffices, when the fabric is not BGP / EVPN,
or for lab / dev workloads where flat L2 is what the operator
actually wants. In those cases the correct answer is *"keep the
host's existing networking; HBN is the wrong tool here"* — not
*"deploy HBN speculatively and debug the overlay"*.

## When to load this skill

Load this skill when the user is doing **hands-on HBN deployment
work** on a BlueField where DOCA is already installed.
Concretely:

- Deciding *whether* HBN is the right answer for the user's
  fabric and workload (vs. keeping plain host networking).
- Deploying the HBN container on BlueField Arm — choosing image
  source per the public DOCA HBN Service Guide, mounting the HBN
  config, and starting / stopping the container.
- Choosing the four configuration axes — BGP (local ASN, peer
  addresses, route policies, optional MD5 / authentication),
  EVPN (VTEPs, route targets, route distinguishers, MAC-VRFs),
  VXLAN (VNIs, multicast underlay vs head-end replication, encap
  policy), and the host-facing interface configuration
  (representor mappings, host VLAN handling) — for the user's
  deployment.
- Confirming the upstream fabric is *actually ready* — TOR
  configured to peer the BlueField, EVPN route targets aligned,
  underlay multicast or replication ready — *before* the
  BlueField-side deployment, because every config knob on the
  BlueField is paired with one on the upstream side.
- Smoke-testing a fresh HBN deployment with one BGP session up,
  one EVPN type-2 route learned, and one host-to-host overlay
  ping — *before* layering real workloads on it.
- Reading the HBN container's logs and the routing-stack's own
  observability surface (BGP / EVPN / dataplane counters) to
  confirm the stack is healthy.
- Debugging an HBN deployment where the container is healthy but
  no BGP session forms, BGP is up but EVPN routes do not arrive,
  EVPN routes are present but the overlay does not forward, or
  the host has lost networking after the deploy.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, library-API questions, or non-HBN networking
topics (host Linux networking, OVS, generic Linux PTP, …). For
those, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or the matching
`libs/<library>` skill.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — HBN's architecture (container that owns the
  BlueField's networking control plane and programs the BlueField
  dataplane via doca-flow internally), the four configuration
  axes (BGP, EVPN, VXLAN, host-facing interface), the deployment
  shape (container on BlueField Arm per the public Container
  Deployment Guide), the pairing surface (upstream fabric / TOR /
  route reflector and the doca-flow / doca-switching libs HBN
  rides on), the observability surface (container logs + routing-
  stack status + dataplane counters), the error taxonomy (four
  independent layers: BGP session / EVPN routes / VXLAN
  forwarding / host connectivity), and the safety policy
  (path-selection up front, HIGH-STAKES posture because HBN
  takes over the control plane, upstream-fabric readiness as a
  precondition, smoke-before-bulk).
- `TASKS.md` — step-by-step workflows for the in-scope HBN
  verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`,
  plus a `Deferred task verbs` block routing out-of-scope
  questions and a `Command appendix` of recurring commands.

The skill assumes a BlueField where DOCA is already installed and
the operator has the privileges the public HBN Service Guide
expects to pull, run, and configure containers on BlueField Arm.
It does not cover installing DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or sample-config
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-baked HBN configuration files** (full BGP / EVPN / VXLAN
  config blocks, ready-to-run route-policy bundles, MAC-VRF
  templates) intended to be copy-pasted into production. Routing
  configuration is deployment-specific (per the user's ASN plan,
  route-target scheme, VNI plan, host VLAN handling) and the
  safe answer for an external operator is to derive the config
  from the public DOCA HBN Service Guide against their own
  deployment. The agent's job is to prescribe the *procedure*
  and the *four-axis decision*, not to ship a config the user
  might run unmodified — a wrong route policy can blackhole a
  whole rack.
- **Container image names, tags, or registry paths.** The
  authoritative image source is the public DOCA HBN Service
  Guide reachable through
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services);
  HBN's image tag is version-bound and changes between DOCA
  releases. Inventing or memorizing a tag is the canonical
  hallucination failure mode for a service skill.
- **Upstream TOR / route-reflector config snippets.** Those are
  network-side artifacts owned by the operator's fabric team and
  live on the switch, not inside the HBN container. The skill
  names *that* the upstream side must be wired and *what its
  shape must be* (BGP neighbor configured to peer the BlueField,
  matching route targets, underlay multicast / replication
  configured); the switch-side config body belongs to the fabric
  vendor's documentation.
- **A `samples/`, `templates/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled *"reference"*, is misleading: operators will read
  it as production-ready and apply a wrong route policy to a
  live fabric.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope **and** that HBN is the right answer at all (vs.
   keeping plain host networking).
2. **For HBN's deployment shape, the four configuration axes,
   the upstream-fabric pairing surface, the error taxonomy, the
   observability surface, and the HIGH-STAKES safety policy,
   see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public DOCA HBN Service Guide and
  the rest of the public DOCA documentation set. The HBN URL is
  listed under
  [`## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation
  and install verification on the BlueField where the HBN
  container will run, including the *I have no install yet*
  path via the public NGC DOCA container. This skill assumes
  its preconditions are satisfied on BlueField Arm.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. HBN's container tag is
  version-bound; this skill's `## Version compatibility`
  cross-links the four-way match rule and adds the
  container-tag-lags-host-package overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect /
  prefer / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-flow`](../../libs/doca-flow/SKILL.md) — the dataplane
  library HBN programs under the hood. The user does not call
  `doca_flow_*` for HBN-managed traffic, but understanding the
  pipe / match / action model from `doca-flow` is what makes
  HBN's dataplane counters and traces interpretable. If the
  user wants their *own* doca-flow pipes to coexist with
  HBN-managed traffic, the coexistence rules live in the HBN
  Service Guide and the agent must teach them before
  programming anything on top.
- [`doca-switching`](../../libs/doca-switching/SKILL.md) — the
  switching-topology library HBN may program as part of its
  setup. HBN may interact with the BlueField switch topology
  (representor enumeration, switching-table primitives) on the
  way to delivering tenant overlays; the agent should NOT
  reprogram switching topology by hand under a running HBN
  unless the HBN guide explicitly says so — HBN owns the
  control plane while it is up.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA patterns. HBN is service-shaped not library-
  shaped, so the build / modify / first-app pattern there does
  not apply directly, but the cross-library debug discipline
  (frontend-before-backend, env-before-program) remains useful
  when HBN reports an error that originated in the container
  runtime or in a DOCA library it called.
- [`doca-firefly`](../doca-firefly/SKILL.md),
  [`doca-dms`](../doca-dms/SKILL.md),
  [`doca-blueman`](../doca-blueman/SKILL.md) — sibling service
  skills. The agent reading multiple service skills should see
  the same service-shape (container, BlueField Arm,
  Container-Deployment-Guide pattern, env-preconditions checked
  first, config mounted as a file, smoke-before-bulk) layered
  on top of a different per-service domain. HBN's *shape* is
  the same as Firefly / DMS / BlueMan; HBN's *posture* is
  distinct in two ways the agent must surface — HBN takes over
  the BlueField's networking control plane (so it is
  HIGH-STAKES on a live deployment) and HBN is coupled to an
  external upstream fabric (the TOR / route reflector must be
  ready before the BlueField-side deploy succeeds).
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). HBN-specific debug (no BGP session, no
  EVPN routes, no overlay forwarding, host lost connectivity)
  overlays on top of that ladder.
