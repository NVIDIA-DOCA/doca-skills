# DOCA App Shield Configuration Tool — Tasks

**Where to start:** The verbs that carry real workflow content
are `## install` (host-side prerequisites + extractor
dependency), `## configure` (axis decisions), `## run` (the
generation flow), `## test` (validation against the live host
before fleet rollout), `## debug` (layered diagnosis), and
`## use` (DPU-side consumption of the produced artifacts). The
two routing-stub verbs (`build`, `modify`) are kept because the
agent's task-verb contract is uniform across the bundle, and
each carries a meaningful pointer to where the user's question
actually belongs.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent
through the documented invocations of `doca_apsh_config.py`,
the prepare → generate → distribute → reload workflow, and the
DPU-side hand-off to the
[`doca-apsh`](../../libs/doca-apsh/SKILL.md) consumer.

## install

`doca_apsh_config.py` is shipped pre-installed under
`/opt/mellanox/doca/tools/` on every DOCA install that
supports App Shield. The host-side prerequisites the operator
must add separately:

1. **Confirm the host-side DOCA install.** The script lives
   in the host-side DOCA install layout; if `/opt/mellanox/
   doca/tools/doca_apsh_config.py` is missing, the App
   Shield optional component is not installed on this host.
   Route to [`doca-setup ## install`](../../doca-setup/TASKS.md#configure)
   to install or repair the host-side DOCA package selection;
   confirm the installed version per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
2. **Install Python 3 and the script's Python dependencies.**
   The script imports `psutil`, `pdbparse`, `pefile`, and
   standard-library modules. Install Python 3 from the host
   distribution's package manager; install the third-party
   modules from PyPI. The script prints a hard error if it
   sees `pefile` newer than `2022.5.30` on the Windows path;
   the agent treats the printed version-pin message as the
   authoritative source, not this skill's prose.
3. **Install the symbol extractor for the chosen OS axis.**
    - **Linux:** download and build `dwarf2json` from the
      public Volatility Foundation repository at
      [`https://github.com/volatilityfoundation/dwarf2json`](https://github.com/volatilityfoundation/dwarf2json).
      Stage the resulting binary somewhere the operator
      controls; pass `--path <binary-path>` to the script,
      or place it as `./dwarf2json` relative to the
      script's working directory (the script's default).
    - **Windows:** download `pdbparse-to-json.py` from the
      public Volatility 3 repository at
      [`https://raw.githubusercontent.com/volatilityfoundation/volatility3/stable/development/pdbparse-to-json.py`](https://raw.githubusercontent.com/volatilityfoundation/volatility3/stable/development/pdbparse-to-json.py)
      and stage it locally; pass `--path <script-path>` to
      the configuration tool. Stage the host's PDB symbol
      cache separately per the upstream Windows debugging
      symbols workflow.
4. **Confirm the host kernel exposes its symbol surface.**
   On Linux, the host must have its `-debuginfo` /
   `-dbgsym` kernel package (or an equivalent uncompressed
   `vmlinux` with DWARF) installed; `dwarf2json` cannot
   extract symbols from a stripped kernel. On Windows, the
   PDB symbols for the running kernel build must be
   resolvable through the operator's symbol cache.
5. **Confirm the operator has the host-side privileges the
   script's chosen artifact set requires.** Reading per-PID
   `/proc/<pid>/mem` for the `hash` artifact typically
   requires elevated privileges; reading the kernel image
   for `symbols` requires read access to the kernel image
   path; the `kpgd_file` artifact on Linux requires kernel-
   memory read access. The DPU-side
   [`doca-apsh`](../../libs/doca-apsh/SKILL.md) library has
   its own DPU-side privilege story (sudo, symbol map
   loaded) — keep the two sides distinct in the operator's
   runbook.

The script itself is not built from source by external
users; if the script is missing or corrupted, the fix is to
re-install the host-side DOCA package, not to patch the
file in place.

## configure

The script's *configuration* is the invocation: there is no
config file, no daemon, no env knob the public guide
documents as required. What the agent must configure is the
artifact set and the OS axis. Steps the agent walks the user
through, in order:

1. **Axis 1 — pick `--os`.** Required. `--os linux` or
   `--os windows`. The wrong choice is rejected by the
   script at parse time and is the most common
   misconfiguration. Re-confirm against the host the script
   will actually run on (Linux script run on a Windows host
   reads the wrong files; vice versa for Windows). Cross-
   check against the OS-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
2. **Axis 2 — pick `--files`.** Default is the full set for
   the chosen OS. Pick the smallest subset the DPU-side
   apsh-class use case needs per the artifact-class table
   in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes):
    - Plain process / module / library / thread enumeration:
      `symbols` + `memregions`.
    - Process-integrity / tamper detection: add `hash`
      (requires `--pid`).
    - Page-table walking from the DPU side: add `kpgd_file`
      (Linux only, requires `--find_kpgd=1`).
3. **If `hash` is in `--files`, supply `--pid <PID>`.** The
   PID must reference a process that is running on the host
   at the moment the script runs; the script reads the
   process's memory map and copies its binaries / libraries
   / VDSO. The script prints a guardrail message and skips
   `hash` if `--pid` is 0 or omitted.
4. **If `kpgd_file` is in `--files` (Linux only), supply
   `--find_kpgd=1`.** The script prints a guardrail message
   and removes `kpgd_file` from the artifact set if
   `--find_kpgd=0`.
5. **Point `--path` at the chosen extractor.** Defaults
   assume `./dwarf2json` (Linux) or `./pdbparse-to-json.py`
   (Windows) in the working directory; override when the
   operator stages them elsewhere. The script does NOT
   include the extractor in PATH discovery; the operator
   either uses the default relative path or names it
   explicitly.
6. **Stage the working directory.** The script writes its
   output files to the current working directory (and
   subdirectories like `apsh_client_build_hash/`). Pick a
   directory the operator owns and that the distribution
   path can pick up from.

For the canonical DOCA universal lifecycle on the DPU-side
consumer this artifact feeds, see
[`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure)
and
[`doca-apsh TASKS.md ## configure`](../../libs/doca-apsh/TASKS.md#configure).
This skill is concerned with the *operator-side* configuration
of the host-side tool.

## build

`doca_apsh_config.py` is **shipped pre-installed** as part of
every host-side DOCA install that includes the App Shield
optional component. There is no source tree the external user
is expected to compile, no build flags, no `meson` or `make`
workflow for the script itself. The external dependencies
(`dwarf2json` for Linux, `pdbparse-to-json.py` for Windows)
have their own upstream build / install instructions.

Routing for nearby "build" questions:

- *"The script isn't there — do I need to build it?"* → no.
  Route to
  [`doca-setup ## install`](../../doca-setup/TASKS.md#configure)
  to install the host-side DOCA package selection that
  includes App Shield, or to confirm the install per
  [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
- *"I want to build `dwarf2json` myself."* → upstream task;
  follow the public Volatility Foundation
  [`dwarf2json` repository's](https://github.com/volatilityfoundation/dwarf2json)
  build instructions. Not in this skill's scope.
- *"I want to build my own DPU-side `doca-apsh` consumer."* →
  not a `doca_apsh_config.py` question. Route to
  [`doca-apsh TASKS.md ## build`](../../libs/doca-apsh/TASKS.md#build)
  for the library-side build pattern.

The `## What this skill deliberately does not ship` block in
[`SKILL.md`](SKILL.md) explicitly forbids adding a build
recipe for `doca_apsh_config.py`; revisit that policy before
changing this section.

## modify

**Do not modify the shipped `doca_apsh_config.py` script.** It
is an NVIDIA-shipped Python file; there is no documented
public way to extend it for external users, and patching it
in place breaks the version-pairing rule in
[`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
silently.

What the agent *does* modify, every time, is the **profile
rotation pipeline** — the operator's process for regenerating
profiles when the host kernel changes. The rotation flow:

1. **Detect the trigger.** Any of: host kernel upgrade,
   kernel security update + reboot, kernel live-patch,
   distribution upgrade, kernel rebuild with different config
   knobs. The operator's host-state-change pipeline is the
   right place to detect this; the configuration tool itself
   does not detect.
2. **Regenerate.** Re-run the script with the same
   `--os` / `--files` / `--path` selection that was used to
   produce the previous profile. The artifact set is the
   same; the artifacts are not.
3. **Validate.** Round-trip per
   [`## test`](#test) on at least one representative DPU
   before any other DPU picks up the new profile.
4. **Distribute and atomic-swap.** Move the validated
   artifacts to every consumer DPU with the
   distribution-path requirements in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   (atomic, version-stamped, rollback-safe). Retain the
   previous profile until at least one full DPU-side
   reload cycle has completed cleanly on the new one.
5. **Roll back if validation fails.** Restore the previous
   profile; do NOT leave the fleet on a half-rotated state.

Routing for nearby "modify" questions:

- *"I want to extend the script with a new artifact class."*
  → out of scope; this skill is for external operators
  consuming the shipped tool, not contributors extending it.
- *"I want to change the produced artifact format so my
  consumer is easier to write."* → not supported; the
  consumer is [`doca-apsh`](../../libs/doca-apsh/SKILL.md)
  and the artifact shape is owned by the matched DPU-side
  library version.
- *"I want to wrap the script in a higher-level rotation
  tool."* → operator-owned automation. The skill names the
  requirements the wrapper must satisfy (atomicity,
  version-stamping, rollback) and refuses to pin a wrapper.

## run

The host-side generation flow — every profile run goes
through it, no exceptions. The full invocation surface lives
in the public DOCA App Shield page; this section names the
*shape* of the flow, not verbatim command lines (per
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
*"do not invent flags"*).

1. **Confirm prerequisites.** Per [`## install`](#install):
   DOCA host-side install present at a known version,
   Python deps installed, the chosen OS-axis extractor
   present at a known version.
2. **Configure the axes.** Per [`## configure`](#configure):
   `--os`, `--files` (smallest subset for the use case),
   `--pid` if `hash` is requested, `--find_kpgd=1` if
   `kpgd_file` is requested.
3. **Run the script.** `python3
   /opt/mellanox/doca/tools/doca_apsh_config.py --os <axis>
   --files <subset> ...`. The script prints a `creating:
   <set>` line at the start naming the artifact subset; the
   agent captures stdout for the run.
4. **Inspect the produced artifacts on disk.** Per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability):
   confirm each requested artifact file / directory exists,
   has non-zero size, and has a modification timestamp
   post-script-start. Attach the (host OS, kernel build,
   timestamp, DOCA version, extractor version) tuple as
   metadata.
5. **Stage for distribution.** Move the artifacts to the
   operator's distribution staging location; do NOT push to
   the consumer DPUs until [`## test`](#test) has passed on
   at least one representative DPU.
6. **Distribute (after validation).** Push to the consumer
   DPUs via the operator's documented atomic-swap path per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).

When recording the run for downstream consumers (the
*baseline* pattern), write down: the host OS axis, the
host kernel build (`uname -r` for Linux; build number for
Windows), the artifact set requested, the DOCA version on
the host, the extractor version, the script's full stdout
output, and a SHA of each produced artifact. The downstream
[`## test`](#test) and [`## debug`](#debug) workflows depend
on those fields.

## test

`doca_apsh_config.py` produces artifacts that the DPU-side
consumer loads at configure time; *testing* the produced
profile means *round-tripping* it through the consumer
against the live host before letting the fleet rely on it.

**Validation gate (mandatory before fleet rollout).**

1. **Pick a representative DPU.** It must be paired with a
   host whose kernel matches the host the profile was
   generated against (per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   the profile is bound to the host kernel, not to the host
   identity).
2. **Distribute the new profile to that DPU only.** Keep the
   previous profile in place on every other DPU until this
   step finishes.
3. **Reload the DPU-side `doca-apsh` consumer.** Walk
   [`doca-apsh TASKS.md ## configure`](../../libs/doca-apsh/TASKS.md#configure)
   to load the new profile into a fresh `doca_apsh_system`.
4. **Enumerate a known-running process from the DPU side.**
   Pick a process the operator knows is running on the host
   (the host's `ps` output is the ground truth). Query the
   DPU side for that process by PID and by name. Both
   must round-trip: the PID returns the right name; the
   name returns the right PID.
5. **Optional, for `hash` use cases:** confirm the
   integrity-check on the DPU side returns a clean match
   against the host process's current binary / library
   bundle.
6. **Optional, for `kpgd_file` use cases:** confirm a
   page-table walk from the DPU side completes against the
   host without `DOCA_ERROR_*` from the apsh-class API.
7. **Roll forward only if all checks pass.** Any failure
   means the profile is rejected; the previous profile
   remains on every other DPU; route to [`## debug`](#debug).

The iteration loop (apply to every rotation):

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| `doca_apsh_system` configure rejects the profile on the DPU side | Layer 5 (DPU-side-load) of the error taxonomy; could be version pairing, corrupted artifact, or wrong OS axis | Confirm version pairing per [`CAPABILITIES.md ## Version compatibility`](#version-compatibility); re-distribute (atomic-swap may have torn the file); re-generate with the right `--os` if mis-axis. |
| Process enumeration round-trip mismatches a known-running process | Profile loads, but symbol offsets are wrong — staleness or wrong-kernel-build | Re-confirm the host kernel build matches the build the script was run against (`uname -r` on both sides of the rotation); regenerate if not. |
| `DOCA_ERROR_NOT_FOUND` on a process that genuinely exists | Per the *"`NOT_FOUND` is a normal answer"* rule in [`doca-apsh CAPABILITIES.md ## Error taxonomy`](../../libs/doca-apsh/CAPABILITIES.md#error-taxonomy), this can be a real *"not present"* answer — but if the validation set is *known-running*, this is a profile-staleness signal | Regenerate the profile against the current running kernel; re-validate. |
| Validation passes on one DPU but fails on another paired with a different host kernel | Two host classes in the fleet; one profile cannot serve both | Generate a profile per host class; route per-DPU during distribution. |

The agent's rule: every change to the produced profile
re-opens the loop. Re-running the script with a tweaked
`--files` selection and quoting the *previous* validation
result is exactly the failure mode this loop replaces.

Loop termination: stop iterating once one round-trip
validation passes cleanly on each represented host class.
Escalate any remaining mismatch to
[`doca-apsh TASKS.md ## debug`](../../libs/doca-apsh/TASKS.md#debug)
and
[`doca-debug ## debug`](../../doca-debug/SKILL.md) with the
captured baseline + validation log as evidence.

This skill does NOT ship a "test fixture" or pre-recorded
expected output. The expected output is host-, kernel-,
distribution-, and DOCA-version-specific; pinning one would
mislead operators on a different host class.

## debug

When `doca_apsh_config.py` fails to produce artifacts, the
artifacts look wrong, or the DPU-side consumer rejects /
mis-reads them, walk the layered error taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
in order. The shape of the diagnosis:

1. **Host-prereq.** Confirm DOCA is installed on the host at
   a known version per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure);
   confirm Python 3 is present; confirm the script's
   third-party Python deps are importable. If `pefile`
   prints the `pefile==2022.5.30` pin message, downgrade as
   directed; do not patch the script to ignore it.
2. **OS-axis.** Confirm `--os` matches the host the script
   actually runs on; re-read the OS-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes);
   re-confirm the requested artifact set is supported on the
   chosen axis (no `kpgd_file` on Windows).
3. **Extractor.** Confirm the extractor at `--path` is
   present, executable, and the right architecture. Route
   any *"`dwarf2json` crashed / refused this kernel"* report
   to the upstream Volatility Foundation
   [`dwarf2json` repository](https://github.com/volatilityfoundation/dwarf2json);
   route any *"`pdbparse-to-json.py` failed"* report to the
   upstream Volatility 3 repository. Do not try to repair
   the extractor inside this skill.
4. **Output-artifact.** Confirm each requested artifact
   appears on disk, has non-zero size, and has a
   modification timestamp post-script-start. If an artifact
   is missing, re-walk [`## configure`](#configure) — the
   guardrails in the script silently drop `hash` (no
   `--pid`) and `kpgd_file` (no `--find_kpgd=1`) when their
   preconditions are not met.
5. **DPU-side-load.** If the artifact exists but the
   DPU-side consumer rejects it or mis-reads it, confirm
   version pairing per
   [`CAPABILITIES.md ## Version compatibility`](#version-compatibility);
   confirm the distribution path delivered the file
   intact (SHA on both sides matches the host-side SHA);
   walk
   [`doca-apsh TASKS.md ## debug`](../../libs/doca-apsh/TASKS.md#debug)
   for the DPU-side consumer's own error ladder.
6. **Version.** Cross-cutting partial-install /
   mixed-version. Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   end-to-end before further investigation.
7. **Cross-cutting.** Cause is below DOCA — host kernel
   built without DWARF, distribution-path tool failure,
   filesystem race. Hand off to
   [`doca-debug ## debug`](../../doca-debug/SKILL.md) and
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   for the host-env layers.

In every case: **quote what the script reported.** Do not
paraphrase stdout, do not infer success from exit code
alone; inspect the produced files per
[`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability).

## use

The DPU-side consumption surface for the produced artifacts
is owned by [`doca-apsh`](../../libs/doca-apsh/SKILL.md). The
agent's hand-off:

1. **Distribute the validated artifact set** to the DPU side
   per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   distribution-path rule (atomic swap, version-stamped,
   rollback-safe).
2. **Load on the DPU side.** Walk
   [`doca-apsh TASKS.md ## configure`](../../libs/doca-apsh/TASKS.md#configure)
   to register the host with `doca_apsh_system`, load the
   profile artifacts, and start the `doca_apsh` Core
   context.
3. **Confirm the round-trip succeeded.** Per [`## test`](#test)
   step 4: enumerate a known-running host process from the
   DPU side; the PID + name round-trip cleanly.
4. **Move workload onto the new profile.** Only after the
   round-trip is clean.
5. **Retain the previous profile** until at least one full
   DPU-side reload cycle has completed cleanly on the new
   one.

The agent's rule: the host-side tool produces, the DPU-side
library consumes, and the two are version-paired. Conflating
the two skills is the most common apsh-class first-touch
error.

## Deferred task verbs

The verbs below are not `doca_apsh_config.py` work and should
be routed out before the agent does any of them under this
skill's name.

- **DPU-side App Shield programming (`doca_apsh_*` API
  calls).** Owned by
  [`doca-apsh`](../../libs/doca-apsh/SKILL.md). This skill
  produces the profile artifacts; the library consumes them.
  Conflating the two is the apsh-class first-touch error.
- **DOCA install / repair / upgrade.** Route to
  [`doca-setup ## install`](../../doca-setup/TASKS.md#configure)
  (and
  [`## no-install`](../../doca-setup/TASKS.md#no-install) for
  the public NGC DOCA container path).
- **`dwarf2json` / `pdbparse` internals.** Route to the
  upstream Volatility Foundation repositories
  ([`dwarf2json`](https://github.com/volatilityfoundation/dwarf2json),
  [Volatility 3](https://github.com/volatilityfoundation/volatility3)).
  This skill consumes them as black-box dependencies.
- **Host kernel debugging.** Profile generation surfaces
  kernel debugging concerns (missing `-debuginfo` packages,
  stripped kernels, missing PDBs) but does not own them.
  Route the user to their host distribution's kernel
  debugging documentation; the skill's role is to flag the
  prerequisite, not to install it.

## Command appendix

`doca_apsh_config.py`-specific invocation classes the verbs
above reach for. Every row is a CLASS — the agent must not
invent flags beyond `python3 doca_apsh_config.py --help` on
the installed version and the public DOCA App Shield page.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers in one shot;
   `doca-capability-snapshot` for per-device capability flags;
   `version-matrix.json` for *"available since"* lookups).
2. If the probe succeeds, the structured tool's output is the
   authoritative answer.
3. If the probe fails, fall back to the manual command in the
   row.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas).

| Purpose (class) | Invocation (shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Discover the documented flag surface | `python3 /opt/mellanox/doca/tools/doca_apsh_config.py --help` + the public DOCA App Shield page | [`## configure`](#configure); [`## debug`](#debug) layer 1 | Prints the documented inventory of `--os`, `--files`, `--pid`, `--path`, `--find_kpgd`. |
| Generate a baseline Linux profile | `python3 .../doca_apsh_config.py --os linux --files <subset> --path <dwarf2json-path>` | [`## run`](#run) steps 1-4 | Produces the requested artifact files on disk; stdout prints `creating: <set>` and the extractor's progress. |
| Generate a per-process integrity bundle | Same as above with `--files` including `hash` and `--pid <PID>` | [`## configure`](#configure) step 3; [`## run`](#run) | Produces the `apsh_client_build_hash/` directory with the process's executable + libraries + VDSO. |
| Generate the Linux page-table anchor | Same as above with `--files` including `kpgd_file` and `--find_kpgd=1` | [`## configure`](#configure) step 4; [`## run`](#run) | Produces `kpgd_file` in the working directory. |
| Round-trip a freshly-generated profile through the DPU side | Distribute artifacts to the DPU per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) → walk [`doca-apsh TASKS.md ## configure`](../../libs/doca-apsh/TASKS.md#configure) → enumerate a known-running host process | [`## test`](#test); [`## use`](#use) | The PID + name round-trip cleanly for at least one known-running host process on the DPU side. |

Three cross-cutting rules for this appendix:

- **Never invent a flag, `--files` token, or artifact
  filename.** `python3 doca_apsh_config.py --help` on the
  installed version and the public DOCA App Shield page are
  the joint contract.
- **Validate before fleet rollout.** Every row above presumes
  the validation gate in [`## test`](#test) ran on at least
  one representative DPU first.
- **Cross-link instead of duplicate.** DOCA-wide cross-cutting
  commands (`pkg-config --modversion doca-apsh`, `doca_caps
  --list-devs`, `uname -r`) live in
  [`doca-debug ## debug`](../../doca-debug/SKILL.md) and
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug);
  this appendix names only `doca_apsh_config.py`-specific
  invocation classes.

## Cross-cutting

A few rules that apply across every verb in this file,
restated here so they are visible at the point of action and
not buried in [`SKILL.md`](SKILL.md):

- The **public DOCA App Shield page** plus the installed
  `python3 doca_apsh_config.py --help` are the joint source
  of truth. When they disagree, the *installed* `--help`
  wins for the user's actual run.
- **Profiles are bound to the host kernel.** Rotate on every
  host-kernel-touching change; never assume a profile is
  *"good for the next N days"*.
- **Validate before fleet rollout.** Round-trip every
  freshly-generated profile against the live host on one
  representative DPU before any other DPU picks it up.
- **Quote the (host OS, kernel build, generation timestamp,
  DOCA version, extractor version) tuple, not just the
  artifact name.** A profile artifact without the
  generation tuple is unreplicable and untraceable.
- This skill **assumes a healthy DOCA install** on the host
  with the App Shield optional component, the chosen OS-axis
  extractor staged at a known path, and a documented
  distribution path to the DPU side. If any of those is in
  doubt, route to
  [`doca-setup`](../../doca-setup/SKILL.md) before running
  anything else here.
