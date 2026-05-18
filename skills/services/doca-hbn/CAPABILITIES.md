# DOCA HBN Service — Capabilities

**Where to start:** The pattern overview below names the recurring
HBN-class operational patterns. Pick the pattern first, then drill
into the H2 that owns the substance. For the *how* of executing
each pattern, jump to [TASKS.md](TASKS.md).

This file enumerates HBN's documented capabilities, deployment
shape, configuration axes, and operational behaviors as described
in the public DOCA HBN Service Guide. Treat it as a *map of what
is documented*, not a substitute for reading the live page when
configuring a real deployment. For the public URL itself, route
through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
— this skill does not duplicate the URL routing.

## Pattern overview

Every HBN-class question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
HBN deployment, not just one fabric topology or one tenant scheme.

| HBN pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Decide whether HBN is the right answer | Cloud-DC fabric speaks BGP / EVPN / VXLAN to every NIC OR plain host networking suffices | [`## Safety policy`](#safety-policy) path-selection rule |
| 2. Pick the four configuration axes | BGP + EVPN + VXLAN + host-facing interface — every axis pairs with an upstream-side knob | [`## Capabilities and modes`](#capabilities-and-modes) four-axis table |
| 3. Confirm the upstream fabric is ready | TOR / route reflector configured to peer; matching route targets; underlay multicast or replication available | [`## Safety policy`](#safety-policy) upstream-readiness rule + [`## Capabilities and modes`](#capabilities-and-modes) pairing surface |
| 4. Wire HBN as the BlueField's networking control plane | Container owns the BlueField routing stack; doca-flow is the dataplane programmed under it; host-facing representors carry tenant traffic | [`## Capabilities and modes`](#capabilities-and-modes) deployment shape + control-plane ownership |
| 5. Read HBN's observability surface | Container state + routing-stack status (BGP neighbors, EVPN routes) + dataplane counters | [`## Observability`](#observability) |
| 6. Map an HBN symptom back to its layer | BGP-session vs EVPN-routes vs VXLAN-forwarding vs host-connectivity — four independent layers, each with its own owner | [`## Error taxonomy`](#error-taxonomy) layered split |

Two cross-cutting rules that apply to *every* pattern above:

- **HBN owns the BlueField's networking control plane while it is
  up.** This is the load-bearing posture rule for the whole
  skill: HBN is not a side-car that observes; it is the *active
  control plane* of the BlueField for as long as the container
  runs. Reconfiguring switching topology by hand, programming
  doca-flow rules that conflict with HBN-programmed rules, or
  changing host interface naming under a running HBN can break
  host connectivity. The skill's HIGH-STAKES posture exists
  because of this rule.
- **Operate the documented path; do not invent one.** HBN's
  config schema, container image source, BGP / EVPN / VXLAN
  semantics in the HBN-specific surface, and observability
  output are all documented in the public DOCA HBN Service
  Guide. Quoting config keys, image tags, or routing protocol
  knobs not in the public guide is the most common
  hallucination failure mode for this skill.

## Capabilities and modes

### Service shape

HBN is a **long-running container** that ships from NGC and runs
on the BlueField Arm cores. The container is the daemon: it owns
the routed network virtualization stack (BGP / EVPN / VXLAN) on
the BlueField, programs the BlueField dataplane via doca-flow
internally, and presents the BlueField to the upstream fabric as
a BGP-speaking, EVPN-participating router. There is no host-side
HBN binary the user installs — HBN is the container; the host's
relationship to HBN is that it sees a routed network interface
from the BlueField and treats the BlueField as its L3 gateway.

Three architectural properties the operator must hold throughout:

- **The BlueField becomes a "host router".** From the host's
  point of view, HBN turns the BlueField into a routed L3
  gateway: the host's IPs are advertised to the upstream fabric
  via BGP, host traffic on tenant networks rides VXLAN to other
  endpoints in the EVPN overlay, and the host's L2 broadcast
  domain (where applicable) is stitched into a tenant MAC-VRF.
  This is a fundamentally different shape than *"host runs its
  own networking, BlueField is a passive NIC"*; the agent must
  surface that the change is structural, not cosmetic.
- **The container is the unit of deployment.** Operators do not
  start HBN as a host binary; they start the HBN container per
  the public Container Deployment Guide pattern (same shape as
  every other DOCA service container — see the sibling
  [`doca-firefly`](../doca-firefly/SKILL.md) for the same shape
  on a different per-service domain).
- **HBN owns the control plane; doca-flow is the dataplane it
  rides on.** Inside the container, HBN programs the BlueField
  dataplane through doca-flow (see
  [`doca-flow`](../../libs/doca-flow/SKILL.md)). The user does
  not call `doca_flow_*` for HBN-managed traffic. If the user
  has *their own* doca-flow pipes, those pipes coexist with
  HBN-programmed flows on the same device, and the coexistence
  rules live in the public HBN Service Guide — read them
  before adding any user-managed pipe under a running HBN.

### Deployment shape

The public HBN Service Guide documents the container deployment
on BlueField Arm. The shape lines up with every other DOCA
service container — pull from NGC, mount the config, start
under the documented runtime (the BlueField OS's container
manager per the public Container Deployment Guide). For the
canonical container-deployment recipe shared with the other
DOCA service containers, route through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

Two deployment-shape rules:

- **BlueField Arm only.** HBN is a BlueField-side service; it
  does not run on the host. The host's relationship to HBN is
  via the network (the BlueField acts as the host's L3 gateway
  / BGP peer toward the fabric) and via representor mappings
  that HBN takes over.
- **One HBN per BlueField, owning the BlueField's networking.**
  HBN owns the routing stack for the BlueField as a whole;
  running two HBN containers fighting over the same dataplane
  is a configuration error, not a redundancy strategy.
  Redundancy in this stack is a *fabric-side* concern (multiple
  TORs, route reflectors, ECMP across uplinks) and does not
  require two HBN containers on the same BlueField.

### Four-axis HBN configuration

Every HBN deployment must commit to four configuration axes
before starting the container. Get any one wrong and the
deployment is broken at the corresponding layer of
[`## Error taxonomy`](#error-taxonomy). The axes are jointly
documented in the public HBN Service Guide; quote the exact
valid keys and values from there rather than from memory.

| Axis | Class shape | Mismatch symptom | Where to look |
| --- | --- | --- | --- |
| **BGP** | Local ASN; per-peer remote ASN and peer address; route policies (import / export); optional MD5 / authentication; optional BFD timers | TOR shows the BlueField as `Idle` / `Active`; no neighbor establishes; or BGP up but expected prefixes never advertised because a route policy drops them | Public HBN Service Guide's BGP section |
| **EVPN** | VTEPs (the BlueField's own VTEP IP and the set of remote VTEPs it expects); route targets (import / export) per MAC-VRF / IP-VRF; route distinguishers; MAC-VRFs per tenant; type-2 / type-3 / type-5 route handling per the deployment | BGP up but EVPN AFI/SAFI not negotiated, or zero type-2 routes learned even though the peer is established; or routes arrive but the wrong RT scheme means they are not imported into the right VRF | Public HBN Service Guide's EVPN section |
| **VXLAN** | VNIs per tenant network; underlay replication strategy (multicast group vs head-end / ingress replication); encap policy (DSCP, source-port hashing, MTU) | EVPN routes present but tenant traffic does not forward — the underlay multicast group is not joined, or head-end replication peers do not match the EVPN-learned VTEP list, or MTU is below the inner-frame + VXLAN header size | Public HBN Service Guide's VXLAN section |
| **Host-facing interface** | Which BlueField representors map to which host functions (PF / VF / SF); host VLAN handling (trunked, access, native VLAN); MTU on the host-facing side; what HBN takes over vs what the host keeps | Host loses its default route or its interface name after the deploy because HBN's representor mapping collided with the host's interface naming; or host VLAN tagging mismatches what HBN expects and tenant traffic does not reach the host | Public HBN Service Guide's host-interface section |

The agent's rule: **the four-axis decision precedes everything
else, AND every axis is paired with an upstream-side decision**.
BGP needs the TOR configured to peer back; EVPN needs the route
targets and route reflector ready; VXLAN needs the underlay
multicast or replication peers ready; the host-facing interface
configuration needs the host operator to know which interface
naming will change. A deployment that names only the BlueField
side of any axis will fail at that axis the first time real
traffic hits.

### Pairing with the upstream fabric

HBN is not free-standing — it is the BlueField half of a pair,
and the upstream half lives on the cloud-DC fabric (TOR / route
reflector / fabric controller). Both sides must be wired; HBN
alone is not a finished deployment.

| Upstream side | Why it pairs with HBN | Pairing shape |
| --- | --- | --- |
| TOR (top-of-rack) switch | BGP neighbor of the BlueField; first hop for VXLAN underlay; usually also EVPN peer | TOR configures a BGP neighbor with the BlueField's IP and the agreed ASN scheme; matching MD5 if used; route policy aligned with what HBN advertises |
| Route reflector (RR) | Some EVPN designs use a route reflector instead of, or in addition to, the TOR peering; the BlueField peers BGP with the RR for EVPN AFI/SAFI | RR is configured with the BlueField as a client; EVPN routes are reflected from / to the BlueField across the fabric |
| Underlay multicast / replication peers | EVPN type-2 broadcast / unknown-unicast / multicast (BUM) traffic uses either an underlay multicast group or head-end ingress replication; both sides must agree | Either: the underlay supports the multicast group and the BlueField joins it; or every EVPN endpoint head-end-replicates to every other endpoint's VTEP IP |
| Host (the box behind the BlueField) | The BlueField becomes the host's L3 gateway and presents representor-backed interfaces to the host | Host operator knows which interfaces HBN will own; host config is updated to use the routed interface HBN exposes as its default gateway path |

The agent's rule: when the user describes an HBN deployment, name
the upstream side and the host side in the same breath as the
BlueField side. Naming only the BlueField side is how an HBN
deploy looks "ready" on the BlueField but never establishes a
session because the fabric was never told to peer back.

### Configuration model

The HBN container is configured by a documented config file (or
config bundle) that the operator mounts into the container at the
path the public guide names. The config declares the four-axis
configuration (BGP, EVPN, VXLAN, host-facing interface) plus any
advanced routing knobs the deployment requires (route maps,
prefix lists, BFD timers, MD5 keys, MAC-VRF parameters, RT lists,
VNI-to-VRF maps, replication strategies). Quote config keys from
the live public HBN Service Guide; do not infer them from generic
FRR / Quagga / Cumulus / SONiC knowledge — HBN's config schema is
documented per the public guide and may not be 1:1 with any
upstream routing daemon's config syntax.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-
docs rule, see [`doca-version`](../../doca-version/SKILL.md). The
body lives there; this skill does not duplicate it.

**The HBN-specific overlay** is:

- **HBN is an NGC container; the container tag is the runtime
  version anchor.** Same pattern as
  [`doca-firefly`](../doca-firefly/SKILL.md) and
  [`doca-dms`](../doca-dms/SKILL.md): the HBN container ships
  from NGC with its own tag that may lag the host's DOCA package
  version, and the relevant version anchor for an as-deployed
  HBN is the container tag pulled, not `pkg-config --modversion`
  on the host. Always quote both versions when the user reports
  an HBN behavior; if they diverge, route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before diagnosing the HBN behavior itself.
- **Routing-stack feature support is version-bound.** EVPN
  type-5 handling, specific BGP knobs, replication-strategy
  options, and VRF features evolve between HBN container
  releases. When the user asks *"does this knob work on my
  deployment?"*, the authoritative answer is the public HBN
  Service Guide page whose version matches the container tag
  pulled.
- **Read the public HBN Service Guide version header.** The
  guide is versioned; the on-page version must match the
  container tag the operator is using. A mismatch between the
  docs version and the container tag is the canonical *"my
  config doesn't work even though it matches the docs"*
  failure mode.
- **HBN-vs-doca-flow ABI coupling.** HBN programs the BlueField
  dataplane via doca-flow internally, so the HBN container is
  jointly bound to the doca-flow ABI it was built against and
  the doca-flow runtime present on the BlueField. The agent
  should NOT mix-and-match an old HBN container against a much
  newer DOCA install or vice versa without checking the
  documented compatibility note in the HBN guide.

## Error taxonomy

HBN errors fall into four operational layers plus a container-
runtime and a version layer underneath them. Each layer has its
own owner. The agent's rule: walk the layers in order; do NOT
skip down without clearing the layer above. The four operational
layers correspond 1:1 to the four configuration axes.

| Layer | Symptom | Root cause class | Where to fix |
| --- | --- | --- | --- |
| 0. Container runtime | Container fails to start, restart-loops, exits immediately, image pull fails | Image tag wrong, registry credentials missing, BlueField runtime not configured to run this container, config file mount path wrong | BlueField container runtime + the public Container Deployment Guide via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) |
| 1. BGP session | Container green but no BGP session forms; TOR shows the BlueField as `Idle` / `Active`; or session flaps | Upstream peer unreachable on the underlay; ASN mismatch (local vs remote); MD5 / authentication mismatch; TCP/179 blocked between the BlueField and the peer; route policy rejecting the session on either side | HBN BGP config + upstream TOR / RR BGP config; confirm L3 reachability between the BlueField's source IP and the peer IP first |
| 2. EVPN routes | BGP up, but no EVPN routes learned; or EVPN routes learned but not imported into the right VRF | EVPN AFI/SAFI not negotiated; route targets misconfigured (import / export RT do not match the fabric scheme); route reflector unreachable in RR-based designs; type-2 / type-3 / type-5 handling mismatched between BlueField and fabric | HBN EVPN config + fabric route-target plan; confirm `show bgp evpn summary` on the upstream side names the BlueField as established before suspecting HBN |
| 3. VXLAN forwarding | EVPN routes present and learned correctly, but tenant traffic does not forward across the overlay | Underlay multicast group not joined or not configured fabric-wide; head-end replication peer list does not match the EVPN-learned VTEP list; VTEP IP not reachable on the underlay; MTU too small for inner + VXLAN header; encap policy mismatch (e.g. DSCP rewrite breaking fabric policy) | HBN VXLAN config + fabric underlay (multicast or replication); confirm the underlay can carry traffic between the BlueField's VTEP IP and the remote VTEP before suspecting the overlay |
| 4. Host connectivity | Host loses default route / DNS / SSH after the HBN deploy; host interface naming changed; host VLAN tagging broken | Representor mappings collided with host interface naming; the host's pre-deploy default route assumed an interface HBN took over; host VLAN configuration mismatched what HBN expects on the host-facing side | HBN host-facing interface config + host networking; this is the LOAD-BEARING high-stakes layer — every change to the host-facing axis must be paired with a host-side change agreed with the host operator |
| 5. Version | Public HBN Service Guide page appears to disagree with what the deployed container does | Docs version may not match the container tag; or DOCA install on the BlueField may not match what the HBN container was built against | Walk [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 (partial install / version mismatch) and apply the HBN container-tag overlay from [`## Version compatibility`](#version-compatibility) |

The agent's rule: **never recommend an HBN config change without
first identifying which of the layers is the cause**. The most
common debug failure for this skill is treating a layer-3
symptom (VXLAN underlay broken) as a layer-2 problem (EVPN
config) and rewriting route targets when the fix is on the
underlay multicast group. Confirm one layer before mutating the
next.

## Observability

Documented observability surfaces the agent should reach for, in
order of how cheaply they answer the *"is HBN actually working"*
question:

1. **Container state.** First — is the HBN container actually
   running? The BlueField container manager reports container
   status, restart count, and the container's stdout / stderr
   log stream. A restart loop is a layer-0 (container runtime)
   symptom per [`## Error taxonomy`](#error-taxonomy); diagnose
   it before touching routing config.
2. **HBN's own logs.** The container's stdout (and any
   documented log destination the public guide specifies) is
   the primary HBN observability surface. Look for the routing-
   stack's documented log lines (BGP neighbor state changes,
   EVPN route imports, VXLAN tunnel up/down). The agent should
   NOT invent log line formats; quote what the live container
   is emitting.
3. **BGP neighbor state.** The routing stack inside HBN exposes
   BGP neighbor status (state, prefixes received / advertised,
   last error) per the public HBN Service Guide's documented
   diagnostic surface. Confirm the documented invocation in the
   live guide rather than memorizing one. Cross-check from the
   upstream TOR / RR side — *both* sides must agree the session
   is established.
4. **EVPN route table.** The HBN routing stack exposes the EVPN
   route table (type-2 MAC/IP, type-3 inclusive multicast, type-5
   IP prefix, etc.) per the documented diagnostic surface.
   Confirm the routes the user expects are present and imported
   into the right VRF.
5. **VXLAN tunnel + counter inspection.** The dataplane
   counters HBN exposes (or the doca-flow counters underneath,
   when the HBN guide says so) are the numeric proof that
   tenant traffic is encapsulated and de-encapsulated as
   expected. The agent should defer to the public HBN guide
   for the documented inspection commands rather than memorize
   them.
6. **Upstream-side confirmation.** When the agent suspects a
   layer-1 / layer-2 mismatch, the cheapest confirmation is to
   read the upstream TOR / RR's BGP and EVPN status from the
   fabric side — does the TOR show the BlueField as an
   established neighbor, do the EVPN routes the BlueField
   advertises appear on the upstream side. The agent should
   NOT prescribe TOR / RR commands (vendor-specific); the
   load-bearing point is *"go read the upstream side before
   changing config a fifth time on the BlueField side"*.

For the cross-library debug-time observability
(`DOCA_LOG_LEVEL`, `--sdk-log-level`, the trace build flavor —
relevant when HBN calls into a DOCA library that emits
structured logs), see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).

## Safety policy

HBN's safety surface is **path-selection first**, then the
HIGH-STAKES control-plane-ownership rule, then the upstream-
readiness rule, then the smoke-before-bulk rule, then the
operational disciplines around the container itself.

- **Path-selection rule (load-bearing).** HBN is the right
  answer only when the surrounding fabric is *actually* a
  BGP / EVPN / VXLAN cloud-DC fabric AND the user wants the
  BlueField to participate in it. Concretely:
    - Use HBN when the cloud-DC fabric is leaf-spine with BGP
      to every NIC, the EVPN overlay carries tenant traffic,
      and host workloads need to live inside that overlay. The
      worked example in the targeted prompt (BlueField in a
      leaf-spine EVPN fabric with BGP to the TOR) is the
      canonical case.
    - Do NOT reach for HBN when host-side Linux networking
      suffices for the workload, when the fabric is not BGP /
      EVPN / VXLAN, or for lab / dev workloads where flat L2
      is what the operator actually wants. In those cases the
      right answer is to keep host networking and explicitly
      tell the user *"HBN is the wrong tool here; here's
      why"* — not to deploy it speculatively and end up
      debugging an overlay that was never needed.
- **HIGH-STAKES posture (load-bearing).** HBN takes over the
  BlueField's networking control plane while it is up. A
  misconfigured HBN can:
    - Break BGP advertisement of the host's IPs, so the host
      becomes unreachable from the rest of the fabric.
    - Misroute tenant traffic over the wrong VXLAN VNI, so
      tenants leak into each other.
    - Collide host-facing representor mappings with host
      interface naming, so the host loses its own default
      route or DNS or SSH path during the deploy.
  The agent must teach this posture *before* prescribing any
  config change on a live deployment: every change on a
  production HBN must have a rollback plan (a previous-known-
  good config the operator can re-apply), a maintenance window,
  and a way to reach the BlueField if the host loses
  connectivity (out-of-band management, BlueField console,
  redundant management path). A casual *"just change this
  knob"* answer on a live HBN is a user-visible regression.
- **Upstream-readiness rule (load-bearing).** Every BlueField-
  side config axis pairs with an upstream-side knob. Before
  bringing up HBN on the BlueField, the agent must walk the
  operator through confirming:
    - The TOR (or RR) is configured to peer BGP with the
      BlueField's IP and the agreed ASN.
    - The fabric's EVPN route-target scheme matches what HBN
      will use (or the operator updates one side to match).
    - The underlay supports the chosen VXLAN replication
      strategy (multicast group reachable, or head-end
      replication peers known).
    - The host operator agrees on which host-facing interfaces
      HBN will own and how that affects host networking
      configuration.
  A deployment that goes ahead with the BlueField side and
  *assumes* the upstream side is ready is the canonical *"why
  is BGP not coming up?"* failure mode — the upstream side
  was never told to expect the peer.
- **Smoke before bulk.** Before considering the deployment
  ready, the agent must walk the user through a smoke: HBN
  container running, one BGP session up to the TOR (or RR),
  one EVPN type-2 route learned in the BlueField's EVPN table,
  and one host-to-host overlay ping that exercises the VXLAN
  encap and the host-facing representor mappings. Only then
  is the deployment ready to carry real tenant traffic. A
  deployment that comes up before the smoke passes carries
  traffic over an unproven overlay, and the bisection across
  BGP / EVPN / VXLAN / host is much harder once the fabric
  is in use.
- **Don't paper over a fabric-side problem with HBN config.**
  When the symptom is *"the upstream TOR doesn't peer back"*
  or *"the underlay multicast is broken"*, the honest answer
  is *"the fabric side is the fix; HBN config knobs cannot
  paper over a peer that was never configured"*. Silently
  layering HBN-side workarounds onto a fabric that was never
  configured to participate is a user-visible regression
  dressed up as helpfulness.
- **One HBN per BlueField, owning the networking.** Two HBN
  containers on the same BlueField fighting over the
  dataplane is a configuration error; the agent must NOT
  recommend it as a redundancy strategy. Redundancy in this
  stack is a fabric-side concern (multiple TORs, RRs, ECMP
  uplinks).

## Public-source pointer

The single canonical public source for HBN is the **DOCA HBN
Service Guide**, reachable through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
Verify that the version of the guide matches the HBN container
tag pulled on the BlueField — HBN's config surface, supported
EVPN / BGP knobs, and observability output are documented to
evolve, so config keys and feature support can change between
releases.
