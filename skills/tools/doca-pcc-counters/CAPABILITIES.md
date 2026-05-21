# DOCA PCC Counter Tool — Capabilities

**Where to start:** The tool is a single read-only diagnostic
CLI; the pattern overview below names the recurring counter-tool
questions. Pick the pattern first, then drill into the H2 that
owns the substance. For the *how* of executing each pattern,
jump to [TASKS.md](TASKS.md). For the host-side custom-PCC
control surface that loads the kernel whose counters this tool
reports, see
[`doca-pcc CAPABILITIES.md`](../../libs/doca-pcc/CAPABILITIES.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents
*what counters the tool reports*, *at which granularities*,
*what versions and environments it ships in*, *the layered
error surface*, *its observability role inside `doca-pcc`'s
host-side debug ladder*, and *the high-stakes safety posture*
that gates any tuning decision behind a captured before / after
diff. For step-by-step invocations and the smoke-before-bulk
workflow, see [`TASKS.md`](TASKS.md).

## Pattern overview

Every PCC Counter Tool question this skill teaches resolves
into one of SIX patterns. The patterns are CLASSES — they
apply across every DOCA install that ships the tool, every
BlueField generation, and every custom-PCC kernel that
[`doca-pcc`](../../libs/doca-pcc/SKILL.md) brought up.

| Counter-tool pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Enumerate available counters | List every PCC counter the tool can see for the BlueField port the user is reasoning about — so the agent refers to real counter identifiers, not invented ones | [`## Capabilities and modes`](#capabilities-and-modes) counter-enumeration row + [TASKS.md ## run](TASKS.md#run) step 2 |
| 2. Snapshot a single counter | Read one named counter once and confirm the value is finite and changing — the cheapest possible *"is this kernel actually running"* check | [`## Capabilities and modes`](#capabilities-and-modes) snapshot row + [TASKS.md ## test](TASKS.md#test) iteration 1 |
| 3. Watch a counter over an interval | Sample one or a small set of counters across a window — for change-over-time signals (rate-update events, drop counts, queue depths the public guide documents) without aliasing | [`## Capabilities and modes`](#capabilities-and-modes) watch row + [TASKS.md ## test](TASKS.md#test) iteration 2 |
| 4. Diff before / after a tuning attempt | Capture a snapshot, allow a controlled change (host-side parameter retune, traffic shift), capture a second snapshot, diff the two — the only safe shape for any custom-PCC tuning decision | [`## Safety policy`](#safety-policy) diff-before-decide rule + [TASKS.md ## debug](TASKS.md#debug) layer 6 |
| 5. Pair the tool with the host-side `doca-pcc` flow | Every counter finding is about a kernel the host-side `doca-pcc` library loaded; bring `doca-pcc` up FIRST, then introspect its counters | [`## Capabilities and modes`](#capabilities-and-modes) parent-skill rule + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 6. Diagnose missing / silent / saturated output | Map symptom (empty enumeration, non-changing value, value pinned at the type's max, permission denied, version mismatch) to the right layer before any code or tuning change | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Read-only, but high-stakes.** Enumeration / snapshot /
  watch / diff are all side-effect-free; the tool does not
  change the running kernel or the BlueField port. The
  high-stakes part is what the user does NEXT — a
  congestion-control tuning decision derived from a misread
  counter can destabilize a fleet of nodes that share the
  same fabric. The agent must always gate any tuning
  recommendation on a captured before / after diff per
  [`## Safety policy`](#safety-policy), not on a single
  reading.
- **The counter tool is one half of the picture.** The other
  half is the host-side `doca-pcc` API per
  [`doca-pcc CAPABILITIES.md ## Observability`](../../libs/doca-pcc/CAPABILITIES.md#observability)
  (host-side reports surfaced by the running algorithm). An
  agent that quotes the counter tool without the host side
  (or vice versa) is missing half the evidence.

## Capabilities and modes

The DOCA PCC Counter Tool ships as a CLI binary under
`/opt/mellanox/doca/tools/` on every DOCA install that
includes the PCC counter tooling subpackage. There is no
daemon, no library to link against, and no programmatic API;
the user's entire interaction model is *invoke the binary,
read the printed output*.

The tool exposes one functional family of operations —
**read-only counter inspection** — at three documented
granularities. The exact, current subcommand inventory, flag
names, counter column names, and per-counter semantics live
in the public DOCA PCC Counter Tool guide (reached via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
and in the tool's own `--help` on the installed version.
This skill names the **class shapes**; the agent does NOT
quote install-bound counter names from prose.

**Three documented granularities — class shapes.**

| Granularity (class) | What kind of counter the agent expects to see at this granularity | When the agent should reach for it |
| --- | --- | --- |
| Per-port | Aggregate PCC counters for an entire BlueField port — the unit of *"this physical port carrying my RDMA / RoCE traffic"*; reflects the combined effect of every flow on that port | FIRST. Always. Per-port aggregates are the cheapest signal that *something* is happening on the port; if per-port shows no change, drilling into per-flow without first checking per-port is the wrong order. |
| Per-flow | Per-flow counters that the running custom PCC kernel exposes for the flows it observes — useful for *"which flow is the algorithm actually modulating"* | AFTER per-port shows a change worth attributing. Per-flow is finer-grain and more expensive to interpret; reach for it only when the per-port aggregate is non-trivial. |
| Per-kernel | Counters that the running PCC kernel itself exposes (algorithm-internal — e.g. a count of per-event invocations, a count of rate-update decisions) for the agent to confirm the kernel is *running* and *making decisions*, not just loaded | When the host-side `doca-pcc` reports the kernel started but per-port and per-flow show nothing, OR when the agent needs to confirm the kernel's internal state machine is advancing. |

The set of counters actually exposed at each granularity is
**kernel-defined plus tool-documented**: the BlueField port
exposes a baseline set the public DOCA PCC Counter Tool guide
documents; the running custom PCC kernel that
[`doca-pcc`](../../libs/doca-pcc/SKILL.md) loaded MAY add
algorithm-defined counters per the algorithm body the user
wrote. The agent's rule: enumerate FIRST per
[`## Pattern overview`](#pattern-overview) pattern 1; do not
quote a counter name as authoritative without confirming it
appears in the enumeration on the user's installed version.

**Pairing with `doca-pcc` — the load-bearing precondition.**

| Step on the `doca-pcc` side | Why the counter tool needs it before it can return anything useful |
| --- | --- |
| Host has loaded a custom PCC algorithm image (`doca_pcc_app`) into a `doca_pcc` Core context against the target BlueField port | Without a loaded image, kernel-defined counters do not exist; per-port and per-flow counters may still exist but will reflect the firmware default, not the user's custom algorithm — surfacing that distinction is part of the agent's job |
| Host has started the `doca_pcc` Core context (`doca_ctx_start`) | Before start, the algorithm is loaded but inert — counters that depend on the algorithm running will not advance. *"My counter is stuck at zero"* on a port whose `doca_pcc` is not yet started is a `doca-pcc` configure-time finding, not a counter-tool failure |
| The attached BlueField port has live RDMA / RoCE traffic | A custom PCC algorithm with no traffic to modulate will keep its counters at zero — that is correct behaviour, not a tool bug. Route to [`doca-rdma`](../../libs/doca-rdma/SKILL.md) when the port is idle |
| The host can also observe the host-side reports per [`doca-pcc CAPABILITIES.md ## Observability`](../../libs/doca-pcc/CAPABILITIES.md#observability) | The counter-tool view and the host-side report stream are the two halves of the picture; the agent should expect them to agree, and a disagreement is itself a finding |

The tool runs on **either side of a host ↔ BlueField pair**
that the public guide documents — the host (when DOCA is
installed there) or the BlueField Arm side. The set of
counters visible from one side is not necessarily symmetric
with the other side; the per-tool guide on the user's
installed DOCA version names which side is preferred for
which question.

The agent's rule: the per-tool guide + `--help` is the joint
source of truth for the actual subcommand and counter
inventory; the skill stays at the class-shape level and
refuses to invent specific counter names from prose. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The PCC Counter Tool-specific overlay** is:

- **The counter tool ↔ `doca-pcc` library version match is the load-bearing rule for this skill.** A counter tool from a different DOCA train than the `doca-pcc` library that loaded the running kernel is a partial-install hazard — the column set the tool prints, the kernel-defined counter names it surfaces, and what it accepts as a kernel identifier may all silently disagree with what the library actually exposed at runtime. The agent must surface BOTH the counter tool's own `--version` AND `pkg-config --modversion doca-pcc` AND `doca_caps --version`, and route any disagreement through [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 (partial install) BEFORE quoting any counter reading as authoritative. This is the same partial-install hazard documented in [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility) (case (a) ≠ (c) of the four-way-match rule), narrowed to the PCC pair.
- **Confirm the tool is present before assuming availability.** If the user reports the binary is absent under `/opt/mellanox/doca/tools/`, the right answer is to confirm the installed DOCA version per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure) and route to [`doca-setup`](../../doca-setup/SKILL.md) for an upgrade or reinstall — NOT to recommend a wrapper script that simulates the tool, and NOT to quote counter values from memory. Per-tool availability — i.e. whether the PCC counter tool ships on a given DOCA version at all — is documented in the public DOCA PCC Counter Tool guide reachable via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools); do not assume it is available across all DOCA versions without checking the public guide for the user's installed version.
- **Where the tool runs:** on the x86 / Arm host that has DOCA installed, *or* on the BlueField Arm side. Same binary class, same shape of flag surface; the per-tool guide on the user's installed DOCA version names which side is preferred for which counter granularity.
- **Counter-name and column-name stability.** The class-shape (per-port / per-flow / per-kernel granularities and the read-only-only posture) is stable across the recent DOCA train. The exact counter names, output column names, and flag inventory are **not** contractually frozen — the installed `--help` and the per-tool public guide on the user's installed DOCA version are the authoritative surface. Agents that need to consume tool output programmatically should prefer a structured helper if one is present per [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) and re-verify the textual layout against the user's installed version when absent.

## Error taxonomy

The PCC Counter Tool's error surface is wider than `doca_caps`
because it depends on a *running* kernel that
[`doca-pcc`](../../libs/doca-pcc/SKILL.md) loaded. The error
layers the agent should distinguish, in escalating order:

1. **Tool-not-installed.** The counter-tool binary does not
   exist under `/opt/mellanox/doca/tools/`. Cause: DOCA is
   not installed on this host, the install does not include
   the PCC counter tooling subpackage, or the install version
   pre-dates the tool's availability. Routing:
   [`doca-setup ## install`](../../doca-setup/TASKS.md#configure)
   and the version-compatibility overlay above.
2. **No-PCC-kernel-loaded.** The tool runs and exits 0 but
   reports no algorithm-defined counters — even when the user
   thinks the host-side flow is up. Cause: the host-side
   `doca-pcc` flow has not actually reached the *started*
   lifecycle stage for a `doca_pcc` against this BlueField
   port (no `doca_pcc_app` loaded, no `doca_ctx_start` yet),
   OR the user is running the tool on a host whose BlueField
   has not had a custom kernel attached at all (the firmware
   default PCC is in effect, and only the per-port baseline
   counters exist). Walk
   [`doca-pcc TASKS.md ## configure`](../../libs/doca-pcc/TASKS.md#configure)
   end-to-end (image loaded, context started) before re-running
   the tool. If the host side claims it is in that state and
   the tool still sees nothing, escalate to layer 3.
3. **Wrong-version-with-PCC-library.** The tool runs but the
   counter set / column set / kernel-identifier shape it
   reports disagrees with what the host-side `doca-pcc`
   library actually exposed at runtime. Cause: the counter
   tool and the `libdoca_pcc.so` came from different DOCA
   installs (DOCA upgraded, the PCC subpackage did not, or
   vice versa). This is the partial-install hazard the
   version overlay above is for; route to
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 and reinstall consistently. Do NOT paper over by
   quoting one side's columns as authoritative.
4. **Counter-not-exposed-by-kernel.** The tool runs, the
   kernel is loaded and started, the per-port baseline is
   visible, but the specific kernel-defined counter the user
   asked about is NOT in the enumeration. Cause: the running
   custom PCC algorithm body (compiled by `dpacc` from the
   user's DPA-side source) does not declare / emit that
   counter. This is a build-side question in disguise — the
   DPA-side translation unit needs to declare and emit the
   counter, and BOTH the host executable AND the DPA-side
   image need to be rebuilt per the *do not partial-rebuild
   one side* rule in
   [`doca-pcc CAPABILITIES.md ## Safety policy`](../../libs/doca-pcc/CAPABILITIES.md#safety-policy).
   Route to
   [`doca-pcc TASKS.md ## modify`](../../libs/doca-pcc/TASKS.md#modify)
   for the algorithm-side change.
5. **Permission.** The tool runs but reports it cannot read
   the requested counter set because the invoking user lacks
   the privileges the public guide requires (typically sudo
   on the BlueField Arm side, or membership in the host's
   standard mlnx-style group). The tool's own message is
   ground truth; the fix is to re-run with the documented
   privileges, NOT to bypass the check. Route to
   [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure).
6. **Sampling-aliasing-or-saturation.** The tool runs, the
   counter is exposed, the value the agent reads is finite —
   but the value is misleading. Two sub-cases the agent must
   distinguish: (a) **aliasing** — the watch interval is too
   coarse to catch the change-rate the user cares about, so
   the diff between consecutive samples looks flat when the
   underlying behaviour is bursty; (b) **saturation** — the
   counter is at the type's maximum (e.g. pinned at a 32-bit
   or 64-bit ceiling because of an unhandled wrap), so the
   diff looks zero even though events are still happening.
   The agent must NOT translate either case into a CC tuning
   decision; the fix is to re-sample at a finer interval (for
   aliasing) or to re-read the counter's documented type and
   wrap behaviour from the public guide (for saturation), per
   [`TASKS.md ## test`](TASKS.md#test) eval-loop.
7. **Version.** A flag, subcommand, or counter column the
   user is reading about in a doc page is not present in the
   tool's actual output / `--help` on this install. Route to
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   for the four-way match check (DOCA + DPACC + tool +
   public guide all on the same version); the *installed*
   `--help` wins.
8. **Cross-cutting.** When the tool runs cleanly against a
   real loaded kernel, the version four-way match passes, the
   privileges are documented, and the user's question is
   really about the host-side `doca-pcc` API behaviour, the
   cross-library `DOCA_ERROR_*` taxonomy, the firmware-side
   custom-PCC slot, the BlueField mode, or generic driver /
   link / runtime failures unrelated to PCC counters. Route
   to [`doca-pcc TASKS.md ## debug`](../../libs/doca-pcc/TASKS.md#debug)
   for host-side; to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   for the cross-cutting ladder; to
   [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
   for the env-side / firmware-side layers.

`doca_pcc_counter`-class tooling does **not** itself return
`DOCA_ERROR_*` values to a calling program — those are owned
by the [`doca-pcc`](../../libs/doca-pcc/SKILL.md) library
API. The tool's CLI exit codes and printed messages are its
own narrow surface; the agent maps those into the layers
above before interpreting any program-side `DOCA_ERROR_*`.

## Observability

The PCC Counter Tool is itself an **observability primitive**
for the rest of the custom-PCC surface — it is *what other
skills load to observe* a running custom PCC kernel from
outside the host-side program. Specifically:

- [`doca-pcc TASKS.md ## debug`](../../libs/doca-pcc/TASKS.md#debug)
  layer 5 (runtime) and the *"my custom PCC algorithm loaded
  but the flows look unchanged"* row in
  [`doca-pcc TASKS.md ## test`](../../libs/doca-pcc/TASKS.md#test)
  prescribe reaching for this tool when host-side reports
  fire but the on-wire behaviour does not. The counter
  tool's read-only enumeration + snapshot + watch + diff is
  the documented way to produce that evidence.
- [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
  consumes the captured before / after counter snapshot pair
  as the *port-state half* of the cross-cutting debug ladder,
  paired with the program-side
  [`doca-pcc CAPABILITIES.md ## Observability`](../../libs/doca-pcc/CAPABILITIES.md#observability)
  host-side report stream and (when present) the BlueField
  driver and firmware view via
  [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).
- The tool's own output is the artifact downstream debug
  consumes. Save BOTH the *before* snapshot and the *after*
  snapshot (file, paste buffer, conversation artifact);
  without them, the next debug step starts inferring a
  tuning decision from a single reading.

The tool does not emit metrics, traces, or DOCA logs of its
own beyond the printed CLI output. For the program-side
observability surface (`DOCA_LOG_LEVEL`, `--sdk-log-level`,
the trace build flavor, the host-side report stream that the
running algorithm emits) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability)
and
[`doca-pcc CAPABILITIES.md ## Observability`](../../libs/doca-pcc/CAPABILITIES.md#observability).
For the install-tree layout and the per-tool guide URLs,
defer to
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

The PCC Counter Tool is **read-only on the wire**, but the
**downstream decisions an agent might derive from its output
are high-stakes**. A misread counter that drives a
congestion-control parameter retune can destabilize the
RDMA / RoCE fabric for every node attached to that port —
that is the failure mode this safety policy exists to prevent.

- **Read-only operations are safe; the tuning decision they
  inform is NOT.** Enumeration / snapshot / watch / diff do
  not change PCC state and can be re-run freely. A tuning
  recommendation that follows from them DOES change PCC
  state (via a host-side `doca-pcc` parameter retune or a
  rebuild of the algorithm body) and may interrupt or
  destabilize live traffic. The agent must say so before
  recommending any tuning move.
- **Diff-before-decide is mandatory.** Before any
  congestion-control tuning recommendation, the agent
  captures a *before* snapshot, names the controlled change
  (host-side parameter retune, traffic shift, or no change
  at all to confirm baseline noise), captures an *after*
  snapshot, and quotes the diff. A tuning decision derived
  from a single reading is a guess; the diff is the evidence.
  See [`TASKS.md ## debug`](TASKS.md#debug) layer 6.
- **Smoke-before-bulk on EVERY new kernel.** Snapshot ONE
  named counter and confirm the value is finite and changing
  BEFORE any sweep across many counters or any sustained
  watch. Skipping this step is how operators discover, ten
  minutes into a sweep, that the kernel was never started or
  the port has no traffic — neither of which the sweep was
  going to surface any faster than a single snapshot would.
- **Never quote a counter name from memory.** The documented
  surface is the surface; the public guide plus installed
  `--help` is the joint source of truth. If the user asks
  about a counter the public guide does not list, the safe
  answer is *"the installed `--help` and the public DOCA PCC
  Counter Tool guide on your installed DOCA version are the
  source of truth — let me check it there"*, not a guess
  based on prose mentions of PCC counters elsewhere.
- **Quote what the tool said. Do not paraphrase a counter
  reading.** When the user later asks *"is the algorithm
  doing anything"*, the correct answer is to point at the
  line of the snapshot that reports the value, not to
  summarize it. Paraphrasing counter output is how stale
  evidence ends up justifying a destabilizing tuning move.
- **High-stakes posture, fleet-impact.** Custom PCC affects
  the on-wire congestion behaviour of an entire BlueField
  port, and CC decisions made on one node propagate into
  the fabric every other node shares. The agent must
  surface this fleet-impact framing whenever a user asks
  for a tuning recommendation based on a counter reading,
  and route any tuning decision back through the user's
  own domain analysis — the skill captures evidence; it
  does not translate evidence into a tuning move.

## Public-source pointer

The single canonical public source for the DOCA PCC Counter
Tool is the **DOCA PCC Counter Tool** page on
`docs.nvidia.com`, reachable through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
Do not invent flags, subcommand names, output columns, or
counter names beyond what that page documents. For the
`doca-pcc` library that loaded the kernel emitting the
counters, the public source is the **DOCA PCC** library page,
reached the same way and named on the
[`doca-pcc`](../../libs/doca-pcc/SKILL.md) skill.
