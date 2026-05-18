# DOCA Virtio-net Service — Tasks

**Where to start:** The order is `configure → build → modify →
run → test → debug`. The `## test` verb is an iterative loop,
not a one-shot pass — see the eval-loop overlay in `## test`
below. For this service, `build` and `modify` are about
*deployment configuration* (container image selection, the
four-axis config bundle, firmware-slot precondition, DPU-side
networking-backend wiring), not about compiling source.

These verbs cover the in-scope operational workflows for an
external operator deploying the Virtio-net Service container on
BlueField. Every step assumes the operator has consulted the
live public DOCA Virtio-net Service Guide for the operator's
DOCA release (reachable through
[doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services))
and is using it as the authoritative reference; this file
prescribes the *order* and *what to look up where*, not a
copy-paste runbook.

## configure

Preparing the BlueField, pinning the BF generation, confirming
the firmware-slot precondition, deciding the four configuration
axes, and wiring the DPU-side networking backend *before* the
container starts. This is also the verb where the HIGH-STAKES
posture (firmware-slot reset, host-facing NIC exposure) is
established up front — every later verb assumes the operator
has read it here.

1. **Confirm the service is actually the right answer.** Per
   the path-selection rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
    - Is the deployment genuinely network disaggregation — the
      host should see a virtio NIC whose dataplane is owned by
      the DPU rather than by the host?
    - Or bump-in-the-wire — a host-facing NIC whose forwarding
      runs on the BlueField rather than the host stack?
    - Or security-isolated — a NIC whose policy is controlled
      by DPU-side code rather than by the host?
    - If the answer is *none of those* (the host's existing
      networking already meets the workload, the user actually
      wants to shape the BlueField's built-in NIC personality
      with [`doca-flow`](../../libs/doca-flow/SKILL.md) +
      [`doca-eth`](../../libs/doca-eth/SKILL.md), or the user
      needs a *custom* backend the packaged service does not
      implement and should adopt
      [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
      instead), stop here and tell the user honestly — *do
      not* deploy this service speculatively.
2. **Confirm the env is healthy.** This skill expects DOCA to
   be installed on the BlueField. If that has not been
   verified, run
   [`doca-setup ## test`](../../doca-setup/TASKS.md#test)
   first. If the user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path.
3. **Pin the BlueField generation FIRST (LOAD-BEARING).** Per
   the BF-generation pinning rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   confirm with the operator which BlueField is in front of
   them, then confirm against the public DOCA Virtio-net
   Service Guide for the operator's DOCA release that this
   generation is on the supported list. Quote no config knob,
   container tag, or per-device sizing bound before this step
   is closed. The honest answer when the BF generation is
   unsupported on the operator's DOCA release is *"this
   deployment needs different hardware or a different DOCA
   release"*, not *"let's try it and see"*.
4. **Confirm the firmware-slot precondition (HIGH-STAKES).**
   Per the firmware-slot rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   and layer 2 of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy),
   walk the operator through:
    - The BlueField firmware virtio-net emulation slot must be
      **enabled** before the service container can stand up an
      emulated device cleanly. This is firmware-level
      configuration, not a container-runtime setting.
    - A BlueField reset is **typically required** after the
      slot is flipped before the new state takes effect. Frame
      this as a scheduled-maintenance-class operation — every
      BlueField service hosted on that DPU restarts, any host
      workload that depends on the BlueField is interrupted.
    - Route the firmware-side enable workflow itself to
      [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
      — this skill names the *precondition*; it does not
      author firmware-tool flags.
   A deployment where the firmware slot has not been confirmed
   is a deployment that will start the container, look healthy
   on the BlueField, and never expose a NIC to the host.
   There is no point starting the container before this step
   is closed.
5. **Decide the four configuration axes.** Per the four-axis
   configuration table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   commit before starting the container to:
    - **Generation** — pinned in step 3; determines the
      supported feature surface, the container-tag namespace,
      and the per-generation config knobs.
    - **Emulated device class is virtio-net** — confirm with
      the user that they actually want virtio-net rather than
      a storage class (route to
      [`doca-snap`](../doca-snap/SKILL.md) for emulated
      storage) or virtio-fs / PCI Generic (route to
      [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
      for custom backends in those classes). The host kernel
      driver that will bind is the upstream `virtio_net`.
    - **Emulated device + queue count** — the number of
      emulated virtio-net devices to expose to the host and
      their queue depths, bounded by the documented limits in
      the public guide for the operator's DOCA release. Wrong
      count = wrong shape exposed; wrong queue depth =
      performance below budget for the workload.
    - **DPU-side networking backend** — the BlueField uplink
      path, an OVS bridge owned by the operator on the
      BlueField Arm, or other DPU-side networking the operator
      owns. Without this axis the host will enumerate the NIC
      and every packet will fail.
6. **Wire and confirm the DPU-side networking backend.** Per
   the backend pairing table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the service container only emulates the host-facing PCIe
   NIC; the actual frames go through the DPU-side backend.
   Walk the operator through:
    - Uplink path → the BlueField's uplink interface reports
      link-up and reaches its expected upstream peer
      independently of the service (e.g. `ip link` + `ping`
      from the BlueField Arm); the service config wires the
      emulated NIC to the documented uplink-facing
      destination.
    - OVS bridge → the bridge exists, has the expected ports
      attached, and forwards frames between them independently
      of the service (the operator's own
      `ovs-vsctl show` / `ovs-ofctl dump-flows` reads as
      expected); the service config wires the emulated NIC to
      the documented OVS-facing destination.
    - Other DPU-side networking → the operator confirms the
      backend processes frames independently of the service
      container — service and backend are independent layers.
   Backend reachability is independent of service container
   health; conflating them is the most common runtime debug
   failure for this service.
7. **Plan the rollback path (HIGH-STAKES).** Because this
   service exposes a network device to the host and the
   firmware-slot precondition may require a BlueField reset,
   every deploy on a live BlueField must have:
    - The pre-deploy BlueField firmware state captured (which
      emulation slots were on / off before the operator
      changed anything).
    - The previous-known-good service config (or a
      no-virtio-net-service baseline) ready to re-apply if the
      new config misbehaves.
    - An out-of-band way to reach the BlueField if the reset
      takes longer than expected or the BlueField does not
      come back cleanly (BlueField console, redundant
      management path, IPMI to the host that hosts the
      BlueField).
    - A maintenance window agreed with whoever uses the host —
      because exposing a new network device to a running host
      AND potentially resetting the BlueField is not a casual
      operation.
   This step is not optional on a production deployment; the
   agent should refuse to walk a live deploy without it.
8. **Author the service container config.** From the public
   DOCA Virtio-net Service Guide *for the operator's DOCA
   release*, derive the config bundle for the chosen device +
   queue count / backend. Quote config keys from the live
   guide; do NOT infer them from generic upstream virtio
   knowledge or from a different DOCA release. Plan where the
   config will live on the BlueField filesystem and what mount
   path the container expects.

## build

This service is shipped as a container, not a library. There is
no service *application* artifact for the operator to build —
the container ships from NGC and the config is a static file
(or bundle). There is no `libvirtio-net.so` for a user to link
against and no `pkg-config --libs doca-virtio-net` form to
consume.

If the user is asking how to build a **custom virtio-net
backend** that the packaged service's surface does not cover,
that is not a service question — it is a library question
against
[`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md):

- For applications that **implement a custom virtio-net
  emulation backend on the DPU**, the build is the DOCA
  library's build — route to
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the canonical build pattern and to
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  for the API surface (the virtio-net sub-library
  specifically). The packaged service and
  `doca-device-emulation` are intentionally separate artifacts
  (service vs library); do not collapse them.
- For applications that **read the service-exposed NIC from
  the host**, no DOCA-specific build is needed — the host's
  upstream `virtio_net` kernel driver binds to the emulated
  PCIe NIC, and host-side applications use standard socket /
  netlink APIs. That is upstream Linux, not DOCA.

If the user is instead asking how to build the **service
container itself** from source, that is *not* an
external-operator workflow — the container ships pre-built from
NGC and rebuilding it is out of scope for this skill. Route to
the public DOCA Virtio-net Service Guide for the operator's
DOCA release via
[doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).

## modify

This service does not have a "modify a sample" workflow
analogous to DOCA libraries; there is no sample program a user
starts from. The analog of "modify" here is **adapt the
documented container config recipe to the user's environment**
— and on a live deployment, every modification must respect the
HIGH-STAKES posture from [`## configure`](#configure) step 7.

1. **Start from the documented recipe.** Identify the public
   guide's recipe (in the DOCA Virtio-net Service Guide for
   the operator's DOCA release) that matches the user's
   device + queue count and backend class. Quote it; do not
   author a new one from scratch.
2. **Diff against the user's environment.** Note the specific
   substitutions the user must make — number and identity of
   emulated devices, queue counts, backend-specific
   parameters (uplink interface name on the BlueField, OVS
   bridge / port names for an OVS-backed deployment,
   user-managed backend integration surface), config file
   path, container image tag (always pulled from NGC at the
   tag the public guide for the operator's DOCA release
   names).
3. **Apply minimum-change.** Change only what the user's
   environment forces. Every additional deviation from the
   documented recipe widens the surface for an unintended
   mismatch the operator will have to debug later — and on
   this service, the wrong axis hides a silently-broken
   network path.
4. **Re-validate against the four-axis table.** Each
   substitution is a chance to accidentally break one of the
   four axes (generation / virtio-net device class / device +
   queue count / DPU-side backend). Walk
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   one row at a time after every substitution.
5. **Re-validate against the BF-generation pinning.** Any
   change that changes the container image tag (e.g. a DOCA
   release bump) must still match what the public guide for
   the new DOCA release says about the supported BF generation
   set. A tag that pulls but was not built for this BF
   generation may start and look healthy without working.
6. **Re-validate the backend pairing.** Any change to the
   backend axis (uplink moved, OVS topology changed,
   user-managed backend redeployed) is a paired change on the
   backend's own surface. Update the backend's reachability
   *and* the service's config together, not one after the
   other.

The agent's anti-pattern alert: a *"start from a generic
virtio-net or upstream OVS config and adapt"* is almost always
slower than starting from the public DOCA Virtio-net Service
Guide for the operator's DOCA release, because the service's
config schema is documented per release and is not 1:1 with
upstream virtio or upstream OVS tooling.

## run

Bringing up the service container, confirming the firmware-slot
precondition surfaces a NIC, and confirming the host sees a
working virtio NIC *before* layering any traffic load on top.
Every step here assumes the prerequisites in
[`## configure`](#configure) are done — including the
BF-generation pinning, the firmware-slot enable, and the
rollback plan.

1. **Pull the service container image from NGC** at the tag
   the public DOCA Virtio-net Service Guide for the operator's
   DOCA release names. Quote the tag from the live guide *for
   the operator's DOCA release*; do NOT memorize or invent the
   tag — and do NOT pull a tag the public guide does not
   match-name against the BF generation in front of the
   operator.
2. **Start the container per the public Container Deployment
   Guide pattern.** Mount the service config bundle at the
   path the public Virtio-net Service Guide for the operator's
   DOCA release names. The runtime command shape (the
   BlueField container manager's start command) is documented
   in the Container Deployment Guide reachable through
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
3. **Confirm the container is running, not restart-looping.**
   A restart loop is a layer-1 symptom per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   (container runtime / image tag / config mount); diagnose
   it before touching service config or firmware. A
   wrong-DOCA-release image tag pulled against the wrong
   BlueField is a particularly load-bearing layer-1 failure
   here — the pull may succeed silently but the container
   will not behave.
4. **Watch the service container's logs for the documented
   device bring-up lines.** The container's stdout is the
   service's primary internal observability surface. Look for
   the documented bring-up sequence in the public guide for
   the operator's DOCA release and for any documented error /
   warning lines. The agent should NOT invent log line
   formats; quote what the live container is emitting.
5. **Confirm host-side enumeration on `lspci`.** The host
   should see a new virtio NIC on the BlueField PCIe surface.
   If `lspci` shows nothing of the expected class, the symptom
   is layer 2 of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   (firmware-slot precondition) — NOT a service-config issue.
   Re-walk [`## configure`](#configure) step 4 before mutating
   service config.
6. **Confirm the upstream `virtio_net` driver binds and `ip
   link` enumerates the interface.** Once `lspci` sees the
   device, the host's upstream `virtio_net` kernel driver
   should bind to it; `ip link` should show a new network
   interface. Read the driver's sysfs entries plus host
   `dmesg` around the moment the service started. A device
   enumerated but not bound is *almost always* a host-kernel
   issue (driver module not loaded, kernel does not ship the
   matching driver, or virtio feature negotiation failed),
   which is a host-side fix outside this service's boundary.
7. **Single-event smoke (next: `## test` step 1).** Before
   driving any traffic load, walk `## test` step 1 once to
   confirm one ICMP round-trips through the DPU end-to-end;
   only then layer the traffic workload on top.

For the runtime version + container-tag cross-checks that
underlie *"the service behaves differently from what the docs
say"*, see
[`doca-version ## run`](../../doca-version/TASKS.md#run) and
apply the container-tag-lags-host-package overlay plus the
generation-vs-version overlay from
[`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).

## test

This service has no "compile and unit-test" workflow — testing
is operational, end-to-end, and HIGH-STAKES (the host is now
receiving and sending traffic through an emulated NIC whose
dataplane lives on the DPU).

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation (device-count change, queue-count change, backend
change, generation bump, container-tag bump) re-opens the
smoke sweep. Skipping the re-run after a mutation is the
failure mode this loop replaces — and on this service the cost
of the failure mode is silent data-path errors or unreachable
hosts, not just *"weird traffic"*.

The eval-loop overlay (rows apply to every deployment, not just
one backend class):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | Step 4 (backend-reachability smoke) often reveals an as-deployed gap on the backend side that masquerades as a service-config issue; loop back to step 1 | [`## test`](#test) step 4 |
| 2 → ## debug | When the host does not enumerate the NIC, the deployment is non-functional — escalate to [`## debug`](#debug) layer 2 immediately, do not run later steps | [`## debug`](#debug) |
| 3 → ## configure → 5 | When the four-axis smoke reveals the wrong device class is exposed or the device count is wrong, the device + queue-count axis is wrong — loop back to [`## configure`](#configure) step 5 and re-pin the four axes | [`## configure`](#configure) |
| 1..5 → ## run | Each loop iteration ends with a smoke; if all five pass, hand off to live `## run` traffic | [`## run`](#run) |

The agent's rule: every mutation re-opens the sweep. A
configuration change followed by *"it probably still works"* is
exactly the failure mode the iterative loop is here to prevent.

1. **End-to-end smoke (the recommended virtio-net smoke).**
   With the container running and the host kernel driver
   bound, confirm in this order:
    1. Service container `running`, restart count stable per
       the BlueField container manager's status output.
    2. Host `lspci` shows the emulated virtio NIC.
    3. Host's upstream `virtio_net` driver bound (no bind
       error in `dmesg`); `ip link` shows the resulting
       network interface.
    4. One ICMP from the host through the emulated NIC to a
       known reachable destination via the DPU-side backend
       round-trips successfully. This is the cheapest
       end-to-end confirmation that all seven layers from
       [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
       are wired.
   Only after all four pieces pass is the deployment ready for
   any traffic load.
2. **Four-axis smoke.** Confirm the negative case to validate
   the operator's understanding of the four-axis rule — pick
   ONE axis (e.g. temporarily change the device count to a
   different value within the documented bounds) and confirm
   the host's `lspci` and `ip link` view changes exactly as
   the four-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   predicts. Restore the correct value afterwards. This is
   also the operator's evidence that the layer-2 vs layer-3
   split in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   is real on their specific BlueField.
3. **Backend-reachability smoke.** Independently of the
   service, confirm the chosen backend is reachable from the
   BlueField Arm — for the uplink path, `ip link` + `ping` on
   the BlueField Arm reaches the upstream peer; for an OVS
   bridge, `ovs-vsctl show` and `ovs-ofctl dump-flows` show
   the expected topology and the operator can confirm frames
   forward between the bridge's ports; for a user-managed
   backend, the operator's own check confirms the backend
   processes traffic. A divergence between *"backend reachable
   independently"* and *"service traffic round-trips"* is a
   layer-3 service-config symptom; convergence is a layer-4
   backend symptom.
4. **Performance smoke (only if the workload has a perf
   budget).** Run a small, bounded workload (e.g. a short
   `iperf3` sweep at the documented queue depth) against the
   emulated NIC and compare the achieved throughput / packet
   rate / latency against the backend's own intrinsic
   ceiling. The service cannot exceed the backend's ceiling;
   a gap between the service-side measurement and the
   backend's ceiling is a layer-6 *queue-count or MTU* symptom
   per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
5. **Capability snapshot.** Save the *as-deployed* answer to
   — which service container tag is running, which BF
   generation it pairs with, which device + queue count and
   DPU-side backend the four axes landed on, what the
   firmware-slot state is, what `lspci` / `ip link` / `dmesg`
   on the host look like after a clean start. This snapshot
   is the artifact that lets future debug sessions skip
   rediscovery — and on this service, it is the rollback
   baseline.

## debug

Layered diagnosis. Walk the layers in this order; do not skip
down without clearing the layer above. The layers match
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).

1. **Container-runtime layer (layer 1).** Is the service
   container actually running and not restart-looping?
   Symptoms — container exits immediately, image pull fails,
   restart count climbing. Resolution — confirm the image tag
   matches what the public Virtio-net Service Guide *for the
   operator's DOCA release* names; confirm the config mount
   path matches what the public guide names; confirm
   BlueField has the runtime configured per the public
   Container Deployment Guide; confirm the pulled tag is the
   right tag for the BF generation in front of the operator.
   This layer is owned by the container runtime, not by
   service config and not by firmware.
2. **Firmware-slot layer (layer 2).** Container green; host
   `lspci` shows no virtio NIC. Resolution:
    - Confirm the firmware virtio-net emulation slot is
      **enabled** per [`## configure`](#configure) step 4 —
      this is the single most common second-time-deploy
      failure.
    - Confirm the BlueField has been reset since the slot was
      flipped; a flipped-but-unreset slot looks identical to
      an un-flipped slot from the service side.
    - Route the firmware-side enable workflow itself to
      [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure).
      Do NOT mutate service config to "work around" a layer-2
      symptom; no service knob can substitute for the
      firmware slot.
3. **Service-config layer (layer 3).** Container green;
   firmware slot on; host enumerates *something* but it is
   the wrong shape (wrong number of NICs, wrong queue depth,
   wrong virtio feature subset). Resolution — walk the
   four-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   one row at a time and reconcile what the config says with
   what `lspci` / `ip link` and the service container logs
   report. The fix is a config edit plus container restart,
   not a firmware-slot change.
4. **DPU-side networking-backend layer (layer 4).** Host
   enumerates the NIC, host driver binds, but no traffic
   forwards. Resolution:
    - Confirm the backend is reachable from the BlueField Arm
      *independently of the service* per the
      backend-reachability smoke in
      [`## test`](#test) step 3.
    - Confirm the backend type declared in the service config
      matches what is actually wired (uplink declared but the
      uplink port is down; OVS bridge declared but the
      expected port is missing; user-managed backend declared
      but not running).
    - The service logs *that* a forwarding operation failed;
      the backend logs *why*. For OVS, drop to the operator's
      own OVS observability; for the uplink path, drop to
      `ip link` / `ethtool` on the BlueField Arm and any
      operator-side switch reads on the upstream port. A
      traffic failure with no matching backend-side error is
      itself a clue — the frame likely never reached the
      backend, which is usually a layer-3 service-config
      error masquerading as a layer-4 backend error.
5. **Host-NIC visibility / driver bind layer (layer 5).**
   Container green; firmware slot on; service-config correct;
   backend reachable; but the host's `lspci` does not see the
   virtio NIC OR sees it but the `virtio_net` driver does not
   bind. Resolution — load the matching upstream
   `virtio_net` kernel module on the host if it is not
   loaded; check host `dmesg` for the virtio feature-
   negotiation error and align the feature surface per the
   public guide for the operator's DOCA release. The fix is
   host-kernel side or service-config side, not DPU-backend
   side.
6. **Performance layer (layer 6).** Traffic works correctly,
   but throughput / packet rate / latency is below the
   workload's budget. Resolution — re-walk the queue-count
   sizing decision in the four-axis table, confirm the
   emulated NIC's MTU matches the backend's MTU, and confirm
   the backend itself is not the bottleneck. The service
   cannot exceed the backend's intrinsic ceiling; *"a service
   queue-count knob fixing a saturated backend"* is the
   canonical false-fix here. The honest answer is *"the
   backend does not deliver the throughput the workload asked
   for; the fix is on the backend, not in the service
   config"*.
7. **Version / generation layer (layer 7).** When the public
   DOCA Virtio-net Service Guide page appears to disagree
   with what the deployed container does, either the docs
   version does not match the container tag OR the BF
   generation does not match what the docs were written
   against. Walk
   [`doca-version ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 (partial install / version mismatch) and
   re-confirm the BF-generation pinning in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   A guide for a different DOCA release open while the
   container runs against this DOCA release is a layer-7
   failure even when every other layer reads clean.
8. **Cross-cutting layer.** For env-side and program-side
   debug that is not service-specific (host install, host
   kernel, DOCA library errors the service may surface from
   the `doca-device-emulation` library underneath), drop to
   [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug).

## Command appendix

Service-specific commands the verbs above reach for, grouped
by purpose so the agent picks the right family without
searching prose. Every row is a class — the agent must not
invent flags beyond what the row names; flag and command
discovery is `--help` on the installed tool or the public guide
for the operator's DOCA release, not prose recall.

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
| Container lifecycle | The BlueField container manager's start / stop / status command for the service container, per the public Container Deployment Guide | [`## run`](#run) | Container `running`, restart count stable. |
| Container logs | The BlueField container manager's log-stream command for the service container | [`## debug`](#debug) layer 1 + 3 | Documented device bring-up lines visible; no documented error / warning lines repeating. |
| Host-side device enumeration | `lspci` on the host filtered to the virtio NIC class — owned by upstream Linux | [`## run`](#run) step 5; [`## debug`](#debug) layer 2 + 3 | A new virtio network device appears on the BlueField PCIe surface with the expected count. |
| Host-side driver bind state | The upstream `virtio_net` driver's sysfs entries plus host `dmesg`; `ip link` for the resulting network interface — upstream Linux | [`## run`](#run) step 6; [`## debug`](#debug) layer 5 | The upstream `virtio_net` driver binds without error; `ip link` shows the device under the documented name. |
| Host-side ICMP round-trip smoke | `ping` from the host through the emulated NIC to a known reachable destination via the DPU-side backend — defer to upstream Linux tooling for the exact form | [`## test`](#test) step 1; [`## debug`](#debug) layer 4 | The ICMP round-trip completes successfully and reply latency is consistent with the path's baseline. |
| Backend reachability (uplink path) | `ip link` / `ethtool` / `ping` on the BlueField Arm against the uplink — owned by upstream Linux | [`## test`](#test) step 3; [`## debug`](#debug) layer 4 | The uplink reports link-up and reaches its expected upstream peer independently of the service. |
| Backend reachability (OVS bridge) | The operator's own OVS-side diagnostic command (`ovs-vsctl show`, `ovs-ofctl dump-flows`) — defer to upstream OVS docs | [`## test`](#test) step 3; [`## debug`](#debug) layer 4 | The bridge exists, has the expected ports attached, and the operator can confirm frames forward as expected independently of the service. |
| Container tag in use | The BlueField container manager's image-inspect command for the running service container | [`## run`](#run) step 1; [`## debug`](#debug) layer 7 | Tag matches what the public DOCA Virtio-net Service Guide *for the operator's DOCA release* names. |

Three cross-cutting rules for this appendix:

- **Never invent a service config key, container tag, PF / VF
  count, or firmware tool flag.** The public DOCA Virtio-net
  Service Guide *for the operator's DOCA release* is the
  contract; upstream Linux PCIe / virtio / OVS tooling is the
  secondary source for the cross-cutting host-side and
  backend commands. Prose-derived flags are the most common
  hallucination failure for this skill — and on this service
  the wrong invented tag can pull an image not built for the
  BF generation that *looks like* it started.
- **Container before firmware; firmware before service-config;
  backend independently of service.** When triaging, confirm
  the container layer (running, not restart-looping, image
  tag correct) before reading any firmware-slot or `lspci`
  output. Then confirm `lspci` (firmware-slot precondition)
  before service config. Then confirm backend reachability
  *independently* of the service before mutating service
  config to "fix" a backend symptom.
- **Cross-link instead of duplicate.** Cross-cutting env
  commands (port-state, `devlink`, `ip link`, `ethtool` on
  the DPU's network side for the uplink) live in
  [`doca-setup ## Command appendix`](../../doca-setup/TASKS.md#command-appendix)
  and
  [`doca-debug ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  this appendix names only the service-specific ones.

## Deferred task verbs

- **Installing DOCA on the BlueField** — out of scope here.
  Route to
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  for env preparation and
  [`doca-setup ## test`](../../doca-setup/TASKS.md#test) for
  install health verification, or
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path.
- **Flipping the BlueField firmware virtio-net emulation
  slot** — out of scope here. The service contract is *that*
  the slot must be enabled before the container can stand up
  the emulated device; the firmware-tool workflow itself is
  owned by
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  and the public BlueField firmware-configuration
  documentation.
- **Authoring a custom DPU-side virtio-net backend** — not a
  service question. Route to
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the canonical build pattern and to
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  for the API surface (the virtio-net sub-library). The
  packaged service and `doca-device-emulation` are
  intentionally separate artifacts; do not collapse them.
- **Host-side `virtio_net` kernel driver configuration**
  (module loading, IRQ tuning, ethtool offload flags) — out
  of scope here. That driver ships with the host kernel; the
  service names *that* the host must ship and bind the
  upstream `virtio_net` driver, not the driver's own config
  body.
- **DPU-side networking-backend internals** (the OVS bridge
  topology, the BlueField uplink configuration, any
  operator-managed backend's own implementation) — out of
  scope here. Those are owned by the backend's own surface;
  this skill names *that* the backend must be wired and
  *what its reachability surface looks like*.
- **Other DOCA services** (SNAP / DMS / DTS / BlueMan /
  Firefly / Flow-Inspector / HBN / Argus / UROM / …) — not
  this service. Route to
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services)
  for the routing table and the matching `services/<service>`
  skill when it exists (e.g.
  [`doca-snap ## configure`](../doca-snap/TASKS.md#configure)
  for the storage-side sibling that shares this service's
  emulated-device shape,
  [`doca-firefly ## configure`](../doca-firefly/TASKS.md#configure)
  for PTP time sync,
  [`doca-hbn ## configure`](../doca-hbn/TASKS.md#configure)
  for BGP / EVPN / VXLAN). The container-shaped deployment
  pattern is shared; the per-service domain is different.

## Cross-cutting

- The public DOCA Virtio-net Service Guide *for the
  operator's DOCA release* is the single source of truth.
  Any config key, device-class knob, container tag, or
  observability output the agent quotes must come from there,
  not from generic upstream virtio / OVS knowledge.
- Generation-first, then everything else. Pin the BF
  generation BEFORE pinning the service version BEFORE
  quoting any config or container detail; confirm the
  generation is on the supported list in the public guide for
  the operator's DOCA release.
- The firmware-slot precondition is high-stakes. Flipping the
  virtio-net emulation slot is firmware-level configuration
  AND typically requires a BlueField reset; treat it as a
  scheduled-maintenance-class operation, not a casual
  command.
- Path-selection is mandatory up front. This service is the
  wrong answer when the host's existing networking suffices,
  when the user actually wants to shape the BlueField's
  built-in NIC personality, or when the user needs a *custom*
  backend the packaged service does not implement.
- Smoke before bulk. The documented smoke (container running,
  host `lspci` sees the NIC, `ip link` enumerates it, host
  driver bound, one ICMP round-trips through the DPU) goes
  before any traffic load, never after.
- For URL routing to the public guide and other public DOCA
  documentation, see
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).
