---
name: doca-bare-metal-deployment
description: >
  Use this skill for launching, supervising, debugging, OR
  platform lifecycle on a BlueField — BFB install, RShim/TMFIFO,
  host PF rebind, post-BFB recovery — taking a DOCA-linked binary
  to a healthy run directly on hardware (host x86 + BlueField NIC
  over PCIe, or BlueField Arm bare-metal). No container, no
  kubelet. Covers launch mode (direct, tmux, systemd), PCI/NUMA/
  CPU/IRQ binding, co-tenant isolation (cgroup-v2/netns/numactl),
  a seven-layer error taxonomy, and a six-state BlueField
  lifecycle classifier. Trigger even when user does not say
  "bare-metal" — implicit phrasings include "binary exits 1 right
  after launch", "systemd keeps restarting it", "no matching
  device on the BF", "bfb-install exited 0 but DPU is dead",
  "ping 192.168.100.2 works but ssh fails", "host PFs aren't
  showing netdevs". Mutating-step meta-policy (firmware burn,
  mlxconfig set, kernel boot params) is doca-hardware-safety,
  loaded alongside; container deployment, library APIs, env prep,
  and binary build belong to other skills.
metadata:
  kind: library
compatibility: >
  No DOCA install required to read this skill (it is an overlay
  loaded against any DOCA artifact skill); the validation steps
  within DO require a live DOCA install at /opt/mellanox/doca on
  a host or BlueField with a built DOCA-linked binary.
---

# DOCA bare-metal deployment

**Where to start:** This skill is the bundle's home for *operating*
a DOCA-linked application binary **directly on hardware** — no
container, no kubelet, no static-pod manifest. It is the parallel
of [`doca-container-deployment`](../doca-container-deployment/SKILL.md)
for the non-container path. If the user has a DOCA-linked binary
they built (per the canonical workflow in
[`doca-programming-guide`](../doca-programming-guide/SKILL.md))
and they want to know *how to actually run it on the host or on
the BlueField Arm cores correctly*, open
[`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what
shape does the bare-metal runtime even have and what is the
deployment contract*, start at [`CAPABILITIES.md`](CAPABILITIES.md).
If the user is not yet sure whether their target system shape is
the container path or the bare-metal path, route the recognition
step to [`doca-setup`](../doca-setup/SKILL.md) first; only return
here once *bare-metal* is the confirmed shape.

## Example questions this skill answers well

The CLASSES of bare-metal-deployment questions this skill is built
to answer, each with one worked example. The class is the
load-bearing piece; the worked example is one instance.

- **"I have a DOCA-linked binary I built. What does it actually
  take to run it correctly on real hardware — not inside a
  container?"** — worked example: *"I built a doca-flow
  application on my host with a BlueField-3 in the PCIe slot; how
  do I launch it the right way?"*. Answered by the pattern
  overview + launch-mode table in
  [`CAPABILITIES.md ## Pattern overview`](CAPABILITIES.md#pattern-overview)
  + the step-by-step launch walkthrough in
  [`TASKS.md ## run`](TASKS.md#run).
- **"I want to run my binary on the BlueField Arm cores
  themselves, not on the x86 host. Is that the same workflow or a
  different one?"** — worked example: *"the BlueField OS image
  has DOCA installed on the Arm side; I'd like to run my DOCA app
  directly on the DPU, talking to its local NIC"*. Answered by
  the two-host-modes contract in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the parallel walkthrough in
  [`TASKS.md ## configure`](TASKS.md#configure) and
  [`TASKS.md ## run`](TASKS.md#run).
- **"Should I just `./my-doca-app &` it, run it in tmux, or wire a
  systemd unit?"** — worked example: *"I want this binary to come
  back automatically after a host reboot, but I also want to be
  able to attach to it and see what it is doing right now"*.
  Answered by the three-launch-modes decision table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the launch-mode-selection step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"How do I bind my DOCA process to the right PCIe function and
  the right NUMA node so it doesn't trip over itself?"** — worked
  example: *"the BlueField is on NUMA node 1; my app is being
  scheduled on cores from node 0 and performance is terrible"*.
  Answered by the hardware-binding rules in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the
  [`### isolation`](TASKS.md#isolation) sub-anchor under
  [`## run`](TASKS.md#run) (cgroup-v2 / namespaces / numactl per-tenant
  primitives).
- **"My binary won't start; or it starts but exits immediately; or
  it starts but can't see the device. How do I diagnose this
  without guessing?"** — worked example: *"my doca-flow binary
  exits with status 1 within a second of launch; I have no idea
  which layer broke"*. Answered by the seven-layer error taxonomy
  in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the matching layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"systemd put my DOCA binary in a `Restart=always` loop because
  it keeps crashing. Should I let it keep restarting, or is that
  exactly the wrong thing?"** — worked example: *"the unit is
  auto-restarting my binary every five seconds and the device is
  reporting odd errors; should I just bump the restart limit?"*.
  Answered by the restart-loop-is-HIGH-STAKES rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the *"clear the root cause first"* layer in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Two of my colleagues are running DOCA processes on the same
  BlueField. How do I make sure their workload doesn't crush
  mine?"** — worked example: *"I want one DOCA-Flow process per
  representor, one DOCA-RDMA process for the storage path, all on
  the same BlueField, without cross-tenant interference"*.
  Answered by the per-tenant isolation rules in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the [`### isolation`](TASKS.md#isolation) sub-anchor.
- **"My host is fine and the BlueField was working last week, but
  after a BFB push it never came back. `bfb-install` exited 0,
  but I cannot ssh to the BF, `ping 192.168.100.2` works but
  feels wrong, and `ip link` doesn't show any BlueField netdev on
  the host any more."** — worked example: *"DOCA 3.3 host
  upgrade is fine; BFB install on the BlueField reported `Ubuntu
  installation completed` then `INFO[MISC]: NIC firmware update
  failed`, but `bfb-install` still exited 0; now the DPU never
  reaches `DPU is ready`, host PFs are present in `lspci -d 15b3:`
  but `ip link` doesn't list their netdevs."* Answered by the
  BlueField lifecycle anchor in
  [`TASKS.md ## bluefield-lifecycle`](TASKS.md#bluefield-lifecycle)
  (the `bfb-install` partial-failure recognition + the
  `192.168.100.2` host-loopback `ip route get` gotcha + the host
  PF rebind sequence + the post-BFB four-way version-match
  re-close) and the six-state classifier in
  [`### bluefield-state-classifier`](TASKS.md#bluefield-state-classifier).

## Audience

This skill serves **external DOCA developers and operators who
have a DOCA-linked application binary they built and want to run
it directly on hardware** — i.e., people who already have:

- a DOCA-linked application binary they built per
  [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build),
- a real BlueField NIC and a host that talks to it (the **host
  x86** path — DOCA host install on the host talks to the
  BlueField NIC over PCIe), OR a BlueField with a console or SSH
  to the Arm side (the **BlueField Arm bare-metal** path — DOCA
  installed on the DPU Arm cores; the binary runs there
  directly), and
- a desire to RUN that binary directly on the hardware, not
  inside a kubelet-standalone-managed container.

It is **not** for:

- kernel-driver developers contributing to `mlx5_*` or the
  BlueField OS,
- DOCA library contributors (those changes go to the internal
  DOCA tree, not to a bare-metal deployment),
- full-Kubernetes-cluster operators managing a fleet of
  BlueFields (the bundle covers
  [`doca-container-deployment`](../doca-container-deployment/SKILL.md)
  for the single-host kubelet-standalone shape; **fleet/production-scale
  deployment is fleet-orchestration scope** — route to the orchestration
  entry-point in
  [`doca-public-knowledge-map ## Deploying DOCA services at scale`](../doca-public-knowledge-map/SKILL.md#deploying-doca-services-at-scale-orchestration-entry-point-personascale-routing)
  (DPF / Network Operator / Launch Kit), not hand-rolled static-pod loops),
- fresh-laptop-no-hardware users with no DOCA install yet — those
  belong on
  [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install).

The skill teaches the agent the bare-metal-deployment *procedure*
and the rules for quoting documented commands from the public DOCA
Programming Guide and the public BlueField / DPU User Manual via
[`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md);
it does not invent flag names, PCI BDFs, NUMA numbers, devlink
paths, representor strings, or systemd `Restart=` mode names from
memory.

## When to load this skill

Load this skill when the user is doing **hands-on bare-metal
deployment of a DOCA-linked application binary** on either of the
two supported host modes (host x86 or BlueField Arm), or asking a
cross-cutting bare-metal question that is not specific to one
library's API. Concretely:

- Launching a DOCA-linked binary for the first time on a host
  with a BlueField NIC in a PCIe slot, with DOCA installed on the
  host.
- Launching a DOCA-linked binary on the BlueField Arm cores
  directly (BlueField Arm bare-metal mode), with DOCA installed
  on the Arm side per the BlueField OS image.
- Deciding which launch mode to use (direct foreground for
  interactive debug; tmux/screen for long-running with manual
  reattach; systemd-supervised for restart-after-reboot,
  journald-integrated logs, and Restart= policy).
- Binding the DOCA process to the right PCIe function, the right
  representor, the right NUMA node, and the right CPU set — and
  pinning IRQs to match — without inventing the addresses or the
  flag names.
- Setting up per-tenant isolation (cgroup-v2 cpu / memory / io
  controllers, network namespaces for multi-tenant deployments,
  `numactl` / `taskset` for CPU + NUMA binding) so multiple DOCA
  processes co-tenant on the same BlueField without crushing each
  other.
- Diagnosing a bare-metal launch that is misbehaving — won't
  start, starts and exits immediately, runs but can't find the
  device, attaches to the device but the workload errors, OOMs or
  is signal-killed, is in a restart loop under a supervisor, or
  is being interfered with by a co-tenant.
- Cross-cutting questions: *"should I run this in tmux or as a
  systemd unit"*, *"what is the smoke-before-bulk loop for a
  binary on bare metal"*, *"my binary works in a container on the
  BlueField but not when I run it directly on the Arm — what
  changed"*.

Do **not** load this skill for the container-path equivalent
(those questions go to
[`doca-container-deployment`](../doca-container-deployment/SKILL.md));
for full-Kubernetes-cluster operations (out of scope per the
bundle's non-goals); for library-API questions (route to the
matching `libs/<library>` skill); for env-preparation questions
including hugepages, IOMMU, pkg-config, and devlink mode flips
(use [`doca-setup`](../doca-setup/SKILL.md)); for any
hardware-state-changing operation including `mlxconfig` writes
and BFB reflashes (route to
[`doca-hardware-safety`](../doca-hardware-safety/SKILL.md) for the
cross-cutting meta-policy); or for cross-library programming
questions (use
[`doca-programming-guide`](../doca-programming-guide/SKILL.md)).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — the bare-metal deployment runtime contract
  for a DOCA-linked binary: the two host modes (host x86 vs
  BlueField Arm bare-metal), the three launch modes (direct,
  tmux/screen, systemd-supervised), the hardware-resource-binding
  surface (PF / VF / representor enumeration; NUMA topology
  discovery; CPU pinning rationale; IRQ affinity rules), the
  per-tenant isolation surface (cgroup-v2 cpu / memory / io,
  network namespaces, `numactl` / `taskset`), the restart and
  recovery semantics (documented `systemd` `Restart=` modes vs
  crash-and-investigate vs supervisor-driven restart), the
  bare-metal-specific version overlay on the four-way version
  match owned by
  [`doca-version`](../doca-version/SKILL.md), the cross-cutting
  error taxonomy (≥ 6 layers, walked in order), the observability
  surface (stdout/stderr discipline by launch mode; device-state
  introspection via `devlink` / `sysfs` / `mlxconfig` *query*;
  per-tenant resource visibility), and the safety policy (overlay
  on
  [`doca-hardware-safety`](../doca-hardware-safety/SKILL.md):
  smoke-before-bulk for binaries; failed bare-metal process is
  HIGH-STAKES; do not invent PCI addresses, NUMA numbers,
  representor names, devlink paths, or systemd `Restart=` mode
  names; confirm tenant-isolation primitives BEFORE the workload
  starts).
- `TASKS.md` — step-by-step workflows for the in-scope bare-metal
  verbs: `configure`, `build`, `modify`, `run` (with an explicit
  `### isolation` sub-anchor covering cgroup-v2 / namespaces /
  numactl per-tenant primitives), `test`, `debug`,
  `bluefield-lifecycle` (the BFB-install → RShim/TMFIFO →
  post-BFB-recovery operational sequencing ladder, with the
  six-state `bluefield-state-classifier` sub-anchor), the
  `Command appendix` (documented commands the agent may quote,
  each cross-linked to its public-doc source — no invented
  commands), and the `Deferred task verbs` block routing
  container-path / cluster / library-API / env-prep /
  hardware-state-change / cross-library questions out to their
  owning skills. (The change-application discipline for any
  mutating burn invoked from `## bluefield-lifecycle` is still
  meta-policy owned by
  [`doca-hardware-safety`](../doca-hardware-safety/SKILL.md),
  loaded alongside.)

The skill assumes a host or BlueField target where:

- DOCA is already installed and healthy (per
  [`doca-setup ## test`](../doca-setup/TASKS.md#test)),
- the user has a DOCA-linked application binary they built (per
  [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build)),
- the user has the host-OS permissions to enumerate devices,
  reserve hugepages, write systemd units (if they choose that
  launch mode), and bind processes to NUMA nodes.

It does not cover installing DOCA — that path goes through
[`doca-setup`](../doca-setup/SKILL.md) — and it does not cover
building the binary — that path goes through
[`doca-programming-guide`](../doca-programming-guide/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates / sample-binaries /
sample-units bundle. To keep the boundary clean, it deliberately
does not contain — and pull requests should not add:

- **Pre-baked binaries.** No DOCA application binary, no sample
  ELF, no statically-linked test program is shipped with this
  skill. The canonical artifact is the user's own DOCA-linked
  binary, built per
  [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build).
- **Sample systemd units, sample `numactl` invocations, sample
  `taskset` invocations, or any other ready-to-copy launch
  recipe.** Bare-metal launch is deployment-specific (per-host
  PCI BDF, per-host NUMA topology, per-tenant CPU set, per-site
  systemd policy) and the safe answer for an external operator
  is to *derive* the launch recipe from the public DOCA
  Programming Guide and the public BlueField / DPU User Manual
  against their own target. The agent's job is to prescribe the
  *procedure* and quote the documented command shapes from
  [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md),
  not to ship a `.service` file or a `numactl --cpunodebind=...`
  line the user might run unmodified.
- **PCI addresses, NUMA node numbers, representor names, devlink
  paths, hugepage allocation amounts, or systemd `Restart=` mode
  names invented from generic Linux knowledge.** The public DOCA
  Programming Guide, the public BlueField / DPU User Manual, the
  Linux man pages (`numactl(8)`, `taskset(1)`, `systemd.service(5)`,
  `systemd.unit(5)`), and `--help` on the installed tool are the
  authoritative sources. Inventing a `0000:01:00.0` or a
  `Restart=on-failure-with-burst-cap` from memory is the
  load-bearing first-run failure for this skill.
- **A `samples/`, `templates/`, `units/`, or `reference/` subtree
  of any kind.** A mock or incomplete artifact in this skill's
  tree, even one labeled "reference", is misleading: operators
  will read it as production-ready.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (bare-metal launch of a DOCA-linked binary on host
   x86 or BlueField Arm; NOT the container path, NOT a full
   cluster, NOT a library-API question).
2. **For the runtime contract (two host modes, three launch
   modes, hardware-binding surface, per-tenant isolation, version
   overlay, ≥ 6-layer error taxonomy, observability surface,
   bare-metal safety overlay), see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — `configure`, `build` (routing
   stub), `modify` (routing stub), `run` (with `### isolation`
   sub-anchor), `test`, `debug`, `bluefield-lifecycle` (BFB
   install + RShim/TMFIFO + post-BFB recovery + the six-state
   `bluefield-state-classifier`), plus the `Command appendix` and
   the `Deferred task verbs` block — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-container-deployment`](../doca-container-deployment/SKILL.md)
  — the SIBLING path. Two parallel deployment shapes in this
  bundle: containers (that skill) vs bare metal (this one). The
  recognition step that picks between them lives in
  [`doca-setup`](../doca-setup/SKILL.md). Once the shape is
  *bare metal*, the agent stays here; if it is *container*, the
  agent routes there.
- [`doca-setup`](../doca-setup/SKILL.md) — env preparation
  (install verification, hugepages mount and reservation, IOMMU
  posture, devlink mode, pkg-config path, representor visibility,
  kernel module load state). This skill assumes its preconditions
  are satisfied at the bare-metal target. The recognition step
  that decides container-vs-bare-metal is in `doca-setup` per
  the bundle convention; load `doca-setup` in parallel when the
  user's situation is ambiguous.
- [`doca-hardware-safety`](../doca-hardware-safety/SKILL.md) —
  the cross-cutting meta-policy for any change touching DPU / NIC
  hardware state. This skill's `## Safety policy` overlays that
  meta-policy with bare-metal-specific rules
  (smoke-before-bulk-for-binaries, restart-loop-is-HIGH-STAKES,
  do-not-invent-PCI-addresses-or-NUMA-numbers-from-memory) and
  does **not** redefine the meta-policy itself. When the change
  the agent is about to recommend writes `mlxconfig`, burns
  firmware, reflashes the BFB, flips the BlueField mode, or
  changes a kernel boot parameter, the agent leaves this skill
  for `doca-hardware-safety` and only returns once the
  hardware-state change is complete.
- [`doca-debug`](../doca-debug/SKILL.md) — the cross-cutting
  layered debug ladder (install / version / build / link /
  runtime / program / driver). Bare-metal-deployment-specific
  debug (process didn't start, started and exited, couldn't find
  the device, OOM / signal, restart loop, co-tenant noise)
  layers on top of the cross-cutting ladder; this skill's
  `## debug` cross-links into `doca-debug` for the broader
  context.
- [`doca-programming-guide`](../doca-programming-guide/SKILL.md)
  — canonical DOCA build / modify / first-app patterns and the
  cross-library `DOCA_ERROR_*` taxonomy. This skill assumes the
  user already has a built binary; questions about *building*
  the binary or interpreting library-specific errors route there.
- [`doca-version`](../doca-version/SKILL.md) — the four-way
  version match rule (host package ↔ binary build ↔ BlueField
  firmware ↔ DOCA-version policy). This skill's
  `## Version compatibility` cross-links the body of the rule
  there and adds only the bare-metal-specific overlay (the
  binary's link-time `pkg-config doca-*` version must match the
  runtime `LD_LIBRARY_PATH`'d install).
- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public DOCA Programming Guide, the
  public BlueField / DPU User Manual, the public Installation
  Guide, and the NGC catalog. This skill does not duplicate
  URLs; it points at the map and adds the bare-metal-deployment
  overlay.
- [`doca-structured-tools-contract`](../doca-structured-tools-contract/SKILL.md)
  — the bundle's structured-tools precedence rule
  (detect / prefer / fall back / report). The
  [`## Command appendix`](TASKS.md#command-appendix) in
  [`TASKS.md`](TASKS.md) honors this contract — the agent probes
  for the matching structured helper first (`doca-env --json`,
  `doca-capability-snapshot`, `version-matrix.json`) and falls
  back to the documented manual commands when the probe fails.
