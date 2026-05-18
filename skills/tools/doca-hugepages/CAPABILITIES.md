# DOCA hugepages — Capabilities

**Where to start:** Hugepages is a cross-library env precondition;
the pattern overview below names the recurring hugepage-class
questions every DOCA-DMA workload eventually surfaces. Pick the
pattern first, then drill into the H2 that owns the substance. For
the *how* of executing each pattern (configure the host, smoke a
single allocation, debug a failure), jump to [TASKS.md](TASKS.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents *what
hugepages are in scope for DOCA*, *which DOCA libraries depend on
them*, *what the three-axis configuration model is*, *what the
narrow but layered error surface looks like*, and *the high-stakes
safety posture that distinguishes hugepage changes from any other
env knob the bundle teaches*. For step-by-step invocations and the
allocate-one-page smoke loop, see [`TASKS.md`](TASKS.md).

## Pattern overview

Every hugepage-class question this skill teaches resolves into one
of SIX patterns. The patterns are CLASSES — they apply across every
DOCA library that DMA-pins memory, not just one.

| Hugepages pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Confirm a DOCA library needs hugepages at all | The cross-library dependency surface (RDMA / DPDK-bridge / GPUNetIO / Compress / AES-GCM / SHA / EC / DMA / Eth) is the load-bearing piece. Skipping this step and configuring hugepages "just in case" is the canonical operator-time-waste failure mode. | [`## Capabilities and modes`](#capabilities-and-modes) library-dependency table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Pick the three-axis configuration | Page size × scope × NUMA placement is axis 1 / 2 / 3 of every hugepage decision. Omitting any axis produces a configuration that the library will fail to allocate against on at least one host. | [`## Capabilities and modes`](#capabilities-and-modes) three-axis table + [TASKS.md ## configure](TASKS.md#configure) steps 2-4 |
| 3. Smoke an allocation from a DOCA library | The cheapest defensible probe is *"the library can pin ONE page on the right NUMA node"*; do that before the real workload. A successful host smoke against the WRONG library is not evidence; the smoke must come from the library that will run the workload. | [TASKS.md ## test](TASKS.md#test) smoke loop + [`## Observability`](#observability) snapshot quartet |
| 4. Read `/proc/meminfo` and `/sys/kernel/mm/hugepages/` for ground truth | These are upstream Linux contracts. They are the read-only authoritative answer to *"is the host hugepage-ready"*; the operator should quote them, not paraphrase them. | [`## Observability`](#observability) read-only surfaces + [TASKS.md ## Command appendix](TASKS.md#command-appendix) |
| 5. Diagnose an allocation failure by layer | Walk the layered error taxonomy (not-configured → wrong-page-size → insufficient-allocation → NUMA-misalignment → runtime-allocation-failed-under-load → hugetlbfs-mount-missing → version-skew → cross-cutting); the layer is the answer. | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |
| 6. Change allocation safely on a live host | Hugepage allocation is global, can OOM the kernel, can starve other workloads, and boot-time changes require a reboot. The agent must surface this posture and recommend a staging-host trial before the production change. | [`## Safety policy`](#safety-policy) + [TASKS.md ## modify](TASKS.md#modify) |

Two cross-cutting rules that apply to *every* pattern above:

- **Hugepages is env-class state, not per-process state.** A change
  to `nr_hugepages` or to the `hugetlbfs` mount affects every
  process on the host that uses (or wants to use) hugepages — DOCA
  libraries, DPDK applications, KVM, JVMs, Postgres, ... — at
  once. The agent's diagnostic posture must be host-wide, not
  process-wide.
- **`/proc/meminfo` and `/sys/kernel/mm/hugepages/` are upstream
  Linux contracts.** They are stable across every kernel DOCA
  supports; citing them by canonical path is safe and is the
  authoritative way the agent quotes hugepage state. Inventing
  DOCA-specific paths for the same data is the canonical
  hallucination failure for this skill.

## Capabilities and modes

DOCA itself does not own the hugepages contract — the **Linux
kernel** does. The DOCA-side surface has two layers: (a) the
public `doca-hugepages` Tool guide reachable via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
that documents the DOCA-shipped helper, and (b) the canonical
Linux hugepages contract (`/proc/meminfo`,
`/sys/kernel/mm/hugepages/`, `hugetlbfs` mounts, the
`hugepagesz=` / `hugepages=` kernel cmdline, the
`vm.nr_hugepages` sysctl). DOCA libraries that DMA-pin memory
allocate from the same pool the rest of the host sees; there is
no DOCA-private hugepage pool.

**Cross-library dependency surface — which DOCA libraries actually
need hugepages.** Hugepages are an env precondition for any DOCA
library that DMA-pins memory through the BlueField / ConnectX
hardware. The bundle's authoritative list is:

| DOCA library | Why hugepages matter | Per-library skill |
| --- | --- | --- |
| `doca-rdma` | RDMA memory regions are pinned DMA-coherent pages; hugepages reduce the IOMMU / page-table overhead the NIC walks per descriptor and are typically a hard requirement for line-rate MR allocation. | [`doca-rdma`](../../libs/doca-rdma/SKILL.md) |
| `doca-dpdk-bridge` | DPDK itself requires hugepages for its `rte_eal_init` mempool backing — the bridge inherits the DPDK env preconditions wholesale. The bridge will not come up if DPDK cannot reserve hugepages on the EAL's chosen NUMA node. | [`doca-dpdk-bridge`](../../libs/doca-dpdk-bridge/SKILL.md) |
| `doca-gpunetio` | GPU ↔ NIC DMA paths need pinned, IOMMU-mapped pages reachable from both the GPU's BAR and the NIC's DMA engine; hugepages are the documented backing. | [`doca-gpunetio`](../../libs/doca-gpunetio/SKILL.md) |
| `doca-compress` | Bulk-buffer DMA into and out of the compress accelerator runs against `doca_mmap` regions sized for hardware throughput; hugepages reduce per-descriptor overhead and are the recommended backing for the throughput-mode jobs the library is designed for. | [`doca-compress`](../../libs/doca-compress/SKILL.md) |
| `doca-aes-gcm`, `doca-sha`, `doca-erasure-coding` | Same shape as Compress — DMA-pinned `doca_mmap` regions backing the accelerator's job pool. | [`doca-aes-gcm`](../../libs/doca-aes-gcm/SKILL.md), [`doca-sha`](../../libs/doca-sha/SKILL.md), [`doca-erasure-coding`](../../libs/doca-erasure-coding/SKILL.md) |
| `doca-dma` | Host ↔ DPU memory copies via the BlueField DMA engine; the source / destination buffers are `doca_mmap` regions whose performance is hugepage-sensitive. | [`doca-dma`](../../libs/doca-dma/SKILL.md) |
| `doca-eth` | Line-rate Ethernet RX / TX queues pin DMA buffers; hugepages are the documented backing for the per-queue buffer pools at the bandwidths the library targets. | [`doca-eth`](../../libs/doca-eth/SKILL.md) |

DOCA libraries that do **not** depend on hugepages are typically
control-plane / introspection libraries (e.g. `doca-comch` control
channel, `doca-telemetry` consumer side, `doca-flow` programming
of the steering plane — Flow programs hardware but does not itself
DMA-pin large buffers in the application's address space). When in
doubt, the matching library skill's `## Version compatibility`
and `## Error taxonomy` sections name hugepages explicitly when
they are an env precondition; absence is the documented signal
that they are not.

**Three-axis configuration model — the load-bearing concept.**
Every hugepage configuration decision commits to a point in this
space; omitting any axis produces a setup that fails on at least
one DOCA library × host combination.

| Axis | What it picks | Why the agent must name it |
| --- | --- | --- |
| 1. Page size | 2 MiB (the canonical Linux default; supported on every x86_64 / aarch64 platform DOCA runs on) vs 1 GiB (gigantic pages; lower TLB pressure but only allocatable at boot on most kernels and only on hosts with sufficient contiguous physical memory). | A library configured for 1 GiB pages will not allocate against a 2 MiB-only pool, and vice versa. Quoting *"the host has hugepages"* without naming the page size is ambiguous. |
| 2. Scope | Boot-time (via the `hugepagesz=` + `hugepages=` kernel command line, and for 1 GiB pages typically the only reliable scope) vs runtime (via `echo <N> > /sys/kernel/mm/hugepages/hugepages-<size>kB/nr_hugepages` or the `vm.nr_hugepages` sysctl — supported for 2 MiB pages, best-effort for 1 GiB pages on most kernels). | Runtime changes are best-effort: under memory pressure or fragmentation the kernel may not honor the request. The agent must surface this when recommending runtime allocation on a host with significant existing workload. |
| 3. NUMA placement | Per-node allocation via `/sys/devices/system/node/node<N>/hugepages/hugepages-<size>kB/nr_hugepages` (the upstream Linux per-NUMA-node surface). Critical on multi-socket hosts: a DOCA workload bound to NIC PCIe slot on socket 1 needs hugepages on socket 1, regardless of the host-wide total. | A hugepage pool with the right *total* size but the wrong *per-node* distribution is exactly the failure mode where `/proc/meminfo` looks healthy and the DOCA library still cannot allocate. NUMA-blind configuration is the most common silent-fail mode on multi-socket hosts. |

**Public `doca-hugepages` Tool guide overlay.** DOCA ships a
documented `doca-hugepages` Tool — its public guide is reachable
via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
and described there as a helper to set up huge-page reservations
expected by some DOCA workloads. The bundle's posture is:

- **Treat the public guide as the source of truth for the helper's
  flag inventory and recipes.** The agent must not invent flag
  strings, default values, or recipe steps that are not on the
  public page. If the agent does not know an exact flag name, the
  honest move is to name the parameter family and tell the user
  to confirm against the public guide on their installed DOCA
  version.
- **Treat the canonical Linux paths as the source of truth for
  the host's actual hugepage state.** Regardless of how the
  reservation was made, `/proc/meminfo` and
  `/sys/kernel/mm/hugepages/` (and the per-NUMA-node mirror
  under `/sys/devices/system/node/`) are what the kernel
  reports. They are stable upstream contracts; quote them
  directly.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The doca-hugepages-specific overlay** is:

- **Hugepages is an env precondition, not a versioned DOCA API.**
  The Linux hugepages contract (`/proc/meminfo`,
  `/sys/kernel/mm/hugepages/`, `hugetlbfs`, `hugepagesz=` /
  `hugepages=` cmdline) is the same on every kernel every DOCA
  release supports; this skill therefore has no
  *"available since DOCA X.Y.Z"* cutoff of its own.
- **The public `doca-hugepages` Tool guide is the per-DOCA-release
  surface that can drift.** The helper's documented flag inventory,
  defaults, and recipe steps can change across DOCA versions; the
  agent must read the public guide on the user's installed DOCA
  version per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
  before quoting any helper-specific flag.
- **Library-specific hugepage preconditions ride the library's
  version.** Each `libs/<library>` skill's `## Version
  compatibility` overlay names the hugepage requirement that
  applies on the user's DOCA version (e.g. a 1 GiB-page
  requirement introduced for a new MR-size class on a recent
  DOCA release). The agent must consult the matching library
  skill before assuming the hugepage requirement is constant
  across DOCA versions.
- **Mismatch between the public guide and the kernel is the
  kernel's win.** When the public DOCA guide describes a
  hugepage knob the operator's kernel does not expose (rare but
  possible on minimal BlueField images), the kernel surface is
  ground truth. Route the gap to upstream Linux documentation
  via [`doca-public-knowledge-map ## Public documentation entry points`](../../doca-public-knowledge-map/SKILL.md#public-documentation-entry-points)
  rather than recommending a workaround the kernel will refuse.

## Error taxonomy

Hugepage failures present as either *"the DOCA library refused to
init"* or *"the DOCA library inited and later failed an allocation
under load"*. The error layers the agent should distinguish, in
escalating order:

1. **Hugepages-not-configured.** `/proc/meminfo` reports
   `HugePages_Total: 0` (or omits the field entirely on a kernel
   with hugepages disabled, which is rare on DOCA platforms). The
   library refuses to init with an allocation error. Routing:
   walk [`TASKS.md ## configure`](TASKS.md#configure) end-to-end;
   the env-side minimum-viable recipe lives in
   [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
   step 4.
2. **Wrong page size.** `HugePages_Total > 0` for the wrong size
   (e.g. only 2 MiB pages reserved but the library expects 1 GiB
   pages, or vice versa). The library refuses to init with a
   page-size-specific error. Symptom: the per-page-size tree at
   `/sys/kernel/mm/hugepages/hugepages-<size>kB/` is empty for
   the size the library wants and non-empty for a different size.
   Routing: re-run axis 1 of the three-axis model in
   [`## Capabilities and modes`](#capabilities-and-modes) and
   re-configure for the expected page size.
3. **Insufficient allocation.** `HugePages_Total > 0` at the right
   page size, but `HugePages_Free` is too small to satisfy the
   library's MR / mempool sizing. Symptom: `/proc/meminfo` shows
   `HugePages_Free` below the library's request; another DOCA /
   DPDK / KVM workload may have already taken the pool. Routing:
   confirm no other consumer is holding the pages
   (`grep -l 'HugePages' /proc/*/numa_maps 2>/dev/null` or the
   per-process maps), then either grow the pool per
   [`TASKS.md ## modify`](TASKS.md#modify) (with the safety
   policy in mind) or shrink the library's request.
4. **NUMA misalignment.** `/proc/meminfo` looks healthy host-wide,
   but the per-NUMA-node tree
   (`/sys/devices/system/node/node<N>/hugepages/hugepages-<size>kB/`)
   shows the pages are on the wrong socket relative to the NIC's
   PCIe slot. The library inits but allocates from a far-NUMA
   node (slow) or refuses with a *"could not allocate on local
   node"* error. Symptom: `numactl --hardware` shows the NIC's
   node has too few free hugepages. Routing: re-run axis 3 of
   the three-axis model in
   [`## Capabilities and modes`](#capabilities-and-modes) and
   redistribute the pool via the per-NUMA-node sysfs surface
   per [`TASKS.md ## modify`](TASKS.md#modify).
5. **Runtime allocation failed under load.** The library inited
   cleanly; allocations succeed early; later allocations fail.
   Symptom: `HugePages_Free` drains over time, sometimes
   accompanied by kernel OOM events in `dmesg`. Causes: a
   leaking DOCA / DPDK workload, an under-sized pool for the
   working set, kernel-side fragmentation that prevents fresh
   page reservation after a runtime `nr_hugepages` bump. Routing:
   capture the read-only snapshot per
   [`## Observability`](#observability) and walk
   [`TASKS.md ## debug`](TASKS.md#debug) layer 5; in many cases
   the fix is to grow the pool *at boot* and reboot, not to
   re-bump at runtime.
6. **`hugetlbfs` mount missing.** The pool is configured but the
   `hugetlbfs` mount the library expects to back its allocations
   is absent. Symptom: `mount | grep hugetlbfs` is empty even
   though `/proc/meminfo` reports a non-zero pool. Routing:
   re-mount per the minimum-viable recipe in
   [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
   step 4. Note: not all DOCA libraries require the
   `hugetlbfs` *filesystem* (some allocate via `MAP_HUGETLB`
   directly); the matching library skill names which is the
   case.
7. **Version skew with the DOCA library.** The hugepage layout
   the library expects on the user's installed DOCA version
   differs from the layout the public guide / agent memory
   described. Symptom: a configuration that worked on a
   previous DOCA install fails on the current one with an
   allocation error. Routing: walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   end-to-end before re-configuring hugepages; the fix may be
   in the library's call-site, not in the hugepage layout.
8. **Cross-cutting.** The cause is below the Linux hugepages
   contract — kernel-side memory cgroup limits, an
   `mlx5_core` driver pinning issue, a firmware-version-tied
   IOMMU behavior. Symptoms that do not fit layers 1-7 (e.g.
   allocation succeeds outside a container and fails inside,
   allocation succeeds with one kernel and fails with another
   at the same DOCA version). Routing: hand off to
   [`doca-debug ## debug`](../../doca-debug/SKILL.md) and
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug);
   the hugepage surface has reached its limit.

Hugepages do **not** themselves participate in the cross-library
`DOCA_ERROR_*` taxonomy that DOCA libraries return through their
C API; the kernel reports allocation failures via the standard
`mmap` / `MAP_HUGETLB` return codes, and the DOCA library maps
those to a library-specific `DOCA_ERROR_*` at the call site. For
the cross-library `DOCA_ERROR_*` taxonomy and the program-side
debug order, see
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).

## Observability

Hugepages' observability surface is **the upstream Linux kernel's
own read-only contracts**, plus the per-library `doca_mmap` /
allocation error surfaced by the matching library skill. The
quartet of canonical paths the agent should quote:

- **`/proc/meminfo` (Hugepages fields).** The host-wide summary:
  `HugePages_Total`, `HugePages_Free`, `HugePages_Rsvd`,
  `HugePages_Surp`, `Hugepagesize`, plus the per-size
  `HugePages_<size>kB_*` family on kernels that report it. This
  is the read-only authoritative answer to *"what is the host's
  current hugepage state"*; the agent quotes the field values,
  it does not paraphrase them.
- **`/sys/kernel/mm/hugepages/hugepages-<size>kB/`.** The
  per-page-size tree. Each directory has `nr_hugepages`,
  `free_hugepages`, `resv_hugepages`, `surplus_hugepages`,
  `nr_overcommit_hugepages`. Used to distinguish *"the pool
  has the right total but the wrong page size"* from *"the
  pool has the right page size but is fully consumed"*.
- **`/sys/devices/system/node/node<N>/hugepages/hugepages-<size>kB/`.**
  The per-NUMA-node mirror of the above. Used to confirm the
  pool is on the correct socket relative to the NIC's PCIe
  slot. `numactl --hardware` is the convenient one-shot for
  the broader NUMA topology a hugepage layout has to match.
- **`mount | grep hugetlbfs` and `mount | grep huge`.** Lists
  the active `hugetlbfs` mount(s) — typically
  `/mnt/huge` or `/dev/hugepages` on a DOCA-prepared host.
  Required for libraries that allocate via the `hugetlbfs`
  filesystem rather than `MAP_HUGETLB`.

Two further read-only commands that round out the surface:

- **`grep -i huge /proc/cmdline`** — confirms whether the
  current kernel was booted with `hugepagesz=` / `hugepages=`
  parameters (the boot-time scope). Empty output means runtime
  scope is the only path available without a reboot.
- **`numactl --hardware`** — reports the NUMA topology (nodes,
  per-node memory, per-node CPUs, distances). Joined with the
  per-node hugepage tree, this is how the agent decides whether
  axis 3 (NUMA placement) is satisfied for a given NIC PCIe
  slot.

For the cross-cutting env-side observability primitives (devlink
device visibility, representor enumeration, `mlxconfig` queries)
see [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).
For the program-side observability surface (`DOCA_LOG_LEVEL`,
`--sdk-log-level`) see
[`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability).

## Safety policy

Hugepage configuration is **the highest-stakes env knob the
bundle teaches**. Unlike `PKG_CONFIG_PATH` or `LD_LIBRARY_PATH`,
changing the hugepage pool is global, immediate, and can crash
unrelated workloads. The safety rules:

- **Hugepage allocation is global, shared system state.** A
  change to `nr_hugepages` or to a `hugetlbfs` mount affects
  every DOCA, DPDK, KVM, JVM, and database workload on the host
  at once. Before recommending a change, ask the user whether
  anything else on this host uses hugepages — if yes, the
  change is a coordination operation, not an isolated one.
- **Runtime allocation is best-effort and can OOM the kernel.**
  Writing into `nr_hugepages` (or setting `vm.nr_hugepages`) on
  a host under memory pressure can starve the kernel and
  trigger OOM events. The agent must surface this and recommend
  doing the change with headroom (e.g. drain other workloads
  first, or do the change at boot via the kernel cmdline
  instead).
- **Boot-time changes require a reboot.** `hugepagesz=` and
  `hugepages=` on the kernel command line are the only reliable
  scope for 1 GiB pages on most kernels and are the recommended
  scope for any host that needs durable allocation. The agent
  must not chain a `grub-mkconfig` / equivalent step with an
  automatic reboot — the agent produces the commands and
  explains the requirement; the operator confirms.
- **Recommend a staging-host trial first.** Before changing
  hugepage allocation on a production host, the agent should
  recommend reproducing the configuration on a staging host
  with the same NUMA topology and validating the
  allocate-one-page smoke from the target DOCA library. A
  hugepage change that worked on a single-socket dev box can
  silently fail on a multi-socket production host with
  different per-node memory distribution.
- **Never `umount hugetlbfs` while a DOCA / DPDK workload is
  running.** Unmounting `hugetlbfs` (or remounting with
  different options) under a running consumer is unsupported
  and will crash the consumer. Coordinate with every consumer
  on the host before the unmount, or do the change at boot
  before any consumer starts.
- **Quote the kernel paths; do not paraphrase.** When the user
  asks *"is the host hugepage-ready"*, the right answer is to
  quote the `HugePages_Total` / `HugePages_Free` /
  `Hugepagesize` lines from `/proc/meminfo` and the
  per-NUMA-node tree, not to summarize them into prose. The
  whole point of using the kernel contracts as ground truth is
  to break the agent out of the *"I think it's configured"*
  trap.

## Public-source pointer

The two canonical public sources for this skill are:

- The **DOCA `doca-hugepages` Tool** page on `docs.nvidia.com`,
  reachable through
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  This documents the DOCA-shipped helper and its flag surface.
- The **upstream Linux kernel hugetlbpage documentation** for
  the canonical contracts the helper drives
  (`/proc/meminfo`, `/sys/kernel/mm/hugepages/`,
  `hugepagesz=` / `hugepages=` cmdline, `vm.nr_hugepages`
  sysctl, `hugetlbfs` filesystem). The agent should treat the
  kernel docs as ground truth for the *paths* and *semantics*;
  the DOCA helper guide is the right place for the
  DOCA-specific recipe layered on top.

Do not invent helper flag strings, default page-size choices, or
NUMA layouts beyond what those two sources document.
