---
name: doca-os-inspector
description: >
  Use this skill when the user is deploying or operating the DOCA OS
  Inspector service container on BlueField Arm — picking the DMA device
  + host VUID, OS type, host kernel symbol map + memory-regions file,
  scan policy (which APSH structs to enumerate), and scan interval;
  wiring the telemetry-exporter into DTS so findings reach a Splunk /
  ELK / Sentinel / custom consumer; or debugging an empty / stale
  feed. Trigger even when the user does not name "OS Inspector" or
  "App Shield" — typical implicit phrasings include "agent-less host
  introspection from the BlueField", "container green but processes
  feed is empty", "feed went silent after host kernel upgrade",
  "DPU-side process / module / library enumeration into our SIEM", or
  "BlueField CPU pegged since starting the scanner". Refuse and route
  elsewhere for building a custom DPU-side introspection tool
  (doca-apsh), runtime-security findings (doca-argus), or DTS / SIEM
  forwarder + ingest configuration — those belong to other skills or
  to the live public guidance.
metadata:
  kind: service
compatibility: >
  BlueField-Arm-only DOCA service container; pulled from NVIDIA NGC
  and started under the BlueField OS container runtime. Host-side
  install is irrelevant, but the deployment requires a host kernel
  symbol map and memory-regions file generated against the exact
  running host kernel build (refreshed on every host kernel change),
  plus a reachable DOCA Telemetry Service on the BlueField.
---

# DOCA OS Inspector

**Where to start:** This skill is for *operating* the DOCA OS
Inspector Service container, not for *linking against* a library.
OS Inspector is the deployable, telemetry-emitting service form of
DOCA App Shield host introspection — it ships as a container that
runs on the BlueField Arm, reads host kernel state over PCIe via
the [`doca-apsh`](../../libs/doca-apsh/SKILL.md) library, and
publishes the findings (processes, threads, loaded libraries, VADs,
system modules) into the DOCA Telemetry Service so a downstream
SIEM / analyst surface can consume them. It is *not* a host-side
agent (the host runs nothing), *not* a programming surface (the
operator does not write code against `libos_inspector.so`), and
*not* the same thing as the [`doca-apsh`](../../libs/doca-apsh/SKILL.md)
library (which is the lower-level introspection library a
developer would use to BUILD custom tooling — OS Inspector is the
service most operators want INSTEAD when the goal is a deployable
introspection feed). If the user wants to *deploy* the OS Inspector
container, open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what
shape of service is OS Inspector, what does it introspect, and
how does it publish findings*, start at
[`CAPABILITIES.md`](CAPABILITIES.md). If DOCA is not installed on
the BlueField yet, route to [`doca-setup`](../../doca-setup/SKILL.md)
first. If the user's real question is *"I want to write a custom
DPU-side security tool against host kernel state from the
BlueField side"*, the right answer is **not** this skill — route
to [`doca-apsh`](../../libs/doca-apsh/SKILL.md) instead.

## Example questions this skill answers well

The CLASSES of OS Inspector questions this skill is built to
answer, each with one worked example. The class is the load-bearing
piece; the worked example is one instance.

- **"Do I deploy OS Inspector, or do I build my own DPU-side
  introspection on top of `doca-apsh`?"** — worked example: *"I
  want a host-OS process / module / loaded-library feed off a
  BlueField-3 paired with a RHEL 9.4 host; what should I reach for
  first?"*. Answered by the OS-Inspector-vs-apsh path-selection
  rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the path-selection step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"What configuration axes do I have to commit to before
  starting the OS Inspector container?"** — worked example: *"a
  BlueField-3 + RHEL 9.4 host pair where I want processes,
  threads, loaded libraries and system modules in the feed, every
  20 seconds, into DTS"*. Answered by the five-axis configuration
  table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the five-axis step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"My OS Inspector container is running but the host
  enumeration is empty / nonsensical — what did I miss?"** —
  worked example: *"container green, but processes feed never
  populates"*. Answered by the host-symbol-map and DMA-path rows
  in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"I upgraded the host kernel and now the feed went silent /
  garbled — what broke?"** — worked example: *"host kernel
  patched from 5.14.0-362 to 5.14.0-427; OS Inspector still says
  it's running but the process list is empty"*. Answered by the
  symbol-map-is-host-OS-version-specific rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the symbol-map-refresh step in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **"How do I get OS Inspector findings into my SIEM / analyst
  surface?"** — worked example: *"forward the OS Inspector feed
  to our Splunk via DTS"*. Answered by the DTS-pairing row in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the END-TO-END pipeline rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the DTS-wiring step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"What data does OS Inspector actually expose, and how do I
  gate it for a production deployment?"** — worked example: *"the
  default config defaults `privileges_info`, `processes_envars_info`,
  and `processes_handles_info` off — should I turn them on?"*.
  Answered by the minimum-exposure-by-default rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the scan-policy step in
  [`TASKS.md ## configure`](TASKS.md#configure).

## Audience

This skill serves **external operators and platform / security
teams who deploy the DOCA OS Inspector Service container** to get
an agent-less, BlueField-side feed of host-OS kernel state into
their security / observability infrastructure. Concretely: people
running the OS Inspector container on BlueField Arm, choosing its
DMA device / host VUID / OS type / host symbol map / scan policy /
scan interval / DTS endpoint from the public OS Inspector / App
Shield Agent guidance, wiring the DTS-side ingest so findings reach
the downstream consumer (a SIEM, an analyst dashboard, a custom
correlator), and validating the end-to-end pipeline before trusting
the feed for production-grade decisions.

It is **not** for NVIDIA developers contributing to OS Inspector
itself, and it is **not** a programming guide for *building DPU-side
introspection tooling on top of* DOCA libraries (that is
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
plus the matching `libs/<library>` skill — in particular
[`doca-apsh`](../../libs/doca-apsh/SKILL.md) for the App Shield
library that custom introspection tooling builds on, and
[`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) /
[`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)
for the telemetry transport surface). OS Inspector is a
**service**, not a library: the operator runs a container and
consumes findings via the DTS pipeline; they do not link against a
`libos_inspector.so` to write their own program.

**Path selection up front (load-bearing).** Use OS Inspector when
the user wants **a deployable, container-shaped host-OS
introspection feed flowing into the BlueField's DTS pipeline** —
most operators in this position should reach for OS Inspector
rather than building their own on top of `doca-apsh`. OS Inspector
is the packaged service; apsh is the library a developer would
use only if OS Inspector is genuinely insufficient (e.g. the team
needs an enumeration target / observation cadence / output shape
OS Inspector does not expose, OR the team is building a custom
security product that must own its own decision logic). Do **not**
reach for OS Inspector when (a) there is no host-introspection
need (OS Inspector has operational cost — container, hugepages,
PCIe DMA traffic, DTS pipeline — for nothing); (b) the user wants
runtime *security findings* (suspicious-activity / integrity-
violation alerts) rather than raw introspection — route to
[`doca-argus`](../doca-argus/SKILL.md), the runtime-security
service that ships detection policy and SIEM forwarding as one
unit; (c) the user is building their own custom DPU-side
introspection tooling that needs to ship its own decision logic
(route to [`doca-apsh`](../../libs/doca-apsh/SKILL.md) — the
library equivalent, same shape of DPU-side observation, different
shape of operator effort).

## Language scope

OS Inspector is a **container-shaped service** built on top of
the DOCA App Shield C library and the DOCA Telemetry Exporter C
library. The operator does not link any language against an
"OS Inspector ABI"; the operator runs the container and consumes
the documented telemetry-exporter output via the DTS pipeline.
Downstream consumers of the DTS feed (a Splunk forwarder, an
analyst dashboard, a custom correlator) are written in whatever
language the consuming team prefers — that boundary is the
DTS-side ingest contract, owned by the public DOCA Telemetry
Service guidance reachable via
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services),
not by this skill. If the user's real question is *"how do I
write a custom DPU-side introspector in C / Rust / Python?"*,
that is a [`doca-apsh`](../../libs/doca-apsh/SKILL.md) question,
not an OS Inspector question.

## When to load this skill

Load this skill when the user is doing **hands-on OS Inspector
deployment work** on a BlueField where DOCA is already installed.
Concretely:

- Deciding *whether* OS Inspector is the right answer for the
  user's introspection requirement (vs. building custom tooling
  on [`doca-apsh`](../../libs/doca-apsh/SKILL.md), vs. deploying
  [`doca-argus`](../doca-argus/SKILL.md) for runtime security
  findings instead of raw introspection, vs. not deploying
  anything at all if there is no host-introspection need).
- Deploying the OS Inspector container on BlueField Arm —
  choosing the image source per the public OS Inspector / App
  Shield Agent guidance, mounting the OS Inspector config, the
  host symbol map, the memory-regions file, and starting /
  stopping the container per the public Container Deployment
  Guide pattern reachable through
  [`doca-container-deployment`](../../doca-container-deployment/SKILL.md).
- Choosing the five configuration axes — DMA device + host VUID
  (the BlueField PCIe path that attaches the host's memory), OS
  type (Linux / Windows), host kernel symbol map + memory-regions
  file (host-OS-version-specific), scan policy (which APSH
  structs to enumerate — `processes_info`, `threads_info`,
  `libs_info`, `vads_info`, `system_modules_info` are on by
  default; `privileges_info`, `processes_envars_info`,
  `processes_handles_info` are off by default per the project's
  own minimum-exposure stance), scan interval (`-t <seconds>`).
- Generating or refreshing the host kernel symbol map ("VMA / OS
  symbols" file) when the host kernel changes — the map is
  host-OS-version-specific and silently stops working after a
  host kernel upgrade, taking the OS Inspector feed with it.
- Wiring the DTS-side pipeline so the events OS Inspector emits
  actually reach the downstream consumer (a SIEM, an analyst
  dashboard, a custom correlator) — without this step the feed
  is generating findings into the void.
- Validating the end-to-end pipeline (OS Inspector container →
  APSH reads host memory → telemetry-exporter source → DTS →
  downstream consumer) before trusting the feed for production
  decisions.
- Reading the OS Inspector container's logs, the DTS-side ingest,
  or any other documented observability surface to confirm the
  deployment is working as configured.
- Debugging an OS Inspector deployment where the container is
  healthy but the enumeration is empty / corrupt, where the host
  kernel was upgraded and the feed went silent, where DTS is not
  receiving events, where the scan interval is too aggressive for
  the workload, or where the operator is unsure which APSH structs
  are appropriate to expose for the deployment's security posture.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, library-API questions, or non-introspection
topics. For those, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or the matching
`libs/<library>` skill (e.g.
[`doca-apsh`](../../libs/doca-apsh/SKILL.md) when the user is
building their own DPU-side introspection tooling).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — OS Inspector's architecture (long-running
  container that owns the host-OS introspection surface on the
  BlueField, wrapping DOCA App Shield + DOCA Telemetry Exporter
  into one deployable unit), the five configuration axes (DMA
  device + VUID / OS type / symbol map + memory regions / scan
  policy / scan interval), the deployment shape (container on
  BlueField Arm per the public Container Deployment Guide, with
  hugepages, the DTS IPC socket volume, the shared-memory
  volume, and the operator-supplied symbol-map / memory-regions
  / scan-policy mount), the pairing surface (DTS consumers — and
  through DTS, downstream SIEM / analyst destinations), the
  observability surface (container logs + DTS-side ingest
  confirmation + per-iteration scanner cadence), the error
  taxonomy (container-runtime / hardware-path / symbol-map +
  memory-regions / scan-policy / telemetry-pipeline /
  performance), and the safety policy (OS-Inspector-vs-apsh path
  selection, OS-Inspector-vs-Argus path selection, minimum-
  exposure-by-default, never-silently-disable-an-event, host
  symbol map is host-OS-version-specific, smoke-before-bulk).
- `TASKS.md` — step-by-step workflows for the in-scope OS
  Inspector verbs: `install`, `configure`, `build`, `modify`,
  `run`, `test`, `debug`, `use`, plus a `Deferred task verbs`
  block routing out-of-scope questions and a `Command appendix`
  of recurring commands.

The skill assumes a BlueField where DOCA is already installed
and the operator has the privileges the public OS Inspector /
App Shield Agent guidance expects to pull, run, and configure
containers on BlueField Arm. It does not cover installing DOCA —
that path goes through
[`doca-setup`](../../doca-setup/SKILL.md). It does not cover
generating the host kernel symbol map artifact itself in detail —
the artifact is host-OS-version-specific and lives in the
operator's own host inventory, owned by the public App Shield
guidance; the skill names *that* the map is a hard prerequisite
and *what* its lifecycle looks like (refresh on every host
kernel change), not how to manufacture one for an arbitrary
host kernel build.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or sample-config
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-baked OS Inspector configuration files** (full scan-policy
  blocks, ready-to-run command-line argument bundles, sample
  `os_inspector_cfg.json` / `os_inspector_params.json` blobs)
  intended to be copy-pasted into production. The scan policy is
  a security-posture decision (turning on `processes_envars_info`
  silently widens the data surface the operator is exposing into
  the DTS pipeline), and a copy-pasted policy bypasses the
  operator's own exposure review. The safe answer for an external
  operator is to derive the config from the public OS Inspector /
  App Shield Agent guidance against their own posture, starting
  from the project's minimum-exposure defaults and turning on
  additional structs only deliberately.
- **Container image names, tags, or registry paths.** The
  authoritative image source is the public OS Inspector / App
  Shield Agent service guidance reachable through
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)
  and the public Container Deployment Guide;
  OS Inspector's image tag is version-bound and changes between
  DOCA releases. Inventing or memorizing a tag is the canonical
  hallucination failure mode for a service skill.
- **Host kernel symbol map blobs or memory-regions files.** Those
  are host-OS-version-specific (a Linux 5.14.0-362 RHEL 9 build
  has a different map than a Linux 5.14.0-427 RHEL 9 build, even
  on the same distro family), and live in the operator's host
  inventory. The skill names *that* the map is a hard
  prerequisite, *that* it must be regenerated when the host
  kernel changes, and *where* the generation procedure is
  documented (the public DOCA App Shield guidance) — not the
  artifact itself.
- **DTS / SIEM-side ingest configurations** (Splunk forwarder
  stanzas, Logstash pipeline definitions, custom analyst
  dashboards). Those are DTS-environment-specific or
  SIEM-environment-specific and live on the consumer side, not
  inside the OS Inspector container. The skill names *that* the
  DTS pipeline must be wired and *what the documented
  telemetry-exporter contract is*; the SIEM-side ingest body
  belongs to the user's SIEM team and to that SIEM's
  documentation.
- **A `samples/`, `templates/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled *"reference"*, is misleading: operators will read
  it as production-ready and security-cleared, neither of which
  this skill can guarantee.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope **and** that OS Inspector is the right answer at all
   (vs. building on `doca-apsh`, vs. deploying
   [`doca-argus`](../doca-argus/SKILL.md) for detection findings,
   vs. deploying nothing if there is no host-introspection need).
2. **For OS Inspector's deployment shape, the five configuration
   axes, the DTS pairing surface, the error taxonomy, the
   observability surface, and the safety policy (including the
   minimum-exposure-by-default rule, the symbol-map-is-host-OS-
   version-specific rule, and the OS-Inspector-vs-apsh /
   OS-Inspector-vs-Argus path selection rules), see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — install, configure, build,
   modify, run, test, debug, use — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public DOCA OS Inspector / App
  Shield Agent / DOCA Telemetry Service / Container Deployment
  Guide pages and the rest of the public DOCA documentation set.
  The OS Inspector service is the deployable form of the App
  Shield introspection surface; the public anchor is the **DOCA
  App Shield Agent Application Guide** at
  `docs.nvidia.com/doca/sdk/DOCA+App+Shield+Agent+Application+Guide`
  alongside the DOCA App Shield library guide.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation and
  install verification on the BlueField where the OS Inspector
  container will run, including the *I have no install yet* path
  via the public NGC DOCA container. This skill assumes its
  preconditions are satisfied on BlueField Arm.
- [`doca-container-deployment`](../../doca-container-deployment/SKILL.md)
  — the cross-cutting container-deployment pattern for every
  DOCA service container on BlueField Arm. OS Inspector follows
  the same recipe (pull from NGC, mount config + symbol map +
  memory regions, start under the BlueField container manager,
  expose hugepages + DTS IPC socket + shared-memory volume); this
  skill layers the per-service overlay on top.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. OS Inspector's container tag is
  version-bound and the underlying App Shield introspection
  surface evolves between releases; this skill's `## Version
  compatibility` cross-links the four-way match rule and adds
  the container-tag-lags-host-package overlay shared with every
  other DOCA service container, plus the host-kernel-version
  axis App Shield introduces.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md) —
  the cross-cutting hardware-safety meta-policy. OS Inspector
  itself is read-only against the host (it observes host memory
  over PCIe without writing) but its deployment touches BlueField
  hugepage reservation and the DTS-side shared-memory volume;
  the safety overlay in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  cross-links the meta-policy and adds the per-artifact overlay
  (minimum-exposure-by-default, host-symbol-map lifecycle, the
  DPU-reads-host-memory data-sensitivity rule).
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA patterns. OS Inspector is service-shaped not
  library-shaped, so the build / modify / first-app pattern
  there does not apply directly, but the cross-library debug
  discipline (frontend-before-backend, env-before-program,
  never-invent-flags) remains useful when OS Inspector reports
  an error that originated in the container runtime or in a
  DOCA library it called.
- [`doca-apsh`](../../libs/doca-apsh/SKILL.md) — the **library
  equivalent**. OS Inspector and App Shield are both BlueField-
  side observation surfaces over host kernel state; they DIFFER
  in operator shape (OS Inspector is a packaged service container
  with a documented scan policy, telemetry-exporter wiring, and
  DTS-targeted output; apsh is a C library a developer builds
  custom DPU-side introspection on top of) and in operator
  effort (OS Inspector's config-and-deploy cycle vs apsh's full
  custom-tool development cycle). The path-selection rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  routes the user to OS Inspector first for a deployable
  introspection feed and to apsh only when OS Inspector is
  genuinely insufficient. The host kernel symbol-map prerequisite
  and the *"NOT_FOUND is a normal answer for a target absent
  right now"* rule are inherited from apsh and apply unchanged.
- [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) and
  [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)
  — the libraries OS Inspector uses internally to publish
  findings. Operators consume the *output* via DTS; library
  consumers (custom forwarders, custom collectors) reach for
  these directly. The DTS-side ingest is the DOCA Telemetry
  Service routed via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
- [`doca-argus`](../doca-argus/SKILL.md) — sibling service skill
  and the closest path-selection neighbor. Argus is the
  **runtime-security** packaged service (it ships detection
  policy + finding emission + SIEM forwarding as one unit, with
  a calibration period and a tuned detector set); OS Inspector
  is the **raw-introspection** packaged service (it ships the
  APSH enumeration surface + telemetry-exporter wiring with no
  detection logic of its own — the consumer side decides what
  to do with the feed). Use Argus when the user wants
  *findings* about suspicious activity; use OS Inspector when
  the user wants *raw observations* and owns the downstream
  detection / correlation themselves.
- [`doca-dms`](../doca-dms/SKILL.md),
  [`doca-firefly`](../doca-firefly/SKILL.md),
  [`doca-flow-inspector`](../doca-flow-inspector/SKILL.md) —
  sibling service skills. The agent reading any two of these
  should see the same service-skill shape (container, BlueField
  Arm, Container Deployment Guide as the canonical recipe,
  smoke-before-bulk, env preconditions, config schema, version
  anchor is the container tag) layered on top of a different
  per-service domain (DMS = device management via gNMI / gNOI;
  Firefly = time synchronization via PTP; Flow Inspector = DOCA
  Flow telemetry; OS Inspector = host-OS kernel introspection
  via APSH).
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). OS Inspector-specific debug (empty
  enumeration, stale symbol map after host-kernel upgrade,
  DTS-side ingest gaps, performance impact at small scan
  intervals) overlays on top of that ladder.
