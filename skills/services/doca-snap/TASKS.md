# DOCA SNAP Service — Tasks

**Where to start:** The order is `configure → build → modify → run →
test → debug`. The `## test` verb is an iterative loop, not a
one-shot pass — see the eval-loop overlay in `## test` below. For
SNAP, `build` and `modify` are about *deployment configuration*
(container image selection, four-axis config bundle, firmware-slot
precondition, DPU-side storage-backend wiring), not about compiling
source.

These verbs cover the in-scope SNAP operational workflows for an
external operator deploying the SNAP container on BlueField. Every
step assumes the operator has consulted the live public DOCA SNAP
Service Guide for their generation (reachable through
[doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services))
and is using it as the authoritative reference; this file prescribes
the *order* and *what to look up where*, not a copy-paste runbook.

## configure

Preparing the BlueField, pinning the SNAP generation, confirming the
firmware-slot precondition, deciding the four configuration axes, and
wiring the DPU-side storage backend *before* the container starts.
This is also the verb where the HIGH-STAKES posture (firmware-slot
reset, host-storage exposure) is established up front — every later
verb assumes the operator has read it here.

1. **Confirm SNAP is actually the right answer.** Per the
   path-selection rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
    - Is the deployment genuinely storage-disaggregation — compute on
      one node, storage on another, the storage exposed to the host
      as a *local* PCIe device through the BlueField?
    - Or remote-storage-as-local-PCIe — a remote NVMe-oF target / S3
      endpoint exposed to the host as if it were a local drive?
    - Or security-isolated storage — a storage device whose blocks
      are controlled by DPU-side code rather than the host?
    - If the answer is *none of those* (a local NVMe behind the host
      already meets the workload, the deployment is pure compute, or
      the BlueField is BlueField-1), stop here and tell the user
      honestly: keep direct local NVMe, *do not* deploy SNAP
      speculatively.
2. **Confirm the env is healthy.** This skill expects DOCA to be
   installed on the BlueField. If that has not been verified, run
   [`doca-setup ## test`](../../doca-setup/TASKS.md#test) first. If
   the user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path.
3. **Pin the BlueField generation FIRST (LOAD-BEARING).** Per the
   BF-generation routing table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   confirm with the operator which BlueField is in front of them:
    - BlueField-3 → SNAP-4 generation (the primary supported
      combination for new deployments).
    - BlueField-2 → SNAP-3 generation (the earlier generation with
      a different config schema and container-tag namespace).
    - BlueField-1 → not on the supported list; the honest answer is
      *"SNAP does not run on BF-1; the deployment needs different
      hardware or a different solution"*.
   Quote no config knob, container tag, or API symbol before this
   step is closed — SNAP-3 and SNAP-4 are not interchangeable and
   mis-pinning is the canonical first-deploy mistake.
4. **Confirm the firmware-slot precondition (HIGH-STAKES).** Per
   the firmware-slot rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   and layer 2 of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy),
   walk the operator through:
    - The BlueField firmware emulation slot for the chosen device
      class (NVMe and/or virtio-blk) must be **enabled** before the
      SNAP container can stand up an emulated device cleanly. This
      is firmware-level configuration, not a container-runtime
      setting.
    - A BlueField reset is **typically required** after the slot is
      flipped before the new state takes effect. Frame this as a
      scheduled-maintenance-class operation: every BlueField service
      hosted on that DPU restarts, any host workload that depends on
      the BlueField is interrupted.
    - Route the firmware-side enable workflow itself to
      [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
      — the SNAP skill names the *precondition*; it does not author
      firmware-tool flags.
   A deployment where the firmware slot has not been confirmed is a
   deployment that will start the container, look healthy on the
   BlueField, and never expose a device to the host. There is no
   point starting the SNAP container before this step is closed.
5. **Decide the four configuration axes.** Per the four-axis
   configuration table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   commit before starting the container to:
    - **Generation** — SNAP-3 (BF-2) vs SNAP-4 (BF-3). This was
      pinned in step 3; the generation determines the config schema,
      the container-tag namespace, and the feature surface.
    - **Emulated device type** — NVMe namespace (host sees a
      standard NVMe device) vs virtio-blk (host sees a virtio block
      device). The host's kernel driver binds based on this; the
      controller config keys differ.
    - **Emulated controller / queue count** — number of emulated
      controllers / namespaces / virtio-blk devices and their queue
      depths, bounded by the generation's documented limits. Wrong
      count = wrong shape exposed; wrong queue depth = performance
      below budget for the workload.
    - **Storage backend** — local NVMe behind the BlueField, an
      NVMe-over-Fabrics initiator on the DPU pointing at a remote
      target, an S3 endpoint, or custom DPU-side code. Without this
      axis the host will enumerate the device and every I/O will
      fail.
6. **Wire and confirm the DPU-side storage backend.** Per the
   storage-backend pairing table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the SNAP container only emulates the host-facing PCIe device; the
   actual blocks come from a backend on the DPU side. Walk the
   operator through:
    - Local NVMe → the DPU sees the drive (e.g. via `lsblk` on the
      BlueField); SNAP's backend config points at that device.
    - NVMe-oF initiator → the DPU can reach the remote NVMe-oF
      target on the network (discovery / connect succeeds
      *independently* of SNAP); the SNAP container is configured
      with the documented NVMe-oF subsystem identity.
    - S3 → the DPU can reach the S3 endpoint (network + DNS + auth);
      SNAP is configured with the documented endpoint / bucket /
      credentials.
    - Custom → the user-implemented backend is running on the DPU
      and reachable to SNAP per the documented integration surface.
      A custom backend implies the operator is very close to the
      [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
      library boundary — re-confirm SNAP (not the library) is still
      the right tool for the user.
   Backend reachability is independent of SNAP container health;
   conflating them is the most common SNAP runtime debug failure.
7. **Plan the rollback path (HIGH-STAKES).** Because SNAP exposes a
   storage device to the host and the firmware-slot precondition may
   require a BlueField reset, every deploy on a live BlueField must
   have:
    - The pre-deploy BlueField firmware state captured (which
      emulation slots were on / off before the operator changed
      anything).
    - The previous-known-good SNAP config (or a no-SNAP baseline)
      ready to re-apply if the new config misbehaves.
    - An out-of-band way to reach the BlueField if the reset takes
      longer than expected or the BlueField does not come back
      cleanly (BlueField console, redundant management path, IPMI to
      the host that hosts the BlueField).
    - A maintenance window agreed with whoever uses the host —
      because exposing a new storage device to a running host AND
      potentially resetting the BlueField is not a casual operation.
   This step is not optional on a production deployment; the agent
   should refuse to walk a live deploy without it.
8. **Author the SNAP container config.** From the public DOCA SNAP
   Service Guide *for the operator's generation*, derive the config
   bundle for the chosen device type / controller count / backend.
   Quote config keys from the live guide for the right generation;
   do NOT infer them from generic NVMe / virtio-blk knowledge or
   from the *other* SNAP generation. Plan where the config will live
   on the BlueField filesystem and what mount path the container
   expects.

## build

SNAP is a service shipped as a container, not a library. There is no
SNAP *application* artifact for the operator to build — the
container ships from NGC and the config is a static file (or
bundle). There is no `libsnap.so` for a user to link against and no
`pkg-config --libs doca-snap` form to consume.

If the user is asking how to build a **custom storage backend** that
SNAP's packaged backends don't cover, that is not a SNAP question —
it is a library question against
[`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md):

- For applications that **implement a custom NVMe / virtio-blk
  emulation backend on the DPU**, the build is the DOCA library's
  build — route to
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the canonical build pattern and to
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  for the API surface. SNAP and `doca-device-emulation` are
  intentionally separate artifacts (service vs library); do not
  collapse them.
- For applications that **read SNAP's exposed device from the
  host**, no DOCA-specific build is needed — the host's standard
  NVMe or virtio-blk kernel driver binds to the emulated PCIe
  device, and applications use standard block-device or file-system
  APIs. That is upstream Linux, not SNAP.

If the user is instead asking how to build the **SNAP container
itself** from source, that is *not* an external-operator workflow —
the container ships pre-built from NGC and rebuilding it is out of
scope for this skill. Route to the public DOCA SNAP Service Guide
for the operator's generation via
[doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).

## modify

SNAP does not have a "modify a sample" workflow analogous to DOCA
libraries; there is no SNAP sample program a user starts from. The
SNAP analog of "modify" is **adapt the documented container config
recipe to the user's environment** — and on a live deployment, every
modification must respect the HIGH-STAKES posture from
[`## configure`](#configure) step 7.

1. **Start from the documented recipe.** Identify the public
   guide's recipe (in the SNAP-3 user guide or the SNAP-4 service
   guide, matching the pinned generation) that matches the user's
   device type and backend class. Quote it; do not author a new one
   from scratch.
2. **Diff against the user's environment.** Note the specific
   substitutions the user must make: number and identity of
   controllers / namespaces, queue counts, backend-specific
   parameters (local device path for local NVMe, subsystem
   identity / target address for NVMe-oF, endpoint / bucket /
   credentials for S3, integration surface for custom backends),
   config file path, container image tag (always pulled from NGC at
   the tag the public guide for the operator's generation names).
3. **Apply minimum-change.** Change only what the user's environment
   forces. Every additional deviation from the documented recipe
   widens the surface for an unintended mismatch the operator will
   have to debug later — and on SNAP, the wrong axis hides a
   silently-broken storage path.
4. **Re-validate against the four-axis table.** Each substitution
   is a chance to accidentally break one of the four axes
   (generation / device type / controller count / backend). Walk
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   one row at a time after every substitution.
5. **Re-validate against the BF-generation routing.** Any change
   that changes the container image tag (e.g. a DOCA-release bump)
   must still match the BF generation. A SNAP-4 tag on a BF-2, or a
   SNAP-3 tag on a BF-3, can pull and start but cannot work.
6. **Re-validate the backend pairing.** Any change to the backend
   axis (target moved, S3 endpoint rotated, local NVMe replaced) is
   a paired change on the backend's own surface. Update the
   backend's reachability *and* SNAP's config together, not one
   after the other.

The agent's anti-pattern alert: a *"start from a generic SPDK or
NVMe-oF initiator config and adapt"* is almost always slower than
starting from the public SNAP Service Guide's recipe for the
operator's generation, because SNAP's config schema is documented
per generation and is not 1:1 with upstream NVMe / virtio-blk
tooling.

## run

Bringing up the SNAP container, confirming the firmware-slot
precondition surfaces a device, and confirming the host sees a
working device *before* layering any production storage workload on
top. Every step here assumes the prerequisites in
[`## configure`](#configure) are done — including the BF-generation
pinning, the firmware-slot enable, and the rollback plan.

1. **Pull the SNAP container image from NGC** at the tag the public
   DOCA SNAP Service Guide for the operator's generation names for
   the operator's DOCA release. Quote the tag from the live guide
   *for the right generation*; do NOT memorize or invent the tag —
   and never quote a SNAP-4 tag for BF-2 or vice versa.
2. **Start the container per the public Container Deployment Guide
   pattern.** Mount the SNAP config bundle at the path the public
   SNAP Service Guide for the operator's generation names. The
   runtime command shape (e.g. the BlueField container manager's
   start command) is documented in the Container Deployment Guide
   reachable through
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
3. **Confirm the container is running, not restart-looping.** A
   restart loop is a layer-1 symptom per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   (container runtime / image tag / config mount); diagnose it
   before touching SNAP config or firmware. A wrong-generation
   image tag pulled against the wrong BF is a particularly
   load-bearing layer-1 failure here — the pull may succeed silently
   but the container will not behave.
4. **Watch the SNAP container's logs for the documented
   controller / namespace bring-up lines.** The container's stdout
   is SNAP's primary internal observability surface. Look for the
   documented bring-up sequence in the public guide for the
   operator's generation and for any documented error / warning
   lines. The agent should NOT invent log line formats; quote what
   the live container is emitting.
5. **Confirm host-side enumeration on `lspci`.** The host should
   see a new PCIe device of the chosen class (NVMe controller or
   virtio block device) on the BlueField PCIe surface. If `lspci`
   shows nothing of the expected class, the symptom is layer 2 of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   (firmware-slot precondition) — NOT a SNAP-config issue. Re-walk
   [`## configure`](#configure) step 4 before mutating SNAP config.
6. **Confirm the host kernel driver binds.** Once `lspci` sees the
   device, the host's standard NVMe (or virtio-blk) kernel driver
   should bind to it. Read the matching driver's sysfs entries plus
   the host's `dmesg` around the moment SNAP started. A device
   enumerated but not bound is *almost always* a host-kernel issue
   (driver module not loaded; kernel does not ship the matching
   driver), which is a host-side fix outside the SNAP boundary.
7. **Single-event smoke (next: `## test` step 1).** Before driving
   any real workload, walk `## test` step 1 once to confirm a
   trivial I/O round-trips end-to-end; only then layer the
   production workload on top.

For the runtime version + container-tag cross-checks that underlie
*"my SNAP behaves differently from what the docs say"*, see
[`doca-version ## run`](../../doca-version/TASKS.md#run)
and apply the container-tag-lags-host-package overlay plus the
generation-vs-version overlay from
[`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).

## test

SNAP has no "compile and unit-test" workflow — testing is
operational, end-to-end, and HIGH-STAKES (the host is now reading
and writing to an emulated storage device whose blocks live
elsewhere).

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation (device-type change, controller-count change, backend
change, generation bump, container-tag bump) re-opens the smoke
sweep. Skipping the re-run after a mutation is the failure mode this
loop replaces — and on SNAP the cost of the failure mode is silent
data-path corruption or unreachable storage, not just *"weird
traffic"*.

The eval-loop overlay (rows apply to every SNAP deployment, not just
one backend class):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | Step 4 (backend-reachability smoke) often reveals an as-deployed gap on the backend side that masquerades as a SNAP config issue; loop back to step 1 | [`## test`](#test) step 4 |
| 2 → ## debug | When the host does not enumerate the device, the deployment is non-functional — escalate to [`## debug`](#debug) layer 2 immediately, do not run later steps | [`## debug`](#debug) |
| 3 → ## configure → 4 | When the four-axis smoke reveals the wrong device class is exposed, the device-type axis is wrong — loop back to [`## configure`](#configure) step 5 and re-pin the four axes | [`## configure`](#configure) |
| 1..5 → ## run | Each loop iteration ends with a smoke; if all five pass, hand off to live `## run` traffic | [`## run`](#run) |

The agent's rule: every mutation re-opens the sweep. A configuration
change followed by *"it probably still works"* is exactly the
failure mode the iterative loop is here to prevent.

1. **End-to-end smoke (the recommended SNAP smoke).** With the
   container running and the host kernel driver bound, confirm in
   this order:
    1. SNAP container `running`, restart count stable per the
       BlueField container manager's status output.
    2. Host `lspci` shows the emulated device of the expected
       class.
    3. Host kernel driver bound (no bind error in `dmesg`).
    4. A trivial I/O round-trips: a single 4 KiB read (or write
       to a scratch namespace) on the host returns success and the
       data round-trips. This is the cheapest end-to-end
       confirmation that all six layers from
       [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
       are wired.
   Only after all four pieces pass is the deployment ready for
   bulk production storage traffic.
2. **Four-axis smoke.** Confirm the negative case to validate the
   operator's understanding of the four-axis rule: pick ONE axis
   (e.g. temporarily change the controller count to a different
   value within the documented bounds) and confirm the host's
   `lspci` view changes exactly as the four-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   predicts. Restore the correct value afterwards. This is also
   the operator's evidence that the layer-2 vs layer-3 split in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   is real on their specific BlueField.
3. **Backend-reachability smoke.** Independently of SNAP, confirm
   the chosen backend is reachable from the DPU: for local NVMe,
   `lsblk` on the BlueField sees the drive; for NVMe-oF, the
   DPU-side initiator can discover / connect the remote target
   without SNAP in the picture; for S3, a documented endpoint
   reachability check from the DPU succeeds. A divergence between
   *"backend reachable independently"* and *"SNAP I/O round-trips"*
   is a layer-3 SNAP-config symptom; convergence is a layer-4
   backend symptom.
4. **Performance smoke (only if the workload has a perf budget).**
   Run a small, bounded workload (e.g. a short `fio` sweep at the
   documented queue depth) against the emulated device and compare
   the achieved IOPS / throughput / latency against the backend's
   own intrinsic ceiling. SNAP cannot exceed the backend's ceiling;
   a gap between the SNAP-side measurement and the backend's
   ceiling is a layer-5 *queue-count* symptom per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
5. **Capability snapshot.** Save the *as-deployed* answer to: which
   SNAP container tag is running, which BF generation it pairs with,
   which device type / controller count / backend the four axes
   landed on, what the firmware-slot state is, what `lspci` and
   `dmesg` on the host look like after a clean start. This snapshot
   is the artifact that lets future debug sessions skip rediscovery
   — and on SNAP, it is the rollback baseline.

## debug

Layered diagnosis. Walk the layers in this order; do not skip down
without clearing the layer above. The layers match
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).

1. **Container-runtime layer (layer 1).** Is the SNAP container
   actually running and not restart-looping? Symptoms: container
   exits immediately, image pull fails, restart count climbing.
   Resolution: confirm the image tag matches what the public SNAP
   Service Guide *for the operator's generation* names for the
   operator's DOCA release; confirm the config mount path matches
   what the public guide names; confirm BlueField has the runtime
   configured per the public Container Deployment Guide; confirm
   the pulled tag is the *right generation* for the BF in front of
   the operator. This layer is owned by the container runtime, not
   by SNAP config and not by firmware.
2. **Firmware-slot layer (layer 2).** Container green; host
   `lspci` shows no emulated device of the expected class.
   Resolution:
    - Confirm the firmware emulation slot for the chosen device
      class (NVMe and/or virtio-blk) is **enabled** per
      [`## configure`](#configure) step 4 — this is the
      single most common second-time-deploy failure.
    - Confirm the BlueField has been reset since the slot was
      flipped; a flipped-but-unreset slot looks identical to an
      un-flipped slot from the SNAP side.
    - Route the firmware-side enable workflow itself to
      [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure).
      Do NOT mutate SNAP config to "work around" a layer-2 symptom;
      no SNAP knob can substitute for the firmware slot.
3. **SNAP-config layer (layer 3).** Container green; firmware slot
   on; host enumerates *something* but it's the wrong shape (wrong
   number of namespaces, wrong device class, wrong queue depth).
   Resolution: walk the four-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   one row at a time and reconcile what the config says with what
   `lspci` and the SNAP container logs report. The fix is a config
   edit plus container restart, not a firmware-slot change.
4. **Storage-backend-reachability layer (layer 4).** Host
   enumerates the device, host driver binds, but every I/O fails
   (or fails after a short delay). Resolution:
    - Confirm the backend is reachable from the DPU *independently
      of SNAP* per the backend-reachability smoke in
      [`## test`](#test) step 3.
    - Confirm the backend type declared in SNAP config matches what
      is actually wired (NVMe-oF declared but no target reachable;
      S3 declared but no credentials; local NVMe declared but the
      device path is wrong).
    - SNAP logs *that* a backend operation failed; the backend
      logs *why*. For NVMe-oF, drop to the DPU-side initiator's
      logs and the remote target's logs; for S3, drop to the
      DPU-side HTTP / auth log and the endpoint's request log;
      for local NVMe, drop to the DPU-side `dmesg`. A SNAP I/O
      failure with no matching backend-side error is itself a
      clue — the request likely never reached the backend, which
      is usually a layer-3 SNAP-config error masquerading as a
      layer-4 backend error.
5. **Performance layer (layer 5).** I/O works correctly, but
   throughput / IOPS / latency is below the workload's budget.
   Resolution: re-walk the controller / queue sizing decision
   in the four-axis table AND the backend's own performance
   characteristics. SNAP cannot exceed the backend's intrinsic
   ceiling; *"SNAP queue-count knob fixing a saturated backend"*
   is the canonical false-fix here. The honest answer is *"the
   backend doesn't deliver the throughput / latency you asked
   for; the fix is on the backend, not in SNAP config"*.
6. **Version / generation layer (layer 6).** When the public DOCA
   SNAP Service Guide page appears to disagree with what the
   deployed container does, either the docs version does not match
   the container tag OR the docs *generation* does not match the
   BF generation. Walk
   [`doca-version ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 (partial install / version mismatch) and re-confirm
   the BF-generation → SNAP-generation routing in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   A SNAP-3 doc page open while a SNAP-4 container is running
   (or vice versa) is a layer-6 failure even when every other
   layer reads clean.
7. **Cross-cutting layer.** For env-side and program-side debug
   that is not SNAP-specific (host install, host kernel, DOCA
   library errors SNAP may surface from the doca-device-emulation
   library underneath), drop to
   [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug).

## Command appendix

SNAP-specific commands the verbs above reach for, grouped by purpose
so the agent picks the right family without searching prose. Every
row is a class — the agent must not invent flags beyond what the row
names; flag and command discovery is `--help` on the installed tool
or the public guide for the operator's generation, not prose recall.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; the BlueField container manager's structured status output
   when available).
2. If the probe succeeds, the structured tool's output is the
   authoritative answer and the agent SHOULD NOT also run the
   manual command in the row below. Report *"using structured
   `<tool>`"*.
3. If the probe fails, fall back to the manual command in the row.
   Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Purpose | Command (class shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Container lifecycle | The BlueField container manager's start / stop / status command for the SNAP container, per the public Container Deployment Guide | [`## run`](#run) | Container `running`, restart count stable. |
| Container logs | The BlueField container manager's log-stream command for the SNAP container | [`## debug`](#debug) layer 1 + 3 | Documented controller / namespace bring-up lines visible; no documented error / warning lines repeating. |
| Host-side device enumeration | `lspci` on the host filtered to the expected device class (NVMe controller or virtio block device) — owned by upstream Linux | [`## run`](#run) step 5; [`## debug`](#debug) layer 2 + 3 | A new device of the expected class appears on the BlueField PCIe surface with the expected count. |
| Host-side driver bind state | The matching standard kernel driver's sysfs entries plus host `dmesg` (`nvme list` for NVMe, `lsblk` for the resulting block device — upstream Linux) | [`## run`](#run) step 6; [`## debug`](#debug) layer 2 + 3 | The standard driver binds without error; the device shows up as a block device under the documented name. |
| Host-side I/O round-trip smoke | A single trivial I/O against the emulated device (e.g. one 4 KiB read from `/dev/<nvme-namespace>` or the virtio-blk device — defer to upstream Linux tooling for the exact form) | [`## test`](#test) step 1; [`## debug`](#debug) layer 4 | The I/O completes successfully and the data round-trips. |
| Backend reachability (local NVMe) | `lsblk` (and equivalent block-layer inspection) on the BlueField Arm — owned by upstream Linux | [`## test`](#test) step 3; [`## debug`](#debug) layer 4 | The local NVMe drive is visible on the DPU side at the device path SNAP's backend config references. |
| Backend reachability (NVMe-oF / S3) | The DPU-side initiator / HTTP client's own diagnostic command (NVMe-oF: upstream `nvme` CLI on the DPU; S3: the documented endpoint reachability check) — defer to those tools' own docs | [`## test`](#test) step 3; [`## debug`](#debug) layer 4 | The remote target / endpoint responds to a documented probe *independently of SNAP*. |
| Container tag in use | The BlueField container manager's image-inspect command for the running SNAP container | [`## run`](#run) step 1; [`## debug`](#debug) layer 6 | Tag matches what the public SNAP Service Guide *for the operator's generation* names for the operator's DOCA release. |

Three cross-cutting rules for this appendix:

- **Never invent a SNAP config key, container tag, or firmware
  tool flag.** The public DOCA SNAP Service Guide *for the
  operator's generation* is the contract; upstream Linux block /
  PCIe / NVMe tooling is the secondary source for the
  cross-cutting host-side commands. Prose-derived flags are the
  most common hallucination failure for this skill — and on SNAP
  the wrong invented tag can pull a wrong-generation image that
  *looks like* it started.
- **Container before firmware; firmware before SNAP-config;
  backend independently of SNAP.** When triaging, confirm the
  container layer (running, not restart-looping, image tag
  correct) before reading any firmware-slot or `lspci` output.
  Then confirm `lspci` (firmware-slot precondition) before SNAP
  config. Then confirm backend reachability *independently* of
  SNAP before mutating SNAP config to "fix" a backend symptom.
- **Cross-link instead of duplicate.** Cross-cutting env commands
  (port-state, `devlink`, `ip link`, `ethtool` on the DPU's
  network side for NVMe-oF / S3 reachability) live in
  [`doca-setup ## Command appendix`](../../doca-setup/TASKS.md#command-appendix)
  and
  [`doca-debug ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  this appendix names only the SNAP-specific ones.

## Deferred task verbs

- **Installing DOCA on the BlueField** — out of scope here. Route
  to [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  for env preparation and
  [`doca-setup ## test`](../../doca-setup/TASKS.md#test) for
  install health verification, or
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path.
- **Flipping the BlueField firmware emulation slot** — out of
  scope here. The SNAP contract is *that* the slot must be
  enabled before the container can stand up the emulated device;
  the firmware-tool workflow itself is owned by
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  and the public BlueField firmware-configuration documentation.
- **Authoring a custom DPU-side storage backend** — not a SNAP
  question. Route to
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the canonical build pattern and to
  [`doca-device-emulation`](../../libs/doca-device-emulation/SKILL.md)
  for the API surface. SNAP and `doca-device-emulation` are
  intentionally separate artifacts; do not collapse them.
- **Host-side NVMe / virtio-blk kernel driver configuration**
  (module loading, IRQ tuning, `nvme-cli` flags, multipath setup)
  — out of scope here. Those drivers ship with the host kernel;
  SNAP names *that* the host must ship and bind the matching
  driver, not the driver's own config body.
- **Storage-backend internals** (the SPDK config the DPU runs,
  the NVMe-oF target's own configuration, S3 bucket / IAM
  policy) — out of scope here. Those are owned by the backend's
  own surface; the SNAP skill names *that* the backend must be
  wired and *what its reachability surface looks like*.
- **Other DOCA services** (DMS / DTS / BlueMan / Firefly /
  Flow-Inspector / HBN / Argus / …) — not SNAP. Route to
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services)
  for the routing table and the matching `services/<service>`
  skill when it exists (e.g.
  [`doca-firefly ## configure`](../doca-firefly/TASKS.md#configure)
  for PTP time sync,
  [`doca-dms ## configure`](../doca-dms/TASKS.md#configure)
  for device management,
  [`doca-hbn ## configure`](../doca-hbn/TASKS.md#configure)
  for BGP / EVPN / VXLAN). The container-shaped deployment
  pattern is shared; the per-service domain is different.

## Cross-cutting

- The public DOCA SNAP Service Guide *for the operator's
  generation* is the single source of truth. Any config key,
  device-type knob, container tag, or observability output the
  agent quotes must come from there, not from generic NVMe /
  virtio-blk / SPDK knowledge and not from the *other* SNAP
  generation.
- Generation-first, then everything else. SNAP-3 and SNAP-4 are
  not interchangeable: they have different config schemas,
  different container tags, and run on different BlueField
  generations. Pin the BF generation BEFORE pinning the SNAP
  version BEFORE quoting any config or container detail.
- The firmware-slot precondition is high-stakes. Flipping the
  emulation slot is firmware-level configuration AND typically
  requires a BlueField reset; treat it as a scheduled-
  maintenance-class operation, not a casual command.
- Path-selection is mandatory up front. SNAP is the wrong
  answer when a simple local NVMe meets the host's needs, for
  pure compute deployments with no storage emulation
  requirement, and on BlueField-1 (not supported).
- Smoke before bulk. The documented smoke (container running,
  host `lspci` sees the device, host driver bound, one trivial
  I/O round-trips) goes before any production storage workload,
  never after.
- For URL routing to the SNAP guides and other public DOCA
  documentation, see
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).
