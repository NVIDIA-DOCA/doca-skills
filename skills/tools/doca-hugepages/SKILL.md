---
name: doca-hugepages
description: NVIDIA DOCA hugepages — the documented DOCA hugepages configuration recipe (the public `doca-hugepages` Tool guide on docs.nvidia.com) plus the canonical Linux hugepages controls every DOCA library that DMA-pins memory ultimately rides on. Covers page size (2 MiB / 1 GiB), scope (boot-time kernel cmdline vs runtime sysctl), NUMA-per-node placement, the `hugetlbfs` mount, the read-only `/proc/meminfo` + `/sys/kernel/mm/hugepages/` surfaces, the smoke-before-bulk allocate-one-page test from a DOCA library, and the high-stakes posture that hugepage allocation is global state — can OOM the kernel or starve other workloads, and boot-time changes require a reboot. Load whenever a DOCA library that needs DMA-backed memory (RDMA memory regions, DPDK-bridge ports, GPUNetIO, Compress, AES-GCM, SHA, EC, DMA) fails to pin or allocate at init. Complements `doca-setup`'s env-prep step on hugepages; never duplicates it.
kind: library
---

# DOCA hugepages

**Where to start:** This skill is a TOOL skill that owns the DOCA
hugepages question — *"how do I configure Linux hugepages so the DOCA
library I am about to run can DMA-pin its buffers?"*. Open
[`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure) for the three-axis decision
(page size × scope × NUMA placement), [`## test`](TASKS.md#test) for
the smoke-before-bulk allocate-one-page-from-a-DOCA-library loop, or
[`## debug`](TASKS.md#debug) when a DOCA library reports a hugepage
allocation failure. Open [`CAPABILITIES.md`](CAPABILITIES.md) when
the question is *what hugepages cover for DOCA*, *which DOCA
libraries actually need them*, or *what the safe vs unsafe knobs
are*. If DOCA itself is not installed yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; this skill assumes
the install is healthy and the question is hugepage-readiness for a
specific DOCA library.

## Example questions this skill answers well

The CLASSES of hugepages questions this skill is built to answer,
each with one worked example. The class is the load-bearing piece;
the worked example is one instance.

- **"Which DOCA libraries actually need hugepages, and how do I
  decide the page size?"** — worked example: *"I am about to bring
  up a doca-rdma workload, do I need 2 MiB or 1 GiB pages?"*.
  Answered by the cross-library dependency surface in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the three-axis configuration in
  [`TASKS.md ## configure`](TASKS.md#configure). The same shape
  answers *"I am about to bring up the DOCA DPDK Bridge"* — this
  skill is cross-library, not single-library.
- **"My DOCA workload fails at init with a hugepage allocation
  error — where do I look?"** — worked example: *"doca-rdma fails
  with a hugepage-allocation-failed error after a few minutes of
  uptime"*. Answered by the layered error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (not-configured → wrong-page-size → insufficient-allocation →
  NUMA-misalignment → runtime-allocation-failed-under-load →
  hugetlbfs-mount-missing → version-skew → cross-cutting) +
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Hugepages are configured but the DOCA library still refuses
  to pin — what did I miss?"** — worked example: *"`/proc/meminfo`
  shows `HugePages_Total > 0` but doca-compress refuses to
  allocate"*. Answered by the NUMA-alignment + per-node placement
  rules in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the allocate-one-page smoke loop in
  [`TASKS.md ## test`](TASKS.md#test).
- **"Should I change hugepage allocation at boot or at runtime?"** —
  worked example: *"I need 16 GiB of 1 GiB pages on a host that
  also runs Postgres"*. Answered by the boot-vs-runtime axis in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the high-stakes safety rules in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  (boot-time changes require a reboot, runtime changes are
  best-effort and can OOM the kernel if the host is under memory
  pressure).
- **"How do I capture a snapshot of hugepage state to attach to a
  debug session?"** — worked example: *"a doca-rdma allocation
  fails sporadically and I need evidence for `doca-debug`"*.
  Answered by the read-only observability surface in
  [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
  (`/proc/meminfo`, `/sys/kernel/mm/hugepages/` per-page-size /
  per-NUMA-node trees, `numactl --hardware`) + the snapshot
  workflow in [`TASKS.md ## test`](TASKS.md#test).
- **"I changed hugepages on a live host and now another DOCA
  application crashed — what is the recovery posture?"** — worked
  example: *"I bumped `nr_hugepages` while a doca-dpdk-bridge app
  was running and it crashed"*. Answered by the high-stakes rules
  in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  (hugepage allocation is global; remounting `hugetlbfs` or
  shrinking the pool under a running workload is unsupported) +
  the staging-host trial recommendation in
  [`TASKS.md ## modify`](TASKS.md#modify).

## Audience

This skill serves **external operators, developers, and AI agents
who need to ready a Linux host's hugepages for a DOCA library that
DMA-pins memory** before running the workload. Concretely:

- An external developer about to run their first
  [`doca-rdma`](../../libs/doca-rdma/SKILL.md) /
  [`doca-dpdk-bridge`](../../libs/doca-dpdk-bridge/SKILL.md) /
  [`doca-gpunetio`](../../libs/doca-gpunetio/SKILL.md) /
  [`doca-compress`](../../libs/doca-compress/SKILL.md) workload on
  a fresh host, who needs the hugepage preconditions documented
  before the first call into the library fails at init.
- A platform operator deploying a DOCA service who needs the
  documented hugepage posture (page size, NUMA layout, allocation
  size) for a multi-socket host before flipping the service from
  staging to production.
- An SRE diagnosing a hugepage allocation failure mid-workload
  (the *"it worked on Monday and OOMs on Tuesday"* shape) who
  needs the layered error taxonomy and the read-only observability
  surface.
- An AI agent answering *"is this host ready to run this DOCA
  library?"* — with `/proc/meminfo` evidence, NUMA placement, and
  an allocate-one-page-from-the-library smoke test — instead of
  guessing that *"hugepages are enabled by default"*.

It is **not** for users learning what hugepages are in the abstract
(consult the upstream Linux kernel documentation for that), and
**not** a substitute for the public DOCA hugepages helper guide on
`docs.nvidia.com`. This skill *cross-links* to those; it does not
re-derive them.

`doca-hugepages` is a unique tool skill — the public DOCA
documentation includes a `doca-hugepages` helper guide (reachable
via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)),
but the substantive configuration surface is the upstream Linux
hugepages contract every DOCA library that DMA-pins memory rides
on. This skill is therefore an honest overlay: the documented DOCA
helper guide *plus* the canonical Linux paths
(`/proc/meminfo`, `/sys/kernel/mm/hugepages/`, `hugetlbfs` mounts)
that the helper ultimately drives. The skill uses the same
`kind: library` three-file shape as the rest of the bundle so the
agent's task-verb contract (`configure / build / modify / run /
test / debug`) is uniform across libraries, services, and tools.

## When to load this skill

Load this skill when the user is — or the agent needs to — answer
*"is this host's hugepage configuration ready for the DOCA library
the user is about to run?"*. Concretely:

- The user is about to run a DOCA library that DMA-pins memory
  ([`doca-rdma`](../../libs/doca-rdma/SKILL.md),
  [`doca-dpdk-bridge`](../../libs/doca-dpdk-bridge/SKILL.md),
  [`doca-gpunetio`](../../libs/doca-gpunetio/SKILL.md),
  [`doca-compress`](../../libs/doca-compress/SKILL.md),
  [`doca-aes-gcm`](../../libs/doca-aes-gcm/SKILL.md),
  [`doca-sha`](../../libs/doca-sha/SKILL.md),
  [`doca-erasure-coding`](../../libs/doca-erasure-coding/SKILL.md),
  [`doca-dma`](../../libs/doca-dma/SKILL.md),
  [`doca-eth`](../../libs/doca-eth/SKILL.md)) and the agent needs
  to confirm the hugepage preconditions before the first init
  call.
- A DOCA library call returned an allocation / memory-region
  failure that the per-library error taxonomy traces back to the
  env (hugepages not reserved on the right NUMA node, not enough
  free pages, wrong page size for the library's MR size).
- The user is planning a hugepage allocation change on a host
  that also runs other workloads and needs the high-stakes
  posture (boot-time vs runtime, OOM risk, reboot requirement,
  recommend staging trial).
- The agent is producing a *hugepage snapshot* artifact during
  a `doca-debug` session (the read-only `/proc/meminfo` +
  `/sys/kernel/mm/hugepages/` quartet is the documented evidence
  layer for cross-cutting hugepage failures).

Do **not** load this skill for general DOCA orientation, library
API work, install procedures, or learning what hugepages are. For
those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
the matching `libs/<library>` skill,
[`doca-setup`](../../doca-setup/SKILL.md), or upstream Linux
kernel documentation respectively.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — which DOCA libraries depend on hugepages
  and why (the cross-library dependency surface), the three-axis
  configuration model (page size × scope × NUMA placement), the
  version overlay (per `doca-version`), the layered error
  taxonomy (not-configured / wrong-page-size /
  insufficient-allocation / NUMA-misalignment /
  runtime-allocation-failed-under-load / hugetlbfs-mount-missing /
  version-skew / cross-cutting), the read-only observability
  surface (`/proc/meminfo`, `/sys/kernel/mm/hugepages/`,
  `numactl --hardware`), and the high-stakes safety posture
  (global state, OOM risk, reboot for boot-time, runtime is
  best-effort, recommend staging trial).
- `TASKS.md` — step-by-step workflows for the in-scope task
  verbs: `configure` (the three-axis decision + cross-link to
  `doca-setup`'s minimum-viable recipe), `build` (route — no
  source to build), `modify` (high-stakes change posture), `run`
  (the documented Linux runtime knobs), `test` (the
  allocate-one-page smoke loop from a DOCA library), `debug`
  (walk the error taxonomy layer by layer), plus a `Deferred
  task verbs` block routing out-of-scope questions and a
  `Command appendix` of hugepage-specific read-only invocations
  with the infra-aware preamble.

The skill assumes a healthy DOCA install (or the public NGC DOCA
container per
[`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install))
and a Linux kernel that exposes the standard hugepages contract
(`/proc/meminfo`, `/sys/kernel/mm/hugepages/`,
`hugetlbfs`) — both of which every documented DOCA platform
guarantees.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts bundle.
To keep the boundary clean, it deliberately does not contain — and
pull requests should not add:

- **Invented flag strings for the public `doca-hugepages` helper
  tool.** The helper's documented flag surface lives in the
  public DOCA hugepages Tool guide reachable via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  Inventing a flag from generic CLI knowledge is the canonical
  hallucination failure mode for this skill.
- **Specific `nr_hugepages` values, NUMA layouts, or page-size
  recommendations beyond the cross-library guidance.** The right
  value is per-host (memory size, NUMA topology, other
  workloads); pinning a number would mislead operators on a
  different host. The skill teaches the *decision*, not the
  *number*.
- **Wrappers, parsers, or scripts** in any language that automate
  hugepage reservation. Hugepage allocation is high-stakes global
  state; automating it without operator review is exactly the
  failure mode the safety policy is here to prevent. If a user
  wants a script, the right answer is *"the operator runs the
  documented commands under their own review"*.
- **A `samples/` or `reference/` subtree.** This is a thin loader
  for a Linux contract + a DOCA helper guide; substantive
  material lives on the public page, in the kernel docs, and in
  the operator's `/proc/meminfo` + `/sys/kernel/mm/hugepages/`
  read-out.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (the user actually wants to configure / verify
   hugepages for a DOCA library, not learn the Linux kernel
   feature in general).
2. **For which DOCA libraries depend on hugepages, the
   three-axis model, the version overlay, the error taxonomy,
   observability surface, and safety posture, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented invocations and the smoke-before-bulk
   workflow — `configure`, `build`, `modify`, `run`, `test`,
   `debug` — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — routing to the public DOCA hugepages Tool guide on
  `docs.nvidia.com` and the rest of the public DOCA documentation
  set. Every cite of the public hugepages guide goes through this
  map; this skill does not duplicate URLs.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, and the env-class
  [`## configure`](../../doca-setup/TASKS.md#configure) step that
  ships the minimum-viable hugepages recipe (mount `hugetlbfs`,
  echo into `nr_hugepages`). This skill *complements* that step
  by owning the multi-axis decision, the NUMA story, the error
  taxonomy, and the high-stakes posture; it does not
  re-implement it.
- [`doca-version`](../../doca-version/SKILL.md) — the canonical
  version-detection chain, four-way match rule, NGC container
  semantics, and headers-win-over-docs rule. The
  `## Version compatibility` section in this skill is a thin
  overlay on top of `doca-version`; the body lives there.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle-wide contract for structured-output helper tools.
  The `doca-env --json` schema includes a `hugepages` block; this
  skill's `## Command appendix` is infra-aware via that contract
  from day one, so the agent prefers the structured one-shot
  when present and falls back to the manual chain when not.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. When a hugepage failure turns out to be below the
  Linux hugepages contract (kernel-side fragmentation, NUMA
  topology surprise, memory-cgroup interaction), this skill's
  error taxonomy hands off to `doca-debug`.
- [`doca-caps`](../doca-caps/SKILL.md) — the sibling read-only
  DOCA tool for the per-device per-library capability snapshot.
  Hugepages and caps are the two cheap, side-effect-free probes
  the agent runs before any DOCA workload that touches DMA.
- The matching `libs/<library>` skill — e.g.
  [`doca-rdma`](../../libs/doca-rdma/SKILL.md),
  [`doca-dpdk-bridge`](../../libs/doca-dpdk-bridge/SKILL.md),
  [`doca-gpunetio`](../../libs/doca-gpunetio/SKILL.md),
  [`doca-compress`](../../libs/doca-compress/SKILL.md) — for the
  library-internal call-site error overlays. This skill says
  *"the env is hugepage-ready"*; the library skill says *"what
  the API call should look like"*.
