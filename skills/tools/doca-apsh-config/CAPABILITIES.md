# DOCA App Shield Configuration Tool — Capabilities

**Where to start:** `doca_apsh_config.py` is a host-side Python
script that produces the host-OS profile artifacts the
DPU-side [`doca-apsh`](../../libs/doca-apsh/SKILL.md) library
loads at configure time. The pattern overview below names the
recurring `doca_apsh_config`-class questions. Pick the pattern
first, then drill into the H2 that owns the substance. For the
*how* of executing each pattern, jump to [TASKS.md](TASKS.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents
*what `doca_apsh_config.py` produces*, *which host OS axes it
supports*, *which external open-source dependencies it shells
out to*, *what the profile-must-match-running-kernel invariant
is and why a stale profile fails silently*, *the rotation
policy after every host-kernel change*, *the layered error and
observability surfaces*, *and the safety posture* that gates
the profile distribution path. For step-by-step invocations
and the prepare → generate → distribute → reload workflow,
see [`TASKS.md`](TASKS.md).

## Pattern overview

Every `doca_apsh_config.py`-class question this skill teaches
resolves into one of SIX patterns. The patterns are CLASSES —
they apply across every host OS axis the tool supports, not
just one.

| `doca_apsh_config` pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pick the OS axis | The script's first decision: `--os linux` (consumes `dwarf2json` for kernel DWARF) vs `--os windows` (consumes `pdbparse-to-json.py` for PDB symbols). The two paths share the script entry point and the output-artifact shape but differ in the symbol extractor and the per-OS support set (`kpgd_file` is Linux-only). | [`## Capabilities and modes`](#capabilities-and-modes) OS-axis table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Pick the artifact set | The `--files` selection — `symbols`, `memregions`, `kpgd_file`, `hash` — driven by the apsh-class introspection use case on the DPU side, not by *"generate everything just in case"*. Generating `hash` requires a `--pid`; generating `kpgd_file` requires `--find_kpgd=1` and is Linux-only. | [`## Capabilities and modes`](#capabilities-and-modes) artifact-class table + [TASKS.md ## configure](TASKS.md#configure) step 2 |
| 3. Match profile to running kernel | The load-bearing safety invariant. The produced artifacts are valid only for the **exact** host kernel build / patch level they were generated against. A live-patch, a kernel package update, or even a build with different config knobs can move the symbol layout under the profile. The DPU-side consumer will then return wrong-symbol data or `DOCA_ERROR_NOT_FOUND` on a known-running process — and the failure is silent. | [`## Safety policy`](#safety-policy) match-rule + [TASKS.md ## modify](TASKS.md#modify) rotation flow |
| 4. Rotate on host-kernel change | The follow-on from pattern 3. Every host-kernel-touching change (kernel upgrade, security-update reboot, live-patch, distribution upgrade) requires regenerating the profile and re-distributing to every DPU side that loads it. The agent surfaces *"regenerate the profile"* as the first step whenever the user reports a regression that coincides with a host change. | [`## Safety policy`](#safety-policy) rotation cadence + [TASKS.md ## modify](TASKS.md#modify) |
| 5. Validate before fleet rollout | A freshly-generated profile is not trusted in production until it has been round-tripped against the live host on the DPU side (load on `doca_apsh_system`, enumerate a known-running process, confirm the name + PID match). | [TASKS.md ## test](TASKS.md#test) validation gate |
| 6. Distribute and atomic-swap | The artifacts live on the **host** when generated and on the **DPU** at consume time; the path between them is operator-owned. The agent prescribes the requirements (atomic swap, version-stamping, rollback artifact retained) and refuses to pin a distribution tool. | [`## Safety policy`](#safety-policy) distribution-path rule + [TASKS.md ## run](TASKS.md#run) step 4 |

Two cross-cutting rules that apply to *every* pattern above:

- **A stale profile is the canonical silent-bug failure mode.**
  An apsh-class consumer that loads a profile that does not
  match the running host kernel will not crash, throw a clear
  `DOCA_ERROR_INVALID_VALUE`, or print a banner. It will keep
  answering queries, just with wrong-symbol offsets or
  `DOCA_ERROR_NOT_FOUND` on processes that genuinely exist on
  the host. The agent's rule: when an apsh-class consumer
  reports a regression, the FIRST hypothesis is *"profile
  stale against host kernel"*, not *"DPU-side bug"*.
- **The two halves are version-paired.** The host-side
  configuration tool ships with a DOCA install; the DPU-side
  [`doca-apsh`](../../libs/doca-apsh/SKILL.md) library
  consumes the produced artifacts. The agent confirms the
  installed DOCA version on both sides is paired per
  [`doca-version`](../../doca-version/SKILL.md) before
  blaming the tool, the library, or the profile.

## Capabilities and modes

`doca_apsh_config.py` is shipped as a host-side Python 3
script under `/opt/mellanox/doca/tools/` on every DOCA install
that supports App Shield. It does not run on the DPU; the DPU
side consumes the artifacts the host generates. The interaction
model is *"the operator runs the script on the host,
distributes the produced files to the DPU side, then the
DPU-side `doca-apsh` consumer loads them at configure time"*.

**OS-axis table.** The script's first decision is the host OS
the profile is built for. The two paths share the entrypoint
and output-artifact shape but differ in the external symbol
extractor and the supported artifact set.

| OS axis | Symbol extractor | Supported `--files` artifacts | Notes |
| --- | --- | --- | --- |
| `--os linux` | `dwarf2json` from the public Volatility Foundation repository ([`https://github.com/volatilityfoundation/dwarf2json`](https://github.com/volatilityfoundation/dwarf2json)) — operator installs separately. The script invokes the binary at `--path` (defaults to `./dwarf2json` relative to the working directory). | `symbols`, `memregions`, `kpgd_file` (Linux-only, requires `--find_kpgd=1`), `hash` (per-PID, requires `--pid`). | Reads host kernel DWARF from the installed kernel image and the running `/proc` state for `memregions` / `kpgd_file` / `hash`. |
| `--os windows` | `pdbparse-to-json.py` from the public Volatility 3 repository ([`https://raw.githubusercontent.com/volatilityfoundation/volatility3/stable/development/pdbparse-to-json.py`](https://raw.githubusercontent.com/volatilityfoundation/volatility3/stable/development/pdbparse-to-json.py)) — operator downloads separately. The script also requires the `pefile` Python package; the tool itself prints the required `pefile==2022.5.30` version pin if it sees a newer version. | `symbols`, `memregions`, `hash` (per-PID). `kpgd_file` is **not** supported on Windows. | Reads PDB symbols from the host's Windows symbol cache (the operator stages them); reads per-process memory for `hash` via Windows debugging APIs. |

**Artifact-class table.** Four output artifact classes the
DPU-side consumer can load. Pick the smallest set the use case
actually needs.

| Artifact (`--files` token) | What it is | Which apsh-class use case needs it |
| --- | --- | --- |
| `symbols` | The host kernel symbol map (function / struct / type offsets) extracted by `dwarf2json` or `pdbparse`. The DPU side maps host kernel memory through this when reading kernel structures. | Every apsh-class use case. Without it, no kernel-structure read on the DPU side can be interpreted. |
| `memregions` | A descriptor of the host's kernel virtual memory layout the DPU-side library uses to translate host kernel addresses. | Every apsh-class use case that reads host kernel state (process enumeration, module enumeration, library / thread enumeration). |
| `kpgd_file` (Linux only) | The kernel page global directory anchor, used when the DPU-side consumer needs an authoritative entry point into the host kernel's page tables. Generated only when `--find_kpgd=1` is passed and `--files` includes `kpgd_file`. | Use cases that walk page tables from the DPU side; not required for plain process / module enumeration. |
| `hash` (per-PID) | A bundle of files the DPU side hashes to confirm the on-host process's executable + libraries + VDSO match an expected baseline. Generated only when `--pid <PID>` is supplied. | Process-integrity-class use cases (rootkit detection, tamper-evident enumeration). Not needed for plain enumeration. |

**External dependencies.** The script shells out to
open-source extractors maintained by the Volatility
Foundation. The agent's rule for any *"the extractor crashed /
returned an error"* report: route the user to the public
upstream repository for the extractor's own troubleshooting
guide, do not try to repair the extractor from inside this
skill.

| Dependency | Public source | Pinned by |
| --- | --- | --- |
| `dwarf2json` (Linux profiles) | [`https://github.com/volatilityfoundation/dwarf2json`](https://github.com/volatilityfoundation/dwarf2json) | Operator's host install. The script accepts `--path` to point at a non-default binary location. |
| `pdbparse-to-json.py` (Windows profiles) | [`https://raw.githubusercontent.com/volatilityfoundation/volatility3/stable/development/pdbparse-to-json.py`](https://raw.githubusercontent.com/volatilityfoundation/volatility3/stable/development/pdbparse-to-json.py) | Operator downloads and stages separately. The script accepts `--path` to point at it. |
| `pefile` Python package (Windows profiles) | Public PyPI. | Operator's Python environment; the tool prints the `pefile==2022.5.30` pin when a newer version is loaded. |
| `psutil`, `pdbparse`, `pefile` (and other Python deps) | Public PyPI. | Operator's Python environment. |

**Per-PID `hash` artifact specifics.** Generating the `hash`
bundle requires the host process to be running at the moment
of generation; the script reads `/proc/<pid>/maps` and
`/proc/<pid>/mem` (Linux) or the equivalent Windows debug
surface to collect the executable, dynamic libraries, and the
VDSO mapping. The agent's rule: if the user's apsh-class use
case is plain enumeration (processes, modules, libraries,
threads), the `hash` artifact is not needed — only request it
when the use case is integrity / tamper detection.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the
headers-win-over-docs rule, see
[`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The `doca_apsh_config`-specific overlay** is:

- **Host-side tool and DPU-side library are version-paired.**
  The configuration tool ships with a host-side DOCA install;
  the DPU-side
  [`doca-apsh`](../../libs/doca-apsh/SKILL.md) library is
  installed via the DPU-side DOCA install. The two must come
  from the same DOCA release band per the
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)
  four-way match rule, or the produced artifact's on-disk
  layout can be misread by an older / newer consumer.
- **Profile is bound to the host kernel build, not to the
  DOCA version.** Two profiles generated by the same DOCA
  version against different host kernels are NOT
  interchangeable, and two profiles generated against the same
  host kernel by different DOCA versions are NOT guaranteed
  interchangeable. The agent does not assume *"same DOCA
  version means same artifact"*; the kernel anchor is
  separate.
- **`dwarf2json` / `pdbparse` are externally versioned.** The
  extractors maintained by the Volatility Foundation evolve
  on their own schedule and are NOT versioned with DOCA. The
  agent does not pin an extractor version from memory; the
  operator's installed extractor is the source of truth, and
  any failure is routed to the upstream repository per
  [`## Capabilities and modes`](#capabilities-and-modes).
- **Public DOCA App Shield page is the source of truth for
  the tool's command-line surface.** Re-verify subcommand
  names, the `--files` token set, and the artifact filenames
  against the live guide and against `python3
  doca_apsh_config.py --help` on the installed version, not
  against this skill's prose.

## Error taxonomy

`doca_apsh_config.py`'s error surface spans the host-side
Python environment, the external extractor binaries, the
host's running kernel state, the produced artifacts, the
distribution path, and the DPU-side consumer. The agent
distinguishes these layers in escalating order; jumping
layers wastes the user's time on the wrong fix.

1. **Host-prereq.** The DOCA install on the host is missing /
   wrong version; Python 3 is missing or too old; the
   required Python packages (`pefile`, `psutil`, `pdbparse`)
   are not in the environment the script runs under; the
   script's path under `/opt/mellanox/doca/tools/` is
   unreadable. Routing: confirm DOCA is installed per
   [`doca-setup`](../../doca-setup/SKILL.md); install the
   missing Python deps per the host's package manager; do
   not patch the script.
2. **OS-axis.** `--os` was set to a value the script does not
   accept, or was omitted (the script requires `--os`); the
   chosen OS axis is unsupported for the requested artifact
   set (e.g. `kpgd_file` on `--os windows`); the host the
   script runs on does not actually match the declared `--os`
   value (Linux script run on a Windows host, or vice versa).
   Routing: re-read the OS-axis table in
   [`## Capabilities and modes`](#capabilities-and-modes);
   re-confirm `--os` matches the running host.
3. **Extractor (`dwarf2json` / `pdbparse`).** The external
   extractor binary at `--path` is missing, not executable,
   the wrong architecture, or rejects the host's kernel
   DWARF / PDB. Cause: extractor not installed; extractor
   version too old for the host kernel; the host kernel
   image is stripped of DWARF (no `-debuginfo` package
   installed); the Windows symbol cache is empty. Routing:
   route the user to the public upstream repository per
   [`## Capabilities and modes`](#capabilities-and-modes);
   do not try to fix the extractor inside this skill.
4. **Output-artifact.** The script ran but the produced
   artifact looks wrong (empty, truncated, wrong shape).
   Cause: the source data was incomplete (e.g. partial DWARF,
   missing PDB symbols, process exited mid-hash-build);
   `--pid` referenced a PID that does not exist when `hash`
   was requested; `--find_kpgd` was not set when `kpgd_file`
   was requested. Routing: re-walk
   [TASKS.md ## configure](TASKS.md#configure); re-run with
   the corrected inputs.
5. **DPU-side-load.** The artifact moved to the DPU side but
   the DPU-side [`doca-apsh`](../../libs/doca-apsh/SKILL.md)
   consumer rejects it or behaves incorrectly. Cause: the
   produced artifact's on-disk layout does not match what
   the DPU-side library expects (version pairing broken per
   [`## Version compatibility`](#version-compatibility));
   the distribution path corrupted the artifact (partial
   copy, atomic-swap not performed); the loaded profile is
   stale against the live host kernel. Routing: confirm the
   version pairing first; re-walk
   [`doca-apsh TASKS.md ## configure`](../../libs/doca-apsh/TASKS.md#configure);
   if version pairing is clean, the staleness layer is the
   most likely culprit and the rotation flow in
   [TASKS.md ## modify](TASKS.md#modify) is the next step.
6. **Version.** Cross-cutting partial-install / mixed-version
   layer per [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
   Routing: walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   end-to-end.
7. **Cross-cutting.** The cause is below DOCA — host kernel
   too new for the extractor, host kernel built without
   DWARF, distribution-path tool failure (network /
   filesystem). Routing: hand off to
   [`doca-debug ## debug`](../../doca-debug/SKILL.md) for the
   cross-cutting ladder and
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   for the host-env layers.

`doca_apsh_config.py` does NOT itself emit `DOCA_ERROR_*`
codes — it is a Python script, not a `doca_*` API call. The
`DOCA_ERROR_*` surface appears on the DPU-side consumer when
it tries to load the produced artifact; the cross-library
taxonomy is owned by
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).

## Observability

`doca_apsh_config.py`'s observability surface is **the produced
artifact files themselves**, plus the script's stdout. The
agent's rule for any *"did the run succeed?"* question:
inspect the artifacts on disk, do not infer from exit code
alone.

- **stdout.** The script prints a `creating: <set>` line at
  the start naming the artifact subset it will produce, plus
  per-step progress messages from the extractors it shells
  out to. Capture stdout for any non-trivial run; it is the
  first hint when the extractor failed silently.
- **Output files on disk.** The four artifact classes appear
  as files / directories in the working directory the script
  was invoked from. The agent's rule for validation: list the
  produced files, confirm non-zero size, confirm the file
  modification timestamp is post-script-start (the script
  may overwrite vs leave a stale artifact).
- **Host-side baseline.** The (host OS, kernel build,
  generation timestamp, DOCA version, extractor version)
  tuple is the minimum metadata to attach to a generated
  artifact for downstream reasoning. Without this, two
  profiles in a fleet drawer cannot be ranked by recency or
  attributed to a specific host class.
- **DPU-side reload signal.** After distribution, the
  DPU-side consumer's `doca_apsh_system` configure step is
  the canonical *"did this profile load cleanly?"* signal.
  Pair the host-side generation log with the DPU-side
  configure log when capturing evidence; either half alone
  is insufficient.

For the cross-cutting env-side observability primitives
(host kernel detection, `uname -r`, kernel-package
introspection), see
[`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).
For the DPU-side observability surface (`DOCA_LOG_LEVEL`,
`--sdk-log-level`), see
[`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

`doca_apsh_config.py` is a **host-side data-extraction
script** — it does not flip firmware, burn images, or touch
DPU mode. Its safety surface is instead about **the integrity
of the introspection pipeline it feeds**. The rules:

- **A stale profile is silently wrong, not loudly broken.**
  The agent surfaces the profile-vs-running-kernel match
  rule whenever the user reports an apsh-class regression
  that coincides with any host-side change; *"regenerate the
  profile"* is the FIRST hypothesis, not a last-resort
  recovery step. The DPU-side library cannot detect the
  mismatch on its own — it will keep answering queries, just
  with wrong-symbol offsets.
- **Rotate on every host-kernel-touching change.** Kernel
  upgrade, security-update reboot, live-patch, distribution
  upgrade, or rebuild with different config knobs all
  require regenerating the profile and re-distributing. The
  agent does NOT promise *"the profile is good for the next
  N days"*; the trigger is the kernel change, not a clock.
- **Validate before fleet rollout.** A freshly-generated
  profile must round-trip through the DPU-side consumer on
  at least one host before the fleet picks it up. The
  validation gate in
  [TASKS.md ## test](TASKS.md#test) is mandatory; skipping it
  is the canonical *"the new profile rolled out and all
  apsh-class consumers started lying"* failure mode.
- **Distribution-path requirements (operator owns the tool).**
  The path from host generation to DPU consumption must be
  atomic (no half-replaced profile mid-read), version-stamped
  (the DPU side knows which host profile it is loading),
  and rollback-safe (the previous profile is retained until
  the new one validates). The agent does not pin a specific
  distribution tool; it names the requirements and refuses
  any path that violates them.
- **Profiles can leak host kernel information.** The
  generated `symbols` artifact contains the host kernel's
  symbol layout; the `hash` artifact contains a per-process
  executable + library bundle. Treat these as host-sensitive
  artifacts and apply the operator's data-handling policy to
  them. Do not stage them in unsecured object storage or
  paste their contents into public chat.
- **Do not invent flags or filenames.** Subcommand strings,
  `--files` tokens, and produced artifact filenames must
  match `python3 doca_apsh_config.py --help` on the
  installed version and the public DOCA App Shield page.
  Prose-derived flags are the most common hallucination
  failure for this skill; see
  [TASKS.md ## Command appendix](TASKS.md#command-appendix).

## Public-source pointer

The canonical public source for `doca_apsh_config.py` is the
**DOCA App Shield** page on `docs.nvidia.com`, reachable
through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
The upstream symbol extractors live in the public Volatility
Foundation organisation on GitHub
([`dwarf2json`](https://github.com/volatilityfoundation/dwarf2json),
[Volatility 3](https://github.com/volatilityfoundation/volatility3));
treat them as black-box dependencies and route any
extractor-side issue to the upstream repository's own
support channel. Do not invent flags, artifact names, or
extractor versions beyond what those public sources document.
