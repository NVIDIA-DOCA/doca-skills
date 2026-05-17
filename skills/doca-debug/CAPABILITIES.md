# DOCA debug — capabilities, version compatibility, errors, observability, safety

Read this file when the loader sent you here from [SKILL.md](SKILL.md). For the step-by-step workflows that *use* the surface described here, see [TASKS.md](TASKS.md). For env-class equivalents (install / build prerequisites, env-class errors, env observability), see [`doca-setup`](../doca-setup/SKILL.md). For program-class equivalents (the cross-library `DOCA_ERROR_*` taxonomy, `doca_error_get_descr()`, the universal lifecycle), see [`doca-programming-guide`](../doca-programming-guide/SKILL.md). For where to find official documentation or the on-disk install layout, route through [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

This file describes the **shape of every DOCA debug surface** — which kinds of debug exist, which version of DOCA exposes which surface, how DOCA reports errors that the agent must interpret, what DOCA emits that the agent can observe, and what safety constraints the agent must respect *while* debugging. Library-specific overlays (Flow pipe traces, RDMA queue-pair stats, Comch channel statistics, etc.) live in the matching library skill; this file is the cross-cutting reference they all build on.

## Capabilities and modes

DOCA debug is **layered**. Each layer has its own surface, its own tools, and its own kind of evidence. The agent must identify which layer the symptom belongs to *before* recommending any tool — running `gdb` on a process that won't link, or reading `dmesg` for a `pkg-config` failure, wastes the user's time and obscures the real problem.

| Layer | What goes wrong here | First evidence to capture | Owning skill |
| --- | --- | --- | --- |
| **Install** | Package missing, package incomplete, wrong arch, partial upgrade. | `dpkg -l` (Debian/Ubuntu) or `rpm -qa` (RHEL/Rocky) for `doca-*` packages; `ls /opt/mellanox/doca` for tree presence. | [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) layers 1–2. |
| **Version** | Host-package version, BFB version, header version, runtime `*.so` version not aligned. | `pkg-config --modversion doca-common`, `cat /opt/mellanox/doca/applications/VERSION`, `doca_caps --version`. All three should agree. | [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) layer 3 + [`doca-public-knowledge-map ## Where to find the version`](../doca-public-knowledge-map/SKILL.md#where-to-find-the-version). |
| **Build** | `pkg-config` cannot find module, header not found, missing experimental-API flag. | `pkg-config --list-all \| grep doca`, the failing compile command, the exact error string. | [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) layer 4 + [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build). |
| **Link** | `undefined reference to doca_*`, missing `-l` flag for one of DOCA's split libraries (Flow ships as 5 separate `*.so`s on recent versions). | `pkg-config --libs doca-<library>`, `ldd` of the failing binary if it produced one. | This skill — see *Link-time debug* in `TASKS.md ## debug`. |
| **Runtime** | Program runs but does nothing on the wire, or returns `DOCA_ERROR_*` from a runtime call. | `--sdk-log-level 70` (TRACE) + the trace build flavor; per-library inspector tools (`doca-flow-inspector`, `doca-flow-tune`, etc.). | This skill — see *Runtime debug* in `TASKS.md ## debug`. Library-specific overlays in matching library skill. |
| **Program** | Lifecycle out of order (e.g. `start` before `init`), `DOCA_ERROR_BAD_STATE` returned, validate-before-commit skipped. | `doca_error_get_descr(err)` quoted verbatim from the program's logs; the actual call sequence. | [`doca-programming-guide ## debug`](../doca-programming-guide/TASKS.md#debug). |
| **Driver / firmware** | `DOCA_ERROR_DRIVER` returned. The layer below DOCA reported failure. | `dmesg \| tail` (kernel-side), `mlxconfig -d <pci> q` (firmware capability snapshot), `devlink dev show`. | [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) layer 5 — DOCA cannot fix what the driver below it reports. |

The agent's rule: **always start at the lowest layer the symptom is consistent with, not the highest**. Most "first DOCA app" failures are install / version / build problems wearing the costume of a runtime error. A bad `pkg-config` returns a successful binary that fails to link; a header from one DOCA version compiled against a runtime from another version returns `DOCA_ERROR_INVALID_VALUE` from a call that should never fail.

**Read-only debug before state-changing debug.** Every layer above has at least one read-only entry point: `doca_caps --list-devs` (no side effects), `pkg-config --modversion doca-common` (no side effects), `cat /proc/meminfo | grep Huge` (no side effects), `ip link show` (no side effects). State-changing actions — `gdb` attach (pauses the process), reloading kernel modules, modifying eswitch mode — must come *after* the read-only picture is captured. Capture first, then mutate.

**Container vs native runtime.** Inside the NGC DOCA container ([`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install) Path 0), debug is constrained: the container can introspect its own process tree, its own logs, its own DOCA install — but it cannot read host kernel state (`dmesg` shows the container's view, which is empty for hardware events on the host) and it cannot see the host's network devices unless explicitly mapped in. For runtime symptoms involving real packets / real hardware, the user must move to a native install (Path B/C) or pass the failing program's state out of the container; debugging a Flow pipe in the container is build/link only.

## Version compatibility

Debug tooling in DOCA is **versioned**. A capability the agent expects to be there may not exist on the user's installed train. Always quote the user's installed `pkg-config --modversion doca-common` (or `doca_caps --version` if installed) before recommending any version-specific tool.

| Debug surface | First DOCA version it shipped in | Verification |
| --- | --- | --- |
| `doca_caps` CLI (capability snapshot, side-effect-free) | DOCA 2.6.0. | `which doca_caps` and `doca_caps --version`. Older trains: capability discovery had to go through the per-library API. See [`doca-caps`](../tools/doca-caps/SKILL.md). |
| `doca-flow-trace` `pkg-config` module (trace build flavor of Flow) | Available across recent DOCA trains; the runtime location of the trace `*.so` is documented in [`doca-setup CAPABILITIES.md ## Capabilities and modes`](../doca-setup/CAPABILITIES.md#capabilities-and-modes). | `pkg-config --exists doca-flow-trace`. Per-library trace flavors follow the same `doca-<library>-trace` pattern when they exist. |
| `doca-flow-inspector` service / tool (Flow-specific debug surface) | Documented per the public Flow Inspector Service guide. Availability per train: verify on the user's install before assuming. | Listed in [`doca-public-knowledge-map ## DOCA services`](../doca-public-knowledge-map/SKILL.md#doca-services). |
| `doca-flow-tune` tool (Flow visibility / analysis) | Alpha at the time of the public guide; may rev. | Listed in [`doca-public-knowledge-map ## DOCA tools`](../doca-public-knowledge-map/SKILL.md#doca-tools); verify on the user's install with `which doca-flow-tune` (or whatever the binary name is on their train). |
| `doca-bench` (performance evaluation) | Listed in the public DOCA tools index. | See [`doca-public-knowledge-map ## DOCA tools`](../doca-public-knowledge-map/SKILL.md#doca-tools). |
| `DOCA_VERSION_MAJOR / MINOR / PATCH` macros (in `doca_version.h`) | Header has been part of the public surface across recent trains. Use these macros in user code rather than parsing version strings. | `grep -RH 'DOCA_VERSION_' /opt/mellanox/doca/infrastructure/include/` to confirm presence on the user's install. |

The agent's rule: **the version string is descriptive, not predictive**. Do not infer downstream patch lineage from the shape of a version string (e.g. *"3.3.0 must be newer than 3.1.0-LTS"* — LTS trains backport bug fixes on their own cadence and may release later than a numerically-higher GA). Always check the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html) (cross-link via [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md)) when the user is mixing GA and LTS trains.

## Error taxonomy

The cross-library `DOCA_ERROR_*` taxonomy is **owned** by [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../doca-programming-guide/CAPABILITIES.md#error-taxonomy). This skill does not redefine it; it only adds the *debug-side framing* the agent needs when interpreting an error from logs.

Three rules every debug session must follow:

1. **Quote `doca_error_get_descr(err)` verbatim.** Every DOCA library exposes this function. Its return is the library's own canonical statement of what went wrong; never paraphrase it from memory or invent a description from the error name. If the user's program does not log the descriptor, instrument it (see [`doca-programming-guide ## modify`](../doca-programming-guide/TASKS.md#modify) for how to add diagnostics to a sample) before forming any hypothesis.

2. **Map the error family to the right debug layer.** A `DOCA_ERROR_INVALID_VALUE` is a *program* bug (wrong argument); a `DOCA_ERROR_BAD_STATE` is a *lifecycle* bug (wrong call order); a `DOCA_ERROR_NOT_SUPPORTED` is a *capability* bug (this hardware/firmware can't); a `DOCA_ERROR_DRIVER` is a *layer-below-DOCA* bug. The taxonomy in `doca-programming-guide CAPABILITIES.md ## Error taxonomy` names which family routes to which layer; this skill's `## debug` ladder consumes that mapping.

3. **Never paper over an error with a retry loop.** `DOCA_ERROR_TIME_OUT` may genuinely be timing-related, but `DOCA_ERROR_INVALID_VALUE`, `DOCA_ERROR_BAD_STATE`, `DOCA_ERROR_NOT_SUPPORTED`, `DOCA_ERROR_INITIALIZATION`, and `DOCA_ERROR_DRIVER` will not become success on retry. Retrying these masks the bug and produces logs that are harder to debug than the original failure.

The env-class error surface (missing `*.pc`, hugepages not mounted, representor not visible) is **separate** and lives in [`doca-setup CAPABILITIES.md ## Error taxonomy`](../doca-setup/CAPABILITIES.md#error-taxonomy). The debug ladder always starts at the env layer; do not begin program-side debug until the env-side errors are clear.

## Observability

DOCA emits a fixed observability surface that every library inherits and every library can extend. The agent's job in any debug session is to *turn the surface up* before forming hypotheses — most "I can't see what's happening" symptoms are a default log level too low, not an actual missing surface.

**The cross-library logging surface.** DOCA libraries log via the `doca_log_register_*` API and emit to `stderr` by default. The verbosity is controlled by *one* of:

- The CLI flag `--sdk-log-level <level>` on any DOCA tool / sample / application that accepts it.
- The environment variable `DOCA_LOG_LEVEL` for programs that read it (verify in the program; not all do).
- The programmatic call `doca_log_backend_set_sdk_level(<level>)` from inside the program.

Log levels (numeric, on the public Programming Guide):

- `30` = `DOCA_LOG_LEVEL_INFO` — quiet, production default.
- `50` = `DOCA_LOG_LEVEL_DEBUG` — useful debug detail.
- `70` = `DOCA_LOG_LEVEL_TRACE` — every call traced; the right setting for any *first run of any new code path* and for any debug session whose first hypothesis is "I don't see enough."

For a side-effect-free smoke-test entry point (when the agent wants to confirm DOCA is *callable* without doing anything visible), prefer `doca_log_*` over a real lifecycle call. Logging initialization is harmless and exercises the library binding without touching hardware.

**The trace build flavor.** Linking a library against `pkg-config doca-<library>-trace` (instead of `doca-<library>`) selects the trace flavor of that library, which adds runtime input-sanitation and emits additional log lines at `DEBUG` / `TRACE` level. The release flavor does not emit those lines no matter how high you set `--sdk-log-level`, because the additional checks aren't compiled in. Use the trace flavor during development and any debug session; switch to release for performance measurements (see [`## Safety policy`](#safety-policy)).

**Capability snapshots.** `doca_caps` (the CLI tool, see [`doca-caps`](../tools/doca-caps/SKILL.md)) is a side-effect-free snapshot of "what DOCA sees on this host right now." Capture it at the start of any debug session — capabilities can change between runs (firmware reflash, eswitch mode change, kernel-module reload), and a stale capability picture is a leading cause of *"it worked yesterday."*

**Library-specific surfaces.** Pipe counters (Flow), queue-pair statistics (RDMA), channel send/recv counters (Comch), tracing dumps (per library), and inspector tools (`doca-flow-inspector`, `doca-flow-tune`) are owned by the matching library skill. The library skill names the call (e.g. `doca_flow_pipe_query`) and the right cadence to query it.

**Standard Linux observability the agent can reach for alongside DOCA.** Read-only and always available on a healthy install:

- `dmesg | tail -100` — kernel-side device events, `mlx5_core` driver messages, link state changes.
- `journalctl -u <service> -e` — for DOCA services (DMS, DTS, etc.) running under SystemD.
- `ip link show`, `ip addr show`, `ethtool <iface>`, `devlink dev show` — interface and device visibility.
- `cat /proc/meminfo | grep Huge`, `mount | grep huge` — hugepage state.
- `ldd /path/to/binary`, `nm -D /opt/mellanox/doca/lib*/libdoca_<lib>.so` — link-layer introspection.
- `lsmod | grep mlx`, `modinfo mlx5_core` — kernel-module state.
- `strace -e trace=openat -f <command>` — what files the program is trying to open (catches missing-config-file failures fast).

**Service log paths.** DOCA services configure their own log destinations (not always `stderr`). Check `/var/log/doca*`, `/var/log/syslog`, or the service's own README before assuming output is missing.

## Safety policy

Debug actions can themselves change the system. The agent must distinguish read-only debug from state-changing debug, and follow a *capture-first, mutate-second* discipline.

1. **Always capture state before mutating it.** Before changing a log level, attaching `gdb`, reloading a kernel module, or modifying any environment, run the read-only snapshot first: `doca_caps --list-devs`, `pkg-config --modversion doca-common`, `dmesg | tail -100`, `mount | grep huge`, `ip link show`. Save the output. Mutation is allowed *after* this snapshot exists, never before.

2. **Do not modify the install tree (`/opt/mellanox/doca/lib*/`) during debug.** It is the release. Build flavor changes go via `LD_LIBRARY_PATH` or the `-trace` `pkg-config` module, never by editing `lib/`. If you find yourself wanting to patch a `.so` to debug it, stop — the symptom is not in the `.so` (which is the same binary every other DOCA user has); it's in the program's interaction with it.

3. **`gdb` attach pauses the process.** A debugger that stops at a breakpoint can starve a watchdog, miss a heartbeat, drop a network connection, or confuse a peer that expects timely responses. For server-class workloads, prefer non-pausing observability (logs, traces, counters) and reach for `gdb` only when those are exhausted. For client-class workloads, attaching is fine; just be aware the wall-clock view will lie.

4. **The trace build flavor has measurable overhead.** It is invaluable while learning the API surface and during any active debug session, but it adds runtime cost that distorts performance measurements. Switch back to the release flavor (`pkg-config doca-<library>` without the `-trace` suffix) before any performance reading is taken seriously, and document the switch.

5. **Core dumps may contain sensitive payload data.** A `gcore` or post-crash dump from a DOCA program processing real traffic includes packet contents in the program's memory. Treat dumps as confidential by default; do not paste them into public forum posts without redaction.

6. **Container debug cannot see the host kernel.** Inside the NGC DOCA container, `dmesg`, `journalctl`, and any `/sys` introspection of physical devices return the container's view, not the host's. If the symptom is "the device disappears" or "the interface drops", debugging from inside the container will mislead. Reach a host shell (or use the container's host-side companion tooling, where the user has it) before forming hypotheses about hardware events.

7. **Env mutations are global.** Hugepage changes, eswitch mode changes, `mlxconfig` resets, BFB updates — all are *global system state* and may affect other users / other tenants on the same machine. The env-side rules in [`doca-setup CAPABILITIES.md ## Safety policy`](../doca-setup/CAPABILITIES.md#safety-policy) bind every debug session; no debug action overrides them. If the user *must* change global state to reproduce a symptom, document the change, capture the before/after, and revert as soon as the reproduction is complete.

8. **Public forum posts must respect the public-sources contract.** The DOCA Developer Forum (<https://forums.developer.nvidia.com/c/infrastructure/doca/370>) is the right escalation channel when the bundle's debug ladder runs out. When helping the user file a forum post, ensure the post does not include internal NVIDIA hostnames, internal package mirror URLs, internal build numbers, or anything that contradicts ground rule #1 in [`AGENTS.md`](../../AGENTS.md). Customer-facing public artifacts only.
