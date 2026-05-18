# DOCA DPACC Compiler — Tasks

**Where to start:** The verbs that carry real workflow content for
DPACC are `## configure`, `## build`, `## modify`, `## test`, and
`## debug`. The `## run` verb is a documented routing stub because
DPACC produces an artifact at build time and does NOT itself
launch anything on the DPA — runtime / launch is owned by
[`doca-dpa`](../../libs/doca-dpa/SKILL.md), runtime / inspect by
[`doca-dpa-tools`](../doca-dpa-tools/SKILL.md). The `## test` verb
is an iterative loop (compile → host-link → load via `doca-dpa` →
smoke-launch one entry point → loop back), not a one-shot pass —
see the eval-loop overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent through
the six task verbs every artifact in this bundle exposes
(`configure / build / modify / run / test / debug`), explicitly
defers task verbs that do not belong here, and ends with the
`Command appendix` honoring the bundle's
[`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
preamble.

For the cross-library DOCA patterns layered under everything
below (the universal lifecycle, the cross-library `DOCA_ERROR_*`
taxonomy, the modify-a-shipped-sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
For the runtime / load + launch counterpart, see
[`doca-dpa`](../../libs/doca-dpa/SKILL.md); for the runtime /
inspect counterpart, see
[`doca-dpa-tools`](../doca-dpa-tools/SKILL.md). The DPA
toolchain triad — DPACC compile, `doca-dpa` runtime load, and
`doca-dpa-tools` runtime inspect — is named explicitly on every
verb that touches a boundary between the three.

## configure

Goal: commit to the three-axis configuration (target DPA
architecture × source-language flavor × output artifact)
documented in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
AFTER confirming the env preconditions that gate the compile —
DOCA installed at a host version, the documented DPACC binary
shipped alongside that DOCA install on `$PATH`, the DPACC ↔ host
DOCA HARD pairing rule satisfied, the target BlueField
generation identified, and the host-side
[`doca-dpa`](../../libs/doca-dpa/SKILL.md) library installed so
the host wrapper that will load the produced image links.

Steps the agent should walk the user through, in order:

1. **Identify the host DOCA install version.** Use
   `pkg-config --modversion doca-dpa` plus
   `doca_caps --version` (and
   `cat /opt/mellanox/doca/applications/VERSION` when present)
   to surface the host's installed DOCA version, then route to
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   for the canonical detection chain and the four-way match
   semantics. If DOCA is not installed, the answer is install
   (route to
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)),
   not a DPACC invocation — DPACC ships *with* DOCA.
2. **Confirm the documented DPACC binary is present.** Read the
   public DOCA DPACC Compiler guide on the user's installed DOCA
   version (via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
   for the documented binary name and install-tree location.
   Confirm it is on `$PATH` (or at the documented install-tree
   path on this DOCA install). If absent, this is layer 1 of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   — route to
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install).
   Do not invent a binary name; the public guide is the source.
3. **Enforce the DPACC ↔ host DOCA HARD pairing rule.** Per the
   load-bearing rule in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   the DPACC version MUST match the host DOCA install version
   per the DOCA Compatibility Policy. Surface BOTH the DPACC
   binary's version (read via the documented `--version`
   invocation on the installed binary, per the public guide)
   AND `pkg-config --modversion doca-dpa`. Route any
   disagreement through
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   for partial-install detection. **Gate the compile on this
   check**; a skewed DPACC is the canonical *image links but
   fails at runtime with `DOCA_ERROR_DRIVER`* failure mode.
4. **Axis 1 — pick the target DPA architecture explicitly.** Per
   the three-axis table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   identify the BlueField generation the produced image will
   run on, then read the public DOCA DPACC Compiler guide on
   the user's installed DOCA version (and the installed
   binary's `--help`) for the arch-name values DPACC accepts.
   Cross-confirm the BlueField generation the host actually
   sees via `doca_caps --list-devs` per
   [`doca-caps TASKS.md ## run`](../doca-caps/TASKS.md#run). Do
   NOT guess from a BlueField marketing name; arch-mismatch is
   the silent runtime-failure mode in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 4 and the only mitigation is committing to the right
   value at configure time.
5. **Axis 2 — pick the source-language flavor.** Commit
   explicitly to what DPACC will compile: the DPA-side
   translation unit (kernel function bodies, possibly using
   DPA-side libraries
   [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) for
   intra-DPA messaging or
   [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md) for
   DPA-side RDMA) PLUS the host-side wrapper that will use
   [`doca-dpa`](../../libs/doca-dpa/SKILL.md) to load and
   launch the produced image. Treat this as one paired
   decision, not two independent ones — a DPA-side library
   call inside the kernel must NOT appear on the host link
   line, per the cross-link rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
6. **Axis 3 — pick the output artifact shape.** Per the same
   three-axis table, commit to what DPACC will emit (relocatable
   object the host link consumes; archive when multiple DPA
   translation units are bundled). The exact shape names live
   on the public DOCA DPACC Compiler guide and the installed
   binary's `--help`; the agent reads them there.
7. **Confirm `doca-dpa` is installed on the host so the wrapper
   links.** Per the runtime / load counterpart in
   [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure)
   step 1 and the host-side build slot in
   [`doca-dpa TASKS.md ## build`](../../libs/doca-dpa/TASKS.md#build),
   the host wrapper needs `pkg-config --cflags --libs doca-dpa`
   to link. If `pkg-config doca-dpa` is missing, the
   DPACC-produced image has nothing to be embedded into and the
   compile-link-load-smoke loop in [`## test`](#test) cannot
   close — route to
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install).

For the canonical DOCA universal lifecycle that underlies the
host-side wrapper this compile feeds into, see
[`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
This skill is concerned with the *build-time* configuration of
the DPACC invocation, not the program-side lifecycle of the
host wrapper that loads the resulting image.

## build

Goal: compile a minimal DPA-side translation unit with DPACC,
link the resulting artifact into a minimal host-side wrapper
that uses [`doca-dpa`](../../libs/doca-dpa/SKILL.md) to load
and launch it, and confirm the full
*compile → host-link → runtime-load → smoke-launch* loop closes
on the user's installed DOCA + DPACC pair. The build pattern
for any DOCA C / C++ consumer is fully documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build);
this skill adds the DPACC compile-time overlay on top of the
host-side overlay in
[`doca-dpa TASKS.md ## build`](../../libs/doca-dpa/TASKS.md#build).

This section is class-shape only — flag strings, supported-arch
names, and include-path strings live on the public DOCA DPACC
Compiler guide on the user's installed DOCA version (route via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
and on the installed binary's `--help`. The agent walks the
*shape* below; the verbatim invocations come from those two
sources, never from this skill.

Steps the agent should walk the user through, in order:

1. **Re-confirm all three axes from [`## configure`](#configure).**
   Without the target DPA architecture committed (axis 1), the
   source-language flavor committed (axis 2), and the output
   artifact shape committed (axis 3), do not invoke DPACC. A
   missing arch axis is the silent-failure setup per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 4; a missing source-language axis is the host-side
   link-symbol mismatch per layer 5.
2. **Author the minimal DPA-side translation unit.** ONE entry
   point that touches one piece of memory (a counter increment
   or a no-op kernel that returns) — the smallest defensible
   kernel that exercises the toolchain. The verified DPA-side
   shape lives in the shipped samples under
   `/opt/mellanox/doca/samples/doca_dpa/`; the agent prescribes a
   minimum-diff modification of the closest sample per
   [`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify),
   not an invented source file. Per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   refuse to ship pre-written DPA-side source from this skill.
3. **Author the minimal host-side wrapper.** A host translation
   unit that creates the `doca_dpa` Core context against the
   chosen `doca_dev`, loads the DPACC-produced image, creates
   one `doca_dpa_thread`, attaches a `doca_dpa_completion`,
   and launches the one kernel entry point via
   `doca_dpa_kernel_launch_update_*` — walk the parent skill's
   [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure)
   for the host-side lifecycle and
   [`doca-dpa TASKS.md ## build`](../../libs/doca-dpa/TASKS.md#build)
   for the `pkg-config doca-dpa` include + link slots.
4. **Compile the DPA-side translation unit via DPACC.** Invoke
   the documented DPACC binary with the axis-1 (target DPA
   arch) and axis-3 (output artifact shape) values committed
   in [`## configure`](#configure); read the exact flag strings
   from the installed binary's `--help` and the public DOCA
   DPACC Compiler guide on the user's installed DOCA version.
   Quote the DPACC diagnostic output verbatim per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability);
   it is the only build-side observability surface DPACC owns.
5. **Link the DPACC artifact into the host wrapper.** The host
   build's link step consumes the DPACC-produced artifact
   alongside `pkg-config --libs doca-dpa` on the host link
   line. A failure here is layer 5
   (link-time-symbol-missing) in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy);
   the most common cause is the DPA-side library symbol set
   (axis 2) being placed on the host link line by mistake —
   per
   [`doca-dpa TASKS.md ## build`](../../libs/doca-dpa/TASKS.md#build)
   the DPA-side library symbols are linked from inside the
   kernel by DPACC, NOT from the host.
6. **Close the loop with the smoke launch.** Run the host
   wrapper, watch it create the `doca_dpa` context, load the
   embedded image, launch the one kernel entry point, and
   drain the attached `doca_dpa_completion` for one
   completion. If yes, the toolchain is sound on this
   install — proceed to [`## test`](#test) for the real
   kernel. If no, jump to [`## debug`](#debug) and identify the
   layer per the seven-layer ladder in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).

For the DPA-side library overlay (axis 2 picks
`doca-dpa-comms` or `doca-dpa-verbs`), the DPACC invocation
grows DPA-side include / link inputs documented in the
matching library's public guide; the host link line does NOT
grow. Per
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
adding a DPA-side library symbol to the host link line is the
canonical *symbol-mismatch* first-build error.

## modify

Goal: extend the smoke kernel into the user's real kernel
without breaking the closed compile-link-load-smoke loop —
**modify the DPA-side source, then recompile + re-link +
re-smoke**, never the DPACC binary itself.

**Do not modify the shipped DPACC binary.** It is an
NVIDIA-shipped build-time toolchain; there is no documented
public way to change its behavior, output format, or accepted
input surface, and none should be invented. What the agent
modifies, every time, is the DPA-side translation unit (and the
matching host-side launch call) that feeds DPACC.

Steps the agent should walk the user through, in order:

1. **Identify the smallest modification that moves the kernel
   closer to the user's intent.** Extend the kernel with one
   function, one memory touch, or one additional argument —
   the minimum-diff modify pattern from
   [`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify)
   applies on top of the shipped sample baseline. Refactoring
   the whole kernel in one pass removes the user's ability to
   bisect against the green smoke; resist that.
2. **Classify the modification's blast radius BEFORE editing.**
   Per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   any source change touching DPA-arch assumptions is
   high-stakes — it interacts with axis 1 (target DPA
   architecture) and can re-trip the silent runtime-failure
   mode in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 4 even when the build still succeeds. Surface the
   blast radius explicitly to the user (which axis the change
   touches, what re-smoke step it forces).
3. **Sync the two sides of the change in one diff.** Per the
   two-side-program rule in
   [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-dpa/CAPABILITIES.md#capabilities-and-modes),
   the DPA-side kernel signature and the host-side launch call
   must agree on count, size, and type of arguments. Track
   both as a single edit so a partial change does not surface
   as `DOCA_ERROR_INVALID_VALUE` at launch submit time later.
4. **Recompile via DPACC.** Re-invoke DPACC with the same
   axis-1 / axis-3 values committed in
   [`## configure`](#configure). A change that requires moving
   to a different DPA architecture re-opens
   [`## configure`](#configure) entirely — do not silently
   re-pick axis 1.
5. **Re-link the host wrapper.** Per the *do not
   partial-rebuild one side* rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   rebuild BOTH the DPA-side image AND the host executable
   that embeds it. Skipping the host re-link against the new
   image is the canonical
   `DOCA_ERROR_DRIVER`-at-runtime failure mode the bundle
   exists to prevent.
6. **Re-smoke per [`## test`](#test).** Every modify iteration
   re-opens the compile-link-load-smoke loop. Treating a
   modify as a one-shot pass and skipping the re-smoke is
   exactly the failure mode the eval loop in
   [`## test`](#test) is built to replace.

Routing for nearby "modify" questions:

- *"Can I patch DPACC to accept a flag the public guide does
  not document?"* → out of scope for external users; this
  skill is for consumers of the shipped tool. The fix is to
  re-read the public DOCA DPACC Compiler guide on the user's
  installed DOCA version for the documented surface, then
  consider whether the user's intent fits one of the
  documented axes.
- *"My DPA-side translation unit calls a DPA-side library
  symbol DPACC rejects."* → axis-2 source-language flavor
  question. Walk the cross-link rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  and the matching DPA-side library skill
  ([`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) or
  [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md))
  before changing the DPACC invocation.

## run

DPACC is a build-time toolchain — it produces an artifact and
exits. **It does not "run" anything on the DPA.** The verb that
runs the DPACC-produced image on a real BlueField is owned by
[`doca-dpa`](../../libs/doca-dpa/SKILL.md), per the
compile-vs-runtime split documented in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
This anchor exists because the bundle's verb contract is
uniform; the content here is the compile→runtime handoff and
the routing it implies.

What the agent walks the user through when the question is
*"how do I actually launch what DPACC built?"*:

1. **Hand the produced artifact to the host build's link
   step**, per [`## build`](#build) step 5. The host
   executable embeds the DPACC output as its loadable DPA
   application image; without that embed step the host has
   nothing to load at runtime.
2. **Launch the host wrapper.** This is owned by
   [`doca-dpa TASKS.md ## run`](../../libs/doca-dpa/TASKS.md#run);
   it is the asynchronous
   `doca_dpa_kernel_launch_update_*` call against a started
   `doca_dpa` Core context with a `doca_dpa_thread` execution
   context. Per the launch + completion section in
   [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-dpa/CAPABILITIES.md#capabilities-and-modes),
   the host must drain the attached `doca_dpa_completion` to
   confirm the kernel actually ran.
3. **Observe the kernel running on the DPA via the runtime /
   inspect surface.** Per-launch DPA-side telemetry —
   *which kernel is loaded, which thread is bound, what is
   running on the DPA right now, per-kernel timing patterns* —
   is owned by
   [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md). Walk
   [`doca-dpa-tools TASKS.md ## run`](../doca-dpa-tools/TASKS.md#run)
   for the three documented DPA tool families (inspection,
   profiling, runtime-debug) and the order they are reached
   for. This is the explicit **compile → runtime handoff**:
   DPACC produced the image, `doca-dpa` loaded and launched
   it, `doca-dpa-tools` introspects it once running.
4. **Capture host-side trace alongside the DPA-side
   observation.** Set `DOCA_LOG_LEVEL=trace` for the host
   wrapper per
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability);
   correlating host-side log lines with the DPA-side
   `doca-dpa-tools` output is the cheapest way to localize
   *which layer* a misbehavior lives in (host PE not
   progressed, DPA-side kernel stuck, DPACC build wrong, or
   DOCA version skew).

Routing for nearby "run" questions:

- *"DPACC fails to run on my build host."* → not a runtime
  question; this is build-time and lives in
  [`## debug`](#debug) layers 1-3 of
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
- *"My host program loaded the image but the kernel did
  nothing."* → host-side `doca-dpa` launch / progress engine
  question, escalated to runtime / inspect via
  `doca-dpa-tools`. Walk
  [`doca-dpa TASKS.md ## run`](../../libs/doca-dpa/TASKS.md#run)
  step 3 (PE progress) and
  [`doca-dpa-tools TASKS.md ## debug`](../doca-dpa-tools/TASKS.md#debug)
  layer 2 (DPA-runtime-not-active). DPACC is not the surface
  for this question.

## test

DPACC's `## test` verb is the **compile-link-load-smoke loop**
— compile the DPA-side source via DPACC, link the artifact into
the host wrapper, load the produced image via
[`doca-dpa`](../../libs/doca-dpa/SKILL.md), launch ONE entry
point on the DPA, and confirm the host observes one completion.
The smoke is **non-optional** per the smoke-before-bulk rule in
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
running it BEFORE any production kernel is the cheapest way to
identify a triad-wide gap (DPACC install, DPACC ↔ host DOCA
pairing, DPA-arch mismatch, link-line wiring) before that gap
hides inside a complex kernel.

**`## test` is an iterative loop, not a one-shot pass.** Each
iteration narrows either the env-precondition set (axis-aware
configure), the three axes, the kernel under compile, or the
host launch call. The loop terminates when (a) the smoke is
green and the user's real kernel compiles, links, loads, and
launches on top of it, or (b) the cause has been narrowed to
a layer outside DPACC (host-side `doca-dpa` lifecycle bug,
BlueField mode, DOCA install) and escalated to the matching
skill.

The compile-link-load-smoke iteration shape:

1. **Smoke compile.** Compile the minimal DPA-side translation
   unit per [`## build`](#build) steps 2-4 against the axis-1
   / axis-3 commitments from [`## configure`](#configure). A
   clean DPACC exit + the diagnostic-output rule per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
   are the configure-side observability snapshot the rest of
   the loop consumes.
2. **Smoke link.** Link the DPACC artifact into the minimal
   host wrapper per [`## build`](#build) step 5. A failure here
   surfaces as layer 5 (link-time-symbol-missing) in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   — most often the DPA-side library symbol set landed on the
   host link line by mistake; re-walk axis 2.
3. **Smoke load via `doca-dpa`.** Run the host wrapper through
   the `doca_dpa` create → load image → start context →
   create thread → attach completion sequence in
   [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure)
   steps 4-6. A failure to load surfaces as
   `DOCA_ERROR_DRIVER` and is the load-bearing signal that
   DPACC ↔ host DOCA are skewed (
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 6) — route to
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug).
4. **Smoke launch one entry point.** Per
   [`doca-dpa TASKS.md ## run`](../../libs/doca-dpa/TASKS.md#run)
   steps 2-3, submit one launch on the one
   `doca_dpa_thread`, then drain the attached
   `doca_dpa_completion` for one completion. If yes — the
   toolchain is sound on this install. If no — and the
   host-side log is silent — the produced image is loaded but
   the kernel may be stuck or the DPA-arch axis is wrong (see
   the arch-mismatch row below).
5. **Arch-mismatch detection (load-bearing high-stakes
   scenario).** A kernel built for the wrong BlueField
   generation often passes steps 1-3 cleanly: DPACC compiled,
   the host link accepted the artifact, `doca-dpa` even
   accepted the load on a BlueField from a different
   generation. The failure surfaces only at step 4 as an
   opaque load error OR — silently — as a kernel that does
   nothing and never produces a completion. Per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 4, this is **the** silent-runtime-failure mode the
   smoke exists to surface. Confirm the BlueField generation
   via `doca_caps --list-devs` per
   [`doca-caps TASKS.md ## run`](../doca-caps/TASKS.md#run),
   cross-confirm the arch-name DPACC accepted on this install
   via the public DOCA DPACC Compiler guide, and recompile.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| DPACC fails to start | The documented DPACC binary is missing on `$PATH` | Layer 1 (compiler-not-installed) in [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy); route to [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install) and re-confirm DPACC ↔ host DOCA pairing |
| DPACC rejects the source | Compile-time bug in the DPA-side translation unit | Layer 3 (source-error); re-walk axis 2 (source-language flavor) and the matching DPA-side library skill ([`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) or [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md)) |
| Host link rejects the DPACC artifact | Symbol mismatch between DPA-side and host-side | Layer 5 (link-time-symbol-missing); re-walk axis 2 — DPA-side library symbols belong in the DPACC invocation, not on the host link line |
| `doca-dpa` rejects the load with `DOCA_ERROR_DRIVER` | DPACC ↔ host DOCA version skew at runtime | Layer 6 (version-skew-with-host-DOCA); route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 and re-pair before recompiling |
| Load succeeds; the launch never completes; host log is silent | DPA-arch-mismatch OR DPA-side kernel stuck OR host PE not progressed | Layer 4 (DPA-arch-mismatch) is the silent-failure mode; cross-check with [`doca-dpa-tools TASKS.md ## run`](../doca-dpa-tools/TASKS.md#run) inspection family BEFORE assuming the kernel is the bug |
| Smoke green on the trivial kernel; user's real kernel fails the same way | Real kernel exercised an axis the smoke did not | Re-open [`## modify`](#modify) — extend the smoke kernel one step toward the real kernel and re-smoke; do NOT skip back to the real kernel |
| Two consecutive smoke runs do not change anything | Cause is below DPACC | Escalate to [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) with the captured DPACC output + host-side trace + DPA-side `doca-dpa-tools` snapshot |

Loop termination: stop iterating once the smoke is green AND
the user's real kernel inherits that green state without
re-opening any axis. Quoting *"compile succeeded"* without the
load + launch + completion chain is exactly the failure mode
the loop replaces — DPACC's exit code 0 is necessary, not
sufficient.

This skill does **not** ship a "test fixture" or pre-recorded
expected output. The expected output is install-, BlueField-,
DOCA-version-, and kernel-specific; pinning one would mislead
operators on a different combination. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When DPACC fails to start, fails to produce an artifact, the
host link rejects the artifact, or the artifact fails at
runtime under
[`doca-dpa`](../../libs/doca-dpa/SKILL.md), walk the seven
layers in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
in order. **Identify the layer first, then act.** The shape of
the diagnosis:

1. **Compiler-not-installed (layer 1).** The documented DPACC
   binary is not on `$PATH` or at the install-tree path the
   public guide names. Confirm DOCA is installed via
   `pkg-config --modversion doca-dpa`, then route to
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)
   for the install side and
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 for partial-install detection (DOCA upgraded,
   DPACC did not). Do not invent an alternate binary name; the
   public DOCA DPACC Compiler guide on the user's installed
   DOCA version is the source.
2. **Wrong-DPACC-version (layer 2, HARD pairing failure).**
   DPACC is present but its version does not match the host
   DOCA install version per the DOCA Compatibility Policy.
   Surface BOTH versions per [`## configure`](#configure)
   step 3 and route to
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   for the four-way match. The fix is a consistent reinstall,
   not a DPACC flag tweak.
3. **Source-error (layer 3).** DPACC parses the DPA-side
   translation unit and rejects it. Re-read the DPACC
   diagnostic output verbatim per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability);
   walk axis 2 (source-language flavor) and the matching
   DPA-side library skill
   ([`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) or
   [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md))
   for symbol / header questions. This is the cross-cutting
   build-layer per
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   layer 3.
4. **DPA-arch-mismatch (layer 4, the silent runtime
   failure).** DPACC compiled cleanly, the host link accepted
   the artifact, but at runtime the load fails or the kernel
   misbehaves opaquely. **The host link does not validate the
   DPA arch** — that check has to happen at configure time
   (axis 1). Confirm the BlueField generation via
   [`doca-caps TASKS.md ## run`](../doca-caps/TASKS.md#run),
   cross-confirm the arch-name DPACC accepted via the public
   DOCA DPACC Compiler guide on the user's installed DOCA
   version, and recompile. Cross-check at runtime via
   [`doca-dpa-tools TASKS.md ## debug`](../doca-dpa-tools/TASKS.md#debug)
   layer 3 (kernel-not-loaded) — if the inspection family
   reports the loaded image but the expected kernel entry
   point is missing, the layer-4 diagnosis is confirmed.
5. **Link-time-symbol-missing (layer 5).** DPACC produced an
   artifact; the host link rejects it with a missing symbol.
   Re-walk axis 2: the DPA-side library symbols
   (`doca-dpa-comms` / `doca-dpa-verbs`) are linked from
   *inside* the kernel by DPACC, not from the host link line —
   adding them to the host link line is the canonical
   first-build symbol-mismatch failure per
   [`doca-dpa TASKS.md ## build`](../../libs/doca-dpa/TASKS.md#build).
   This is also the layer where a partial-rebuild against a
   changed DPA-side translation unit surfaces; per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   the fix is to rebuild BOTH sides.
6. **Version-skew-with-host-DOCA (layer 6, runtime overlay).**
   DPACC compiled, host link succeeded,
   `doca-dpa` rejected the load with `DOCA_ERROR_DRIVER`. Same
   diagnosis as layer 2 plus the runtime overlay in
   [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug)
   layer 7 (driver). The fix is to rebuild the DPA-side image
   against the host DOCA install version; per the *do not
   partial-rebuild one side* rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   the host executable that embeds it must also be re-linked.
7. **Cross-cutting (layer 7).** DPACC compiled, host link
   succeeded, `doca-dpa` loaded the image, the kernel ran, and
   the user's question is now a host-side `doca-dpa` API
   question, a DPA-side library question, or a generic
   driver / firmware question unrelated to DPACC. Route to
   [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug)
   for host-side, to
   [`doca-dpa-tools TASKS.md ## debug`](../doca-dpa-tools/TASKS.md#debug)
   for DPA-side inspect, and to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   for the cross-cutting ladder. DPACC is the wrong surface
   for these.

In every case: **quote what DPACC reported.** Do not
paraphrase the diagnostic output, do not reorder lines, do not
"summarize" a multi-line error. The DPACC diagnostic output is
the build-side observability snapshot the host-side debug
ladder consumes when the runtime misbehaves.

Once the layer is identified, route to the matching debug verb
on the matching skill: install / link / driver to
[`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug);
version to
[`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug);
runtime / inspect to
[`doca-dpa-tools TASKS.md ## debug`](../doca-dpa-tools/TASKS.md#debug);
runtime / load to
[`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug);
cross-cutting to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).

## Deferred task verbs

The verbs below are not DPACC work and should be routed out
before the agent does any of them under this skill's name.

- **install** ⇒
  [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)
  (and
  [`doca-setup TASKS.md ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). DPACC is shipped
  by the DOCA install; this skill does not own the install
  workflow.
- **load / launch / drain DPA kernels from the host** ⇒
  [`doca-dpa`](../../libs/doca-dpa/SKILL.md). DPACC compiles
  the image; the host-side runtime that loads and launches
  what DPACC built is owned by `doca-dpa`. Misrouting a
  *"my launch never completes"* symptom here instead of to
  `doca-dpa` (with a runtime / inspect overlay via
  `doca-dpa-tools`) is the canonical compile-vs-runtime
  confusion.
- **runtime introspection of the DPA processor while a
  kernel is executing** ⇒
  [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md). DPACC has
  no runtime observability surface; the DPA Tools umbrella
  (inspection / profiling / runtime-debug families) is the
  documented runtime surface, not DPACC.
- **deploy the compiled DPA kernel to a fleet of
  BlueFields** ⇒
  [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md).
  DPACC produces one artifact for one install pair; fanning
  that artifact out across many hosts / many BlueFields is a
  packaging + deployment problem, not a DPACC problem, and
  reserved for the platform service skill.
- **production-grade kernel tuning** (per-kernel
  microarchitectural tuning, kernel-specific scheduling
  rules) ⇒ deferred to per-kernel work. This skill teaches
  the *toolchain* class — compile + link + load + smoke; the
  *kernel itself* belongs in per-kernel review against the
  public DOCA DPA developer guide reached through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **cross-kernel orchestration** (intra-DPA messaging
  patterns between kernels on the same DPA, DPA-side RDMA to
  remote peers, multi-kernel pipelines) ⇒ the matching
  DPA-side library skills
  [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) and
  [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md). DPACC
  *compiles* a kernel that calls into those libraries; how the
  kernels then coordinate at runtime belongs in those skills.

## Command appendix

DPACC-specific invocation classes the verbs above reach for.
Every row is a CLASS — the agent must not invent flags,
supported-arch names, or include-path strings beyond what the
public DOCA DPACC Compiler guide on the user's installed DOCA
version and `--help` on the installed binary document. The
six-class symmetry below (detect → version → compile → link →
load → launch + observe) is the load-bearing piece; one
worked example per class is shown.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; `doca-capability-snapshot` for per-device capability flags;
   `version-matrix.json` for *"available since"* lookups).
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
| Detect the documented DPACC binary on this install | `which <documented-DPACC-binary>` (the binary name comes from the public DOCA DPACC Compiler guide on the user's installed DOCA version, reached via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools); the agent reads `--help` on the installed binary for the exact flag inventory, not from this row) | [`## configure`](#configure) steps 1-2; [`## debug`](#debug) layer 1 | A single path under the DOCA install tree; absence = layer 1 (compiler-not-installed), route to [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install) |
| Version DPACC against the host DOCA install (HARD pairing) | The installed binary's documented `--version` invocation (per the public guide) AND `pkg-config --modversion doca-dpa` AND `doca_caps --version` | [`## configure`](#configure) step 3; [`## debug`](#debug) layer 2 | All three agree per the DOCA Compatibility Policy; any disagreement = layer 2 (wrong-DPACC-version), route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| Compile a DPA-side translation unit via DPACC | The documented DPACC invocation with the axis-1 (target DPA arch) and axis-3 (output artifact shape) values committed in [`## configure`](#configure) — use the documented binary and `--help` for the exact flags rather than quoting flag strings here | [`## build`](#build) step 4; [`## modify`](#modify) step 4; [`## test`](#test) iteration 1 | DPACC exits 0; the diagnostic output per [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability) names no errors; the documented output artifact appears at the path DPACC names |
| Link the DPACC artifact into the host wrapper | The host build's link step (e.g. `meson` / `ninja` / `make` against `pkg-config --libs doca-dpa`) — wired per [`doca-dpa TASKS.md ## build`](../../libs/doca-dpa/TASKS.md#build); use the documented build manifest pattern and `--help` from the user's build tool for the exact flags rather than quoting flag strings here | [`## build`](#build) step 5; [`## test`](#test) iteration 2 | The host executable links cleanly with the DPACC-produced artifact embedded; absence of `-ldoca-dpa-comms` / `-ldoca-dpa-verbs` on the host link line (those are DPA-side, per axis 2); a link failure here = layer 5 (link-time-symbol-missing) |
| Load the produced image at runtime via `doca-dpa` | The host wrapper's `doca_dpa` Core context create → load image → start context sequence per [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure) steps 4-5 — use the documented API and the shipped sample shape rather than quoting code here | [`## test`](#test) iteration 3 | `doca_ctx_start()` returns success; absence = layer 6 (version-skew-with-host-DOCA, `DOCA_ERROR_DRIVER`), route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| Launch one entry point on the DPA and observe it via `doca-dpa-tools` | The host wrapper's `doca_dpa_kernel_launch_update_*` call per [`doca-dpa TASKS.md ## run`](../../libs/doca-dpa/TASKS.md#run); cross-checked at runtime with the inspection family per [`doca-dpa-tools TASKS.md ## run`](../doca-dpa-tools/TASKS.md#run) step 1 — read each tool's installed `--help` for the exact subcommand rather than quoting it here | [`## run`](#run); [`## test`](#test) iteration 4 | The host drains one completion from the attached `doca_dpa_completion`; the inspection family in `doca-dpa-tools` reports the loaded image and the bound thread with the launched kernel entry point — the compile → runtime handoff is closed |

Three cross-cutting rules for this appendix:

- **Never invent a DPACC flag, supported-arch name, output
  artifact shape name, or include-path string.** The
  installed binary's `--help` and the public DOCA DPACC
  Compiler guide on the user's installed DOCA version are
  the joint contract; prose-derived flag strings are the
  most common hallucination failure for this skill.
- **Smoke before bulk; arch before flag.** Every row above
  presumes the smoke loop in [`## test`](#test) closes and
  axis 1 (target DPA arch) is committed; running a real
  kernel against an unconfirmed arch is exactly the
  silent-failure mode in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  layer 4.
- **Cross-link instead of duplicate.** Cross-cutting
  commands (`pkg-config --modversion`, `doca_caps`,
  `DOCA_LOG_LEVEL`, `dmesg`, `mlxconfig -d <bdf> q`) live
  in
  [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
  and
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug);
  the runtime / inspect surface lives in
  [`doca-dpa-tools TASKS.md ## Command appendix`](../doca-dpa-tools/TASKS.md#command-appendix);
  this appendix names only DPACC-specific build-time
  invocation classes on top.

## Cross-cutting

A few rules that apply across every verb in this file, restated
here so they are visible at the point of action and not buried
in [`SKILL.md`](SKILL.md):

- The **public DOCA DPACC Compiler guide** on the user's
  installed DOCA version plus the installed binary's `--help`
  are the joint source of truth. When they disagree (e.g. a
  flag landed in a release this skill was not written
  against), the *installed* `--help` wins for the user's
  actual compile.
- **Pair DPACC with the host DOCA install BEFORE invoking
  it.** The HARD pairing rule in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  is non-negotiable; a skewed DPACC is the canonical
  *"image links but fails at runtime with
  `DOCA_ERROR_DRIVER`"* failure mode the bundle exists to
  prevent.
- **DPA-arch is the load-bearing silent-failure axis.**
  Surface the chosen target DPA architecture explicitly at
  configure time; the host link does not validate it, so a
  wrong choice surfaces only at runtime, often opaquely.
- **Compile-vs-runtime is the load-bearing scope split.**
  Build-time = this skill; runtime / load + launch =
  [`doca-dpa`](../../libs/doca-dpa/SKILL.md); runtime /
  inspect = [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md).
  Reaching for DPACC for a runtime stuck-kernel symptom is
  the canonical misroute.
- This skill **assumes a healthy DOCA install** (or the
  public NGC DOCA container) with DPACC + the host-side
  `doca-dpa` library both present at matching versions. If
  the install is in doubt, route to
  [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
  and [`doca-setup`](../../doca-setup/SKILL.md) before
  invoking DPACC.
