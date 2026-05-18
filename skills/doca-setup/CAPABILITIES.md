# DOCA setup — capabilities, version compatibility, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your question
(modes / version / errors / observability / safety) and read that
section end-to-end before issuing a command. Tables in each section
are the load-bearing content; the prose around them is interpretation.

Read this file when the loader sent you here from [SKILL.md](SKILL.md). For the env workflows that *use* the surface described here, see [TASKS.md](TASKS.md). For the program-side counterparts (build flavor selection rationale, the universal lifecycle, the cross-library `DOCA_ERROR_*` taxonomy, the program-side safety policy), see [`doca-programming-guide`](../doca-programming-guide/SKILL.md). For where to find official documentation, the on-disk layout of an installed DOCA package, or the official Installation Guide, route through [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

This file describes the **install / build / runtime *environment*** that any DOCA program assumes has been verified before its own workflows begin. It is deliberately library-agnostic and program-agnostic; everything here is about the host the program runs on, not about the program itself.

> Lint note: this file references `/opt/mellanox/doca` and `docs.nvidia.com` paths several times. For most library skills the lint flags this and asks for cross-links to `doca-public-knowledge-map` instead, since URL/path duplication is normally drift waiting to happen. For `doca-setup` specifically the references are *intrinsic* — the skill's whole job is to operate on the install tree and verify it. The repeated paths are intentional; do not refactor them out.

## Pattern overview

Every env-class concern this skill teaches resolves into one of FIVE
patterns. Reach for the pattern first, then drill into the matching
H2 anchor; the patterns are CLASSES, not use cases.

| Pattern | When it applies (class shape)                              | Where it lives                                          |
|---------|------------------------------------------------------------|---------------------------------------------------------|
| 1. Reach an install | User has no DOCA reachable from where they are now | [TASKS.md ## no-install](TASKS.md#no-install) (NGC Path 0) |
| 2. Detect an install | User has *something* installed and must figure out what | [`## Version compatibility`](#version-compatibility) + [TASKS.md ## test](TASKS.md#test) |
| 3. Wire the build to the install | Headers / `*.pc` / `LD_LIBRARY_PATH` / build flavor | [`## Capabilities and modes`](#capabilities-and-modes) + [TASKS.md ## configure](TASKS.md#configure) |
| 4. Wire the runtime to the device | Hugepages / representors / devlink / kernel modules | [`## Observability`](#observability) + [TASKS.md ## configure](TASKS.md#configure) |
| 5. Diagnose env vs program | Symptom looks like a bug; agent must rule env out first | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two principles cut across all five patterns:

- **Env layers run in order: install → capability → runtime.** A
  hugepages question with an unreachable install is the install
  question. Skipping a layer is the single most common
  failure mode the env-debug ladder catches.
- **Env-class only.** The instant the answer becomes "rewrite the
  program", hand off to
  [`doca-programming-guide`](../doca-programming-guide/SKILL.md). The
  patterns above never tell the user to change their code.

## Capabilities and modes

DOCA install is layered into three orthogonal env axes. Pick the right combination *before* writing or building any code. Program-side selection of which mode the program initializes (host vs DPU vs switch) and which build flavor it links against is in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); this section covers what the env supports.

**Install profiles.** Determined by the package profile selected at install time (see the Installation Guide via `doca-public-knowledge-map`).

| Profile | What it pulls in | When to use |
| --- | --- | --- |
| `doca-all` | Full superset: SDK + samples + applications + tools + `doca-ofed` + `doca-networking`. | Default for any developer host, BlueField, or CI machine. Recommended for first-time setup. The public NGC DOCA container ([TASKS.md ## no-install](TASKS.md#no-install) Path 0) ships this profile. |
| `doca-ofed` | OFED userspace + kernel modules only (RDMA stack). | Constrained host that only needs the underlying RDMA stack, no DOCA libraries. Rare in a development context. |
| `doca-networking` | The DOCA networking subset (Flow, telemetry, etc.) on top of `doca-ofed`. | Constrained images that ship only the networking libraries. Most agent users will instead want `doca-all`. |

**The agent's rule:** if a sample build fails with a missing `*.pc` file (`doca-flow.pc`, `doca-rdma.pc`, …), the most likely cause is the wrong install profile, not a code bug. Surface this hypothesis before any code-level diagnosis.

**Build flavor — env side.** Two `*.so` trees ship with every DOCA install. The choice of which one a program links against is a programming decision (see [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes)); the env side is *where each tree lives on disk* and *how to make the runtime see it*.

| Flavor | On-disk location | How a program reaches it |
| --- | --- | --- |
| Release | `/opt/mellanox/doca/lib/<arch>-linux-gnu/` | Default; `pkg-config doca-<library>` resolves here. |
| Trace | `/opt/mellanox/doca/lib/<arch>-linux-gnu/trace/` | Either link with the `doca-<library>-trace` `pkg-config` module at build time, or set `LD_LIBRARY_PATH=/opt/mellanox/doca/lib/<arch>-linux-gnu/trace:$LD_LIBRARY_PATH` at runtime. |

**Runtime modes — env-side enablement.** Most DOCA libraries (Flow in particular) run in one of three host configurations. The env determines which modes are *available* on this host; the program selects one at init time.

| Mode | Env enablement check |
| --- | --- |
| Host | x86 / Arm host with BlueField visible as a SmartNIC. Confirmed by `devlink dev show` listing the BlueField PCIe device, plus PF/VF representors under `/sys/class/net/`. |
| DPU | Inside the BlueField OS itself (Arm). The env is the BlueField BFB image; confirmed by `lsb_release -a` matching the BFB release. |
| Switch | DPU-side, with the BlueField in switch (DPU) mode. Confirmed by `mlxconfig -d <pcie> q INTERNAL_CPU_MODEL` reporting `EMBEDDED_CPU(1)` and the eswitch in `switchdev` mode. |

The agent must clarify *which* mode the user expects before recommending any port-id or representor naming. Program-side mode-selection guidance is in [`doca-programming-guide`](../doca-programming-guide/SKILL.md).

## Version compatibility

For the canonical DOCA version-detection chain (`pkg-config --modversion doca-common` → `cat applications/VERSION` → `doca_caps --version` → BFB version on BlueField), the four-way match rule, NGC container semantics, the headers-win-over-docs rule, and the routing to the DOCA Compatibility Policy, see [`doca-version`](../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The env-side overlay** is responsible for making the detection chain *work* on this host before any version question can be answered:

- `PKG_CONFIG_PATH` must include `/opt/mellanox/doca/infrastructure/lib/pkgconfig` so that `pkg-config --modversion doca-<library>` resolves at all. The env-setup procedure in [`TASKS.md ## configure`](TASKS.md#configure) verifies this; partial-install diagnosis lives in [`doca-version TASKS.md ## debug`](../doca-version/TASKS.md#debug) layer 2.
- The on-disk paths the detection chain reads (`/opt/mellanox/doca/applications/VERSION`, `/opt/mellanox/doca/infrastructure/include/doca_version.h`, the `*.pc` directory) are env-side artifacts — see [`## Capabilities and modes`](#capabilities-and-modes) for the install-tree layout that places them where the chain expects.
- On the *no-install* path (NGC container, per [`TASKS.md ## no-install`](TASKS.md#no-install) Path 0), the env-side overlay is that the four-way match is *of the container tag* the user pulled; the container's headers, `*.so`, samples, and `doca_caps` are guaranteed consistent by construction. The agent must still report which path was used so the user knows which install they verified.

## Error taxonomy

Env-class errors that the agent should recognize and disambiguate before falling back to a program-internal diagnosis. The cross-library, program-side `DOCA_ERROR_*` taxonomy lives in [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../doca-programming-guide/CAPABILITIES.md#error-taxonomy); the library-specific overlays live in the matching library skills.

| Error surface | Typical message | Most-likely cause | Next step |
| --- | --- | --- | --- |
| `pkg-config` | `Package 'doca-flow' was not found` | Wrong install profile (`doca-flow.pc` is missing) **or** `PKG_CONFIG_PATH` does not include `/opt/mellanox/doca/infrastructure/lib/pkgconfig`. | Run `ls /opt/mellanox/doca/infrastructure/lib/pkgconfig/`. If `doca-flow.pc` exists, fix `PKG_CONFIG_PATH` (see [`TASKS.md ## configure`](TASKS.md#configure)). If it doesn't, reinstall with `doca-all` — or, if no install is reachable, the user should reach one via [`TASKS.md ## no-install`](TASKS.md#no-install). |
| `meson` configure | `Dependency doca-flow found: NO` | Same as above (meson uses `pkg-config` under the hood). | Same as above. |
| `meson` configure | `compiler not found` / `meson not found` | Build toolchain missing on this host (common on minimal BlueField images). | Install the appropriate `build-essential` / `meson` / `ninja-build` packages for the OS. The NGC DOCA container ships these by default. |
| Compile time | `error: unknown type name 'doca_flow_pipe_cfg'` | The header path is not on the include search path, or the headers are from an older DOCA than the library you intend to link against. | `pkg-config --cflags doca-flow` to obtain the canonical include flags; cross-check the version ([`TASKS.md ## test`](TASKS.md#test)). |
| Link time | `undefined reference to 'doca_flow_pipe_create'` | The library is not on the link line (`-ldoca_flow` missing), or the library found at link time is older than the headers. | `pkg-config --libs doca-flow`; verify `--modversion` of the package matches the headers' release. |
| Runtime | `EAL: No free 2048 kB hugepages reported` | Hugepages not mounted or insufficient. | Mount and reserve hugepages ([`TASKS.md ## configure`](TASKS.md#configure)). |
| Runtime | `Cannot find any working PCI driver` | Kernel modules for the device not loaded, or the BlueField is not in the expected mode (host vs. DPU vs. switch). | `lsmod | grep mlx5`; verify mode via `mlxconfig`. Inside an NGC container with no real NIC, this is *expected* and the right move is to graduate the user to a hardware path (Path A or Path C in [`TASKS.md ## no-install`](TASKS.md#no-install)). |
| Runtime | `representor X not found` | Representors not enabled on the PF (`devlink dev eswitch set ... mode switchdev`), or the application is asking for a representor index that doesn't exist on this hardware. | `devlink dev show`; cross-check requested index against `cat /sys/class/net/*/phys_port_name`. |
| Runtime | Application starts, exits cleanly, no traffic effect | Often a silent steering-mode mismatch (HWS expected, SWS active) or a switch-mode app run in non-switch mode. | Re-run `doca_caps`; cross-check the steering mode the application requested via library init args. |

The taxonomy above is **env-class only**. Program-internal `DOCA_ERROR_*` codes (`DOCA_ERROR_BAD_STATE`, `DOCA_ERROR_NOT_SUPPORTED`, etc.) live in [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../doca-programming-guide/CAPABILITIES.md#error-taxonomy); the library-specific overlay (e.g. Flow's mapping from API call to which `DOCA_ERROR_*` it returns) lives in the matching library skill — for Flow, see [`doca-flow CAPABILITIES.md ## Error taxonomy`](../libs/doca-flow/CAPABILITIES.md#error-taxonomy).

## Observability

What *"healthy install"* looks like under observation. The agent should run these checks (or have the user run them) **before** recommending any code-level change. Program-side observability (DOCA log levels, capability snapshots, library counters) lives in [`doca-programming-guide CAPABILITIES.md ## Observability`](../doca-programming-guide/CAPABILITIES.md#observability).

**Install layer:**

```bash
ls /opt/mellanox/doca                                  # SDK root present
ls /opt/mellanox/doca/samples                          # samples shipped
ls /opt/mellanox/doca/infrastructure/include/          # headers shipped
ls /opt/mellanox/doca/infrastructure/lib/pkgconfig/    # *.pc files shipped
pkg-config --list-all | grep -i doca                   # what the build env can find
pkg-config --modversion doca-common                    # the unified version
```

**Capability layer (DPU and Flow):**

```bash
doca_caps                                              # device capabilities snapshot
doca_caps --version                                    # runtime version
```

**Runtime layer (host or DPU):**

```bash
mount | grep huge                                      # hugepages mounted
cat /proc/meminfo | grep -i huge                       # hugepages reserved
devlink dev show                                       # devices visible
ls /sys/class/net/                                     # network interfaces
cat /sys/class/net/*/phys_port_name                    # representor names
```

The presence of all of the above (without errors or empty output where output is expected) is the precondition for *any* program-level work. The agent's investigation order on an env-class report is exactly **install → capability → runtime**, in that order — never start at the application layer when these have not been verified.

Inside the NGC DOCA container, the install and capability layers above will respond normally; the runtime layer will partially or fully report no real hardware (no hugepages mounted by default, no `devlink` devices visible, no representors). That is the expected state for the build / read / learn loop the container is for; for runtime against real hardware, the user has to graduate to a hardware path (see [`TASKS.md ## no-install`](TASKS.md#no-install) Paths A and C).

## Safety policy

DOCA install and runtime preparation are **shared system state**. Several env actions affect more than just the user's program; the agent must surface this before recommending them. The program-side safety policy (validate-before-commit, stage-first-widen-later) lives in [`doca-programming-guide CAPABILITIES.md ## Safety policy`](../doca-programming-guide/CAPABILITIES.md#safety-policy).

1. **Never modify `/opt/mellanox/doca/lib*/`.** The shipped libraries are the release; rewriting them voids the install and breaks any other DOCA application on the host. Build flavor changes go via `LD_LIBRARY_PATH` or the `-trace` `pkg-config` module, never by editing the `lib/` tree.

2. **Hugepage mounts and reservations are global.** Adding hugepages reduces memory available to the kernel and to other applications; removing or remounting hugepages while another DOCA / DPDK application is running will crash that application. Before recommending a hugepages change, ask the user whether anything else on this host is using DOCA or DPDK; if yes, do the change in coordination, not in isolation. The same applies to `mlxconfig` changes that require a reset, and to `devlink dev eswitch set ... mode switchdev`.

3. **Never auto-`reboot` or auto-power-cycle.** `mlxconfig` and BFB updates require a host reset to take effect. The agent should produce the *commands* and explain the requirement, but must not chain them with an unattended reboot — let the user confirm their environment can absorb the reboot.

4. **The NGC container is build / read / learn only — not a runtime substitute.** The public NGC DOCA container at `nvcr.io/nvidia/doca/doca` is the canonical Stage-1 path for any user on macOS, Windows, or Linux without DOCA, but it is *not* a substitute for running against real hardware. DPDK / DOCA calls that require a real NIC, real DPU, real hugepages on the host kernel, or real driver presence will fail inside the container — and that failure is correct. The agent must not recommend `--privileged` / `--device` workarounds to "make it run anyway"; the right move when the user needs runtime is to graduate them from Path 0 to Path A or Path C in [`TASKS.md ## no-install`](TASKS.md#no-install).

5. **Be explicit about what changes when the user installs DOCA.** Installing the host package modifies kernel modules (`mlx5_core`, OFED), adds udev rules, and (for `doca-all`) installs services that may auto-start. Surface this before recommending an install on a host that has other workloads.
