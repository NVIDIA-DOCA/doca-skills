# DOCA OS Inspector Service — Tasks

**Where to start:** The order is `install → configure → build →
modify → run → test → debug → use`. The `## test` verb is an
iterative loop, not a one-shot pass — see the eval-loop overlay
in `## test` below. For OS Inspector, `build` and `modify` are
about *deployment configuration* (container image selection,
mounted symbol-map / memory-regions / scan-policy files,
DTS-side pipeline wiring), not about compiling source.

These verbs cover the in-scope OS Inspector operational
workflows for an external operator deploying the OS Inspector
container on BlueField. Every step assumes the operator has
consulted the live public DOCA OS Inspector / App Shield Agent /
DOCA Telemetry Service / Container Deployment Guide pages
(reachable through
[doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services))
and is using them as the authoritative reference; this file
prescribes the *order* and *what to look up where*, not a
copy-paste runbook.

## install

Bring the BlueField up to the state where the OS Inspector
container can actually run. *"Install"* here is environment
preparation plus image acquisition; it is NOT building
OS Inspector from source (the container ships pre-built from
NGC — see [`## build`](#build) for why source-building is out
of scope for the external operator).

1. **Confirm DOCA is installed on the BlueField.** This skill
   assumes DOCA is already installed at the standard location
   on BlueField Arm. If that has not been verified, run
   [`doca-setup ## test`](../../doca-setup/TASKS.md#test) first.
   If the user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path. OS Inspector adds
   its per-service container on top of an already-healthy DOCA
   install; it is not a substitute for installing DOCA itself.
2. **Confirm the BlueField env meets the per-service
   prerequisites the public OS Inspector / App Shield Agent
   guidance names.** In particular: hugepages reserved on the
   BlueField (the project's Pod spec requests `hugepages-2Mi:
   "1Gi"` as the documented order of magnitude — quote the
   exact value from the live guidance for the operator's
   release), the DTS-side IPC socket volume directory present
   on the BlueField filesystem (so the OS Inspector container
   can mount it), and a writable shared-memory volume for the
   telemetry-exporter to use. Cross-check against
   [`doca-hardware-safety CAPABILITIES.md ## Capabilities and modes`](../../doca-hardware-safety/CAPABILITIES.md#capabilities-and-modes)
   if a kernel-boot-parameter change (hugepages reservation,
   IOMMU mode) is needed — that is a host-reboot-class change
   per the hardware-safety meta-policy.
3. **Confirm the BlueField is in a mode of operation that
   gives the DPU side the APSH host-memory-access surface.**
   The public DOCA App Shield guidance names which BlueField
   modes support DPU-side introspection of the host; a
   BlueField configured for a mode that does not expose the
   host memory path will fail at layer 2 (hardware path) per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   no matter how clean the rest of the deployment is. If a
   mode flip is needed, route to
   [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md)
   for the change-application discipline (out-of-band path,
   pre-flight inventory, maintenance window, replica-first
   validation) BEFORE touching the mode.
4. **Identify the DTS deployment on the BlueField.** OS
   Inspector publishes via the documented telemetry-exporter
   IPC socket into DTS; if DTS is not deployed on the
   BlueField, OS Inspector has nowhere to send findings. Route
   to the public DOCA Telemetry Service Guide via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
   for the DTS install / deploy story; this skill assumes DTS
   is reachable on the BlueField.
5. **Pull the OS Inspector container image from NGC.** Quote
   the exact image string and tag from the live public OS
   Inspector / App Shield Agent guidance for the operator's
   DOCA release; do NOT memorize or invent the tag. The
   container tag is the runtime version anchor per
   [`CAPABILITIES.md ## Version compatibility`](#version-compatibility).
6. **Capture the install baseline.** Record which DOCA release
   is installed on the BlueField, which OS Inspector container
   tag was pulled, which DTS release is deployed, which
   BlueField mode of operation is in effect, and the host
   kernel build version (as of right now — this becomes the
   anchor the symbol-map prerequisite in [`## configure`](#configure)
   must match). This snapshot is the artifact the rollback
   path and every later debug session will refer back to per
   the pre-flight-inventory rule in
   [`doca-hardware-safety CAPABILITIES.md ## Capabilities and modes`](../../doca-hardware-safety/CAPABILITIES.md#capabilities-and-modes).

## configure

Preparing the OS Inspector deployment shape: confirm OS
Inspector is the right answer, decide the five configuration
axes, plan the end-to-end pipeline (OS Inspector → DTS →
consumer), and assemble the prerequisites BEFORE the container
starts.

1. **Confirm OS Inspector is actually the right answer.** Per
   the path-selection rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
    - Does the user want **a deployable, container-shaped
      host-OS introspection feed** flowing into the BlueField's
      DTS pipeline for a downstream consumer to act on? If yes,
      OS Inspector is the right answer — and specifically,
      **recommend OS Inspector over building from
      [`doca-apsh`](../../libs/doca-apsh/SKILL.md)** for this
      production case. The bundled service is the production
      default; the library is the right answer only when the
      user is genuinely building a custom DPU-side introspection
      product of their own.
    - Does the user want **runtime-security findings**
      (suspicious-activity / integrity-violation alerts) with
      detection policy + SIEM forwarding built in? Route to
      [`doca-argus`](../doca-argus/SKILL.md). OS Inspector
      emits raw enumerations; Argus emits findings.
    - Is the user trying to build a custom DPU-side
      introspection tool of their own? Route them to
      [`doca-apsh`](../../libs/doca-apsh/SKILL.md) — same shape
      of DPU-side observation, different shape of operator
      effort.
    - Is there no host-introspection need at all? Stop here
      honestly — OS Inspector has operational cost (container,
      hugepages, DMA traffic, DTS pipeline) and deploying it
      for nothing is not a neutral choice.
2. **Decide the five configuration axes.** Per the five-axis
   table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   commit before starting the container to:
    - **DMA device + host VUID** — the BlueField IBdev (a
      `mlx5_*` form, named by the operator's live BlueField
      inventory, not from memory) and the host VUID identifying
      the host whose memory will be introspected. The
      [`doca-setup`](../../doca-setup/SKILL.md) device-listing
      path names how to discover these on the BlueField.
    - **OS type** — Linux or Windows. Drives which APSH
      telemetry-event registration the scanner uses.
    - **Host kernel symbol map + memory-regions file** — the
      host-OS-version-specific artifacts the APSH library needs
      to interpret the host's kernel memory. Generated against
      the *exact* host kernel build currently running on the
      host; the generation procedure is in the public DOCA
      App Shield guidance. **The map silently invalidates on
      every host kernel upgrade** — the operator's runbook
      MUST treat refreshing the map as a mandatory step on
      every host kernel change per the
      symbol-map-lifecycle rule in
      [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
    - **Scan policy** — which APSH structs the scanner
      enumerates and publishes each iteration. Start from the
      project's minimum-exposure defaults
      (`processes_info`, `threads_info`, `libs_info`,
      `vads_info`, `system_modules_info` ON;
      `privileges_info`, `processes_envars_info`,
      `processes_handles_info` OFF) and turn structs on only
      deliberately, with a documented downstream consumer that
      needs the data and a documented data-sensitivity review
      per the minimum-exposure-by-default rule in
      [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
    - **Scan interval** (the `-t` / time-interval argument the
      public guidance names) — the cadence at which the
      scanner re-walks every enabled APSH struct. Trade
      freshness against BlueField CPU / DMA bus / host PCIe
      pressure; size against the workload's budget, not against
      the "see everything as fast as possible" instinct.
3. **Plan the DTS-side pipeline.** Decide which downstream
   consumer (Splunk / ELK / Sentinel / custom analyst
   dashboard / custom correlator) will receive the OS Inspector
   feed via DTS, and confirm the DTS team is ready to forward
   to it. Capture the DTS-side forwarder destination, the
   protocol the DOCA Telemetry Service Guide names, and the
   auth material the forwarder expects. The DTS-side
   ingest body itself is the DTS / consumer team's
   responsibility and lives in the DOCA Telemetry Service
   Guide and in the SIEM's own documentation; OS Inspector's
   contract is to publish APSH events in the documented
   telemetry-exporter format.
4. **Plan the host-kernel-change rollover.** Before declaring
   the channel production-ready, the operator should document
   the procedure for refreshing the symbol map on every host
   kernel change. The procedure (a) detects the host kernel
   build version on the host, (b) regenerates the symbol map +
   memory-regions files per the public DOCA App Shield
   guidance, (c) updates the mounts the OS Inspector container
   is using, and (d) restarts the container so the new APSH
   context picks up the new map. Skipping this planning step
   is how an otherwise-healthy deployment goes silent the day
   after the host's next routine kernel patch.
5. **Author the OS Inspector container argument set.** From
   the public OS Inspector / App Shield Agent guidance,
   derive the per-deployment argument set: the DMA device, the
   host VUID, the OS type, the symbol-map file path inside the
   container, the memory-regions file path inside the
   container, the scan-policy JSON path inside the container,
   the scan interval, and any log-level / DOCA argp arguments
   the operator wants. The project's entrypoint accepts the
   argument set via the documented `--json` form pointing at
   the operator-supplied parameters file (the project's
   `os_inspector_params.json` shape). Quote argument names from
   the live guidance, do NOT infer them from generic
   security-tooling knowledge or from a previous OS Inspector
   release. Plan where the mounted files (params,
   scan-policy, symbol map, memory regions) will live on the
   BlueField filesystem and which container mount paths they
   land at.

## build

OS Inspector is a service shipped as a container, not a
library. There is no OS Inspector *application* artifact for the
external operator to build — the container ships from NGC and
the operator-supplied artifacts (scan policy, symbol map,
memory regions, params file) are static files. The container
itself is built upstream against a versioned base image (the
public guidance pins the base image per release); rebuilding
OS Inspector from source is not an external-operator workflow.

If the user is asking how to build a **custom DPU-side
introspection tool** (a program that reads host kernel state
from the BlueField side to make its own decisions, or that
publishes the enumeration into a non-DTS surface, or that
emits a non-APSH event shape), that is not an OS Inspector
question — it is the path-selection rule pointing at
[`doca-apsh`](../../libs/doca-apsh/SKILL.md):

- For applications that **introspect the host's running kernel
  state from the DPU side** with custom scan logic, the build
  is the App Shield library's build — route to
  [`doca-apsh ## build`](../../libs/doca-apsh/TASKS.md#build)
  and to
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  for the canonical build pattern.
- For applications that **consume OS Inspector's APSH events
  from DTS** (an internal dashboard, a custom enrichment
  pipeline, a hand-written alert correlator that reads from
  the DTS forwarder), no DOCA-specific build is needed — the
  application reads the documented APSH event shape from DTS
  in whatever language the consumer is written in. The event
  shape is the public OS Inspector / App Shield Agent
  guidance's surface plus the DTS-side forwarder contract,
  not a DOCA C ABI the consumer links against.
- For applications that **publish their own telemetry events
  into the same DTS pipeline** (so the consumer sees both the
  OS Inspector feed and the application's own feed in one
  place), the build is the
  [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)
  library's build — route there for the publisher-side ABI.

If the user is instead asking how to build the **OS Inspector
container itself** from source, that is *not* an
external-operator workflow — the container ships pre-built from
NGC and rebuilding it is out of scope for this skill. Route to
the public OS Inspector / App Shield Agent guidance via
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

## modify

OS Inspector does not have a "modify a sample" workflow
analogous to DOCA libraries; there is no OS Inspector sample
program a user starts from. The OS Inspector analog of
"modify" is **adapt the documented container deployment recipe
to the user's environment, evolve the scan policy as the
downstream consumer's needs change, and refresh the host
symbol map on every host kernel change**:

1. **Start from the documented recipe.** Identify the public
   guidance's recipe that matches the user's deployment posture
   (the same OS type, the same scan-policy size, the same
   scan-interval tier). Quote it; do not author a new one from
   scratch.
2. **Diff against the user's environment.** Note the specific
   substitutions the user must make: DMA device IBdev name
   (named by the operator's live BlueField inventory), host
   VUID, OS type, symbol-map and memory-regions file paths
   inside the container, params file path, container image tag
   (always pulled from NGC per the public guidance).
3. **Apply minimum-change.** Change only what the user's
   environment forces. Every additional deviation from the
   documented recipe widens the surface for an unintended
   misconfiguration the operator will have to debug later.
4. **Re-validate against the five-axis table.** Each
   substitution is a chance to accidentally break one of the
   five axes (DMA device + VUID / OS type / symbol map +
   memory regions / scan policy / scan interval). Walk
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   one row at a time after every substitution.
5. **Refresh the host symbol map on every host kernel
   change.** Per the symbol-map-lifecycle rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   the symbol-map and memory-regions files MUST be regenerated
   against the post-change host kernel build and the
   OS Inspector container restarted with the new mounts. The
   container does NOT detect a stale map automatically — the
   feed silently stops representing reality until the
   operator's runbook runs this step. Update the deployment's
   symbol-map version anchor in the operator's runbook in the
   same change.
6. **Re-validate against the minimum-exposure and
   never-silently-disable rules.** Per the safety policy in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   any change that turns an APSH struct ON must be explicit,
   documented, and tied to a downstream consumer that actually
   needs the data; any change that turns one OFF must be
   explicit, documented, and time-boxed with a re-evaluation
   date. Silent expansions widen the data-sensitivity surface;
   silent removals create unknown blind spots.
7. **Re-open the smoke sweep.** Any non-trivial change to the
   five axes, the scan policy, or the mounted symbol map
   re-opens the smoke sweep — re-run the smoke steps in
   [`## test`](#test) before re-enabling production consumer
   alerting on the DTS channel.

The agent's anti-pattern alert: a *"copy a generic
security-agent config and adapt"* is almost always slower than
starting from the public OS Inspector / App Shield Agent
guidance's recipe, because OS Inspector's argument set, scan-
policy schema, and APSH event registration shape are documented
per the public guidance and are not 1:1 with any other
introspection tooling.

## run

Bringing up the OS Inspector container and confirming the
end-to-end pipeline (OS Inspector → APSH → telemetry-exporter →
DTS → consumer) is flowing, BEFORE enabling any production
consumer pipeline on top.

1. **Confirm the install baseline still holds.** The container
   tag, DOCA release, DTS release, BlueField mode, and host
   kernel build version snapshotted at the end of
   [`## install`](#install) should still match what's on the
   BlueField + host today. A drift in any of those re-opens the
   five-axis decision (per [`## configure`](#configure)) before
   the container starts; in particular, a host kernel that has
   changed since [`## install`](#install) was run requires a
   symbol-map refresh per the lifecycle rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   BEFORE the container starts.
2. **Stage the operator-supplied files on the BlueField
   filesystem at the mount paths the public guidance names.**
   The scan-policy JSON, the params file (the JSON form the
   project's entrypoint accepts via `--json`), the symbol-map
   file, and the memory-regions file all live at
   operator-chosen paths on the BlueField; the container mounts
   them at the documented mount points the public OS Inspector
   / App Shield Agent guidance names.
3. **Start the container per the public Container Deployment
   Guide pattern.** Mount the scan-policy JSON, the params
   file, the symbol map, and the memory-regions file at the
   paths the public OS Inspector / App Shield Agent guidance
   names; mount the BlueField hugepages volume, the DTS-side
   IPC socket volume, and the shared-memory volume at the
   container paths the public guidance names. The runtime
   command shape (e.g. `docker run` / `crictl` / the BlueField
   container manager / the Pod-spec form the project ships)
   is documented in the Container Deployment Guide reachable
   through
   [`doca-container-deployment`](../../doca-container-deployment/SKILL.md).
4. **Confirm the container is running, not restart-looping.** A
   restart loop is a layer-1 symptom per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   (container runtime / image tag / hugepages / volume
   mounts); diagnose it before touching scan policy.
5. **Watch the OS Inspector container's logs for the
   documented startup-banner, APSH-context-created, and
   scanner-iteration lines.** The container's stdout is the
   primary operational observability surface. The public
   guidance names the expected `DOCA_LOG_INFO` lines (the
   "Successfully created DOCA APSH lib context", "Successfully
   created DOCA APSH system context", "Successfully created
   telemetry endpoint", "Starting data collection" shape the
   project's source emits is a useful reference for the *order*
   of operations; the *exact* log strings for the operator's
   release belong to the live guidance). A startup that stops
   short of "data collection starting" indicates a layer-2
   (hardware path) or layer-3 (symbol map) failure; walk
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   before continuing.
6. **Confirm APSH iterations are completing.** Each scan
   interval the scanner re-walks every enabled APSH struct
   over DMA reads of host memory; an iteration that runs
   forever, or that produces a zero-result enumeration where
   the operator knows the host has running processes, is the
   cheapest signal of a layer-2 / layer-3 problem. Stop and
   walk the error taxonomy before continuing.
7. **Confirm the telemetry-exporter source connected to DTS.**
   The container should emit the documented telemetry-source-
   started line confirming the IPC socket to DTS was opened
   and authenticated. If it does not, stop and walk
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 5 before continuing — there is no point in waiting
   for the consumer side if the BlueField-side pipeline is
   broken between OS Inspector and DTS.
8. **Confirm the DTS-side ingest.** Get the DTS team / runbook
   to confirm that DTS is receiving the OS Inspector events
   and forwarding them onward. The end-to-end pipeline is not
   "OS Inspector emitted an event"; it is "the downstream
   consumer surface shows the event that OS Inspector emitted".
9. **Single-event smoke (next: `## test` step 1).** Before
   enabling production consumption on the DTS channel, walk
   `## test` step 1 once with a known-running target on the
   host so the end-to-end pipeline is exercised; only then
   layer production consumer pipelines on top.

For the runtime version + container-tag cross-checks that
underlie *"my OS Inspector behaves differently from what the
docs say"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run)
and apply the container-tag-lags-host-package overlay from
[`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
PLUS the host-kernel-version axis OS Inspector adds.

## test

OS Inspector has no "compile and unit-test" workflow — testing
is operational and end-to-end.

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation (DMA device change, OS type change, symbol-map
refresh after a host kernel change, scan-policy change,
scan-interval change, DTS-side forwarder change) re-opens the
smoke sweep. Skipping the re-run after a mutation is the
failure mode this loop replaces — and in introspection tooling,
the silent failure mode means the feed goes wrong-shaped in a
way the downstream consumer does not notice until somebody
audits the output.

The eval-loop overlay (rows apply to every OS Inspector
deployment, not just one scan policy):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | Step 4 (consumer-side review check) often reveals a DTS-forwarder gap or a scan-policy gap; loop back to step 1 and re-run the smoke | [`## test`](#test) step 4 |
| 2 → ## debug | When the known-target smoke produces a zero-result enumeration or a corrupt one, the deployment is non-functional — escalate to `## debug` layer 2 (hardware path) or layer 3 (symbol map) immediately, do not enable production consumption | [`## debug`](#debug) |
| 3 → ## configure → 3 | When the DTS-side does not receive the smoke event, the telemetry pipeline is wrong — loop back to `## configure` step 3 and re-run | [`## configure`](#configure) |
| Host kernel change → ## modify → 1 | A host kernel upgrade silently invalidates the symbol map; refresh the map per [`## modify`](#modify) step 5 and re-run the smoke. This is THE most common trigger for a previously-healthy deployment going wrong | [`## modify`](#modify) |
| 1..5 → ## run | Each loop iteration ends with a smoke; if all five pass, hand off to live `## use` consumer pipelines | [`## use`](#use) |

The agent's rule: every mutation re-opens the smoke sweep. A
configuration change followed by *"it probably still works"* is
exactly the failure mode the iterative loop is here to prevent.

1. **End-to-end smoke (known-target).** With OS Inspector
   running and the DTS-side pipeline wired, confirm in this
   order: (a) the OS Inspector container's stdout shows the
   documented startup banner, the APSH context created against
   the configured DMA device + VUID + OS type + symbol map +
   memory regions, the telemetry source started, and the
   scanner iteration loop running; (b) the operator picks ONE
   target known to be running on the host independently (e.g.
   `init` / `systemd` for Linux; an equivalent always-running
   process for Windows) and confirms the corresponding
   `processes_info` event for that target appears in the
   OS Inspector → DTS feed; (c) the same event reaches the
   downstream consumer's review surface. This is the smoke
   pattern App Shield itself teaches (a known target is the
   cheapest proof that the symbol map + DMA path + APSH
   context are all correct before scaling to broad
   enumeration); OS Inspector inherits the pattern unchanged.
2. **Negative-axis smoke.** Confirm the negative case:
   temporarily misconfigure ONE non-load-bearing axis (e.g.
   point the params at a symbol-map path that does not exist)
   and verify the container surfaces the error explicitly in
   the documented startup-banner shape — OS Inspector must NOT
   silently start without the symbol map. Restore the
   correct config afterwards. This validates the operator's
   understanding of the layered error taxonomy AND that a
   five-axis mutation is detectable.
3. **DTS-pipeline smoke.** Stop the DTS-side forwarder (or
   block its reachability for a short, scheduled window) and
   confirm that the OS Inspector container's documented
   error / warning path surfaces the IPC failure — the feed
   must NOT silently drop events without surfacing the
   failure. Restore reachability and confirm the feed
   recovers per the public guidance. This validates the
   telemetry pipeline, not the APSH context.
4. **Wide-enumeration smoke (post-known-target).** Once the
   known-target smoke is green, enable the full configured
   scan policy and confirm that the wide enumeration's event
   volume into DTS matches the operator's order-of-magnitude
   expectation for the host (e.g. a host running a few
   hundred processes should produce a `processes_info` event
   set of that magnitude per iteration; a host running tens of
   thousands of processes should produce orders of magnitude
   more). A wide enumeration whose event volume is wildly off
   the expected magnitude is a layer-3 (symbol map) or
   layer-4 (scan policy) symptom even when the known-target
   smoke passed.
5. **Capability snapshot.** Save the *as-deployed* answer to:
   which OS Inspector container tag is running, which DMA
   device + host VUID / OS type / symbol-map version / scan
   policy / scan interval are in effect, which DTS release is
   on the BlueField, which downstream consumer the DTS
   forwarder targets, the host kernel build version anchor
   the symbol map matches, the steady-state event-volume
   baseline at the wide-enumeration smoke, and the operator's
   data-sensitivity sign-off on the enabled APSH structs (in
   particular, any off-by-default struct that was turned on
   and why). This snapshot is the artifact that lets future
   debug sessions skip rediscovery — and the
   never-silently-disable + minimum-exposure rules in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   say the on-list and the off-list MUST both be in the
   snapshot, with reasons.

## debug

Layered diagnosis. Walk the layers in this order; do not skip
down without clearing the layer above. The six layers match
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).

1. **Container runtime layer.** Is the OS Inspector container
   actually running and not restart-looping? Symptoms:
   container exits immediately, image pull fails, restart
   count climbing, hugepages-allocation failure, DTS IPC
   socket / shared-memory volume mount failure. Resolution:
   confirm the image tag matches what the public guidance
   names for the operator's DOCA release; confirm the
   container mount paths match what the guidance names;
   confirm BlueField hugepages are reserved, the DTS-side IPC
   socket volume directory exists, and the shared-memory
   volume is writable; confirm BlueField has the runtime
   configured per the public Container Deployment Guide. This
   layer is owned by the container runtime, not by APSH or by
   the scan policy.
2. **Hardware-path layer.** Container green; OS Inspector logs
   report an APSH-side initialization failure or every
   enumeration returns zero results across every struct.
   Resolution: confirm the DMA device IBdev name is one that
   exists on this BlueField; confirm the host VUID matches the
   attached host; confirm the BlueField mode of operation
   exposes the host-memory-access surface APSH needs; confirm
   the DPU side has the privileges App Shield expects per the
   public DOCA App Shield guidance. This layer is owned by the
   BlueField configuration, not by the symbol map or by the
   scan policy. Cross-link [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
   for env-class confirmation.
3. **Symbol-map + memory-regions layer.** Container green;
   APSH context starts; enumeration returns empty / corrupt /
   nonsensical results; *especially* the symptom surfaces
   "after a host reboot" or "after a host patch round" and the
   deployment "was working yesterday". Resolution: confirm
   the host kernel build version on the host right now;
   confirm the symbol-map and memory-regions files mounted in
   the container were generated against THAT exact kernel
   build; if not, regenerate per the public DOCA App Shield
   guidance, replace the mounts, and restart the container.
   **Do NOT respond to a layer-3 symptom by changing the scan
   policy or by widening the enumeration** — the fix is on the
   symbol map.
4. **Scan-policy layer.** Container green; APSH context
   starts; enumeration runs and the known-target smoke passes;
   but the downstream consumer says either *"the struct I
   needed isn't in the feed"* (an enabled-struct gap) or
   *"the feed is carrying data we did not intend to expose"*
   (a struct turned on the operator's posture review did not
   sign off on). Resolution: walk the scan-policy JSON
   against the public guidance's struct-name set; turn the
   missing struct on with a documented downstream consumer;
   turn the over-firing struct off with a documented removal
   date per the never-silently-disable rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
5. **Telemetry-pipeline layer.** Container green; APSH
   enumeration runs and the OS Inspector container's logs
   show iterations completing; the downstream consumer
   surface stays empty. Resolution: walk the DTS-side ingest
   per the DOCA Telemetry Service Guide (via
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services));
   confirm the IPC socket between OS Inspector and DTS is
   live; confirm the DTS-side forwarder is configured to
   route to the downstream consumer; confirm the consumer
   side is configured to receive. This layer is owned by DTS
   and by the consumer side — re-tuning OS Inspector's scan
   policy here is wasted effort.
6. **Performance layer.** Container healthy, enumeration
   correct, DTS pipeline carrying — but the BlueField CPU is
   pegged, DMA traffic to the host is saturating, the host
   workload's PCIe latency is noticeably impacted, or
   hugepages pressure is rising. Resolution: lengthen the
   scan interval per the public guidance (tens of seconds vs
   single-digit seconds is a large posture shift); shrink
   the scan policy to only the APSH structs the downstream
   consumer actually needs; confirm hugepage reservation is
   sized to the deployment per the public guidance. **Do NOT
   respond to performance impact by silently dropping APSH
   structs** — re-tune the scan interval first, then prune
   the scan policy with documented removals.
7. **Version layer.** When the public OS Inspector / App
   Shield Agent / DOCA App Shield / DOCA Telemetry Service /
   Container Deployment Guide page appears to disagree with
   what the deployed container does, the docs version may not
   match the container tag, OR the host kernel build axis
   that OS Inspector adds on top of the standard four-way
   match is mismatched. Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 (partial install / version mismatch) and apply the
   container-tag overlay PLUS the host-kernel-version axis
   from
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
8. **Cross-cutting layer.** For env-side and program-side
   debug that is not OS Inspector-specific (host install,
   host kernel, DOCA library errors OS Inspector may surface
   from APSH or telemetry-exporter), drop to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).

## use

Day-2 operation: the consumer side is wired, the deployment is
past calibration, the feed is flowing — what does the operator
actually *do* with OS Inspector once it is in production?

1. **Treat the feed as a contract with the downstream
   consumer.** The OS Inspector → DTS → consumer pipeline is
   one continuous channel that the consumer side is
   alerting / triaging / archiving against. Changes to the
   scan policy, scan interval, symbol map, or container tag
   change the *shape* and *cadence* of the data the consumer
   sees; surface the change to the consumer side in the same
   change window, per the END-TO-END discipline in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
2. **Run the per-host-kernel-change rollover proactively.**
   Per the symbol-map-lifecycle rule, every host kernel
   change re-opens the deployment. The operator's runbook
   should:
    - Detect host kernel changes (the host's normal patching /
      reboot rotation is the trigger).
    - For every change, regenerate the symbol map and the
      memory-regions file against the new host kernel build
      per the public DOCA App Shield guidance.
    - Update the OS Inspector container's mounts and restart
      the container.
    - Re-run the known-target smoke from
      [`## test`](#test) step 1 BEFORE re-enabling the
      consumer-side alerting on the channel.
    - Update the symbol-map version anchor in the deployment's
      capability snapshot.
3. **Hold the minimum-exposure stance over time.** Operators
   under pressure from downstream consumers to *"add a few
   more fields"* will be tempted to flip off-by-default APSH
   structs (`processes_envars_info`, `processes_handles_info`,
   `privileges_info`) ON without a real downstream need. The
   honest moves are: (a) demand a documented downstream
   consumer that actually requires the data, (b) document the
   data-sensitivity classification of the now-widened feed,
   (c) confirm the DTS-side and consumer-side audiences are
   cleared to see the additional data, and (d) record the
   flip in the deployment's capability snapshot with the
   reason and the date. Per the minimum-exposure-by-default
   rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   silent expansions of the scan policy are the failure mode
   the rule exists to prevent.
4. **Watch for drift between the OS Inspector feed and the
   consumer side's expectations.** The downstream consumer
   typically codifies their expectations as a set of alerts /
   dashboards / correlation rules; those expectations are
   coupled to the scan policy and the APSH event shape the
   guidance pinned at the container tag the operator
   deployed. A consumer-side rule that depended on a struct
   that was disabled, or that expected fields the new
   guidance moved, will degrade silently. The operator's
   periodic review surface is the capability snapshot from
   [`## test`](#test) step 5 plus the consumer-side rule
   inventory.
5. **Use the layered error taxonomy as the on-call playbook.**
   When the operator is paged on *"the feed is wrong"*, the
   first question is *"which of the six layers in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   does this symptom map to?"*. Most production incidents on
   OS Inspector are layer 3 (host kernel changed; symbol map
   is stale) or layer 5 (DTS-side forwarder or consumer-side
   ingest changed); jumping to the scan policy or the
   container tag before walking the layers is the dominant
   debug-time failure mode.

## Command appendix

OS Inspector-specific commands the verbs above reach for,
grouped by purpose so the agent picks the right family without
searching prose. Every row is a class — the agent must not
invent flags beyond what the row names; flag and command
discovery is `--help` on the installed tool or the public
guidance, not prose recall.

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
| Container lifecycle | The BlueField container manager's start / stop / status command for the OS Inspector container, per the public Container Deployment Guide | [`## run`](#run) | Container `running`, restart count stable. |
| Container logs | The BlueField container manager's log-stream command for the OS Inspector container | [`## debug`](#debug) layers 1–3 | Documented startup banner + APSH-context-created + telemetry-source-started + scanner-iteration lines visible; no documented error / warning lines repeating. |
| Hugepages inventory | The BlueField's normal hugepages query (per [`doca-setup TASKS.md ## Command appendix`](../../doca-setup/TASKS.md#command-appendix)) | [`## install`](#install); [`## debug`](#debug) layer 1 | The reservation matches what the public OS Inspector / App Shield Agent guidance names. |
| BlueField device inventory | The BlueField's normal IBdev / device-listing path (per [`doca-setup TASKS.md ## Command appendix`](../../doca-setup/TASKS.md#command-appendix)) | [`## configure`](#configure); [`## debug`](#debug) layer 2 | The DMA device the operator chose is present and bound. |
| DTS IPC socket presence | A filesystem check that the DTS-side IPC socket volume directory exists on the BlueField and is mountable into the container | [`## install`](#install); [`## debug`](#debug) layer 5 | The path exists; the OS Inspector container can mount it. |
| Symbol-map version anchor | The operator's own documented record of which host kernel build the mounted symbol-map + memory-regions files were generated against | [`## test`](#test) step 5; [`## use`](#use) step 2 | The anchor matches the host kernel build currently running on the host. |
| Container tag in use | The BlueField container manager's image-inspect command for the running OS Inspector container | [`## run`](#run) step 1; [`## debug`](#debug) layer 7 | Tag matches what the public OS Inspector / App Shield Agent guidance names for the operator's DOCA release. |
| Scan-policy snapshot | The operator's own documented record of which APSH structs are enabled, which off-by-default structs (if any) were flipped on, and the reason / data-sensitivity sign-off for each | [`## test`](#test) step 5; [`## use`](#use) step 3 | The snapshot is current; no off-by-default struct is enabled without a documented downstream consumer and a documented review sign-off. |
| DTS-side ingest confirmation | The DTS team's normal ingest-confirmation surface and the downstream consumer's review surface | [`## test`](#test) step 1; [`## debug`](#debug) layer 5 | Known-target smoke event present at the consumer surface; steady-state event flow visible at the expected rate. |
| Container DOCA log level | The OS Inspector container's `--log-level` / `-l` argument the public guidance documents (the project's params shape allows a numeric level in the documented range) | [`## debug`](#debug) layers 1–3 | The level is set high enough to surface the documented log lines the debug step depends on; `DOCA_LOG_LEVEL` cross-link in [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability). |

Three cross-cutting rules for this appendix:

- **Never invent an OS Inspector argument, container tag,
  APSH struct name, or telemetry-event field.** The public
  OS Inspector / App Shield Agent guidance is the contract;
  the public DOCA App Shield library guide is the secondary
  source for the underlying APSH semantics; the public DOCA
  Telemetry Service Guide is the secondary source for the
  consumer side. Prose-derived flags, struct names, or event
  fields are the most common hallucination failure for this
  skill.
- **Container before findings before consumer.** When
  triaging, confirm the container layer (running, not
  restart-looping, image tag correct, mounts present) BEFORE
  reading any APSH-layer command; confirm the APSH-layer
  (context created, scanner iterating) BEFORE reading any
  DTS / consumer-side command. A non-running container
  makes every downstream command meaningless; a non-healthy
  APSH context makes every consumer-side command misleading.
- **Cross-link instead of duplicate.** Cross-cutting env
  commands (port-state, `devlink`, `ip link`, `ethtool`,
  hugepages, IBdev listing) live in
  [`doca-setup TASKS.md ## Command appendix`](../../doca-setup/TASKS.md#command-appendix);
  this appendix names only the OS Inspector-specific ones.

## Deferred task verbs

- **Installing DOCA on the BlueField** — out of scope here.
  Route to [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  for env preparation and
  [`doca-setup ## test`](../../doca-setup/TASKS.md#test) for
  install health verification, or
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path. The [`## install`](#install)
  step in this skill is the OS-Inspector-container-side install
  on top of an already-healthy DOCA install, not DOCA itself.
- **Generating a host kernel symbol map from scratch** — out
  of scope here. The generation procedure is host-OS-version-
  specific and lives in the public DOCA App Shield guidance;
  this skill names *that* the map is a hard prerequisite,
  *that* it must be refreshed on every host kernel change,
  and *where* the procedure is documented. The artifact
  itself is the operator's host-inventory responsibility.
- **Configuring the DTS-side forwarder or the SIEM-side
  ingest** (Splunk forwarder stanzas, ELK pipelines, Sentinel
  data-connector blocks) — out of scope here. The OS
  Inspector contract is *that* the telemetry-exporter source
  must reach DTS and *what* the documented event shape is;
  the DTS-side forwarder configuration belongs to the DOCA
  Telemetry Service Guide, and the SIEM-side ingest body
  belongs to the consumer team's SIEM documentation.
- **Designing the host-introspection posture** (which APSH
  structs matter for which downstream consumer, regulatory
  mappings, incident response runbooks against the feed) —
  out of scope here. That is a security-program / posture-
  design concern that the operator and the consumer team
  own; OS Inspector only publishes the APSH events the
  posture has decided are worth publishing.
- **Building a custom DPU-side introspection tool** — not an
  OS Inspector question. Route to
  [`doca-apsh ## configure`](../../libs/doca-apsh/TASKS.md#configure)
  for the App Shield library workflow plus
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the canonical build pattern.
- **Runtime-security findings (suspicious activity,
  integrity violations)** — not raw introspection. Route to
  [`doca-argus ## configure`](../doca-argus/TASKS.md#configure)
  for the packaged runtime-security service workflow.
- **Other DOCA services** (DMS / Firefly / Flow Inspector /
  BlueMan / HBN / SNAP / …) — not OS Inspector. Route to
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services)
  for the routing table and the matching `services/<service>`
  skill when it exists (e.g.
  [`doca-firefly ## configure`](../doca-firefly/TASKS.md#configure)
  for PTP, or
  [`doca-flow-inspector ## configure`](../doca-flow-inspector/TASKS.md#configure)
  for DOCA Flow telemetry). The container-shaped deployment
  pattern is shared; the per-service domain is different.

## Cross-cutting

- The public OS Inspector / App Shield Agent guidance, the
  public DOCA App Shield library guide, the public DOCA
  Telemetry Service Guide, and the public DOCA Container
  Deployment Guide are jointly the single source of truth.
  Any argument name, struct name, container tag, telemetry
  event field, or observability output the agent quotes must
  come from those, not from generic introspection knowledge
  or memory from a previous OS Inspector release.
- OS Inspector is END-TO-END. The container reads host
  memory via APSH; the telemetry-exporter source publishes
  to DTS; the DTS-side forwarder ships to the downstream
  consumer; the consumer team reviews / correlates /
  archives. All four legs are mandatory; naming only one is
  how the channel silently breaks.
- Path-selection is mandatory up front. OS Inspector (the
  packaged service) is the production default for a
  deployable introspection feed;
  [`doca-apsh`](../../libs/doca-apsh/SKILL.md) (the library)
  is the right answer only when the user is genuinely
  building their own custom introspection product;
  [`doca-argus`](../doca-argus/SKILL.md) is the right answer
  when the user wants runtime-security *findings* rather
  than raw introspection.
- The host kernel symbol map is host-OS-version-specific.
  Refreshing the map on every host kernel change is a
  mandatory step in the deployment runbook; the
  *"container is green but the feed is wrong"* failure mode
  is silent without this discipline.
- Hold the minimum-exposure stance over time. The off-by-
  default APSH structs (`privileges_info`,
  `processes_envars_info`, `processes_handles_info`) carry
  the highest-sensitivity host data; flipping any of them on
  is a deliberate decision with a documented downstream
  consumer and a documented review, never a "might as
  well" flip.
- Smoke before bulk. One known-running target on the host
  must traverse the full OS Inspector → APSH → DTS →
  consumer pipeline, with a baseline established, before the
  consumer team's production consumption is enabled on the
  channel.
- For URL routing to the OS Inspector / App Shield Agent /
  DOCA Telemetry Service / Container Deployment Guide and
  other public DOCA documentation, see
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).
