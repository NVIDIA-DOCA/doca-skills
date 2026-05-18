# DOCA PCC Counter Tool — Tasks

**Where to start:** The verbs that carry real workflow content
for this tool are `## configure`, `## run`, `## test`, and
`## debug`. The other two (`build`, `modify`) are documented
routing stubs because the counter tool is shipped pre-built and
read-only — the user does not compile it and does not patch it.
The `## test` verb is the smoke-before-bulk loop (snapshot ONE
finite-and-changing counter before any sweep), not a one-shot
pass — see the eval-loop overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent through
the six task verbs every artifact in this bundle exposes
(`configure / build / modify / run / test / debug`), explicitly
defers task verbs that do not belong here, and ends with the
`Command appendix` honoring the bundle's
[`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
preamble.

For the cross-library DOCA patterns layered under everything
below (the universal Core lifecycle, the cross-library
`DOCA_ERROR_*` taxonomy, the modify-a-shipped-sample workflow),
see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
For the host-side custom-PCC control surface that loads the
kernel whose counters this tool inspects, see
[`doca-pcc`](../../libs/doca-pcc/SKILL.md).

## configure

Goal: confirm the env preconditions the PCC Counter Tool needs to
return anything useful — DOCA installed, the `doca-pcc` library
present, a custom Programmable Congestion Control kernel actually
loaded against the target BlueField port via the host-side
`doca-pcc` flow, and the counter tool's version aligned with
that library — BEFORE reaching for any list / snapshot / watch
invocation.

Steps the agent should walk the user through, in order:

1. **Identify the host DOCA version FIRST.** Surface
   `pkg-config --modversion doca-pcc`, `pkg-config --modversion
   doca-common`, and `doca_caps --version` per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
   Anything the agent later says about *"is this counter
   available on this install"* / *"does this column belong on
   this train"* depends on this version being captured up front;
   without it the downstream debug ladder has nothing to anchor
   against. If DOCA is not installed at all, route to
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)
   (or [`doca-setup TASKS.md ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path) before doing
   anything else.
2. **Confirm the host-side `doca-pcc` library is installed AND
   a custom PCC kernel is actually loaded against the target
   BlueField port.** Per the pairing rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the counter tool inspects what the running kernel emits; it
   does not load or run a kernel. Walk
   [`doca-pcc TASKS.md ## configure`](../../libs/doca-pcc/TASKS.md#configure)
   end-to-end (image loaded into a `doca_pcc` Core context, the
   context started, the algorithm live on the port) BEFORE
   reaching for the counter tool. If the host side has not
   reached the started lifecycle stage, the counter tool will
   correctly report nothing for the kernel-defined family — go
   back to `doca-pcc` first; that is not a counter-tool finding.
3. **Confirm the counter tool ↔ `doca-pcc` library version
   match via doca-version.** Per the PCC-Counter-Tool-specific
   overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   capture BOTH the counter tool's own `--version` AND
   `pkg-config --modversion doca-pcc` AND `doca_caps --version`,
   and cross-check via
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
   Disagreement is the partial-install hazard — the column set
   the tool prints and the kernel-defined counter names it
   surfaces may silently differ from what the library actually
   exposed at runtime — and is routed through
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 BEFORE any counter reading is quoted as authoritative.
4. **Confirm the attached port actually has RDMA / RoCE traffic
   to modulate.** Per the pairing-precondition row in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   a custom PCC kernel on an idle port will keep its
   algorithm-defined counters at zero — that is correct
   behaviour, not a tool bug. Route to
   [`doca-rdma`](../../libs/doca-rdma/SKILL.md) if the port is
   idle; do NOT diagnose *"counter stuck at zero"* without first
   confirming there is traffic.
5. **Capture the configure baseline.** Save DOCA version,
   counter-tool `--version`, `doca-pcc` library `--modversion`,
   BlueField identity, the target port the host-side `doca-pcc`
   loaded the kernel against, and the side (host vs BlueField
   Arm) the tool will run on, BEFORE any list / snapshot / watch
   call. The downstream `## test` and `## debug` workflows
   depend on these fields.

The PCC Counter Tool itself takes **no configuration of its
own** — there is no admin tool config file, no daemon, no
required environment knob the public guide documents beyond
what `doca-pcc` and the BlueField already need. Configuration
*here* means *confirming the preconditions the tool depends
on*, not setting tool-side options.

## build

The PCC Counter Tool is **shipped pre-built** as part of every
DOCA install that includes the PCC counter tooling subpackage
(`/opt/mellanox/doca/tools/` per the per-tool public guide on
the user's installed DOCA version). There is no source tree the
external user is expected to compile, no build flags, no
`meson` or `make` workflow under this skill — and the agent
MUST NOT recompile or "patch then build" the shipped binary.

Routing for nearby "build" questions:

- *"The counter-tool binary isn't there — do I need to build
  it?"* → no. Route to
  [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)
  (or [`doca-setup TASKS.md ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). Per-tool
  availability — i.e. whether the PCC counter tool ships on a
  given DOCA version at all — is documented in the public DOCA
  PCC Counter Tool guide reachable via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools);
  confirm against the user's installed DOCA version.
- *"How do I BUILD the kernel whose counters this tool is
  supposed to report?"* → that is the host-side + DPA-side
  compile path for the user's custom PCC algorithm. Route the
  host-side build through
  [`doca-pcc TASKS.md ## build`](../../libs/doca-pcc/TASKS.md#build);
  route the DPA-side translation unit (the algorithm body
  `dpacc` compiles into the `doca_pcc_app`) through the
  `doca-dpacc-compiler` tool skill reachable via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  Both halves rebuild together per the *do not partial-rebuild
  one side* rule in
  [`doca-pcc CAPABILITIES.md ## Safety policy`](../../libs/doca-pcc/CAPABILITIES.md#safety-policy).
- *"Can I patch the counter tool to add a flag / column?"* →
  out of scope; this skill is for consumers of the shipped
  read-only tool, not contributors to it. The
  [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship)
  block explicitly forbids adding a build recipe or wrappers
  here; revisit that policy before changing this section.

## modify

**Do not modify the shipped PCC Counter Tool binary.** It is
an NVIDIA-shipped read-only diagnostic CLI; there is no
documented public way to change its behavior, output format,
counter column set, or invocation surface, and none should be
invented. What the user actually wants to modify is almost
always either the *running kernel* or the *watch parameters of
a tool invocation*, both of which are routed out:

- *"I need a counter the tool isn't reporting"* → that is a
  modify of the **kernel**, not of the tool. The set of
  kernel-defined counters at each granularity is set by the
  DPA-side algorithm body the user wrote (per
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  the kernel-defined family is *kernel-defined plus
  tool-documented*). To add a counter the user must update
  their DPA-side translation unit to declare and emit it AND
  rebuild BOTH the host executable AND the DPA-side image per
  the partial-rebuild rule in
  [`doca-pcc CAPABILITIES.md ## Safety policy`](../../libs/doca-pcc/CAPABILITIES.md#safety-policy).
  Route to
  [`doca-pcc TASKS.md ## modify`](../../libs/doca-pcc/TASKS.md#modify)
  for the algorithm-side change and to the
  `doca-dpacc-compiler` tool skill via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
  for the DPA-side compile.
- *"I want to change the watch interval / the sample window /
  which counter the watch follows"* → that is a modify of the
  **tool invocation**, not of the binary. The documented watch
  / interval-sample family is named in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes);
  the exact flag spelling comes from `--help` on the installed
  binary and the public DOCA PCC Counter Tool guide via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  The agent treats *"modify the invocation, not the binary"*
  as the operating mode, mirroring the same posture as
  [`doca-bench TASKS.md ## modify`](../doca-bench/TASKS.md#modify).
- *"The output format is inconvenient — can I change it?"* →
  no, not inside this skill. If the user wants structured
  output, the right answer is to prefer the structured helpers
  per
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  when present, otherwise treat the documented textual format
  as the contract on the user's installed version; even the
  parser is out of scope per
  [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## run

The PCC Counter Tool exposes one functional family — **read-only
counter inspection** — at the three granularities documented in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
(per-port / per-flow / per-kernel). The canonical flow the
agent walks the user through when the user asks *"what are the
PCC counters on this port doing?"* is
**list → snapshot → watch → diff**, in that order, and this is
the load-bearing rhythm for every invocation in this skill:

1. **Confirm the configure baseline.** Per [`## configure`](#configure)
   above; without DOCA version + counter-tool version +
   `doca-pcc` library version + a confirmed-loaded kernel, the
   next four steps cannot be interpreted.
2. **List available counters at the target granularity FIRST.**
   Always. Per
   [`CAPABILITIES.md ## Pattern overview`](CAPABILITIES.md#pattern-overview)
   pattern 1, the enumeration is the source of truth for *which
   counter identifiers actually exist on the user's install +
   kernel right now* — the agent does NOT quote a counter name
   from prose without seeing it in this enumeration. Per the
   class-shape rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the exact subcommand and flag inventory comes from `--help`
   on the installed binary and the public DOCA PCC Counter Tool
   guide reached via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools),
   not from agent memory.
3. **Snapshot ONE named counter** picked from the enumeration
   in step 2 — the cheapest *"is this kernel actually doing
   anything"* check per
   [`CAPABILITIES.md ## Pattern overview`](CAPABILITIES.md#pattern-overview)
   pattern 2. Always pick a counter the public guide documents
   as advancing under live traffic (typically a per-port
   aggregate first, then drill in). Confirm the value is finite
   AND changing across two back-to-back snapshots; a pinned
   value at zero or at the type's maximum is itself a finding
   (route to [`## debug`](#debug) layer 2 or layer 6).
4. **Expand to a per-flow / per-port / per-kernel sweep ONLY
   after the single-counter snapshot reads cleanly.** Per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   the three granularities have an explicit *per-port first,
   per-flow after, per-kernel for kernel-internal
   confirmation* ordering — drilling into per-flow before the
   per-port aggregate has shown a change worth attributing is
   the wrong order and almost always wastes the operator's
   time.
5. **Watch with a short interval window for change-over-time
   signals.** Per
   [`CAPABILITIES.md ## Pattern overview`](CAPABILITIES.md#pattern-overview)
   pattern 3, sampling at an interval too coarse for the
   underlying change rate aliases the signal; sampling at an
   interval finer than the counter's documented update
   granularity wastes CPU without surfacing more. Quote back
   to the user *why* the chosen interval was chosen (e.g.
   *"because the algorithm reports per second and we want
   sub-second granularity"*) so the user can challenge it if
   the framing is wrong.
6. **Diff two captured snapshots** — a *before* snapshot, then
   a controlled change (host-side parameter retune, traffic
   shift, or no change at all to confirm baseline noise), then
   an *after* snapshot — and quote the diff line by line per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   diff-before-decide rule. This is the load-bearing artifact
   the host-side [`doca-pcc TASKS.md ## debug`](../../libs/doca-pcc/TASKS.md#debug)
   layer 5 (runtime) and the cross-cutting
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   ladder consume.
7. **For the exact subcommand inventory, flag spelling, counter
   column names, and per-counter semantics** read `--help` on
   the installed binary AND the public DOCA PCC Counter Tool
   guide via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
   Do **not** invent any of these from generic CLI knowledge;
   they are install-, version-, and kernel-defined.

When recording the run for downstream consumers, write down:
the DOCA version (per [`doca-version`](../../doca-version/SKILL.md)),
the side the tool was run on (host vs BlueField Arm), the
exact command line used, the target port the host-side
`doca-pcc` attached the kernel to, the granularity used, and
the full unredacted output of each list / snapshot / watch /
diff step. The downstream `## test` and `## debug` workflows
depend on those six fields.

## test

The PCC Counter Tool is **a measurement tool**, so its `## test`
verb is about *testing the measurement* — i.e. confirming the
snapshot or sweep is meaningful — not unit-testing the binary
itself.

**`## test` is an iterative loop, not a one-shot pass.** Every
controlled change on the system the counter tool observes (a
host-side `doca-pcc` parameter retune, a traffic shift on the
attached port, a kernel reload, an interval change in the
watch) re-opens the smoke. Treating it as a one-shot pass is
the failure mode this loop replaces, and the same shape as
[`doca-bench TASKS.md ## test`](../doca-bench/TASKS.md#test)
on the bench side.

The smoke-before-bulk shape:

1. **Single-counter smoke — finite-and-changing on ONE named
   counter.** Pick one counter from the enumeration in
   [`## run`](#run) step 2 that the public guide documents as
   advancing under live traffic (typically a per-port
   aggregate). Snapshot it twice back-to-back; the value must
   be FINITE (not pinned at zero, not pinned at the type's
   maximum) and CHANGING (the two snapshots must differ in
   the documented direction). If yes, advance to step 2. If
   no — and the configure baseline confirmed a running kernel
   and live traffic — walk
   [`## debug`](#debug) layers 2-4 before any sweep.
2. **Sweep correctness check — sum-of-parts equals whole.**
   Pick a per-port aggregate counter the public guide
   documents as the sum of a per-flow or per-kernel
   breakdown; snapshot both granularities back-to-back; the
   per-flow / per-kernel breakdown summed across the
   reported entries should agree with the per-port aggregate
   within the documented sampling skew. A large
   disagreement is a finding (route to [`## debug`](#debug)
   layer 4 or 6); a small one within documented skew is the
   expected behaviour.
3. **Aliasing check — interval too short surfaces noise, not
   signal.** Watch the same counter at the shortest interval
   the user is considering, then at a longer interval per
   [`## run`](#run) step 5. If the short-interval series
   shows wild swings the long-interval series flattens out,
   the short interval is sampling below the counter's update
   granularity and is producing measurement noise — not a
   tuning signal — and the agent MUST refuse to translate it
   into a CC tuning decision per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
4. **Cross-check against the host-side `doca-pcc` report
   stream.** Per
   [`CAPABILITIES.md ## Pattern overview`](CAPABILITIES.md#pattern-overview)
   the counter tool is one half of the picture; the host-side
   report stream per
   [`doca-pcc CAPABILITIES.md ## Observability`](../../libs/doca-pcc/CAPABILITIES.md#observability)
   is the other half. They MUST agree on whether the kernel
   is doing anything; disagreement is itself a finding.

Eval-loop overlay (rows apply to every counter-tool session,
not just one kernel × port):

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Single-counter smoke reads pinned at zero on a port with live traffic | Either no PCC kernel is actually loaded against THIS port, or the host-side `doca-pcc` has not reached the started lifecycle stage, or the wrong granularity was picked first | Re-verify the configure baseline against [`doca-pcc TASKS.md ## configure`](../../libs/doca-pcc/TASKS.md#configure); confirm the BlueField device the host targeted matches the port the tool is asking about; fall back to per-port granularity per [`## run`](#run) step 4 |
| Single-counter smoke reads pinned at the type's maximum | Saturation — the counter wrapped or hit a ceiling per [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy) layer 6 | Re-read the counter's documented type and wrap behaviour from the public guide; do NOT translate a saturated reading into a CC tuning decision |
| Sum-of-parts and whole disagree by far more than the documented sampling skew | Either a counter-not-exposed-by-kernel finding, a version mismatch between tool and library, or a sampling artifact (the per-flow snapshot and the per-port snapshot were taken too far apart to be comparable) | Route to [`## debug`](#debug) layer 4 (counter-not-exposed-by-kernel) then layer 6 (sampling); confirm via [`doca-version`](../../doca-version/SKILL.md) overlay that tool and library are on the same DOCA train |
| Short-interval watch looks noisy, long-interval watch looks flat | Aliasing — the short interval is sampling below the counter's update granularity per [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy) layer 6 | Lengthen the interval to the documented update granularity; if the user genuinely wants sub-update-granularity signal, the answer is a different observability surface, not a faster sample |
| Counter changes; host-side report stream is silent | Host PE not being progressed OR queue full silently; cross-check via [`doca-pcc TASKS.md ## run`](../../libs/doca-pcc/TASKS.md#run) step 3 | Walk the parent skill's progress-engine row; do NOT translate the on-wire counter delta into a tuning move while the host-side surface is unreliable |
| Two consecutive same-shape iterations don't change anything | Cause is below the counter tool (kernel design, BlueField firmware, NIC firmware, DOCA install) | Escalate to [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) with the captured before / after snapshot pair plus the host-side report stream as evidence |

Loop termination: stop iterating once two consecutive
iterations of the same kind don't change the picture — the
answer is now *"this is what the running kernel is doing on
this DOCA version / firmware / driver stack / port"*. Escalate
cross-version or cross-host comparisons to
[`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test)
or the cross-cutting ladder in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured baselines as evidence.

This skill does **not** ship a "test fixture" or pre-recorded
expected counter output. The expected output is install-,
version-, device-, kernel-, and traffic-state-specific; pinning
one would mislead operators on a different combination. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When the PCC Counter Tool prints nothing useful, prints a value
that does not look defensible, or surfaces a column the user
does not recognize, walk the layered diagnosis in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
IN ORDER. The shape of the diagnosis:

1. **Tool-not-installed.** The counter-tool binary does not
   exist where the per-tool public guide says it should. Confirm
   DOCA is installed (e.g. `pkg-config --modversion doca-common`,
   `cat /opt/mellanox/doca/applications/VERSION`) and that the
   install profile included the PCC counter tooling subpackage
   on the user's DOCA version per the public guide via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
   Route to
   [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)
   if not. Do NOT recommend a wrapper script that simulates
   the tool.
2. **No-PCC-kernel-loaded.** The tool runs and exits 0 but
   reports no algorithm-defined counters. This is the
   single most common PCC-Counter-Tool first-touch finding
   and is almost always *the host-side `doca-pcc` flow has
   not reached the started lifecycle stage on this port*,
   not a tool bug. Walk
   [`doca-pcc TASKS.md ## configure`](../../libs/doca-pcc/TASKS.md#configure)
   end-to-end (image loaded, context started) before
   re-running the tool. If the host side claims it is in
   that state and the tool still sees nothing, escalate to
   layer 3.
3. **Wrong-version-with-PCC-library.** The tool runs but the
   counter set / column set / kernel-identifier shape
   disagrees with what the host-side `doca-pcc` library
   actually exposed at runtime — the partial-install hazard
   per
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
   Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 and reinstall consistently; do NOT paper over by
   quoting one side's columns as authoritative.
4. **Counter-not-exposed-by-kernel.** The tool runs, the
   kernel is loaded and started, the per-port baseline is
   visible, but the specific kernel-defined counter the
   user asked about is NOT in the enumeration. This is a
   build-side question in disguise — the DPA-side
   translation unit does not declare / emit that counter.
   Route to
   [`doca-pcc TASKS.md ## modify`](../../libs/doca-pcc/TASKS.md#modify)
   for the algorithm-side change and to the
   `doca-dpacc-compiler` tool skill via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
   for the DPA-side compile; both sides rebuild together
   per the partial-rebuild rule in
   [`doca-pcc CAPABILITIES.md ## Safety policy`](../../libs/doca-pcc/CAPABILITIES.md#safety-policy).
5. **Permission.** The tool runs but reports it cannot read
   the requested counter set because the invoking user lacks
   the privileges the public guide requires (typically sudo
   on the BlueField Arm side, or membership in the standard
   mlnx-style group). The tool's own message is ground
   truth; re-run with the documented privileges via
   [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure),
   do not bypass the check.
6. **Sampling-aliasing-or-saturation.** The tool runs, the
   counter is exposed, the value is finite — but misleading.
   Two sub-cases per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 6: aliasing (interval too coarse) or saturation
   (counter pinned at the type's maximum). The agent MUST
   NOT translate either case into a CC tuning decision; the
   fix is to re-sample at a finer interval (for aliasing) or
   to re-read the counter's documented type and wrap
   behaviour from the public guide (for saturation), per
   [`## test`](#test) eval-loop.
7. **Version.** A flag, subcommand, or counter column the
   user is reading about in a doc page is not present in the
   tool's actual output / `--help` on this install. Route to
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   for the four-way match check (DOCA + DPACC + counter
   tool + public guide all on the same version); the
   *installed* `--help` wins.
8. **Cross-cutting.** The tool runs cleanly against a real
   loaded kernel, the version four-way match passes, the
   privileges are documented — and the user's question is
   really about the host-side `doca-pcc` API behaviour, the
   cross-library `DOCA_ERROR_*` taxonomy, the BlueField
   firmware custom-PCC slot, the BlueField mode, or generic
   driver / link / runtime failures unrelated to PCC
   counters. Route to
   [`doca-pcc TASKS.md ## debug`](../../libs/doca-pcc/TASKS.md#debug)
   for host-side; to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   for the cross-cutting ladder; to
   [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
   for the env-side / firmware-side layers.

In every case: **quote what the tool said.** Do not
paraphrase counter output, do not reorder columns, do not
summarize a snapshot into prose. The whole point of
inspecting counters before recommending a CC tuning move is
to break the agent out of the inference-from-symptom trap;
paraphrasing the snapshot is exactly the failure mode this
skill is here to prevent, and the load-bearing reason the
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
quote-do-not-paraphrase rule exists.

## Deferred task verbs

The verbs below are not PCC Counter Tool work and should be
routed out before the agent does any of them under this
skill's name.

- **install** ⇒
  [`doca-setup TASKS.md ## install`](../../doca-setup/TASKS.md#install)
  (and
  [`doca-setup TASKS.md ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). The counter tool
  is shipped by the install; this skill does not own the
  install workflow.
- **per-kernel design / writing a custom PCC algorithm body**
  ⇒ [`doca-pcc`](../../libs/doca-pcc/SKILL.md) (host-side
  load + control surface) plus the public DOCA PCC
  programming guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  Algorithm design is a research / domain question; this
  skill captures evidence about a running algorithm, it does
  not design one.
- **fleet-wide congestion-control orchestration and
  multi-BlueField CC tuning** ⇒ out of scope for this skill
  and reserved for the operator-tooling surface a future
  platform skill will own. Custom PCC affects on-wire
  behaviour for an entire BlueField port, so any decision
  derived from a counter reading must go back through the
  user's own domain analysis per
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy);
  this skill refuses to translate evidence into a fleet-wide
  tuning move.
- **long-term retention and analytics on PCC counters** ⇒
  not a counter-tool feature. The DOCA Telemetry Service
  (DTS) is the documented telemetry / analytics surface;
  routing belongs in
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
  This skill is for read-only point-in-time inspection plus
  before / after diff; it does not own retention.

## Command appendix

PCC Counter Tool-specific invocations the verbs above reach
for. Every row is a CLASS — the agent MUST not invent
subcommand names, flag strings, or counter column names
beyond `--help` on the installed binary and the public DOCA
PCC Counter Tool guide via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
The list → snapshot → watch → diff symmetry is the
load-bearing piece; one worked-example class per step is
shown.

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
| Detect the counter-tool binary on this install | The documented binary path the per-tool public guide names on the user's installed DOCA version, plus `--help` on it (subcommand / flag inventory comes from here, not from prose) | [`## configure`](#configure) step 1; [`## debug`](#debug) layer 1 | The binary is present where the public guide documents it and `--help` prints the documented inventory the agent uses as the only source of truth for subcommand and flag names |
| Confirm counter-tool version against the `doca-pcc` library | The counter tool's documented `--version` invocation, cross-checked with `pkg-config --modversion doca-pcc` and `doca_caps --version` per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure) | [`## configure`](#configure) step 3; [`## debug`](#debug) layer 3 | All three strings agree against the DOCA Compatibility Policy; disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2) |
| List available counters at the target granularity | The documented list-counters subcommand on the side (host or BlueField Arm) the public guide names as preferred for the chosen granularity; flag spelling re-confirmed against `--help` on the installed binary | [`## run`](#run) step 2; [`## test`](#test) iteration 1 | Exit 0; the enumeration includes the counter identifiers the agent expects to drill into, and the agent uses ONLY identifiers that appear in this listing for the next steps |
| Snapshot a single named counter | The documented snapshot / single-read subcommand against ONE counter identifier from the enumeration, captured once-then-once again back-to-back | [`## run`](#run) step 3; [`## test`](#test) iteration 1 | Exit 0; the two back-to-back values are FINITE and CHANGING in the direction the public guide documents for live traffic; pinned-at-zero / pinned-at-max are findings, not healthy reads |
| Watch a counter over an interval window | The documented watch / sample-over-time subcommand against the same counter identifier, with an interval long enough to be above the counter's documented update granularity per [`CAPABILITIES.md ## Pattern overview`](CAPABILITIES.md#pattern-overview) pattern 3 | [`## run`](#run) step 5; [`## test`](#test) iteration 3 | The series advances monotonically (for counters the public guide documents as monotonic) or oscillates within the documented range (for counters the public guide documents as gauges); short-interval noise that flattens on the longer interval is aliasing per [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy) layer 6 |
| Diff two captured snapshots | Two redirected snapshot outputs (`> before.txt`, *controlled change*, `> after.txt`, then a textual diff) with the four-tuple context (DOCA version + tool version + library version + port identity) attached | [`## run`](#run) step 6; [`## debug`](#debug) layer 6 | The diff isolates the column(s) the controlled change was supposed to affect; columns unrelated to the controlled change are unchanged within documented sampling skew; the captured pair is the evidence the cross-cutting debug ladder consumes |
| Route to the cross-cutting debug ladder | Save the before / after diff plus the host-side report stream and hand off to [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) with the captured four-tuple | [`## debug`](#debug) layer 8 | The downstream ladder consumes a captured snapshot pair plus the host-side report stream, not a paraphrased summary; the agent surfaces the documented binary / subcommand and `--help` invocation rather than quoting strings from memory |

Three cross-cutting rules for this appendix:

- **Never invent a subcommand, flag, or counter column name.**
  `--help` on the installed binary plus the public DOCA PCC
  Counter Tool guide via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
  are the joint contract; prose-derived counter names are the
  most common hallucination failure for this skill, and the
  one with the highest downstream blast radius because a
  misread counter can drive a destabilizing CC tuning move
  per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- **List → snapshot → watch → diff is non-optional.** Every
  row above presumes the row above it succeeded first; running
  a watch without a prior single-counter snapshot, or quoting
  a diff without a captured before / after pair, is exactly
  the failure mode this skill is here to prevent.
- **Cross-link instead of duplicate.** Cross-cutting commands
  (`pkg-config --modversion`, `dmesg`, `mlxconfig -d <bdf> q`,
  `doca_caps --list-devs`) live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix)
  and
  [`doca-setup TASKS.md ## Command appendix`](../../doca-setup/TASKS.md#command-appendix);
  this appendix names only PCC Counter Tool-specific
  invocations on top.

## Cross-cutting

A few rules that apply across every verb in this file,
restated here so they are visible at the point of action and
not buried in [`SKILL.md`](SKILL.md):

- The **public DOCA PCC Counter Tool guide** plus the
  installed `--help` are the joint source of truth. When they
  disagree (e.g. a column landed in a release this skill was
  not written against), the *installed* `--help` wins for the
  user's actual run.
- The **read-only operations are safe**; the **downstream CC
  tuning decisions they inform are NOT**. The agent must
  surface this asymmetry before recommending any tuning move,
  and gate every tuning move on a captured before / after
  diff per [`## run`](#run) step 6 and
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- **Quote, do not paraphrase.** The counter output is the
  artifact the host-side
  [`doca-pcc TASKS.md ## debug`](../../libs/doca-pcc/TASKS.md#debug)
  ladder and the cross-cutting
  [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
  ladder consume; reformatting it loses fidelity that the rest
  of the bundle's procedures depend on, and is the canonical
  way stale evidence ends up justifying a destabilizing
  tuning move.
- This skill **assumes a healthy DOCA install** (or the public
  NGC DOCA container) AND a host-side
  [`doca-pcc`](../../libs/doca-pcc/SKILL.md) flow already at
  the started lifecycle stage on the target port. If either
  is in doubt, route there first before running anything in
  this appendix.
