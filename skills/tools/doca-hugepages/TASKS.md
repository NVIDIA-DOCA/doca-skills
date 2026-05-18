# DOCA hugepages — Tasks

**Where to start:** The verbs that carry real workflow content are
`## configure`, `## test`, and `## debug`. The other three
substantive verbs (`build`, `modify`, `run`) describe shape rather
than commands — `build` is a routing stub (there is no source to
compile), `modify` carries the high-stakes change posture, and
`run` names the documented Linux runtime knobs. The `## test` verb
is an iterative loop, not a one-shot pass — see the eval-loop
overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent through
the six task verbs every artifact in this bundle exposes
(`configure / build / modify / run / test / debug`), then
explicitly defers task verbs that do not belong here.

For `doca-hugepages`, the verbs that carry real workflow content
are `configure`, `test`, and `debug`. The other three verbs
*exist as anchors* because the agent's task-verb contract is
uniform across libraries, services, and tools — and each one
carries a meaningful **routing stub** that names where the user's
question really belongs.

## configure

Goal: decide a hugepage configuration on the right axis values for
the DOCA library the user is about to run, before any reservation
or mount command is issued. **Precondition for this verb is that
DOCA is installed and the target DOCA library is known.** If
either is missing, route to
[`doca-setup`](../../doca-setup/SKILL.md) or to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
respectively before any hugepage work.

Steps the agent should walk the user through, in order:

1. **Confirm the target DOCA library actually needs hugepages.**
   Cross-reference the library-dependency table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   If the library is control-plane-only (e.g. `doca-comch` for
   most invocations), hugepages are not the right preparation
   step and the agent must not recommend changing the host's
   hugepage pool — surface that finding and route to the
   matching library skill instead.
2. **Read the current hugepage state on the host.** Run the
   observability quartet in
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
   (`cat /proc/meminfo | grep -i Huge`,
   `ls /sys/kernel/mm/hugepages/`, the per-NUMA-node tree under
   `/sys/devices/system/node/`, `mount | grep huge`). Quote the
   raw output back to the user; this is the baseline every
   subsequent decision is made against.
3. **Axis 1 — pick page size.** Per the three-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   commit explicitly to 2 MiB vs 1 GiB. The default-safe answer
   for first-app work is 2 MiB; 1 GiB is the right choice when
   the library's memory regions are large enough that TLB
   pressure shows up (the matching library skill's
   `## Capabilities and modes` calls this out when it applies)
   and the host has the contiguous physical memory to back the
   gigantic pages.
4. **Axis 2 — pick scope.** Boot-time (kernel cmdline
   `hugepagesz=` + `hugepages=`) vs runtime
   (`echo <N> > /sys/kernel/mm/hugepages/hugepages-<size>kB/nr_hugepages`
   or `sysctl -w vm.nr_hugepages=<N>`). The default-safe answer
   for 1 GiB pages on most kernels is boot-time; for 2 MiB pages
   either works, but boot-time is more durable. Quote back to
   the user *why* you picked the scope so the user can
   challenge it before the change is made.
5. **Axis 3 — pick NUMA placement.** On a single-socket host
   the host-wide total is also the per-node total and this
   step is trivial. On a multi-socket host, run
   `numactl --hardware` to enumerate nodes and confirm which
   socket owns the NIC's PCIe slot, then plan the
   per-node allocation via the
   `/sys/devices/system/node/node<N>/hugepages/hugepages-<size>kB/nr_hugepages`
   path. The agent must surface this axis explicitly even when
   the host is single-socket — saying *"NUMA does not matter
   here because this is a single-socket host"* is itself the
   axis-3 answer.
6. **Plan the `hugetlbfs` mount if the library requires it.**
   Some DOCA libraries allocate via `MAP_HUGETLB` and do not
   need a `hugetlbfs` filesystem; others (notably DPDK-backed
   paths driven by
   [`doca-dpdk-bridge`](../../libs/doca-dpdk-bridge/SKILL.md))
   expect the mount. The minimum-viable
   `mount -t hugetlbfs -o pagesize=<size> nodev <mountpoint>`
   recipe lives in
   [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
   step 4; this skill points there rather than duplicating the
   exact command.
7. **Surface the safety posture before issuing any change
   command.** Per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   hugepage changes are global; the agent must ask whether any
   other DOCA / DPDK / KVM / Postgres / JVM workload runs on
   this host, and must recommend a staging-host trial when the
   answer is *"this is production"*. Then hand off to
   [`## modify`](#modify) for the change-execution shape.

For the DOCA-specific helper recipe (the public `doca-hugepages`
Tool guide), the agent must read the public page on the user's
installed DOCA version per
[`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
before quoting any helper-specific flag. Inventing a flag is the
canonical hallucination failure for this skill.

## build

`doca-hugepages` is **not a source artifact the external user
compiles**. The DOCA helper (when present on the install) is
shipped pre-built; the canonical Linux hugepages contract lives
in the running kernel and is not built per-skill. There is no
source tree, no `meson` / `ninja` invocation, no build flag the
agent should recommend.

Routing for nearby "build" questions:

- *"How do I build a DOCA application that consumes hugepages?"* →
  not a hugepages question. Route to
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the cross-library build pattern and to the matching
  `libs/<library>` skill (e.g.
  [`doca-rdma ## build`](../../libs/doca-rdma/TASKS.md#build))
  for the library-specific build overlay. The library handles
  the call-site; hugepages is an env precondition the build
  does not bake in.
- *"I want a custom hugepage-prep script of my own."* →
  out of scope per
  [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).
  Hugepage allocation is high-stakes global state and the
  bundle deliberately does not automate it.
- *"My kernel does not have hugepages enabled."* → not a build
  question; it is a kernel-config question that lives upstream.
  Route to the upstream Linux kernel documentation reachable
  via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  and recommend the operator's distribution's kernel package
  with `CONFIG_HUGETLBFS` and `CONFIG_HUGETLB_PAGE` enabled
  (the default on every distribution DOCA supports).

The `## What this skill deliberately does not ship` block in
[`SKILL.md`](SKILL.md) explicitly forbids adding a build recipe
or shipping wrappers around the DOCA helper; revisit that policy
before changing this section.

## modify

**Hugepage modification is the highest-stakes operation this
skill covers.** Per
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
a change to `nr_hugepages` or to a `hugetlbfs` mount affects
every consumer on the host immediately, can OOM the kernel under
memory pressure, and (for the boot-time scope) requires a reboot
to take effect. The agent's posture is *modify carefully, with
operator review and a staging-host trial before production*.

The shape of the change-execution flow:

1. **Verify the operator has consent for the change.** Surface
   the safety items in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   explicitly: *"this change affects every hugepage consumer on
   this host"*, *"runtime allocation can OOM the kernel"*,
   *"boot-time changes require a reboot"*. Stop and ask if the
   user is the host's operator and if the change has been
   reviewed; do not proceed on an ambiguous *"go ahead"*.
2. **Reproduce the change on a staging host first.** Especially
   for production changes — same NUMA topology, same kernel,
   same set of resident workloads — and validate the
   allocate-one-page smoke from the target DOCA library per
   [`## test`](#test) before promoting to production.
3. **Pick the scope you committed to in
   [`## configure`](#configure) step 4.** Boot-time changes
   edit the kernel cmdline (typically via the bootloader's
   configuration, e.g. `/etc/default/grub` + a
   `grub-mkconfig`-equivalent step the operator runs by hand,
   then a reboot). Runtime changes write into
   `/sys/kernel/mm/hugepages/hugepages-<size>kB/nr_hugepages`
   (host-wide) or into the per-NUMA-node mirror under
   `/sys/devices/system/node/node<N>/hugepages/...`. The
   agent quotes the path, not a guessed integer; the operator
   chooses the value based on the library's working-set
   sizing.
4. **Re-read the observability quartet immediately after the
   change.** Per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability),
   confirm `HugePages_Total` and the per-NUMA-node tree
   reflect the requested change. A silent partial honoring
   (e.g. the kernel granted 800 pages when 1024 were
   requested, because of fragmentation) is the documented
   runtime-best-effort behavior and must be surfaced; the
   agent does not silently retry.
5. **Re-run [`## test`](#test) before the workload starts.**
   The change is not done until the target DOCA library's
   allocate-one-page smoke passes on the right NUMA node;
   without that smoke the change is hypothetical.

What the agent *must not* modify, ever:

- The shipped `doca-hugepages` helper binary or its config
  files. The helper is NVIDIA-shipped; there is no documented
  public way to change its behavior.
- The kernel hugepages contract itself
  (`/proc/meminfo` fields, `/sys/kernel/mm/hugepages/` layout).
  These are upstream Linux contracts; the operator does not
  patch them.

Routing for nearby "modify" questions that are actually env
changes:

- *"I want to remove hugepages because nothing on this host
  uses them anymore."* → this is the same flow as
  reservation, with the change direction inverted. The safety
  rules in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  apply identically — shrinking the pool while a consumer is
  attached will crash that consumer.
- *"I want to change the page size of an existing pool."* →
  not a single operation. The operator drains the old pool
  (after coordinating with every consumer), then reserves a
  new pool at the new page size. The agent walks both halves
  per the steps above.

## run

Hugepages does not have its own runtime daemon; the "run" surface
is the set of documented Linux runtime knobs the operator reaches
for after the configuration is decided in
[`## configure`](#configure). The shape of the runtime surface:

1. **Read the host's current hugepage state — read-only.** The
   observability quartet in
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
   is side-effect-free; the agent runs it before any change to
   establish the baseline and after every change to confirm the
   effect. This is the same set of paths the snapshot pattern
   in [`## test`](#test) captures.
2. **Issue the runtime allocation (only after
   [`## configure`](#configure) and the safety check in
   [`## modify`](#modify)).** The path is
   `/sys/kernel/mm/hugepages/hugepages-<size>kB/nr_hugepages`
   (host-wide) or
   `/sys/devices/system/node/node<N>/hugepages/hugepages-<size>kB/nr_hugepages`
   (per-NUMA-node). Either accepts an integer count of pages
   via `echo`; the kernel returns a best-effort response.
   `sysctl -w vm.nr_hugepages=<N>` is the equivalent
   host-wide knob; do not run both in the same change.
3. **Mount the `hugetlbfs` filesystem if the library needs
   it.** Per
   [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
   step 4 — `mount -t hugetlbfs -o pagesize=<size> nodev
   <mountpoint>`. The mountpoint is conventionally
   `/mnt/huge` or `/dev/hugepages`; either works as long as
   the consuming library is configured for it.
4. **Hand off to the DOCA library's runtime.** Hugepages is
   not the workload — it is the precondition. After the
   runtime surface above is configured, the DOCA library
   takes over per its own `## run` workflow (see
   [`doca-rdma ## run`](../../libs/doca-rdma/TASKS.md#run),
   [`doca-dpdk-bridge ## run`](../../libs/doca-dpdk-bridge/TASKS.md#run),
   etc.). Do not conflate *"hugepages are reserved"* with
   *"the DOCA workload is running"*.

For the program-side runtime surface (`DOCA_LOG_LEVEL`,
`--sdk-log-level`, the lifecycle of the library that consumes
the pages) see
[`doca-programming-guide TASKS.md ## run`](../../doca-programming-guide/TASKS.md#run).

## test

The skill's `## test` verb is the **allocate-one-page-from-the-
target-DOCA-library smoke loop**. A configuration that reads
clean in `/proc/meminfo` is not the same as a configuration the
target library can actually allocate against; this loop closes
that gap.

**`## test` is an iterative loop, not a one-shot pass.** The
agent runs the smallest meaningful probe at each layer, reads
the output, picks the next narrowest probe based on what is
revealed, and only declares the host *"hugepage-ready for
library X"* when every layer is observed clean in the same
session.

The eval-loop overlay (rows apply to every DOCA library that
DMA-pins memory, not just one):

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| `/proc/meminfo` shows zero hugepages | Pool not configured at all | Walk [`## configure`](#configure) end-to-end; do NOT proceed to the library smoke. |
| Pool present, host-wide; per-NUMA-node tree empty on the NIC's socket | Axis 3 (NUMA placement) is wrong | Redistribute the pool via the per-NUMA-node sysfs surface per [`## modify`](#modify); re-read the per-node tree before re-attempting the library smoke. |
| Pool present at the right size on the right node; library smoke still fails | Axis 1 (page size) is likely wrong, or the library is not on hugepages at all on this DOCA version | Cross-check against the matching library skill's `## Capabilities and modes`; if the library wants 1 GiB and the pool is 2 MiB (or vice versa), re-configure for the expected size. |
| Smoke passes once; later library allocation fails under load | Insufficient allocation or runtime-best-effort honoring | Re-read `/proc/meminfo`; grow the pool *at boot* (not at runtime) and reboot; re-run the smoke. |
| Smoke passes on a staging host; fails on production | NUMA topology or memory-pressure delta | Capture the read-only snapshot per [`## Command appendix`](#command-appendix) on both hosts and diff them before any further change. |
| Library smoke uses `MAP_HUGETLB` and succeeds; same library configured for `hugetlbfs` fails | `hugetlbfs` mount missing or mounted at the wrong page size | Re-mount per the recipe in [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure) step 4; re-run the smoke. |
| Smoke fails inside a container; succeeds on the bare host | Container did not receive the hugepage namespace / mount | Surface the container-runtime gap; route to [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install) for the NGC container path and to the container runtime's hugepage-passthrough guidance. |

The pattern the rest of the bundle expects:

1. **Confirm `/proc/meminfo` reports the expected pool.**
   `HugePages_Total >= 1`, `HugePages_Free >= 1`,
   `Hugepagesize` matches the chosen axis 1.
2. **Confirm the per-NUMA-node tree matches axis 3.**
   `/sys/devices/system/node/node<NIC's-node>/hugepages/
   hugepages-<size>kB/free_hugepages >= 1`.
3. **Allocate ONE page from the target DOCA library.** Use
   the smallest defensible call that pins a hugepage — for
   `doca-rdma` this is a minimal `doca_mmap` + memory region
   over a one-page buffer; for `doca-dpdk-bridge` this is
   `rte_eal_init` against a one-page mempool; for the
   accelerator libraries (`doca-compress`, `doca-aes-gcm`,
   `doca-sha`, `doca-erasure-coding`) this is a minimal
   `doca_mmap` against a one-page input buffer. The exact
   shape lives in the matching library skill's `## test`
   workflow; this skill's role is to *trigger* the per-library
   smoke and read the result.
4. **Read `/proc/meminfo` again and confirm `HugePages_Free`
   decreased by exactly the expected count.** A pin that
   succeeds but does not show up in `/proc/meminfo` is a
   measurement bug (often a small-MR allocation that the
   library backed with regular pages); the agent surfaces
   the discrepancy.
5. **Only after the smoke passes, hand off to the library's
   real workload `## run`.** A smoke that did not pass is the
   wrong precondition to start a real workload against.

**Snapshot-capture rule.** When the goal of the test session is
a snapshot for a `doca-debug` session (vs an ad-hoc check), the
captured artifact must include the *quartet* per
[`## Command appendix`](#command-appendix) — `/proc/meminfo`
hugepage fields + per-page-size sysfs tree + per-NUMA-node
sysfs tree + `mount | grep huge` — alongside `numactl
--hardware` and `grep -i huge /proc/cmdline`. Quoting one without
the others is the canonical *"the snapshot looked fine, the
allocation still failed"* failure mode.

Loop termination: stop iterating once the target library's
allocate-one-page smoke passes AND the read-out from the
quartet reflects the expected post-allocation state. Escalate
cross-cutting symptoms (allocation fails inside a container,
succeeds on the bare host; allocation succeeds with one kernel
and fails with another) to
[`doca-debug ## debug`](../../doca-debug/SKILL.md) with the
captured quartet as evidence.

This skill does **not** ship a "test fixture" or pre-recorded
expected output. The expected output is host-, kernel-, and
library-specific; pinning one would mislead operators on a
different platform. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When a DOCA library reports an allocation / memory-region failure
that the agent suspects is hugepage-related, walk the
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
layers in order. The shape of the diagnosis:

1. **Hugepages-not-configured.** `cat /proc/meminfo | grep -i
   Huge` reports `HugePages_Total: 0` or omits the field
   entirely. Walk
   [`## configure`](#configure) end-to-end. Until this layer
   is green, any further investigation is premature.
2. **Wrong page size.** `HugePages_Total > 0` overall but the
   tree at `/sys/kernel/mm/hugepages/hugepages-<size>kB/` for
   the page size the library wants is empty. Re-configure for
   the expected size per axis 1 in
   [`## configure`](#configure) step 3; on most kernels a
   1 GiB-page reservation requires the boot-time scope.
3. **Insufficient allocation.** `HugePages_Free` is below the
   library's request. Identify the consumer holding the rest
   (`grep -l HugePages /proc/*/numa_maps 2>/dev/null` is a
   common starting point; check `mount | grep huge` for an
   active `hugetlbfs` mount with files inside it) before
   recommending a pool grow — growing the pool to hide a
   leaking consumer is the wrong fix.
4. **NUMA misalignment.** `/proc/meminfo` looks healthy
   host-wide but the per-NUMA-node tree shows zero free pages
   on the NIC's socket. Confirm with `numactl --hardware`;
   redistribute the pool via the per-NUMA-node sysfs surface
   per [`## modify`](#modify).
5. **Runtime allocation failed under load.** Pool was right at
   init; later allocations fail. Capture the quartet snapshot
   per [`## test`](#test) AND a `dmesg -T | tail -n 100`
   excerpt — kernel OOM events and `mlx5_core` driver
   warnings are the ground truth. Common fix: re-allocate at
   boot rather than at runtime; the runtime-best-effort
   behavior is the documented cause of late-in-day failures.
6. **`hugetlbfs` mount missing.** `mount | grep hugetlbfs` is
   empty even though the pool is reserved. Re-mount per
   [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
   step 4. Note: not every library needs the filesystem; the
   matching library skill's `## Capabilities and modes`
   names the case.
7. **Version skew with the DOCA library.** A configuration
   that worked on a previous DOCA install fails on the
   current one. Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   end-to-end before re-tuning the hugepage layout — the fix
   may be in the library's call-site, not in the hugepage
   pool.
8. **Cross-cutting.** Cause is below the Linux hugepages
   contract (kernel-side cgroup limits, IOMMU surprises,
   firmware-version-tied behavior). Hand off to
   [`doca-debug ## debug`](../../doca-debug/SKILL.md) and
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   with the captured quartet as evidence.

In every case: **quote what `/proc/meminfo` and the per-NUMA-node
tree said.** Do not paraphrase the field values, do not
summarize the pool sizes into prose. The whole point of using
the upstream Linux contracts as ground truth is to break the
agent out of the *"hugepages are probably fine"* trap.

## Command appendix

Hugepage-specific read-only invocations the verbs above reach
for. Every row is a CLASS — the agent must not invent paths,
sysctl knobs, or helper-flag strings beyond what the upstream
Linux kernel documentation and the public DOCA hugepages Tool
guide document. The seven-class symmetry below is the
load-bearing piece; one worked example per class is shown.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; `doca-capability-snapshot` for per-device capability
   flags; `version-matrix.json` for *"available since"* lookups;
   a future hugepages-snapshot helper for the quartet-capturing
   snapshot pattern when it lands per
   [`doca-structured-tools-contract ## Relationship to PR2 executables`](../../doca-structured-tools-contract/SKILL.md#relationship-to-pr2-executables)).
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

| Purpose (class) | Invocation (shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Read host-wide hugepage state | `cat /proc/meminfo \| grep -i Huge` | [`## configure`](#configure) step 2; [`## test`](#test) step 1; [`## debug`](#debug) layers 1-5 | Reports `HugePages_Total`, `HugePages_Free`, `Hugepagesize` (and per-size `_<size>kB_*` fields on kernels that include them) with non-zero values matching the chosen axis-1 page size. |
| Read per-page-size hugepage tree | `ls /sys/kernel/mm/hugepages/` then `cat /sys/kernel/mm/hugepages/hugepages-<size>kB/{nr,free,resv,surplus}_hugepages` | [`## configure`](#configure) step 2; [`## debug`](#debug) layer 2 | Directory for the chosen page size exists; `nr_hugepages` matches the reservation; `free_hugepages` reflects the post-allocation state expected by [`## test`](#test). |
| Read per-NUMA-node hugepage tree | `cat /sys/devices/system/node/node<N>/hugepages/hugepages-<size>kB/{nr,free}_hugepages` (per node) | [`## configure`](#configure) step 5; [`## debug`](#debug) layer 4 | The NIC's NUMA node has non-zero `nr_hugepages` AND non-zero `free_hugepages` at the chosen size; reading this from every node confirms the distribution. |
| Read `hugetlbfs` mount state | `mount \| grep huge` | [`## configure`](#configure) step 6; [`## debug`](#debug) layer 6 | Either the chosen mountpoint (e.g. `/mnt/huge`, `/dev/hugepages`) appears with `type hugetlbfs (..pagesize=<size>..)`, or the library's `## Capabilities and modes` documents that no mount is required. |
| Read the boot-time hugepage cmdline | `grep -i huge /proc/cmdline` | [`## configure`](#configure) step 4; [`## debug`](#debug) layer 2 | If the operator chose boot-time scope, the output names `hugepagesz=<size>` and `hugepages=<N>`. Empty output means the current kernel boot has no boot-time hugepage parameters and the pool is runtime-only. |
| Read NUMA topology | `numactl --hardware` | [`## configure`](#configure) step 5; [`## debug`](#debug) layer 4 | Lists every NUMA node, its CPUs, its memory total, and the per-node distances. Joined with the per-node hugepage tree, this is how axis 3 is decided. |
| Capture a quartet snapshot for a debug session | A captured artifact combining `/proc/meminfo` hugepage fields + per-page-size sysfs tree + per-NUMA-node sysfs tree + `mount | grep huge` + `numactl --hardware` + `grep -i huge /proc/cmdline` | [`## test`](#test) snapshot-capture rule; [`doca-debug ## test`](../../doca-debug/TASKS.md#test) | The artifact is saved verbatim and consumed by the debug session as evidence; quoting one component without the others is the canonical *"snapshot looked fine, allocation still failed"* failure mode. |

Three cross-cutting rules for this appendix:

- **Never invent a hugepage path, sysctl knob, or DOCA helper
  flag.** The upstream Linux kernel documentation and the
  public DOCA `doca-hugepages` Tool guide (via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
  are the joint contract. Prose-derived paths are the most
  common hallucination failure for this skill.
- **Quote the read-out; do not paraphrase.** `/proc/meminfo`
  and the sysfs trees are the read-only authoritative
  answer; the agent surfaces the field values verbatim, not a
  summary.
- **Cross-link instead of duplicate.** Cross-cutting commands
  (`pkg-config --modversion`, `doca_caps --list-devs`,
  `dmesg`, `mlxconfig -d <bdf> q`) live in
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
  and [`doca-debug ## debug`](../../doca-debug/SKILL.md); this
  appendix names only hugepage-specific read-only paths and
  the documented Linux runtime knobs.

## Deferred task verbs

The four verbs below are not hugepage work and should be routed
out before the agent does any of them under this skill's name.

- **install (DOCA itself)** ⇒ [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  (and [`## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). The DOCA install is
  the precondition for this skill; this skill does not own the
  install workflow.
- **install a kernel that supports hugepages** ⇒ upstream Linux
  distribution documentation, reachable via
  [`doca-public-knowledge-map ## Public documentation entry points`](../../doca-public-knowledge-map/SKILL.md#public-documentation-entry-points).
  Every kernel every DOCA platform ships on has hugepages
  enabled; this verb is only relevant on a hand-rolled custom
  kernel, which is out of scope.
- **library-internal MR / mempool / buffer-pool sizing
  decisions** ⇒ the matching `libs/<library>` skill (e.g.
  [`doca-rdma`](../../libs/doca-rdma/SKILL.md),
  [`doca-dpdk-bridge`](../../libs/doca-dpdk-bridge/SKILL.md),
  [`doca-compress`](../../libs/doca-compress/SKILL.md)). This
  skill says *"the env is hugepage-ready for the library's
  request"*; the library says *"what the request should be"*.
- **fleet / multi-host coordinated hugepage rollout** ⇒ out of
  scope. Reserved for a future platform skill
  (`doca-platform-deploy` or similar). Until that ships, the
  agent should stop and tell the user this is
  fleet-orchestration scope and recommend they engage their
  platform team rather than guess.

## Cross-cutting

A few rules that apply across every verb in this file, restated
here so they are visible at the point of action and not buried
in [`SKILL.md`](SKILL.md):

- The **public DOCA `doca-hugepages` Tool guide** plus the
  **upstream Linux kernel hugetlbpage documentation** are the
  joint source of truth. When they disagree (rare; the helper
  is documented to drive the upstream contract), the kernel
  contract wins for the user's actual run because that is what
  the running system actually exposes.
- Hugepages is **env-class, high-stakes, global state.** The
  agent's posture is *understand before changing, change in
  staging before production, re-read the state after the
  change, smoke from the target DOCA library before declaring
  victory*. Skipping any of those four steps is the failure
  mode this skill is here to prevent.
- **Quote the kernel paths verbatim.** `/proc/meminfo` and the
  sysfs trees are the read-only authoritative answer; the
  agent surfaces the field values, not a summary, to break out
  of the *"hugepages are probably fine"* inference trap.
- This skill **assumes a healthy DOCA install** (or the public
  NGC DOCA container per
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install))
  and a Linux kernel with the standard hugepages contract
  enabled. If either is in doubt, route to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the
  upstream Linux documentation via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  before running anything else here.
