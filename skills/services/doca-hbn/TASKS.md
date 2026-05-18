# DOCA HBN Service — Tasks

**Where to start:** The order is `configure → build → modify → run →
test → debug`. The `## test` verb is an iterative loop, not a
one-shot pass — see the eval-loop overlay in `## test` below. For
HBN, `build` and `modify` are about *deployment configuration*
(container image selection, mounted config file, upstream-fabric
pairing, host-facing interface plan), not about compiling source.

These verbs cover the in-scope HBN operational workflows for an
external operator deploying the HBN container on BlueField. Every
step assumes the operator has consulted the live public DOCA HBN
Service Guide (reachable through
[doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services))
and is using it as the authoritative reference; this file
prescribes the *order* and *what to look up where*, not a
copy-paste runbook.

## configure

Preparing the BlueField, choosing the four configuration axes, and
confirming the upstream fabric is ready *before* the container
starts. This is also the verb where the HIGH-STAKES posture is
established up front — every later verb assumes the operator has
read it here.

1. **Confirm HBN is actually the right answer.** Per the
   path-selection rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
    - Is the surrounding fabric a BGP / EVPN / VXLAN cloud-DC
      fabric, with TOR / RR configured (or being configured) to
      peer BGP with every NIC?
    - Do the host's workloads need to live inside the EVPN
      overlay (tenant networks, multi-tenancy)?
    - Is the agent (and the user) prepared for HBN to take over
      the BlueField's networking control plane?
    - If any answer is *no*, stop here and tell the user
      honestly: keep host-side Linux networking, *do not* deploy
      HBN speculatively. HBN-on-a-flat-L2-network is a deploy
      that costs more than it earns.
2. **Confirm the env is healthy.** This skill expects DOCA to be
   installed on the BlueField. If that has not been verified,
   run [`doca-setup ## test`](../../doca-setup/TASKS.md#test)
   first. If the user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path.
3. **Confirm the upstream fabric is ready (LOAD-BEARING).** Per
   the upstream-readiness rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   and the pairing surface in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   walk the user through:
    - The TOR (or RR) is configured to peer BGP with the
      BlueField's source IP, on the agreed ASN scheme, with any
      MD5 / authentication / BFD configuration matched on both
      sides.
    - The fabric's EVPN route-target scheme is agreed with the
      operator deploying the BlueField — either the BlueField
      will use the fabric's existing RT plan, or the fabric is
      updated to accept the BlueField's RTs.
    - The underlay supports the chosen VXLAN replication
      strategy (multicast group joinable on the underlay, or
      head-end replication peers known to both sides).
    - The host operator knows which host-facing interfaces HBN
      will own and has agreed how that affects the host's own
      networking configuration (default route, DNS, SSH, host
      VLAN handling).
   A deployment where the upstream side has not been confirmed
   is a deployment where BGP will not come up — there is no
   point starting the container before this step is closed.
4. **Decide the four configuration axes.** Per the four-axis
   table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   commit before starting the container to:
    - **BGP** — local ASN; per-peer remote ASN and peer
      address; route policies (import / export);
      MD5 / authentication if used; BFD timers if used. Must
      match what the TOR / RR is configured for.
    - **EVPN** — VTEPs (local VTEP IP and the set of remote
      VTEPs); route targets (import / export) per MAC-VRF /
      IP-VRF; route distinguishers; MAC-VRFs per tenant; how
      type-2 / type-3 / type-5 routes are handled. Must match
      the fabric's RT plan.
    - **VXLAN** — VNIs per tenant network; replication strategy
      (multicast group vs head-end / ingress replication);
      encap policy (DSCP, source-port hashing, MTU). Must match
      the underlay.
    - **Host-facing interface** — which BlueField representors
      map to which host functions; host VLAN handling; MTU.
      Must match what the host operator has agreed to.
5. **Plan the rollback path (HIGH-STAKES).** Because HBN takes
   over the BlueField's networking control plane, every deploy
   on a live BlueField must have:
    - The pre-deploy host-networking state captured (default
      route, interface names, IP assignments).
    - The previous-known-good HBN config (or a no-HBN baseline)
      ready to re-apply.
    - An out-of-band way to reach the BlueField if the host
      loses connectivity (BlueField console, redundant
      management path, IPMI to the host).
    - A maintenance window agreed with whoever uses the host.
   This step is not optional on a production deployment; the
   agent should refuse to walk a live deploy without it.
6. **Author the HBN container config.** From the public DOCA
   HBN Service Guide, derive the config bundle for the chosen
   BGP / EVPN / VXLAN / host-facing configuration. Quote config
   keys from the live guide, do NOT infer them from generic
   FRR / Quagga / Cumulus / SONiC knowledge. Plan where the
   config will live on the BlueField filesystem and what mount
   path the container expects.

## build

HBN is a service shipped as a container, not a library. There is
no HBN *application* artifact for the operator to build — the
container ships from NGC and the config is a static file (or
bundle).

If the user is asking how to build a **routing-stack client** in
their own language (e.g. an application that talks to HBN's
routing surface), that is not an HBN question:

- For applications that **read EVPN or BGP state** from HBN,
  the documented surface is the routing stack's own diagnostic
  interface inside the container, not a library the user links
  against. Route to the public DOCA HBN Service Guide via
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).
- For applications that **program packet steering** on the same
  BlueField, that is the
  [`doca-flow`](../../libs/doca-flow/SKILL.md) library, but the
  user must read the HBN-vs-doca-flow coexistence rules in the
  HBN guide *before* programming any pipe that could conflict
  with HBN's own dataplane programming.

If the user is instead asking how to build the **HBN container
itself** from source, that is *not* an external-operator workflow
— the container ships pre-built from NGC and rebuilding it is
out of scope for this skill. Route to the public DOCA HBN Service
Guide via
[doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).

## modify

HBN does not have a "modify a sample" workflow analogous to DOCA
libraries; there is no HBN sample program a user starts from. The
HBN analog of "modify" is **adapt the documented container config
recipe to the user's environment** — and on a live deployment,
*every* modification must respect the HIGH-STAKES posture from
[`## configure`](#configure) step 5.

1. **Start from the documented recipe.** Identify the public
   guide's recipe that matches the user's fabric pattern
   (leaf-spine BGP-everywhere, RR-based EVPN, multicast or
   head-end replication, host-VLAN handling). Quote it; do not
   author a new one from scratch.
2. **Diff against the user's environment.** Note the specific
   substitutions the user must make: local ASN, peer
   addresses, EVPN route targets, route distinguishers,
   per-tenant VNIs, replication peer addresses (for head-end),
   host-facing representor mappings, MTU, container image tag
   (always pulled from NGC per the public guide).
3. **Apply minimum-change.** Change only what the user's
   environment forces. Every additional deviation from the
   documented recipe widens the surface for an unintended
   routing mismatch the operator will have to debug later —
   and in HBN's case, *"debug later"* can mean *"recover from
   broken host connectivity later"*.
4. **Re-validate against the four-axis table.** Each
   substitution is a chance to accidentally break one of the
   four axes (BGP / EVPN / VXLAN / host-facing). Walk
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   one row at a time after every substitution.
5. **Re-validate the upstream pairing.** Per the upstream-
   readiness rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   any change that affects what the BlueField advertises or
   accepts (peers, RTs, VNIs, replication peers) is a paired
   change on the upstream side. Update both together or the
   session / route / forwarding will break the moment the new
   config takes effect.
6. **Re-validate the host-side plan.** Any change to the
   host-facing axis (representor mappings, host VLAN handling,
   MTU on the host-facing side) is a paired change with the
   host operator. Apply the host-side change first, or at the
   same maintenance window, or be ready to roll back fast.

The agent's anti-pattern alert: a *"start from a generic FRR /
Cumulus / SONiC routing config and adapt"* is almost always
slower than starting from the public HBN Service Guide's recipe,
because the HBN config schema is documented per the public guide
and is not 1:1 with any upstream routing daemon's syntax.

## run

Bringing up the HBN container and confirming the routing stack
reaches a healthy state at each layer, *before* layering any real
tenant traffic on top. Every step here assumes the prerequisites
in [`## configure`](#configure) are done — including the upstream-
readiness check and the rollback plan.

1. **Pull the HBN container image from NGC** at the tag the
   public HBN Service Guide names for the operator's DOCA
   release. Quote the tag from the live guide; do NOT memorize
   or invent the tag.
2. **Start the container per the public Container Deployment
   Guide pattern.** Mount the HBN config bundle at the path
   the public HBN Service Guide names. The runtime command
   shape (e.g. the BlueField container manager's start
   command) is documented in the Container Deployment Guide
   reachable through
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
3. **Confirm the container is running, not restart-looping.**
   A restart loop is a layer-0 symptom per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   (container runtime / image tag / config mount); diagnose
   it before touching routing config.
4. **Watch the HBN container's logs for the BGP session
   transitions.** The container's stdout is the primary
   observability surface. The BGP neighbor state should
   advance from `Idle` / `Active` to `Established` against
   each configured peer within the timeline the public guide
   describes for the chosen BGP / BFD configuration. If the
   neighbor never establishes, the symptom is at layer 1 of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   — *cross-check the upstream side* before mutating HBN
   config.
5. **Confirm EVPN routes are learned.** Read HBN's EVPN
   route-table view per the documented diagnostic surface in
   the public HBN Service Guide. Expect type-2 (MAC/IP) and
   type-3 (inclusive multicast) routes for the configured
   MAC-VRFs and tenants the deployment expects to participate
   in. Zero EVPN routes despite an established BGP session is
   a layer-2 symptom.
6. **Confirm host-facing interface state.** Per the
   host-facing axis from
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   confirm:
    - The host still has its own management connectivity
      (out-of-band or otherwise) — if not, *stop and roll
      back*; this is the layer-4 host-connectivity failure
      mode and it must be repaired before anything else.
    - The host-facing representors map to the host functions
      the operator expected.
    - Host VLAN tagging and MTU on the host-facing side match
      what HBN expects.
7. **Single-event smoke (next: `## test` step 1).** Before
   carrying real tenant traffic, walk `## test` step 1 once to
   confirm one EVPN type-2 route is learned and one
   host-to-host overlay ping crosses the VXLAN; only then
   layer real workloads on top.

For the runtime version + container-tag cross-checks that
underlie *"my HBN behaves differently from what the docs say"*,
see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run)
and apply the container-tag-lags-host-package overlay from
[`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).

## test

HBN has no "compile and unit-test" workflow — testing is
operational, end-to-end, and HIGH-STAKES.

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation (BGP knob change, EVPN RT change, VXLAN replication
change, host-facing axis change) re-opens the smoke sweep.
Skipping the re-run after a mutation is the failure mode this
loop replaces — and on HBN the cost of the failure mode is
broken host connectivity, not just *"weird traffic"*.

The eval-loop overlay (rows apply to every HBN deployment, not
just one fabric pattern):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | Step 4 (host-connectivity check) often reveals an as-deployed gap in the host-facing axis or in the upstream pairing; loop back to step 1 | [`## test`](#test) step 4 |
| 2 → ## debug | When the BGP smoke does NOT advance the neighbor to `Established`, the deployment is non-functional — escalate to `## debug` layer 1 immediately, do not run later steps | [`## debug`](#debug) |
| 3 → ## configure → 3 | When the EVPN smoke does not learn the routes the operator expected, the upstream-readiness step is incomplete — loop back to `## configure` step 3 and re-walk the upstream side | [`## configure`](#configure) |
| 1..5 → ## run | Each loop iteration ends with a smoke; if all five pass, hand off to live `## run` traffic | [`## run`](#run) |

The agent's rule: every mutation re-opens the sweep. A
configuration change followed by *"it probably still works"* is
exactly the failure mode the iterative loop is here to prevent,
and on HBN the failure can blackhole a rack.

1. **End-to-end smoke (the recommended HBN smoke).** With the
   container running, confirm in this order:
    1. The BGP session to the TOR (or RR) is `Established`
       per HBN's neighbor view AND per the upstream side's
       neighbor view.
    2. At least ONE EVPN type-2 route is learned for the
       MAC-VRFs the deployment expects.
    3. ONE host-to-host overlay ping that exercises the VXLAN
       encap and the host-facing representor mappings
       succeeds (e.g. between two hosts that both sit behind
       BlueFields participating in the same tenant VNI).
    4. The host's own management connectivity (default
       route / DNS / SSH) is still intact.
   This is the documented smoke — BGP up, EVPN type-2
   learned, overlay ping crossing — and only after all four
   pieces pass is the deployment ready for bulk tenant
   traffic.
2. **Four-axis smoke.** Confirm the negative case to validate
   the operator's understanding of the four-axis rule: pick
   ONE axis (e.g. temporarily change the EVPN route-target
   import so it no longer matches the fabric scheme) and
   confirm HBN's EVPN route table loses the affected routes
   exactly as the four-axis table predicts. Restore the
   correct value afterwards. This is also the operator's
   evidence that the layer-2 vs layer-3 split in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   is real on their specific fabric.
3. **Upstream-pairing smoke.** Read the upstream TOR / RR's
   view of the BlueField (BGP neighbor state, EVPN routes
   advertised by the BlueField) and confirm it agrees with
   HBN's own view. A divergence between the two sides is a
   layer-1 / layer-2 symptom that no amount of HBN-side knob
   twiddling will fix.
4. **Host-connectivity smoke.** Specifically validate the
   host side: the host still has its expected default route,
   the expected DNS / SSH paths still work, host VLAN
   tagging on the host-facing side behaves as expected.
   This is the smoke that catches the layer-4 failure mode
   before it costs the operator their SSH session.
5. **Capability snapshot.** Save the *as-deployed* answer to:
   which HBN container tag is running, which local ASN /
   peer ASN / RTs / VNIs / replication strategy / host-facing
   mappings are in effect, what the steady-state BGP and
   EVPN tables look like, what the host's interface and
   routing-table state is. This snapshot is the artifact that
   lets future debug sessions skip rediscovery — and on HBN,
   it is the rollback baseline.

## debug

Layered diagnosis. Walk the layers in this order; do not skip
down without clearing the layer above. The layers match
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).

1. **Container-runtime layer (layer 0).** Is the HBN container
   actually running and not restart-looping? Symptoms:
   container exits immediately, image pull fails, restart
   count climbing. Resolution: confirm the image tag matches
   what the public guide names for the operator's DOCA
   release; confirm the config mount path matches what the
   public guide names; confirm BlueField has the runtime
   configured per the public Container Deployment Guide.
   This layer is owned by the container runtime, not by
   routing config.
2. **BGP-session layer (layer 1).** Container green; no BGP
   session forms; TOR shows the BlueField as `Idle` /
   `Active`; or the session flaps. Resolution:
    - Confirm L3 reachability on the underlay between the
      BlueField's source IP and the peer IP (ping, traceroute)
      — if the underlay is broken, the session cannot form.
    - Walk the BGP-config row of the four-axis table in
      [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes):
      local ASN, remote ASN, peer address, MD5, BFD timers.
    - Read the upstream TOR / RR side. A divergence between
      what HBN expects and what the upstream side is
      configured for is the most common cause here.
3. **EVPN-routes layer (layer 2).** BGP up, but no EVPN
   routes learned, or learned but not imported into the
   right VRF. Resolution:
    - Confirm the EVPN AFI/SAFI is negotiated for the session
      (look at HBN's neighbor capability view and the
      upstream-side capability view).
    - Walk the EVPN row of the four-axis table: route
      targets (import / export), RDs, MAC-VRFs, type-2 /
      type-3 / type-5 handling.
    - For RR-based designs, confirm the RR is reachable and
      actually reflecting the BlueField's advertisements
      back to it.
4. **VXLAN-forwarding layer (layer 3).** EVPN routes present
   and learned correctly, but tenant traffic does not
   forward across the overlay. Resolution:
    - Confirm the underlay can carry traffic between the
      BlueField's VTEP IP and the remote VTEP (ping the
      underlay, check MTU is sufficient for inner + VXLAN
      header).
    - For multicast-based underlay: confirm the multicast
      group is joined and reachable fabric-wide.
    - For head-end replication: confirm the EVPN-learned
      VTEP list matches the replication peer list HBN is
      actually using.
    - Walk the VXLAN row of the four-axis table: VNIs,
      replication strategy, encap policy.
5. **Host-connectivity layer (layer 4) — HIGH-STAKES.** Host
   loses default route / DNS / SSH after the HBN deploy, or
   host interface naming has changed in unexpected ways.
   Resolution:
    - **First: preserve out-of-band access** before mutating
      anything further. BlueField console, IPMI, or any
      other out-of-band path is the operator's lifeline
      here.
    - If the host has lost networking entirely and the
      operator cannot recover it: roll back to the previous-
      known-good HBN config (or no-HBN baseline) per the
      rollback plan from
      [`## configure`](#configure) step 5.
    - Once recovered: walk the host-facing axis of the
      four-axis table; identify which representor mapping
      collided with the host's interface naming or which
      VLAN handling broke the host's default route. Apply
      the host-side change and the HBN-side change as a
      paired update in the next maintenance window.
6. **Version layer (layer 5).** When the public HBN Service
   Guide page appears to disagree with what the deployed
   container does, the docs version may not match the
   container tag. Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 (partial install / version mismatch) and apply
   the container-tag overlay from
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
7. **Cross-cutting layer.** For env-side and program-side
   debug that is not HBN-specific (host install, host
   kernel, DOCA library errors HBN may surface from the
   doca-flow dataplane underneath), drop to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).

## Command appendix

HBN-specific commands the verbs above reach for, grouped by
purpose so the agent picks the right family without searching
prose. Every row is a class — the agent must not invent flags
beyond what the row names; flag and command discovery is
`--help` on the installed tool or the public guide, not prose
recall.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env
   --json` for version + devices + libraries + drivers +
   hugepages in one shot; the BlueField container manager's
   structured status output when available).
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
| Container lifecycle | The BlueField container manager's start / stop / status command for the HBN container, per the public Container Deployment Guide | [`## run`](#run) | Container `running`, restart count stable. |
| Container logs | The BlueField container manager's log-stream command for the HBN container | [`## debug`](#debug) layers 0 + 1 + 2 | BGP neighbor transitions visible; no documented error / warning lines repeating. |
| BGP neighbor state | The HBN routing stack's documented BGP-neighbor-status command (quote the exact form from the public HBN Service Guide) | [`## run`](#run) step 4; [`## debug`](#debug) layer 1 | Each configured peer reports `Established`; prefix counts advance as expected. |
| EVPN route inspection | The HBN routing stack's documented EVPN-route-table command (per the public HBN Service Guide) | [`## run`](#run) step 5; [`## debug`](#debug) layer 2 | Expected type-2 / type-3 / type-5 routes present and imported into the right VRFs. |
| Underlay reachability | `ping` / `traceroute` between the BlueField's VTEP IP and a remote VTEP (defer to upstream Linux networking docs for the exact form) | [`## debug`](#debug) layer 1 + 3 | Underlay path responds; latency / loss consistent with the fabric's baseline. |
| Host-side connectivity check | The host's own routing / interface tooling (`ip route`, `ip -j link`, `ip -j addr`, the host's `resolv.conf` / DNS test) — owned by the host operator | [`## run`](#run) step 6; [`## debug`](#debug) layer 4 | Host has its expected default route, interfaces, and DNS / SSH path intact. |
| Upstream pairing check | The upstream TOR / RR's BGP and EVPN status commands — vendor-specific, owned by the fabric team | [`## test`](#test) step 3; [`## debug`](#debug) layers 1 + 2 | Upstream side reports the BlueField as established and accepts the routes the BlueField advertises. |
| Container tag in use | The BlueField container manager's image-inspect command for the running HBN container | [`## run`](#run) step 1; [`## debug`](#debug) layer 5 | Tag matches what the public HBN Service Guide names for the operator's DOCA release. |

Three cross-cutting rules for this appendix:

- **Never invent an HBN config key, container tag, or routing
  command.** The public HBN Service Guide is the contract;
  upstream Linux networking tooling and the fabric vendor's
  documentation are the secondary sources for the cross-
  cutting underlay and TOR-side commands HBN reuses. Prose-
  derived flags are the most common hallucination failure for
  this skill — and on HBN the wrong invented flag can
  blackhole a rack.
- **Container before routing; underlay before overlay.** When
  triaging, confirm the container layer (running, not restart-
  looping, image tag correct) before reading any routing-
  layer command. Then confirm BGP before EVPN, EVPN before
  VXLAN. A non-running container or a broken underlay makes
  every higher-layer command meaningless.
- **Cross-link instead of duplicate.** Cross-cutting env
  commands (port-state, `devlink`, `ip link`, `ethtool`) live
  in
  [`doca-setup TASKS.md ## Command appendix`](../../doca-setup/TASKS.md#command-appendix);
  this appendix names only the HBN-specific ones.

## Deferred task verbs

- **Installing DOCA on the BlueField** — out of scope here.
  Route to
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  for env preparation and
  [`doca-setup ## test`](../../doca-setup/TASKS.md#test) for
  install health verification, or
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path.
- **Configuring the upstream fabric** (TOR BGP neighbor, RR
  setup, underlay multicast, EVPN RT plan) — out of scope
  here. The HBN contract is *that* the upstream side must be
  configured to pair with the BlueField; the upstream side's
  own config body is owned by the operator's fabric team and
  by the switch vendor's documentation, not by this skill.
- **Designing the EVPN topology** (where to place route
  reflectors, which tenants get which VNIs, RT scheme across
  the fabric, replication strategy at fabric scale) — out of
  scope here. That is a fabric-architect concern that the
  operator owns; HBN consumes the topology decision rather
  than designing it.
- **Programming a user-managed doca-flow pipe under a running
  HBN** — out of scope here as a primary workflow. Route to
  [`doca-flow ## modify`](../../libs/doca-flow/TASKS.md#modify)
  for the pipe-creation pattern, but the user must FIRST read
  the HBN-vs-doca-flow coexistence rules in the public HBN
  Service Guide so their pipes do not collide with HBN's own
  programming. Reprogramming switching topology under a
  running HBN routes through
  [`doca-switching ## modify`](../../libs/doca-switching/TASKS.md#modify)
  with the same coexistence warning — HBN owns the control
  plane while it is up.
- **Other DOCA services** (DMS / DTS / BlueMan / Firefly /
  Flow-Inspector / Argus / …) — not HBN. Route to
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services)
  for the routing table and the matching `services/<service>`
  skill when it exists (e.g.
  [`doca-firefly ## configure`](../doca-firefly/TASKS.md#configure)
  for PTP time sync,
  [`doca-dms ## configure`](../doca-dms/TASKS.md#configure)
  for device management). The container-shaped deployment
  pattern is shared; the per-service domain is different.

## Cross-cutting

- The public DOCA HBN Service Guide is the single source of
  truth. Any config key, BGP / EVPN / VXLAN knob, container
  tag, or observability output the agent quotes must come
  from there, not from generic FRR / Cumulus / SONiC / Linux-
  routing knowledge.
- HBN is HIGH-STAKES because it owns the BlueField's
  networking control plane. Every change on a live deployment
  must have a rollback plan, a maintenance window, and an
  out-of-band path to recover the BlueField if host
  connectivity breaks. Casual *"just change this knob"*
  answers are not acceptable on a production HBN.
- Path-selection is mandatory up front. HBN is the wrong
  answer when host-side Linux networking suffices, when the
  fabric is not BGP / EVPN / VXLAN, or for lab / dev
  workloads where flat L2 is enough.
- Upstream readiness is a precondition, not a follow-up.
  Every BlueField-side config axis pairs with an upstream-
  side knob; deploying without confirming the upstream side
  is the canonical *"BGP never comes up"* failure mode.
- Smoke before bulk. The documented smoke (BGP up, one EVPN
  type-2 learned, one host-to-host overlay ping) goes before
  any real tenant traffic, never after.
- For URL routing to the HBN guide and other public DOCA
  documentation, see
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).
