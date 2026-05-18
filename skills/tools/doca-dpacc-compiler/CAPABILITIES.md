# DOCA DPACC Compiler — Capabilities

**Where to start:** DPACC is a build-time DPA toolchain; the
pattern overview below names the recurring DPACC-class
questions. Pick the pattern first, then drill into the H2
that owns the substance. For the *how* of executing each
pattern, jump to [TASKS.md](TASKS.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents
*what DPACC is and is not*, *its two-stage role inside the DPA
toolchain triad (DPACC build, `doca-dpa` runtime load + launch,
`doca-dpa-tools` runtime inspect)*, *the three-axis
configuration model an agent must commit to before any flag is
chosen*, *the HARD pairing rule between DPACC and the host DOCA
install*, *the layered DPACC error surface*, *the
observability role inside the DPA toolchain triad*, and *the
safety policy that gates partial rebuilds and silent
arch-mismatch failure modes*. For step-by-step compile + link
+ smoke workflows, see [`TASKS.md`](TASKS.md).

## Pattern overview

Every DPACC question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across
every DOCA install, every BlueField generation that exposes a
DPA, and every DPA-side translation unit DPACC accepts.

| DPACC pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Place DPACC inside the three-skill DPA toolchain triad | DPACC = COMPILE-TIME (this skill, produces the DPA image); `doca-dpa` = RUNTIME-LOAD-AND-LAUNCH (loads + launches the produced image); `doca-dpa-tools` = RUNTIME-INSPECT (introspects the running workload); a misroute among the three is the canonical DPA toolchain first-touch error | [`## Capabilities and modes`](#capabilities-and-modes) compile-vs-runtime split + [TASKS.md ## Deferred task verbs](TASKS.md#deferred-task-verbs) |
| 2. Pick the three-axis configuration | target DPA architecture × source-language flavor (DPA kernel + host-side wrapper that uses `doca-dpa`) × output artifact (relocatable object / archive); commit to all three explicitly before any flag is chosen | [`## Capabilities and modes`](#capabilities-and-modes) three-axis table + [TASKS.md ## configure](TASKS.md#configure) |
| 3. Honor the HARD DPACC ↔ host DOCA pairing rule | DPACC version must match the host DOCA install version per the DOCA Compatibility Policy; a skewed DPACC produces an image that links cleanly but fails at runtime with `DOCA_ERROR_DRIVER` from `doca-dpa` | [`## Version compatibility`](#version-compatibility) DPACC overlay + [TASKS.md ## configure](TASKS.md#configure) version-state check |
| 4. Compile-link-load-smoke before bulk | Build a minimal DPA kernel + a minimal host-side wrapper that uses `doca-dpa` to load and launch it BEFORE compiling the user's real kernel; without the smoke a DPACC bug, an arch mismatch, or a partial-install hazard discovers itself in a complex kernel where it is hardest to read | [TASKS.md ## test](TASKS.md#test) compile-link-load-smoke loop + [`## Safety policy`](#safety-policy) smoke rule |
| 5. Treat DPA-arch-mismatch as a high-stakes silent runtime failure | Compiling for the wrong DPA architecture often yields an artifact the host link accepts (the host link does not validate the DPA arch); the failure surfaces only at runtime as a `doca-dpa` load error or an opaque execution misbehavior — silently is the load-bearing word | [`## Error taxonomy`](#error-taxonomy) DPA-arch-mismatch row + [TASKS.md ## debug](TASKS.md#debug) layer 4 |
| 6. Diagnose a DPACC failure by layer | Map a symptom (compiler-not-installed / wrong-DPACC-version / source-error / DPA-arch-mismatch / link-time-symbol-missing / version-skew-with-host-DOCA / cross-cutting) to its layer before any code or config change | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Compile-vs-runtime is load-bearing.** A *"DPA kernel
  hangs at runtime"* question is NOT a DPACC question; it is
  a [`doca-dpa`](../../libs/doca-dpa/SKILL.md) question and
  a [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md) question.
  A *"image fails to load"* question is mostly a
  [`doca-dpa`](../../libs/doca-dpa/SKILL.md) question with a
  DPACC overlay (the DPACC-host-DOCA pairing rule). A
  *"compile fails"* / *"host link rejects symbol"* question
  is this skill's question. The agent must classify the
  question against this split before doing anything else;
  reaching for DPACC for a runtime stuck-kernel symptom is
  the canonical misroute.
- **Class-shape only. Do not invent flag strings,
  supported-arch names, or include-path strings.** The
  authoritative surface for each per-flag inventory is the
  installed `dpacc --help` (or the install-tree path the
  public guide names on the user's installed DOCA version)
  and the public DOCA DPACC Compiler guide reachable via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  Naming the axis is the agent's job here; quoting flag
  strings is not.

## Capabilities and modes

DPACC is shipped as the **DOCA DPACC Compiler** — a
build-time toolchain documented on the public DOCA DPACC
Compiler guide (reached via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools);
direct URL
<https://docs.nvidia.com/doca/sdk/DOCA-DPACC-Compiler/index.html>).
There is no daemon, no runtime library to link against from a
long-running program; the user's interaction model is *invoke
DPACC at build time on a DPA-side translation unit, link the
resulting object into the host executable, watch the host's
`doca-dpa` flow load that artifact onto the DPA at runtime*.

### Compile-time vs runtime / load vs runtime / inspect — the load-bearing split

| Side | What runs there | Toolchain | Skill that owns it |
| --- | --- | --- | --- |
| Compile-time | Producing the DPA application image from the user's DPA-side source; producing the host-linkable artifact the host executable embeds | DPACC compiler (this skill) | `doca-dpacc-compiler` (this skill) |
| Runtime / load | Loading the produced image into a `doca_dpa` Core context, creating `doca_dpa_thread` execution contexts, launching kernels, draining `doca_dpa_completion` | `doca-dpa` (host-side library) | [`doca-dpa`](../../libs/doca-dpa/SKILL.md) |
| Runtime / inspect | Introspecting the loaded / bound / executing state of the DPA processor while a workload is running, profiling, runtime-debug | The DPA tool suite under the public DPA Tools umbrella | [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md) |

The agent's rule: a *"DPACC fails to compile"* / *"host link
rejects DPACC's output"* / *"`doca-dpa` rejects the load
because the artifact is malformed"* error belongs in the
compile-time row. A *"`doca-dpa` loaded the image but the
launch never returned a completion"* / *"the kernel runs but
hangs"* error belongs in the runtime / load and runtime /
inspect rows. Misrouting between these three surfaces is the
most common DPA toolchain first-touch error and the reason
this triad is named explicitly in every DPA skill in the
bundle.

### Three-axis configuration

Every concrete DPACC invocation is configured along three
independent axes. Get any one wrong and the build either
fails outright or — worse — succeeds and produces an artifact
that fails at runtime in confusing ways. The agent's job is
to force the explicit decision on each axis before DPACC is
invoked.

| Axis | Class shape | Examples (read from the installed `--help` and the public DOCA DPACC Compiler guide; do NOT invent values) | Why a wrong choice fails |
| --- | --- | --- | --- |
| **1. Target DPA architecture** | Which BlueField generation's DPA processor the artifact is for. Different generations carry different DPA hardware and the artifact is arch-specific | The set of supported DPA architecture names is documented on the public DOCA DPACC Compiler guide on the user's installed DOCA version, and the installed `dpacc --help` lists the values DPACC actually accepts on this install. The agent reads them there; it does NOT guess from BlueField marketing names | A wrong arch is the load-bearing silent-failure mode (see [`## Error taxonomy`](#error-taxonomy) row 4); the host link often accepts the artifact and the failure surfaces only when `doca-dpa` tries to load it on the wrong-generation BlueField |
| **2. Source-language flavor** | What DPACC compiles AND what the host link consumes — the DPA-side kernel translation unit (the function bodies that run on the DPA processor; possibly using DPA-side libraries [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) for intra-DPA messaging or [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md) for DPA-side RDMA) PLUS the host-side wrapper that will use [`doca-dpa`](../../libs/doca-dpa/SKILL.md) to load and launch the produced image | The DPA-side translation unit is whatever the public DOCA DPACC Compiler guide says DPACC accepts on this version; the host-side wrapper is a normal C / C++ translation unit using `pkg-config doca-dpa`. The shipped samples under `/opt/mellanox/doca/samples/doca_dpa/` (and its DPA-comms / DPA-verbs siblings) are the verified two-side template | A DPA-side translation unit that calls into a DPA-side library the host-side link line tries to add (or vice versa) is the canonical *symbol-mismatch* failure; the DPA-side library symbols are linked from inside the kernel by DPACC, NOT from the host |
| **3. Output artifact** | What DPACC emits — the artifact shape the host build will then consume on its link line. Class-level shapes are *relocatable object* (single DPA translation unit, becomes part of the host executable's link inputs) and *archive* (multiple DPA translation units bundled together) | The exact artifact-shape flags are documented on the public DOCA DPACC Compiler guide and `dpacc --help` on the user's installed DOCA version; the agent reads them there | An artifact-shape choice that does not match the host build's link expectations breaks the host link with a *symbol not found* / *wrong file format* error — a layer-5 (link) symptom of a layer-3 (build) misconfiguration in [`doca-debug`](../../doca-debug/SKILL.md)'s ladder |

The three axes interact: an artifact compiled for one DPA
architecture is not portable to another; a DPA-side
translation unit that uses `doca-dpa-comms` symbols still
needs the matching DPA-side library to be present at
DPACC-time on this DOCA install (which is why the version
overlay is HARD); the output artifact shape must match what
the host build's link step expects to consume. The agent's
rule: commit to all three axes explicitly — the chosen
target DPA architecture, the chosen source-language flavor
(including any DPA-side libraries the kernel calls), and the
chosen output artifact shape — before invoking DPACC.

### Two-stage role inside the DPA toolchain triad

DPACC's role is **two-stage** and the agent must surface
both stages explicitly:

1. **Stage 1 — DPACC compiles the DPA-side translation
   unit.** Input: the user's DPA-side source (kernel
   function bodies, possibly using DPA-side libraries
   [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) or
   [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md)).
   Output: a relocatable object the host link consumes.
2. **Stage 2 — the host build links the DPACC output into
   the host executable; the host runtime uses
   [`doca-dpa`](../../libs/doca-dpa/SKILL.md) to load the
   embedded DPA application image onto the DPA processor at
   runtime.** This stage is owned by `doca-dpa`, not DPACC;
   this skill cross-links and does not redefine the
   `doca_dpa_app` / `doca_dpa_thread` /
   `doca_dpa_kernel_launch_update_*` /
   `doca_dpa_completion` surfaces.

The agent's rule: a *"my DPACC build succeeded but my host
program does not load the image"* question is a stage-2
question — route to
[`doca-dpa`](../../libs/doca-dpa/SKILL.md) for the host-side
load + launch lifecycle, with this skill's version overlay
applied for the DPACC-host-DOCA pairing check. A *"my host
program loaded the image but the kernel does nothing"*
question routes further to
[`doca-dpa-tools`](../doca-dpa-tools/SKILL.md) for the
runtime / inspect side.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the
headers-win-over-docs rule, see
[`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The DPACC-specific overlay is HARD — DPACC ↔ host DOCA
must match.** This is the load-bearing version rule for the
DPA toolchain triad and the most common silent-failure mode
the bundle exists to prevent:

- **DPACC version must match the host DOCA install version
  per the DOCA Compatibility Policy.** DPACC is the compile-
  time half of the DPA toolchain; `doca-dpa` is the
  runtime-load half. A skewed DPACC (e.g. installed by an
  older DOCA package while the host runtime DOCA install was
  upgraded, or vice versa) produces an artifact that the
  host link accepts but `doca-dpa` rejects at load time with
  `DOCA_ERROR_DRIVER`, OR — worse — the artifact loads but
  the kernel misbehaves at runtime in ways that look like
  hardware bugs but are version-skew bugs. Per the DPA
  overlay in
  [`doca-dpa CAPABILITIES.md ## Version compatibility`](../../libs/doca-dpa/CAPABILITIES.md#version-compatibility),
  cross-check against the DOCA Compatibility Policy at
  <https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html>;
  the agent must surface BOTH `pkg-config --modversion
  doca-dpa` AND the installed DPACC version BEFORE
  recommending a DPACC invocation, and route any
  disagreement through
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  for the partial-install detection.
- **Where DPACC runs:** on the host (or BlueField Arm) that
  has DOCA installed. DPACC is a build-time toolchain — it
  runs at `meson` / `ninja` / `make` time on whichever
  machine is doing the build, and produces an artifact for
  the user's chosen target DPA architecture. The build host
  and the runtime host can differ (cross-build), but
  DPACC's DPA-arch axis must match the target BlueField
  generation regardless.
- **Per-DOCA-train availability of features.** Specific
  DPACC features (new DPA architectures, new artifact
  shapes, new DPA-side library symbols available to the
  kernel) land per DOCA release. The public DOCA DPACC
  Compiler guide on the user's installed DOCA version and
  `dpacc --help` are the joint source of truth for what is
  available; the agent does NOT assume a flag exists across
  versions.
- **Output stability is not contractually frozen.** The
  artifact shape DPACC produces on the user's installed DOCA
  is the contract for that install; the agent does not
  assume bit-for-bit compatibility across DOCA versions.
  Pair the DPACC version with the host DOCA install version
  per the rule above and the artifact contract holds.

## Error taxonomy

DPACC's error surface layers onto the cross-library
`DOCA_ERROR_*` taxonomy in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy)
and onto the cross-cutting debug ladder in
[`doca-debug CAPABILITIES.md ## Error taxonomy`](../../doca-debug/CAPABILITIES.md#error-taxonomy).
The DPACC-specific layers, in escalating order:

1. **Compiler-not-installed.** The DPACC binary the agent
   wants to invoke is not present on `$PATH` or in the
   install-tree path the public DOCA DPACC Compiler guide
   names on the user's installed DOCA version. Cause: DOCA
   is not installed, the install is missing the DPACC
   component, or the install was a partial install (DOCA
   upgraded, DPACC did not). Routing:
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
   for the install side; [`doca-version`](../../doca-version/SKILL.md)
   for the partial-install detection per the four-way match
   rule.
2. **Wrong-DPACC-version (the HARD pairing failure).** DPACC
   is present but its version does not match the host DOCA
   install version per the DOCA Compatibility Policy. Cause:
   DOCA was upgraded (or downgraded) without re-installing
   DPACC, or the user is invoking a DPACC binary from a
   different install tree than the host runtime DOCA. Symptom
   often surfaces only at runtime — DPACC compiles, host
   link succeeds, `doca-dpa` rejects the load with
   `DOCA_ERROR_DRIVER`. Routing:
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 (partial install).
3. **Source-error.** DPACC parses the DPA-side translation
   unit and rejects it because the source itself is wrong —
   syntax error, undefined symbol against the DPA-side
   library headers (`doca-dpa-comms` /
   `doca-dpa-verbs` symbols missing because the source did
   not include their headers, or a DPA-side function
   signature uses a type DPACC does not accept on this
   version). Cause: a normal compile-time bug in the user's
   source. Routing: fix the source per the matching DPA-side
   skill ([`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md)
   or [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md))
   and the public DOCA DPACC Compiler guide; this is
   [`doca-debug`](../../doca-debug/SKILL.md) layer 3 (build).
4. **DPA-arch-mismatch (the silent runtime failure).** DPACC
   compiled cleanly, the host link accepted the artifact,
   but the artifact targets a different DPA architecture
   than the BlueField the host actually runs against. The
   host link **does not validate the DPA arch** because the
   DPA arch is not part of the host's instruction set — so
   the symptom surfaces only at runtime, typically as a
   `doca-dpa` load error or an opaque execution misbehavior
   that looks like a hardware bug. This is the **load-bearing
   silent-failure mode**; the agent must surface the chosen
   target DPA architecture explicitly at configure time
   (axis 1 of [`## Capabilities and modes`](#capabilities-and-modes))
   so this layer cannot strike. Routing:
   re-read the public DOCA DPACC Compiler guide for the arch
   names DPACC accepts on the user's installed DOCA version,
   confirm the BlueField generation via `doca_caps
   --list-devs` per
   [`doca-caps TASKS.md ## run`](../doca-caps/TASKS.md#run),
   recompile.
5. **Link-time-symbol-missing.** DPACC produced an artifact;
   the host build's link step rejects it because a symbol
   the host link expects is missing (most commonly the DPA
   application image embed step was wired wrong, or the
   DPA-side translation unit and the host-side launch call
   disagree on the kernel function signature). Cause: a
   build-system wiring problem in the user's project, often
   a partial-rebuild against a changed DPA-side translation
   unit. Routing: this is
   [`doca-debug`](../../doca-debug/SKILL.md) layer 4 (link);
   the *do not partial-rebuild one side* rule from
   [`doca-dpa CAPABILITIES.md ## Safety policy`](../../libs/doca-dpa/CAPABILITIES.md#safety-policy)
   applies — rebuild BOTH the DPA-side image via DPACC AND
   the host executable that embeds it.
6. **Version-skew-with-host-DOCA (runtime overlay).** DPACC
   compiled cleanly, host link succeeded, host program ran,
   `doca-dpa` rejected the load with `DOCA_ERROR_DRIVER` or
   the launch returned `DOCA_ERROR_NOT_SUPPORTED`. Cause:
   the DPACC version and the host runtime DOCA install
   version drifted between DPACC-time and runtime (e.g.
   DOCA was upgraded after the artifact was built but the
   artifact was not rebuilt). Same routing as layer 2 plus
   the DPA overlay in
   [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug)
   layer 7 (driver).
7. **Cross-cutting.** DPACC compiled, host link succeeded,
   `doca-dpa` loaded the image, the kernel ran but the
   user's question is really a host-side `doca-dpa` API
   question, a DPA-side library question, or a generic
   driver / firmware / BlueField-mode issue unrelated to
   DPACC. Cause: DPACC is the wrong surface for this
   question. Routing: cross-cutting ladder in
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug);
   the host-side surface in
   [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug);
   the runtime / inspect surface in
   [`doca-dpa-tools TASKS.md ## debug`](../doca-dpa-tools/TASKS.md#debug).

The agent's rule: **identify the layer FIRST, then act.**
Reaching for a DPACC config tweak when the layer is 6
(version-skew-with-host-DOCA) loops without progress; the
fix is a consistent reinstall, not a flag change.

## Observability

DPACC's observability surface is **build-time only** — it is
*what other skills load to observe* the DPA toolchain at
build time, before the runtime / load and runtime / inspect
surfaces become available. Specifically:

- **DPACC's own diagnostic output.** DPACC emits diagnostics
  (warnings, errors, optional verbose / trace output) at
  build time. The exact verbose / log-level flags are
  documented in the public DOCA DPACC Compiler guide and
  `dpacc --help`; the agent does NOT invent them. Capture
  these on first failure — they are the primary build-side
  observability surface and the only one DPACC owns.
- **Build-system surface.** The user's `meson` /
  `ninja` / `make` invocation surrounding DPACC owns the
  rest of the build observability surface: which DPA-side
  translation units were rebuilt, which were cached, what
  the host link line ended up being. This is generic build
  observability, not DPACC-specific; treat it the same way
  any other library skill treats `meson` / `ninja` output.
- **Runtime observability is owned by the runtime skills,
  not this one.** When the artifact DPACC produced loads
  successfully but the runtime kernel misbehaves, the
  observability surface is
  [`doca-dpa`](../../libs/doca-dpa/SKILL.md) (host-side
  completions, `DOCA_LOG_LEVEL=trace`) plus
  [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md) (the public
  DPA Tools umbrella's inspection / profiling /
  runtime-debug families). DPACC does not have a runtime
  observability surface; an agent that tries to invoke
  DPACC to *"observe"* a running DPA workload has the model
  wrong.
- **Cross-cutting controls.** For the cross-cutting
  observability primitives (`DOCA_LOG_LEVEL`,
  `--sdk-log-level`, the trace build flavor) see
  [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability);
  these affect the host runtime that loads the DPACC-produced
  image, not DPACC itself.

The agent's rule: a clean DPACC build + a clean host link is
the *DPACC-side observability snapshot* the host-side debug
ladder consumes when the runtime misbehaves; without that
snapshot, the host-side debug starts with guesses about
whether the artifact is sound.

## Safety policy

DPACC's safety surface is **build-time, narrow, but
load-bearing for the runtime that follows**:

- **Smoke before bulk: compile-link-load-smoke is non-
  optional.** Build a minimal DPA kernel + a minimal
  host-side wrapper that uses `doca-dpa` to load and launch
  it BEFORE compiling the user's real kernel. The smoke
  exercises every layer of the toolchain triad — DPACC
  produces an artifact, the host link consumes it,
  `doca-dpa` loads it, the launch returns a completion. A
  smoke that fails identifies a triad-wide gap (DPACC
  install, DPACC ↔ host DOCA pairing, DPA-arch mismatch,
  link-line wiring) cheaply; skipping the smoke is the
  canonical way to discover the gap inside a complex kernel
  where it is hardest to read.
- **Do not partial-rebuild one side.** Per the *do not
  partial-rebuild one side* rule in
  [`doca-dpa CAPABILITIES.md ## Safety policy`](../../libs/doca-dpa/CAPABILITIES.md#safety-policy),
  rebuild BOTH the DPA-side image (via DPACC) AND the host
  executable that embeds it whenever the DPA-side
  translation unit, the host-side launch call, the DOCA
  install, or DPACC itself changed. A host-side rebuild
  against a new DOCA install with the DPA-side image still
  built by an old DPACC is the canonical
  `DOCA_ERROR_DRIVER`-at-runtime failure mode.
- **Treat DPA-arch-mismatch as a high-stakes silent
  failure.** The host link does not validate the DPA arch.
  The agent must surface the chosen target DPA architecture
  EXPLICITLY at configure time (axis 1) and confirm the
  BlueField generation via `doca_caps --list-devs` per
  [`doca-caps TASKS.md ## run`](../doca-caps/TASKS.md#run)
  before recommending a DPACC invocation; recommending a
  DPACC build without committing to the arch axis is how a
  silent runtime failure gets shipped.
- **Pair DPACC with the host DOCA install BEFORE invoking
  it.** The HARD pairing rule in
  [`## Version compatibility`](#version-compatibility) is
  the load-bearing version rule; an agent that recommends a
  DPACC invocation without first surfacing both
  `pkg-config --modversion doca-dpa` and the installed
  DPACC version is recommending a build whose runtime
  behavior is undefined.
- **Class-shape only — do NOT invent flag strings,
  supported-arch names, or include-path strings.** The
  installed `dpacc --help` and the public DOCA DPACC
  Compiler guide on the user's installed DOCA version are
  the joint source of truth. If the user asks for a flag
  the public guide does not list, the safe answer is *"the
  installed `--help` is the source of truth — let me check
  it there"*, not a guess based on generic toolchain
  conventions.
- **Refuse to ship pre-written DPA-side source.** The
  shipped DPA samples under
  `/opt/mellanox/doca/samples/doca_dpa/` and its DPA-comms /
  DPA-verbs sample siblings are the verified two-side
  template. The agent's job is to route the user to those
  files and prescribe a minimum-diff modification per
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md);
  shipping invented source short-circuits the user's
  ability to bisect against a known-good baseline.

## Public-source pointer

The single canonical public source for DPACC is the **DOCA
DPACC Compiler** page on `docs.nvidia.com`, reachable through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
(direct URL
<https://docs.nvidia.com/doca/sdk/DOCA-DPACC-Compiler/index.html>).
The DPA Tools umbrella
(<https://docs.nvidia.com/doca/sdk/DPA+Tools/index.html>),
which the `doca-dpa-tools` skill names as its primary
public surface, links to DPACC alongside the DPA developer /
admin CLIs. Do not invent flags, supported-arch names,
output formats, or include-path strings beyond what the
public DOCA DPACC Compiler guide and the installed `dpacc
--help` document on the user's installed DOCA version. For
the DPA-side library surfaces the kernel may call (intra-DPA
messaging, DPA-side RDMA), the source of truth is the
matching DPA-side library skill
([`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md),
[`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md))
plus the per-library guide reached through the same map.
