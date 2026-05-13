# DOCA setup — capabilities, version compatibility, errors, observability, safety

Read this file when the loader sent you here from [SKILL.md](SKILL.md). For the step-by-step workflows that *use* the surface described here, see [TASKS.md](TASKS.md). For where to find official documentation, the on-disk layout of an installed DOCA package, or the official Installation Guide, route through [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

This file describes the **install / build / runtime surface** that any DOCA library skill assumes has been verified before its own workflows begin. It is deliberately library-agnostic.

> Lint note: this file references `/opt/mellanox/doca` and `docs.nvidia.com` paths several times. For most library skills the lint flags this and asks for cross-links to `doca-public-knowledge-map` instead, since URL/path duplication is normally drift waiting to happen. For `doca-setup` specifically the references are *intrinsic* — the skill's whole job is to operate on the install tree and verify it. The repeated paths are intentional; do not refactor them out.

## Capabilities and modes

DOCA install is layered into three orthogonal axes. Pick the right combination *before* writing or building any code.

**Install profiles.** Determined by the package profile selected at install time (see the Installation Guide via `doca-public-knowledge-map`).

| Profile | What it pulls in | When to use |
| --- | --- | --- |
| `doca-all` | Full superset: SDK + samples + applications + tools + `doca-ofed` + `doca-networking`. | Default for any developer host, BlueField, or CI machine. Recommended for first-time setup. |
| `doca-ofed` | OFED userspace + kernel modules only (RDMA stack). | Constrained host that only needs the underlying RDMA stack, no DOCA libraries. Rare in a development context. |
| `doca-networking` | The DOCA networking subset (Flow, telemetry, etc.) on top of `doca-ofed`. | Constrained images that ship only the networking libraries. Most agent users will instead want `doca-all`. |

**The agent's rule:** if a sample build fails with a missing `*.pc` file (`doca-flow.pc`, `doca-rdma.pc`, …), the most likely cause is the wrong install profile, not a code bug. Surface this hypothesis before any code-level diagnosis.

**Build flavors.** The `pkg-config` module name selects which library variant your build links against.

| `pkg-config` module | Variant | When to use |
| --- | --- | --- |
| `doca-<lib>` (e.g. `doca-flow`) | Release. Optimized, no extra sanitation. | Production and benchmarking. |
| `doca-<lib>-trace` (e.g. `doca-flow-trace`) | Trace build. Enables additional input sanitation, slower, much louder logs. | **First app development.** First-time-user errors are caught earlier. Switch to release once the app stabilizes. |

The `-trace` variant lives at `/opt/mellanox/doca/lib/<arch>-linux-gnu/trace/`. Either link with the trace `pkg-config` module at build time, or set `LD_LIBRARY_PATH` to the trace directory at runtime.

**Runtime modes.** Most DOCA libraries (Flow in particular) run in one of three host configurations. The mode is selected by the application at init time, not by the install.

| Mode | Where the application runs | Which ports the app sees |
| --- | --- | --- |
| Host | x86 / Arm host with BlueField as a SmartNIC | Physical ports of the BlueField from the host's view, via PF/VF representors. |
| DPU | Inside the BlueField OS itself (Arm). | Local network interfaces and (in switch mode) representors of the host's PF/VF. |
| Switch | DPU-side, with the BlueField in switch (DPU) mode. | The unified switch-manager port; representors of host PFs/VFs and uplinks. *Library-imposed constraint:* in switch mode the application must not call DPDK `rte_eth_dev_*` configure/start on representors — Flow takes them over. |

The agent must clarify *which* of these the user is in before recommending any port-id or representor naming. The `devlink dev show` output (host-side) and the contents of `/sys/class/net/` are the primary cues.

## Version compatibility

DOCA uses a single unified version string across host packages, BlueField BFB image, headers, and the libraries the application links against. **All four must match within a release.** Cross-version mixing is the single most common source of "the program built but does nothing on the wire" reports for first-time users.

**Detect the installed version, in this order of preference:**

1. `pkg-config --modversion doca-common` — the build-time version. This is what your application will link against. The agent should always quote *this* version when answering API-availability questions.
2. `cat /opt/mellanox/doca/applications/VERSION` — fallback if `pkg-config` is missing or `PKG_CONFIG_PATH` is not configured (which itself is a setup problem the agent should fix first; see `TASKS.md ## configure`).
3. `doca_caps --version` — the runtime view; should match #1. A mismatch between #1 and #3 means headers and the runtime library on disk are from different DOCA installs (e.g. partial upgrade). The fix is to reinstall consistently — not a code change.

**On a BlueField host specifically**, the BFB image carries its own DOCA version. If the host package is at version *X* and the BlueField BFB is at version *Y* with *X ≠ Y*, communication paths that span the two (control channel, RDMA across PCIe) can fail in confusing ways. Verify with `mlxprivhost` or `bfb-info` (Installation Guide section "Verifying the BFB image" via `doca-public-knowledge-map`).

**Headers vs. runtime.** The headers under `/opt/mellanox/doca/infrastructure/include/` are the *authoritative* statement of what API symbols exist on this release. If a public web page mentions a symbol and the header does not, the header wins — it is the release; the web page describes a release.

## Error taxonomy

Setup-class errors that the agent should recognize and disambiguate before falling back to a library-internal diagnosis.

| Error surface | Typical message | Most-likely cause | Next step |
| --- | --- | --- | --- |
| `pkg-config` | `Package 'doca-flow' was not found` | Wrong install profile (`doca-flow.pc` is missing) **or** `PKG_CONFIG_PATH` does not include `/opt/mellanox/doca/infrastructure/lib/pkgconfig`. | Run `ls /opt/mellanox/doca/infrastructure/lib/pkgconfig/`. If `doca-flow.pc` exists, fix `PKG_CONFIG_PATH` (see `TASKS.md ## configure`). If it doesn't, reinstall with `doca-all`. |
| `meson` configure | `Dependency doca-flow found: NO` | Same as above (meson uses `pkg-config` under the hood). | Same as above. |
| `meson` configure | `compiler not found` / `meson not found` | Build toolchain missing on this host (common on minimal BlueField images). | Install the appropriate `build-essential` / `meson` / `ninja-build` packages for the OS. |
| Compile time | `error: unknown type name 'doca_flow_pipe_cfg'` | The header path is not on the include search path, or the headers are from an older DOCA than the library you intend to link against. | `pkg-config --cflags doca-flow` to obtain the canonical include flags; cross-check the version (`TASKS.md ## test`). |
| Link time | `undefined reference to 'doca_flow_pipe_create'` | The library is not on the link line (`-ldoca_flow` missing), or the library found at link time is older than the headers. | `pkg-config --libs doca-flow`; verify `--modversion` of the package matches the headers' release. |
| Runtime | `EAL: No free 2048 kB hugepages reported` | Hugepages not mounted or insufficient. | Mount and reserve hugepages (`TASKS.md ## configure`). |
| Runtime | `Cannot find any working PCI driver` | Kernel modules for the device not loaded, or the BlueField is not in the expected mode (host vs. DPU vs. switch). | `lsmod | grep mlx5`; verify mode via `mlxconfig`. |
| Runtime | `representor X not found` | Representors not enabled on the PF (`devlink dev eswitch set ... mode switchdev`), or the application is asking for a representor index that doesn't exist on this hardware. | `devlink dev show`; cross-check requested index against `cat /sys/class/net/*/phys_port_name`. |
| Runtime | Application starts, exits cleanly, no traffic effect | Often a silent steering-mode mismatch (HWS expected, SWS active) or a switch-mode app run in non-switch mode. | Re-run `doca_caps`; cross-check the steering mode the application requested via library init args. |

The taxonomy above is **setup-class only**. Library-internal `DOCA_ERROR_*` codes (`DOCA_ERROR_BAD_STATE`, `DOCA_ERROR_NOT_SUPPORTED`, etc.) live in the relevant library skill — for Flow, see [`doca-flow CAPABILITIES.md ## Error taxonomy`](../doca-flow/CAPABILITIES.md#error-taxonomy).

## Observability

What "healthy install" looks like under observation. The agent should run these checks (or have the user run them) **before** recommending any code-level change.

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

The presence of all of the above (without errors or empty output where output is expected) is the precondition for *any* library-level work. The agent's investigation order on a setup-class report is exactly **install → capability → runtime**, in that order — never start at the application layer when these have not been verified.

## Safety policy

DOCA install and runtime preparation are **shared system state**. Several setup actions affect more than just the user's program; the agent must surface this before recommending them.

1. **Never modify `/opt/mellanox/doca/lib*/`.** The shipped libraries are the release; rewriting them voids the install and breaks any other DOCA application on the host. Build flavor changes go via `LD_LIBRARY_PATH` or the `-trace` `pkg-config` module, never by editing the `lib/` tree.

2. **Hugepage mounts and reservations are global.** Adding hugepages reduces memory available to the kernel and to other applications; removing or remounting hugepages while another DOCA / DPDK application is running will crash that application. Before recommending a hugepages change, ask the user whether anything else on this host is using DOCA or DPDK; if yes, do the change in coordination, not in isolation. The same applies to `mlxconfig` changes that require a reset, and to `devlink dev eswitch set ... mode switchdev`.

3. **Never auto-`reboot` or auto-power-cycle.** `mlxconfig` and BFB updates require a host reset to take effect. The agent should produce the *commands* and explain the requirement, but must not chain them with an unattended reboot — let the user confirm their environment can absorb the reboot.

4. **Stage every first run on one representor, with controlled traffic.** The generic `## modify ## first-app derivation` workflow in [TASKS.md](TASKS.md) requires a single representor, in a controlled traffic loop, before any wider deployment. This is non-negotiable for hardware-programming libraries (Flow) and a strong convention for everything else; misprogrammed steering can take a link offline. The library skill (e.g. [`doca-flow CAPABILITIES.md ## Safety policy`](../doca-flow/CAPABILITIES.md#safety-policy)) extends this with library-specific hardware-commit gates.

5. **Trace builds are for development, not production.** The `-trace` variant adds runtime sanitation that is invaluable while learning the API surface but introduces measurable overhead. Make the switch to the release variant a deliberate, documented step before any performance reading is taken seriously.
