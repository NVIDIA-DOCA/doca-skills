# DOCA OS Inspector Service — Capabilities

**Where to start:** The pattern overview below names the recurring
OS-Inspector-class operational patterns. Pick the pattern first,
then drill into the H2 that owns the substance. For the *how* of
executing each pattern, jump to [TASKS.md](TASKS.md).

This file enumerates OS Inspector's documented capabilities,
deployment shape, configuration axes, and operational behaviors.
OS Inspector is the deployable, telemetry-emitting service form
of the DOCA App Shield introspection surface; the authoritative
public sources are the **DOCA App Shield Agent Application
Guide** (the application form of the same APSH-driven
introspection workflow), the **DOCA App Shield** library guide
(for the underlying introspection semantics, the host kernel
symbol-map prerequisite, and the per-target *NOT_FOUND* rule),
the **DOCA Telemetry Service Guide** (for the consumer side of
OS Inspector's findings), and the **DOCA Container Deployment
Guide** (for the canonical container deployment recipe). For URL
routing, go through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
— this skill does not duplicate the URL routing. Treat this file
as a *map of what is documented*, not a substitute for reading the
live page when configuring a real deployment.

## Pattern overview

Every OS-Inspector-class question this skill teaches resolves into
one of SIX patterns. The patterns are CLASSES — they apply across
every OS Inspector deployment, not just one host OS or one DTS
consumer.

| OS Inspector pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Decide OS Inspector (packaged service) vs apsh (library) vs Argus (security findings) vs nothing | Deployable host-OS introspection feed → OS Inspector; custom DPU-side introspection tool → [`doca-apsh`](../../libs/doca-apsh/SKILL.md); runtime-security findings packaged with detection policy + SIEM forwarding → [`doca-argus`](../doca-argus/SKILL.md); no introspection need → neither | [`## Safety policy`](#safety-policy) path-selection rule |
| 2. Pick the five configuration axes | DMA device + host VUID + OS type + host symbol map + memory regions + scan policy + scan interval — every axis is a deployment hazard if wrong | [`## Capabilities and modes`](#capabilities-and-modes) five-axis table |
| 3. Wire the END-TO-END introspection pipeline | OS Inspector container reads host memory via APSH; the telemetry-exporter source publishes to DTS; DTS forwards to the downstream consumer (SIEM / analyst dashboard / custom correlator) — all four legs are independent moving parts | [`## Safety policy`](#safety-policy) END-TO-END rule + [`## Capabilities and modes`](#capabilities-and-modes) deployment shape |
| 4. Pair with the consumer side | DTS-fed Splunk / ELK / Sentinel / analyst dashboard / custom correlator — each pairs with OS Inspector in the same shape (OS Inspector = APSH-event emitter; DTS = transport; consumer = decision layer) | [`## Capabilities and modes`](#capabilities-and-modes) pairing table |
| 5. Map an OS Inspector symptom back to its layer | Container-runtime vs hardware-path vs symbol-map + memory-regions vs scan-policy vs telemetry-pipeline vs performance — six independent layers, each with its own owner | [`## Error taxonomy`](#error-taxonomy) layered split |
| 6. Hold the data-sensitivity / minimum-exposure stance | Introspecting a running host kernel exposes process / library / module / VAD / (optionally) handle and env-var data; the deployment posture must be reviewed before the scan-policy widens beyond the project's defaults | [`## Safety policy`](#safety-policy) minimum-exposure rule |

Two cross-cutting rules that apply to *every* pattern above:

- **The host kernel symbol map is host-OS-version-specific —
  refresh on every host kernel change.** OS Inspector inherits
  App Shield's hard prerequisite: the DPU must hold a symbol map
  (and a memory-regions file) that matches the running host
  kernel build. A kernel upgrade on the host silently invalidates
  the map; the container keeps running, the scanner keeps
  iterating, and the feed quietly stops representing reality.
  This is the single largest source of *"the container is green
  but the findings are wrong"* incidents for OS Inspector and
  the failure mode this skill exists to keep from being silent.
- **Operate the documented path; do not invent one.** OS
  Inspector's container image source, command-line arguments,
  config schema, scan-policy keys, and DTS-side ingest contract
  are all documented in the public OS Inspector / App Shield
  Agent / DOCA Telemetry Service / Container Deployment Guide
  pages reachable through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  Quoting config keys, image tags, CLI flags, or APSH event
  types not in the public guidance is the most common
  hallucination failure mode for this skill.

## Capabilities and modes

### Service shape

OS Inspector is a **long-running container** that ships from
NGC and runs on the BlueField Arm cores. The container is the
daemon: it owns the host-OS introspection surface (an APSH
context driving a DMA-attached read of the host's kernel memory
over PCIe), it owns the per-iteration scanner that re-walks the
configured APSH structs, and it owns the telemetry-exporter
source that publishes each iteration's findings into the DOCA
Telemetry Service's IPC socket. There is no host-side OS
Inspector binary the user installs — OS Inspector is the
container; the host's relationship to OS Inspector is that
OS Inspector *observes* the host (over the DPU's DMA path into
host memory), not that OS Inspector *runs on* the host.

Three architectural properties the operator must hold throughout:

- **The container is the unit of deployment.** Operators do not
  start `doca_os_inspector` as a host binary; they start the
  OS Inspector container per the public Container Deployment
  Guide pattern (same shape as every other DOCA service
  container — see the sibling
  [`doca-argus`](../doca-argus/SKILL.md),
  [`doca-firefly`](../doca-firefly/SKILL.md), and
  [`doca-flow-inspector`](../doca-flow-inspector/SKILL.md) for
  the same shape on different per-service domains). The
  cross-cutting recipe lives in
  [`doca-container-deployment`](../../doca-container-deployment/SKILL.md);
  this skill layers the per-service mounts and arguments on top.
- **OS Inspector is a packaged service, not a library.** The
  whole point of OS Inspector is that the APSH context, the
  per-iteration scanner loop, the telemetry-event registration
  for each enumerated struct, and the DTS-targeted output ship
  as one operationally-ready unit. An operator who finds
  themselves writing their own scanner loop on top of
  `doca_apsh_*` has reached for the wrong artifact and should
  be routed to [`doca-apsh`](../../libs/doca-apsh/SKILL.md), the
  lower-level library that custom introspection tooling builds
  on.
- **Findings are raw enumerations, not detection alerts.** OS
  Inspector publishes the APSH-shaped data ("here are the
  processes currently running on the host, here are the loaded
  kernel modules, here are the libraries loaded into each
  process") into the DTS pipeline; it does NOT decide what is
  suspicious. An operator looking for *findings about
  suspicious activity* with a tuned detection policy and SIEM
  forwarding built in is asking the wrong service; route them
  to [`doca-argus`](../doca-argus/SKILL.md). OS Inspector is
  the right tool when the consumer side wants the raw
  enumeration to feed their own detection / correlation /
  archival logic.

## Deployment shape

The public Container Deployment Guide documents the container
runtime story; the public OS Inspector / App Shield Agent
guidance names the per-service mounts and command-line arguments.
The shape lines up with every other DOCA service container — pull
from NGC, mount the config + the operator-supplied APSH
prerequisites (symbol map, memory regions), start under the
documented runtime (the BlueField OS's container manager per the
public Container Deployment Guide). For the canonical
container-deployment recipe shared with the other DOCA service
containers, route through
[`doca-container-deployment`](../../doca-container-deployment/SKILL.md)
and confirm the URL set via
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

Two deployment-shape rules:

- **BlueField Arm only.** OS Inspector is a BlueField-side
  service; it does not run on the host. The host's relationship
  to OS Inspector is via the PCIe DMA path that the BlueField
  attaches to host memory (the same architectural shape as
  [`doca-apsh`](../../libs/doca-apsh/SKILL.md), only packaged)
  and via the DTS pipeline (the downstream consumer reaches the
  feed off the BlueField).
- **One OS Inspector deployment per BlueField + host pair.** The
  five-axis configuration (DMA device + VUID + OS type + symbol
  map + scan policy) describes one operator-owned posture
  against one host kernel. Running two OS Inspector containers
  on the same BlueField competing for the DMA path against the
  same host is a configuration error, not a redundancy strategy
  — APSH context contention multiplies operational cost without
  multiplying signal.

### Five-axis configuration

Every OS Inspector deployment must commit to five configuration
axes before starting the container. Get any one wrong and the
deployment fails in a different mode (no enumeration / wrong
host / wrong-shaped enumeration / no findings published /
performance-impacted host or BlueField). The axes are jointly
documented in the public OS Inspector / App Shield Agent / DOCA
App Shield guidance; quote the exact valid values from there
rather than from memory.

| Axis | Class shape | Mismatch symptom | Where to look |
| --- | --- | --- | --- |
| **DMA device + host VUID** | The BlueField PCIe path that attaches to the host's memory. The DMA device is the IBdev name of the BlueField NIC function the container will use (typically a `mlx5_*` form); the host VUID identifies the host whose memory is being introspected. Both come from the live BlueField + host inventory, not from memory | Container starts; APSH cannot open the host memory path; every enumeration returns zero results or an APSH-side error. Distinct from a stale symbol map (this axis is the *hardware path*, the next axis is the *interpretation layer*) | The public DOCA App Shield guidance plus the operator's BlueField inventory ([`doca-setup`](../../doca-setup/SKILL.md) for the device-listing path) |
| **OS type** (Linux / Windows) | Drives which APSH telemetry-event registration the scanner uses; an OS Inspector built for one OS family cannot interpret the other's kernel layout | Container starts; APSH-side enumeration is silent or garbled because the configured event registration shape doesn't match the host's actual kernel | The public DOCA App Shield guidance's OS-type matrix |
| **Host kernel symbol map + memory regions** | The host-OS-version-specific symbol-map file ("VMA / OS symbols") and memory-regions file the APSH library needs to interpret the host's kernel memory. Generated against the *exact* host kernel build; silently invalid after a host kernel upgrade | Container starts; APSH context creates; enumeration returns empty / corrupt results; the most common *"the container is green but the feed is wrong"* mode for OS Inspector | The public DOCA App Shield guidance's symbol-map generation procedure; the artifact lives in the operator's host inventory |
| **Scan policy** | Which APSH structs the scanner enumerates and publishes each iteration. The project's default JSON exposes `processes_info`, `threads_info`, `libs_info`, `vads_info`, and `system_modules_info` and explicitly **defaults `privileges_info`, `processes_envars_info`, and `processes_handles_info` OFF** — that minimum-exposure stance is the deployment's safety floor, not a starting point to flip ON without review | Wrong scan policy = wrong feed shape: a deployment that turns on `processes_envars_info` silently widens the data the DTS pipeline (and every downstream consumer) is now carrying; a deployment that leaves `system_modules_info` off cannot detect a loaded kernel module the consumer wanted to alert on | The public DOCA App Shield Agent guidance's scan-policy section; cross-link the minimum-exposure rule in [`## Safety policy`](#safety-policy) |
| **Scan interval** (`-t <seconds>`) | The cadence at which the scanner re-walks every enabled APSH struct. Trades freshness against DMA traffic / BlueField CPU / host PCIe pressure | Too short → BlueField CPU pegged, DMA bus saturated, host-side PCIe latency observable; too long → the feed misses transient processes / loaded modules / loaded libraries that came and went between iterations | The public DOCA App Shield Agent guidance's command-line argument set |

The agent's rule: **the five-axis decision precedes everything
else**. A deployment that starts the container before the
operator can name the DMA device, host VUID, OS type, symbol
map + memory regions, scan policy, and scan interval is going
to debug the wrong axis first. Force the decision up front.

### Pairing with DTS-side consumers

OS Inspector is the APSH-event-emitting side of every supported
pairing. The DOCA Telemetry Service (DTS) on the BlueField is
the transport. The downstream SIEM / analyst dashboard / custom
correlator is the decision-making side. All three legs must be
wired; OS Inspector alone is not a finished deployment.

| Consumer side | Why it pairs with OS Inspector | Pairing shape |
| --- | --- | --- |
| Splunk (via DTS forwarding) | Standard enterprise SIEM; common when the operator already triages on Splunk and wants a host-introspection feed alongside their network telemetry | OS Inspector publishes APSH events into DTS via the documented telemetry-exporter IPC socket; DTS forwards to Splunk via DTS's own documented forwarder per the DOCA Telemetry Service Guide; review happens in Splunk dashboards / alerts on the consumer side |
| ELK (Elasticsearch + Logstash + Kibana) | Open-source consumer stack; common when teams self-host | Same shape — OS Inspector emits to DTS; DTS forwards to ELK; review happens in Kibana dashboards |
| Microsoft Sentinel | Cloud-hosted SIEM; common when the security ops team is already on Azure | Same shape — OS Inspector emits to DTS; DTS forwards to Sentinel; review happens in Sentinel |
| Custom analyst dashboard / correlator | Floor case when the consumer side is built in-house (a security tool, a host-fleet inventory, a custom enrichment pipeline) | Same shape — OS Inspector emits APSH events to DTS in the documented telemetry-exporter format; the custom consumer reads from DTS per the DOCA Telemetry Service Guide's consumer contract; decision logic lives entirely on the consumer side |

The agent's rule: when the user mentions a downstream consumer by
name, name OS Inspector *and* the DTS pipeline *and* the
consumer-side ingest in the same breath. Naming only the
OS Inspector side is how the end-to-end pipeline silently breaks:
the feed is "up" from OS Inspector's perspective, the events sit
in DTS, and the consumer surface stays empty until somebody
checks why.

### Configuration model

The OS Inspector container is configured by (a) the documented
command-line arguments (or the equivalent JSON-form argument
file the project's entrypoint accepts via `--json`) — covering
the DMA device, host VUID, OS type, symbol-map and memory-regions
file paths, scan interval, and log level — and (b) a documented
scan-policy JSON file that names which APSH structs the scanner
enumerates each iteration. The operator mounts the symbol map,
the memory-regions file, and the scan-policy file into the
container at the paths the public guidance names. Quote argument
names, scan-policy keys, and command-line flags from the live
public OS Inspector / App Shield Agent guidance; do not infer
them from generic introspection-tooling knowledge or from a
previous DOCA release.

For deployments that need to evolve their scan policy over time
(adding a struct to the feed because a downstream consumer
needs it, removing a struct because its data-sensitivity is no
longer in scope), the agent should walk the operator through
the public guidance's documented procedure rather than ad-hoc
editing — every scan-policy mutation re-opens the smoke sweep
per [`## Safety policy`](#safety-policy) and the eval-loop in
[`TASKS.md ## test`](TASKS.md#test).

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-docs
rule, see [`doca-version`](../../doca-version/SKILL.md). The body
lives there; this skill does not duplicate it.

**The OS Inspector-specific overlay** is:

- **OS Inspector is an NGC container; the container tag is the
  runtime version anchor.** Same pattern as
  [`doca-argus`](../doca-argus/SKILL.md),
  [`doca-firefly`](../doca-firefly/SKILL.md), and the other
  DOCA service containers: OS Inspector ships from NGC with its
  own tag that may lag the host's DOCA package version, and the
  relevant version anchor for an as-deployed OS Inspector is the
  container tag pulled, not `pkg-config --modversion` on the
  host. Always quote both versions when the user reports an
  OS Inspector behavior; if they diverge, route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before diagnosing the OS Inspector behavior itself.
- **The host kernel version is a third compatibility axis on top
  of the DOCA / container-tag axes.** OS Inspector inherits from
  App Shield the requirement that the symbol-map and
  memory-regions files match the exact host kernel build. When
  the user asks *"why did my feed go silent after the host
  reboot?"*, the authoritative answer is to confirm that (a)
  the host kernel build version did or did not change across
  the reboot, and (b) the symbol map and memory-regions files
  on the BlueField match the post-reboot host kernel. A
  matching DOCA version + container tag is necessary but not
  sufficient — the host kernel axis is an additional gate that
  no other DOCA service container has.
- **Read the public OS Inspector / App Shield Agent guide
  version header.** The guide is versioned; the on-page version
  must match the container tag the operator is using. A
  mismatch between the docs version and the container tag is
  the canonical *"my config doesn't work even though it
  matches the docs"* failure mode shared with every other DOCA
  service container.
- **Scan-policy schema and APSH event-type set are version-
  bound.** The set of APSH structs OS Inspector can enumerate
  and the keys the scan-policy JSON accepts evolve between
  releases. When the user asks *"is `processes_handles_info`
  available on this OS type at this release?"*, the
  authoritative answer is the public App Shield / OS Inspector
  guide page whose version matches the container tag pulled —
  not memory from a previous release.

## Error taxonomy

OS Inspector errors fall into six layers, each with its own
owner. The agent's rule: walk the layers in order; do NOT skip
down without clearing the layer above.

| Layer | Symptom | Root cause class | Where to fix |
| --- | --- | --- | --- |
| 1. Container runtime | Container fails to start, restart-loops, exits immediately, image pull fails, hugepages allocation fails, the DTS IPC socket volume / shared-memory volume mount fails | Image tag wrong, registry credentials missing, BlueField runtime not configured to run this container, hugepages not reserved on the BlueField (a BFB-side env precondition), the DTS-side IPC socket volume not present on the BlueField filesystem, config file mount path wrong | BlueField container runtime + the public Container Deployment Guide via [`doca-container-deployment`](../../doca-container-deployment/SKILL.md); [`doca-setup`](../../doca-setup/SKILL.md) for the hugepages and DTS-side prerequisites |
| 2. Hardware path | Container green; OS Inspector logs report an APSH-side initialization failure or `DOCA_ERROR_*` opening the host memory path; enumeration is zero results across every struct | DMA device wrong (no such IBdev on the BlueField), host VUID wrong (no such host attached on that PCIe path), DPU lacks the privileges App Shield needs to open the host introspection path, the BlueField is not in a mode of operation that gives the DPU side the necessary memory-access surface | The public DOCA App Shield guidance's prerequisites; the BlueField mode of operation (cross-link [`doca-hardware-safety CAPABILITIES.md ## Capabilities and modes`](../../doca-hardware-safety/CAPABILITIES.md#capabilities-and-modes) if a mode flip is being considered) |
| 3. Symbol map + memory regions | Container green; APSH context starts; enumeration returns empty / corrupt / nonsensical results; the symptom often surfaces *after a host kernel upgrade* and "the deployment was working yesterday" | Symbol map and / or memory-regions file does NOT match the running host kernel build. The map is host-OS-version-specific; the post-upgrade host kernel is reading uninterpretable memory through last release's map | The public DOCA App Shield guidance's symbol-map generation procedure against the *current* host kernel build; refresh the map, restart the container, re-confirm the symbol-map version anchor in the operator's runbook |
| 4. Scan policy | Container green; APSH context starts; enumeration runs but the consumer side reports either "the struct I wanted isn't in the feed" or "the feed is carrying data we did not intend to expose" | Scan policy mismatched against the consumer's expectations: a struct the consumer needed is off, or a struct the operator's posture review did not include is on. The mismatch is a config decision, not a runtime fault | The scan-policy JSON the container is mounted; the public guidance's struct-name set; the minimum-exposure rule in [`## Safety policy`](#safety-policy) |
| 5. Telemetry pipeline | Container green; APSH enumeration runs and the OS Inspector container's logs show iterations completing; the downstream consumer surface stays empty | The telemetry-exporter source is publishing into DTS's IPC socket, but the DTS-side ingest is not configured or the DTS forwarder is not routing to the consumer. The container is correct; the gap is on the DTS / consumer side | The DOCA Telemetry Service Guide (via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)) for the DTS-side ingest + forwarder configuration; the consumer-side docs for the receiving end |
| 6. Performance | Container healthy, enumeration correct, DTS pipeline carrying — but the BlueField CPU is pegged, DMA traffic to the host is saturating the PCIe budget, or the host workload is reporting noticeable latency / CPU since OS Inspector started | Scan interval too aggressive for the workload pattern (every iteration walks every enabled APSH struct over DMA reads of host memory); too many APSH structs enabled at once for the scan interval the operator picked; insufficient hugepages reserved on the BlueField | The scan interval + scan-policy axes in this skill; the BlueField hugepage reservation in [`doca-setup`](../../doca-setup/SKILL.md) |

The agent's rule: **never recommend a scan-policy change without
first identifying which of the six layers is the cause**. The
most common debug failure for this skill is misreading a layer-3
symptom (stale symbol map after a host kernel upgrade) as a
layer-4 problem (wrong scan policy) and turning structs on or
off when the fix is on the map. Equally common: misreading a
layer-5 symptom (DTS pipeline gap) as a layer-2 problem
(hardware path) and rewriting the container arguments when the
fix is on the DTS-side ingest.

## Observability

Documented observability surfaces the agent should reach for, in
order of how cheaply they answer the *"is OS Inspector actually
working"* question:

1. **Container state.** First — is the OS Inspector container
   actually running? The BlueField container manager reports
   container status, restart count, and the container's stdout /
   stderr log stream. A restart loop is a layer-1 (container
   runtime) symptom per [`## Error taxonomy`](#error-taxonomy);
   diagnose it before touching scan policy.
2. **OS Inspector's own logs.** The container's stdout (and any
   documented log destination the public guidance specifies) is
   the primary operational observability surface. Look for the
   documented startup-banner lines, the APSH-context-created
   line, the per-iteration scanner lines that the public
   guidance documents, and any `DOCA_LOG_ERR` lines surfacing
   APSH-side or telemetry-exporter-side errors. The agent should
   NOT invent log line formats; quote what the live container is
   emitting.
3. **APSH-side enumeration cadence.** The scanner re-walks every
   enabled APSH struct each scan interval. The OS Inspector
   container's logs report when each iteration starts and
   completes; an iteration that runs forever, or that produces a
   zero-result enumeration where the operator knows the host has
   running processes, is the cheapest signal of a layer-2
   (hardware path) or layer-3 (symbol map) problem.
4. **DTS-side ingest confirmation.** OS Inspector publishes via
   the documented telemetry-exporter IPC socket into DTS. The
   end-to-end smoke is not *"OS Inspector emitted a telemetry
   event"*; it is *"DTS received the event and forwarded it
   to the downstream consumer surface the team will actually
   look at"*. The agent must teach the user to verify the
   DTS-side ingest, not just the OS Inspector-side emit. The
   DTS-side observability surface is owned by the DOCA
   Telemetry Service Guide (route through
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)).
5. **BlueField + host performance baseline.** When the agent
   suspects layer 6 (performance), the cheapest confirmation is
   a BlueField-CPU / DMA-traffic / host-PCIe-latency comparison
   before vs after OS Inspector was started, paired with the
   scan-interval setting. If the BlueField was healthy without
   OS Inspector and is impacted with it running, the scan
   interval + scan-policy size are the first things to re-tune,
   not the layer-2 hardware path.
6. **Host kernel version anchor.** When the user reports *"it
   was working yesterday, now the feed is wrong"*, the cheapest
   layer-3 confirmation is to compare the symbol-map version
   anchor against the *current* host kernel build. A host that
   silently rebooted onto a new kernel is the canonical
   triggering event for layer-3 symptoms.

For the cross-library debug-time observability (`DOCA_LOG_LEVEL`,
`--sdk-log-level`, the trace build flavor — relevant when
OS Inspector calls into the App Shield or Telemetry Exporter
libraries and they emit structured logs), see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

OS Inspector's safety surface is **path-selection first**, then
the END-TO-END discipline, then the minimum-exposure rule, then
the host-symbol-map-lifecycle rule, then the smoke-before-bulk
rule. OS Inspector is a host-introspection tool that reads
running-kernel memory; the agent's safety bar is higher here
than for a network-side service, because the failure modes
include silent data-exposure widening and silent feed-correctness
loss.

- **Path-selection rule (load-bearing).** OS Inspector is the
  right answer only when the user wants **a deployable, container-
  shaped host-OS introspection feed flowing into the BlueField's
  DTS pipeline for a downstream consumer to act on**. Concretely:
    - Use OS Inspector when the operator needs a packaged
      introspection feed they can deploy on BlueField Arm
      without writing code against APSH, and they own the
      downstream detection / correlation / archival logic on
      the consumer side (a SIEM, an analyst dashboard, a
      custom correlator). This is the production default for
      most operators in this position.
    - **First recommend OS Inspector (the packaged service)
      over [`doca-apsh`](../../libs/doca-apsh/SKILL.md) (the
      library) for production introspection-feed use cases.** A
      response that walks an external operator into building
      their own scanner loop on apsh as the default answer for
      a deployable introspection feed is wrong by construction
      — the operator gets to own the scanner cadence, the
      APSH-struct enumeration, the telemetry-exporter wiring,
      and the lifetime of all of it, when OS Inspector already
      ships those.
    - When the user wants **runtime-security findings**
      (suspicious-activity / integrity-violation alerts) with
      detection policy + SIEM forwarding built in, route to
      [`doca-argus`](../doca-argus/SKILL.md). OS Inspector is
      the raw-enumeration surface; Argus is the detection
      surface. Recommending OS Inspector when the user actually
      wants alerts trains the operator to build their own
      detection logic on top of a feed that does not need to
      be built up to that.
    - Do NOT reach for OS Inspector when there is no host-
      introspection need (the feed has operational cost —
      container, hugepages, DMA traffic, DTS pipeline — for
      nothing); when the user is genuinely building a custom
      DPU-side introspection product that needs to ship its
      own decision logic (route to
      [`doca-apsh`](../../libs/doca-apsh/SKILL.md) — same shape
      of DPU-side observation, different shape of operator
      effort); or when the user actually wants observability
      / metrics rather than introspection (route to the DOCA
      Telemetry Service via
      [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).
- **END-TO-END discipline (load-bearing).** OS Inspector emits
  APSH events into DTS. DTS forwards to the downstream consumer.
  The consumer reviews / correlates / archives. An OS Inspector
  deployment that names only the BlueField side and stops there
  is a deployment that will *fail silently at DTS or on the
  consumer side*, not a deployment that works. The agent must
  always teach the four legs together: OS Inspector container →
  APSH reads host memory over PCIe → telemetry-exporter source →
  DTS → consumer surface.
- **Minimum-exposure-by-default rule (load-bearing).** The
  project's default scan policy ships with `processes_info`,
  `threads_info`, `libs_info`, `vads_info`, and
  `system_modules_info` ON and **with `privileges_info`,
  `processes_envars_info`, and `processes_handles_info` OFF**.
  That asymmetry is a deliberate minimum-exposure stance: the
  off-by-default structs carry the highest-sensitivity host
  data (process command-line / environment variables, open
  handles, security privileges). The agent's safety job is to
  preserve that floor. Turning any off-by-default struct ON
  must be a deliberate decision with a documented reason and
  a documented downstream consumer that actually needs the
  data, not a "might as well" flip. **Silent expansions of the
  scan policy widen the data the DTS pipeline (and every
  downstream consumer of it) is now carrying about the host;
  unwinding that exposure later is harder than not opening it.**
- **Host kernel symbol map is host-OS-version-specific
  (load-bearing).** Every host kernel upgrade silently
  invalidates the symbol-map and memory-regions files on the
  BlueField. The container keeps running, the scanner keeps
  iterating, and the feed quietly stops representing reality.
  The agent's job is to keep this from being silent: the
  symbol-map version anchor MUST be tracked alongside the
  container tag and the host kernel build, the deployment
  runbook MUST include "refresh the symbol map after every
  host kernel change" as a mandatory step, and any
  "container is green but enumeration is empty / wrong"
  symptom must check the symbol-map / host-kernel pair FIRST
  per [`## Error taxonomy`](#error-taxonomy) layer 3.
- **Never silently disable an APSH event (load-bearing).** When
  a scan policy is over-firing (too much data into DTS for the
  downstream consumer to triage, performance impact on the
  BlueField), the honest moves are: (a) tighten the scan
  interval per the public guidance, (b) remove an APSH struct
  from the policy explicitly and document the removal with the
  date and the reason, or (c) move the deployment to a less
  aggressive sampling tier. **Silent disables are forbidden.**
  An undocumented struct removal becomes an unknown blind spot
  the next time the team rotates, and the agent's only job in
  this corner is to keep the disable from becoming silent.
- **Smoke before bulk (load-bearing).** Before pointing the
  downstream consumer's production review channel at the
  OS Inspector deployment, the agent must walk the user
  through a smoke: container running and not restart-looping,
  APSH context created against the configured DMA device + VUID
  + OS type + symbol map + memory regions, one iteration
  completes against a known-running target on the host
  (e.g. `init` / `systemd` for Linux), the event appears in
  DTS, and DTS forwards it to the consumer surface. Only then
  enable the production consumer pipeline on top. A consumer
  channel that goes from "no OS Inspector" to "all production
  consumption on" without a smoke step silently uses a wrong
  baseline, and the bisection across OS Inspector / APSH /
  DTS / consumer is much harder when the first real event
  arrives.
- **One OS Inspector per BlueField + host pair, one posture.**
  Two OS Inspector containers on the same BlueField competing
  for the same APSH path against the same host is a
  configuration error; the agent must NOT recommend it as a
  redundancy strategy. Introspection-side redundancy is a
  consumer-side concern (the SIEM's own HA, the analyst
  dashboard's own retention) that does not require multiple
  OS Inspector containers.
- **The DPU reads host memory; treat that boundary as a
  data-sensitivity boundary.** OS Inspector's whole reason for
  being is to read the host's running kernel memory from the
  DPU side over PCIe. That capability is what enables agent-
  less introspection, AND it is what makes the deployment
  posture review load-bearing. The operator's safety review
  must answer: who has access to the DTS-side ingest, who has
  access to the downstream consumer surface, what retention
  applies, and which of those audiences is cleared to see the
  particular APSH structs the scan policy enables. The agent
  surfaces these questions; the operator answers them.

## Public-source pointer

The canonical public sources for OS Inspector, all reachable
through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services),
are:

- The **DOCA App Shield Agent Application Guide** — the
  application form of the same APSH-driven introspection
  workflow OS Inspector packages as a service. The deployment
  shape, the command-line arguments, the scan-policy schema,
  the symbol-map / memory-regions prerequisites, and the
  telemetry-event registration story all live here.
- The **DOCA App Shield** library guide — for the underlying
  APSH semantics, the host kernel symbol-map prerequisite,
  the `doca_apsh_*` object family, and the *NOT_FOUND-is-a-
  normal-answer-for-an-absent-target* rule that OS Inspector
  inherits unchanged.
- The **DOCA Telemetry Service Guide** — for the consumer side
  of OS Inspector's findings, the IPC socket contract, and
  the DTS forwarder set.
- The **DOCA Container Deployment Guide** — for the canonical
  container deployment recipe shared with every other DOCA
  service container.

Verify that the version of each guide matches the OS Inspector
container tag pulled on the BlueField — the scan-policy schema,
supported APSH structs, telemetry-exporter contract, and
container deployment recipe are documented to evolve, so config
keys, struct names, and runtime conventions can change between
releases.
