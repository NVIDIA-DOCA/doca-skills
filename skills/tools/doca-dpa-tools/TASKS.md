# DOCA DPA tool suite — Tasks

**Where to start:** The verbs that carry real workflow content
for the DPA tool suite are `## run`, `## test`, and `## debug`.
The other three (`configure`, `build`, `modify`) are documented
routing stubs that exist because the bundle's verb contract is
uniform. The `## test` verb is an iterative loop (inspection
smoke → narrowed profiling → cross-check against the host-side
`doca-dpa` flow → loop back), not a one-shot pass — see the
smoke-before-bulk overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent through
the six task verbs every artifact in this bundle exposes
(`configure / build / modify / run / test / debug`), then
explicitly defers task verbs that do not belong here.

For the cross-library DOCA patterns layered under everything
below (the universal lifecycle, the cross-library `DOCA_ERROR_*`
taxonomy, the modify-a-shipped-sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
For the host-side DPA flow these tools introspect, see
[`doca-dpa`](../../libs/doca-dpa/SKILL.md).

## configure

Goal: confirm the env preconditions the DPA tool suite needs to
return anything useful — DOCA installed, BlueField with a DPA
processor exposed to the host, the host-side `doca-dpa` flow
brought up at least to the started lifecycle stage with an
application image loaded — BEFORE reaching for any individual
DPA tool.

Steps the agent should walk the user through:

1. **Confirm DOCA is installed and DPACC is at a matching
   version.** Per the version overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   surface `pkg-config --modversion doca-dpa`, the installed
   `dpacc` version, and `doca_caps --version`; cross-check
   against the DOCA Compatibility Policy via
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
   If DOCA is not installed or the install is partial, route to
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install).
2. **Confirm the BlueField actually exposes its DPA to the
   host.** Per the dual-axis rule in
   [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-dpa/CAPABILITIES.md#capabilities-and-modes),
   run `doca_caps --list-devs` and confirm a BlueField device
   appears with the DPA capability surface; if it does not,
   the answer is the BlueField mode or generation, not the DPA
   tool suite — route to
   [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
   layer 5 (driver).
3. **Confirm the host-side `doca-dpa` flow is brought up.** The
   DPA tools observe a workload — they do not bring one up.
   Walk the parent skill's configure ladder in
   [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure)
   to confirm the host has loaded a `doca_dpa_app`, created at
   least one `doca_dpa_thread`, started the `doca_dpa` Core
   context, and ideally already launched a kernel that the
   user wants to inspect. If the host has not done this,
   running the inspection tool now will (correctly) report
   nothing — go back to `doca-dpa` first.
4. **Discover which DPA tool binaries are present on this
   install.** The DPA tool suite is documented as the **DPA
   Tools** umbrella in
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
   (umbrella URL <https://docs.nvidia.com/doca/sdk/DPA+Tools/index.html>);
   the per-tool guides under that umbrella name the actual
   binaries. The agent must read each per-tool guide for the
   user's installed DOCA version, then confirm with the
   user's `which <tool>` and `<tool> --help`. Do not invent
   binary names from prose.
5. **Capture the env baseline.** Save the DOCA version, the
   BlueField identity, the DPACC version, and the list of
   DPA tool binaries present BEFORE any inspect / profile /
   runtime-debug run. The downstream `## test` and `## debug`
   workflows depend on these four fields.

For the canonical DOCA universal lifecycle that the host-side
`doca-dpa` flow rides on (steps 2-3 above check it from
outside), see
[`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
This skill assumes its preconditions are satisfied; it does not
redefine them.

## build

The DPA tool suite ships as **shipped binaries** alongside the
DOCA install — there is no source tree the external user is
expected to compile, no per-tool build flags, no `meson` or
`make` workflow under this skill.

Routing for nearby "build" questions:

- *"The DPA tool binary isn't there — do I need to build it?"*
  → no. Route to
  [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install).
  The fix is to install (or re-install) DOCA at a version that
  ships the tool, per the per-tool public guide reachable
  through
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
- *"How do I BUILD a DPA application image so these tools have
  something to inspect?"* → compile-time question. That is
  exactly the `doca-dpacc-compiler` tool skill's surface
  (DPACC compile), reachable via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  Then load the produced image via
  [`doca-dpa TASKS.md ## build`](../../libs/doca-dpa/TASKS.md#build)
  + [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure)
  step 5. Do not reach for `doca-dpa-tools` for a compile or
  load problem.
- *"I want to build a tool that wraps a DPA tool's output."*
  → not in scope here per
  [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).
  Read the per-tool public guide for the user's installed
  DOCA version and write the parser against that.

The `## What this skill deliberately does not ship` block in
[`SKILL.md`](SKILL.md) explicitly forbids adding a build recipe
for the DPA tools or shipping wrappers around them; revisit
that policy before changing this section.

## modify

**Do not modify the shipped DPA tool binaries.** They are
NVIDIA-shipped CLIs; there is no documented public way to
change their behavior, output format, or family surface, and
none should be invented.

Routing for nearby "modify" questions:

- *"The output format is inconvenient — can I change it?"* →
  no, not inside this skill. The documented surface (per-tool
  `--help` + per-tool public guide on the user's installed
  DOCA version) is the surface. If the user wants structured
  output, prefer the structured helpers per
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  when present; otherwise treat the documented format as the
  contract and write a parser against your installed version.
- *"Can I patch a DPA tool to add flag X?"* → out of scope for
  external users; this skill is for consumers of the shipped
  tools, not contributors to them.
- *"I need different *information* than the inspection /
  profiling / runtime-debug families surface."* → the question
  is a host-side or DPA-side library question, not a tool
  question. Route to [`doca-dpa`](../../libs/doca-dpa/SKILL.md)
  for host-side, [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md)
  / [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md) for
  DPA-side comms / RDMA, or
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  for the cross-library lifecycle / error patterns.

## run

The DPA tool suite is run by reaching for one of three
documented families — **inspection**, **profiling**, or
**runtime-debug** — per
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
This skill does NOT quote per-tool subcommand strings; the
authoritative surface is the installed `<tool> --help` and the
per-tool public guide reachable via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).

Recommended flow when the user asks the agent to *"see what the
DPA is doing"*:

1. **Reach for the inspection family FIRST.** Always. Confirm
   the tool sees an active DPA on this BlueField, sees the
   loaded `doca_dpa_app`, sees the bound `doca_dpa_thread`(s),
   and lists the kernel entry points the host expects.
   Inspection is the equivalent of running `doca_caps` before
   anything else — see
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   inspection-family row.
2. **Only then reach for profiling.** Once inspection confirms
   the tool can see the user's running workload at all,
   profiling can ask the *"which kernel is the hot one"* /
   *"what is the DPA-side communication pattern"* questions.
   Profiling a workload the inspection family cannot see is
   the wrong order and almost always means the tool is
   attached to the wrong thing.
3. **Reach for runtime-debug LAST, and only on a confirmed
   stuck workload.** Runtime-debug may halt DPA-side execution;
   the host-observed completion stream stops during the halt
   and an unrecovered halt leaves the DPA processor in a
   state the next `doca-dpa` process inherits. Use deliberately
   per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
4. **Capture trace-level structured logs from the host side
   alongside the DPA-side run.** Set `DOCA_LOG_LEVEL=trace`
   for the host program during the DPA-tool session (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability));
   correlating host-side log silence with DPA-side state from
   the tool is the cheapest way to localize where the workload
   is actually stuck.
5. **For exact, current flag inventory and column names**, read
   `--help` on the installed binary for each tool and the
   per-tool public guide for the user's installed DOCA version.
   Do **not** invent flags from generic CLI knowledge — the
   per-tool guide and `--help` are the joint source of truth,
   see [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   for the documented families and
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
   for the per-tool guide URLs.

When recording the run for downstream consumers (the *DPA-side
snapshot* pattern), write down: the DOCA version + DPACC
version, the host platform (host vs BlueField Arm, OS, kernel),
the BlueField identity and DPA-capable axis the host saw via
`doca_caps --list-devs`, the host-side `doca-dpa` state at the
time (loaded image, thread count, kernel under inspection),
and the exact tool invocation + full unredacted output. The
downstream `## debug` workflow depends on those fields.

## test

The DPA tool suite is the **DPA-side validation surface** for a
host-side `doca-dpa` workload that the host claims is running.
The smoke-before-bulk loop is non-optional: inspect ONE running
kernel and confirm the tool can see it BEFORE any profiling
sweep or any runtime-debug attach.

**`## test` is an iterative loop, not a one-shot pass.** Each
iteration narrows either the env-precondition set, the host-side
`doca-dpa` state the tool is observing, the family chosen, or
the kernel under inspection. The loop terminates when (a) the
user has a clean inspection snapshot of the workload they
wanted to introspect AND a profiling or runtime-debug run that
matches the host-side symptom, or (b) the cause has been
narrowed to a layer outside the DPA tool suite (host-side
`doca-dpa` API behavior, DPACC build, BlueField mode, DOCA
install) and escalated to the matching skill.

Iteration shape:

1. **Inspection smoke on ONE running kernel.** With the
   host-side `doca-dpa` flow brought up and a single kernel
   already launched and completing, run the inspection tool
   and confirm the tool reports: an active DPA on this
   BlueField, the loaded `doca_dpa_app`, the bound
   `doca_dpa_thread`(s), and at least one kernel entry point.
   If yes, advance. If no — and host-side `doca-dpa` claims the
   workload is healthy — walk
   [`## debug`](#debug) layer 2 (DPA-runtime-not-active) and
   layer 4 (HART-binding).
2. **Profiling smoke on the same kernel.** Once inspection is
   clean, run the profiling family in its lightest mode against
   the SAME kernel inspection just confirmed. Confirm the tool
   reports a recognizable per-kernel timing / communication
   pattern. If profiling reports nothing despite a clean
   inspection, the workload may not have actually launched yet
   (host-side progress engine bug; route to
   [`doca-dpa TASKS.md ## run`](../../libs/doca-dpa/TASKS.md#run)
   step 3) or the profiling tool's prerequisites are not met
   (re-read the per-tool guide for the user's installed DOCA).
3. **Profiling sweep (if used).** Re-run profiling across all
   kernels in the loaded `doca_dpa_app` only AFTER iterations
   1-2 are clean. Per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   smoke rule, do not start a sweep on a workload the
   inspection family cannot see — the sweep will be a
   coordinated way to discover the same fact later.
4. **Runtime-debug attach (only on a stuck workload).** Reach
   for runtime-debug only when the host-side `doca-dpa` flow
   reports a submitted launch that never completes AND
   iterations 1-2 confirm the kernel IS running on the DPA.
   Capture the DPA-side state, then **resume** before tearing
   down — an unrecovered halt is the failure mode this step
   is most vulnerable to.
5. **Cross-check against the host-side `doca-dpa` flow.** For
   each finding from steps 1-4, confirm whether the host-side
   `doca-dpa` symptom the user opened with is consistent with
   what the DPA side actually shows. Disagreement is itself a
   finding — most commonly the host-side completion queue is
   full silently or the host PE is not being progressed.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Inspection reports no loaded `doca_dpa_app` despite the host claiming the workload is running | The host-side flow has not actually reached the started lifecycle stage for this `doca_dpa`, OR the user is running the tool against a different BlueField than the host program is driving | Re-walk [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure) and confirm WHICH `doca_dev` the host program targeted versus which BlueField the tool is asking about |
| Inspection reports the loaded image but the expected kernel entry point is missing | Compile-time, not runtime / inspect — the DPA-side translation unit `dpacc` compiled does not contain that function | Route to the `doca-dpacc-compiler` tool skill via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools); rebuild the DPA-side image and the host executable that embeds it per the *do not partial-rebuild one side* rule in [`doca-dpa CAPABILITIES.md ## Safety policy`](../../libs/doca-dpa/CAPABILITIES.md#safety-policy) |
| Profiling reports zero events despite a clean inspection and a host claim of a running workload | The host-side `doca-dpa` progress engine is not being progressed, OR the host completion queue is full silently | Walk [`doca-dpa TASKS.md ## run`](../../libs/doca-dpa/TASKS.md#run) step 3 (PE progress) and the *queue-full / drain-rate* row in [`doca-dpa CAPABILITIES.md ## Error taxonomy`](../../libs/doca-dpa/CAPABILITIES.md#error-taxonomy) |
| Runtime-debug attach succeeds but the agent is unsure whether to halt | The user asked "what is the DPA doing?" — that is inspection, not runtime-debug | Detach, return to step 1, do not halt a running workload to answer an inspection-shaped question |
| Tool and host disagree on what is loaded | A version-skew between DOCA + DPACC + the loaded image, or the user is reading a doc for a different DOCA version | Route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) for the four-way match; re-read the per-tool public guide on the user's installed DOCA version |

Loop termination: stop iterating once two consecutive
iterations of the same kind don't change anything — that means
the cause is below the DPA tool suite (host-side `doca-dpa` bug,
DPACC build bug, BlueField mode, NIC firmware). Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured DPA-side snapshot + host-side log + version
state as evidence.

This skill does **not** ship a "test fixture" or pre-recorded
expected output. The expected output is install-, BlueField-,
DOCA-version-, and workload-specific; pinning one would mislead
operators on a different combination. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When a DPA tool returns nothing useful, or returns something
the user did not expect, walk the
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
layers in order. The shape of the diagnosis:

1. **Tool-not-installed (layer 1).** The DPA tool binary the
   user named is not present. Confirm DOCA is installed at a
   version that ships the tool (per the per-tool public guide
   reachable through
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools));
   check `pkg-config --modversion doca-dpa` and the installed
   `dpacc` version per
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   for the partial-install detection (DOCA upgraded, DPACC +
   DPA tools did not). Route install / re-install through
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install).
2. **DPA-runtime-not-active (layer 2).** The tool runs and
   exits 0 but reports no DPA application loaded, no DPA
   execution contexts bound, no kernels running. This is the
   single most common DPA-tool first-touch finding and it is
   almost always *the host-side `doca-dpa` flow has not
   reached the right state*, not a tool bug. Walk
   [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure)
   end-to-end (image loaded, thread created, context started,
   kernel launched) before re-running the tool. If the host
   side claims it is in that state and the tool still sees
   nothing, escalate to BlueField mode per
   [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
   layer 5 (driver).
3. **Kernel-not-loaded (layer 3).** Inspection reports the
   loaded image but the expected kernel entry point is missing.
   This is a compile-time problem in disguise — the DPA-side
   translation unit `dpacc` compiled does not contain that
   function, OR a host-side rebuild against a new DOCA install
   was not paired with a DPA-side rebuild per the *do not
   partial-rebuild one side* rule in
   [`doca-dpa CAPABILITIES.md ## Safety policy`](../../libs/doca-dpa/CAPABILITIES.md#safety-policy).
   Route to the `doca-dpacc-compiler` tool skill via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
4. **HART-binding (layer 4).** A specific DPA execution context
   the user expected is not bound or cannot be attached.
   Common cause: the host's `doca-dpa` flow created fewer
   `doca_dpa_thread` objects than the user thought, or the
   thread the user named was already torn down per the
   lifecycle ordering rule in
   [`doca-dpa CAPABILITIES.md ## Safety policy`](../../libs/doca-dpa/CAPABILITIES.md#safety-policy).
   Re-walk the parent skill's configure step 5.
5. **Permission (layer 5).** The tool fails or refuses to
   attach / read with a permission-class error. Read the
   per-tool public guide for the user's installed DOCA version
   to confirm the documented privilege required; route the
   OS-side privilege fix through
   [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure).
6. **Version (layer 6).** A column or flag the user is reading
   about in a doc page is not present in the tool's actual
   output / `--help` on this install. Route to
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   for the four-way match check (DOCA + DPACC + tool +
   public guide all on the same version); the *installed*
   `--help` wins.
7. **Cross-cutting (layer 7).** The tool runs cleanly against
   a real workload but the user's question is really a
   host-side `doca-dpa` API question, a cross-library
   `DOCA_ERROR_*` taxonomy question, or a generic driver /
   link / runtime issue unrelated to DPA introspection. Route
   to [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug)
   for host-side; to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   for the cross-cutting ladder; to
   [`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug)
   for Core-context lifecycle patterns.

In every case: **quote what the tool said.** Do not paraphrase
DPA-side findings, do not reformat column data into prose, do
not "summarize" inspection output. The whole point of the DPA
tool suite in a debug context is to break the agent out of
inferring DPA-side state from host-side behavior.

## Deferred task verbs

The verbs below are not DPA-tool-suite work and should be
routed out before the agent does any of them under this
skill's name.

- **install** ⇒ [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)
  (and [`doca-setup TASKS.md ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). The DPA tools are
  shipped by the install; this skill does not own the install
  workflow.
- **compile a DPA application image** ⇒ the `doca-dpacc-compiler`
  tool skill (compile-time DPA toolchain), reachable through
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  The DPA tools INSPECT a compiled image; they do not produce
  one. Misrouting a *"symbol not in the loaded image"* error
  here instead of to DPACC is the canonical compile-vs-runtime
  confusion.
- **load / launch / drain DPA kernels from the host** ⇒
  [`doca-dpa`](../../libs/doca-dpa/SKILL.md). The host-side
  lifecycle that the DPA tools observe is owned by the
  `doca-dpa` skill.
- **DPA-side kernel-internal questions (intra-DPA messaging,
  DPA-side RDMA)** ⇒
  [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) and
  [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md). When
  a DPA-tool finding is *"the kernel is stuck on a comms
  receive"* or *"the kernel issued a verbs op that never
  completed"*, the interpretation lives in those skills, not
  here.

## Command appendix

`doca-dpa-tools`-specific invocations the verbs above reach
for. Every row is a class — the agent must not invent flags
beyond `--help` on the installed binary and the per-tool
public guide on the user's installed DOCA version. The
three-family symmetry below is the load-bearing piece; one
worked example class per family is shown.

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

| Purpose (class) | Invocation shape | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Confirm DOCA + DPACC installed and matched | `pkg-config --modversion doca-dpa`; installed `dpacc` version; `doca_caps --version` | [`## configure`](#configure) step 1 | All three agree per the DOCA Compatibility Policy; disagreement = partial install, route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) |
| Confirm the BlueField exposes its DPA | `doca_caps --list-devs` (per [`doca-caps TASKS.md ## run`](../doca-caps/TASKS.md#run)) | [`## configure`](#configure) step 2 | At least one BlueField entry shows the DPA capability; absence = BlueField mode / generation issue, route to [`doca-setup`](../../doca-setup/SKILL.md) |
| Discover which DPA tool binaries are present | `which <tool>` and `<tool> --help` for each per-tool binary listed in the per-tool public guide on the user's installed DOCA version | [`## configure`](#configure) step 4 | Each binary the user needs is on `$PATH` and prints a `--help` that the per-tool public guide describes; missing = layer 1 (tool-not-installed) per [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy) |
| Inspection family — what is loaded / bound right now | The inspection tool the per-tool public guide names (read the binary's `--help` for the actual invocation; the agent does NOT quote a fabricated subcommand) | [`## run`](#run) step 1; [`## test`](#test) iteration 1 | Reports an active DPA, the loaded `doca_dpa_app`, the bound `doca_dpa_thread`(s), and the kernel entry points the host expects; silence = layer 2 (DPA-runtime-not-active) |
| Profiling family — per-kernel timing / DPA-side comms patterns | The profiling tool the per-tool public guide names (read the binary's `--help` for the actual invocation) | [`## run`](#run) step 2; [`## test`](#test) iteration 2 | Reports a recognizable per-kernel pattern for the kernel inspection just confirmed; silence on a kernel inspection saw = host-side progress engine bug, route to [`doca-dpa TASKS.md ## run`](../../libs/doca-dpa/TASKS.md#run) step 3 |
| Runtime-debug family — attach / halt / resume from outside the DPA | The runtime-debug tool the per-tool public guide names (read the binary's `--help` for the actual invocation) | [`## run`](#run) step 3; [`## test`](#test) iteration 4 | Attaches to a confirmed-stuck DPA thread; the agent **resumes** before tearing down per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) |
| Capture host-side trace alongside the DPA-side tool run | `DOCA_LOG_LEVEL=trace ./<host_binary>` (see [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability)) | [`## run`](#run) step 4 | A trace-level line on every host-side `doca-dpa` lifecycle transition and every launch submit; correlated with the DPA-side tool output to localize the stuck layer |
| Save a DPA-side snapshot for the host-side debug ladder | Redirect each family's invocation's output to a file alongside the host-side trace; record DOCA + DPACC + BlueField + kernel-under-inspection identity | [`## test`](#test) iteration 5; [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug) layer 5 | The saved snapshot is consumed by the host-side debug ladder as ground truth instead of inferred DPA-side state |

Three cross-cutting rules for this appendix:

- **Never invent a DPA tool flag.** The installed `--help` and
  the per-tool public guide on the user's installed DOCA
  version are the joint contract; prose-derived flags are the
  most common hallucination failure for this skill.
- **Inspect before profile; profile before runtime-debug.** The
  family order in [`## run`](#run) is non-optional; reversing
  it produces confident-looking but wrong findings.
- **Cross-link instead of duplicate.** Cross-cutting commands
  (`pkg-config --modversion`, `dmesg`, `mlxconfig -d <bdf> q`)
  live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  this appendix names only DPA-tool-suite-specific invocation
  classes.
