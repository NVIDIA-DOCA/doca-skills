---
name: doca-pcc-counters
description: NVIDIA DOCA PCC Counter Tool — the operator-facing diagnostic CLI shipped under `/opt/mellanox/doca/tools/` that inspects Programmable Congestion Control counters on a BlueField port, paired with the `doca-pcc` library that loads custom congestion-control kernels onto the BlueField DPA. The counter tool is read-only and side-effect-free — its job is to list available counters, snapshot per-flow / per-port / per-kernel counters, watch a sweep, and diff snapshots so the agent can localize where a custom PCC algorithm is (or is not) modulating RDMA / RoCE traffic. Runs from the host or BlueField Arm side. The canonical public source is the DOCA PCC Counter Tool guide on `docs.nvidia.com`. Subcommand names, flag strings, and counter column names come from that guide and the installed `--help`, never from agent memory — misreading a counter into a CC tuning decision can destabilize a fleet.
kind: library
---

# DOCA PCC Counter Tool

**Where to start:** This is a tool skill for invoking the
documented DOCA PCC Counter Tool — the operator-side, read-only
diagnostic CLI counterpart to the
[`doca-pcc`](../../libs/doca-pcc/SKILL.md) library that loads
custom congestion-control (CC) kernels onto the BlueField DPA.
Open [`TASKS.md`](TASKS.md) and start at
[`## run`](TASKS.md#run) for the
list-then-snapshot-then-watch-then-diff entry point, or
[`## debug`](TASKS.md#debug) when the user reports *"my custom
PCC algorithm loaded but the flows look unchanged"*. Open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
counters can this tool report and at what granularity*. If the
user has not installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user
has not yet brought up a custom PCC kernel via the host-side
library, route to [`doca-pcc`](../../libs/doca-pcc/SKILL.md)
first — the counter tool inspects what the running kernel
emits; it does not load or run a kernel.

This skill is the **runtime / inspect side** of custom
Programmable Congestion Control. It is NOT the host-side
control library that loads kernels (that is
[`doca-pcc`](../../libs/doca-pcc/SKILL.md)) and it is NOT the
default factory PCC algorithm shipped in ConnectX firmware
(that path is firmware-only configuration, no host-side code,
routed via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).
Three separate surfaces; conflating them is the most common
PCC first-touch error.

## Example questions this skill answers well

The CLASSES of PCC counter-tool questions this skill is built
to answer, each with one worked example. The class is the
load-bearing piece; the worked example is one instance.

- **"Which PCC counters can I read on this BlueField right
  now?"** — worked example: *"my custom PCC kernel just
  attached to a BlueField port — enumerate every counter the
  tool can list for that port"*. Answered by the
  counter-enumeration family in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the list-first invocation in
  [`TASKS.md ## run`](TASKS.md#run).
- **"What is this single PCC counter doing right now?"** —
  worked example: *"snapshot one named counter for the port
  carrying the user's RoCE traffic and confirm the value is
  finite and changing"*. Answered by the snapshot pattern in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the smoke step in
  [`TASKS.md ## test`](TASKS.md#test).
- **"My custom PCC algorithm loaded but the flows look
  unchanged — is the algorithm doing anything?"** — worked
  example: *"the host-side `doca-pcc` reports the algorithm
  started cleanly; the RDMA / RoCE rate-curve is unchanged"*.
  Answered by the diff-before-decide pattern in
  [`TASKS.md ## debug`](TASKS.md#debug) +
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  high-stakes-tuning gate.
- **"How do I sweep a counter over time without aliasing or
  saturating it?"** — worked example: *"watch a per-flow
  counter for a minute and tell whether the change is real"*.
  Answered by the watch / interval-sample family in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the eval-loop overlay in
  [`TASKS.md ## test`](TASKS.md#test).
- **"Is this counter tool on my installed DOCA version, and
  does it match the `doca-pcc` library version on this
  host?"** — worked example: *"is the tool available on my
  install and does it agree with the library the kernel was
  loaded against"*. Answered by the overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
  which redirects to the canonical
  [`doca-version`](../../doca-version/SKILL.md) rules and
  adds the counter-tool ↔ `doca-pcc` library matching
  overlay.
- **"The tool prints nothing — is the install broken, the
  kernel not loaded, or genuinely no traffic?"** — worked
  example: *"`list` returned an empty result on a host where
  I just attached a custom PCC kernel"*. Answered by the
  layered diagnosis in
  [`TASKS.md ## debug`](TASKS.md#debug) +
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).

## Audience

This skill serves **external operators, developers, and AI
agents who have already loaded a custom Programmable
Congestion Control kernel via the host-side `doca-pcc`
library** (or who are operating against a BlueField with a
DPA-resident PCC algorithm) and now need to inspect what the
running kernel is reporting at the counter level.
Concretely:

- A developer of a custom CC algorithm who finished the
  `doca-pcc` lifecycle (load → start → observe) and needs the
  external counter view to confirm the algorithm is actually
  modulating the BlueField port's RDMA / RoCE traffic.
- A platform operator who runs a DOCA-PCC-using service and
  needs a documented, read-only way to ask *"what are this
  port's PCC counters doing?"* without touching the host-side
  program.
- An AI agent producing a *PCC counter snapshot* as evidence
  for the host-side debug ladder in
  [`doca-pcc TASKS.md ## debug`](../../libs/doca-pcc/TASKS.md#debug)
  layer 5 (runtime) when the host-side log is silent.

It is **not** for users debugging the counter tool itself,
**not** a substitute for the live public DOCA PCC Counter
Tool guide, **not** the right place for users learning how
to write a custom PCC algorithm — that audience belongs in
[`doca-pcc`](../../libs/doca-pcc/SKILL.md) — and **not** the
right place for users who only want the default factory PCC
algorithm shipped in ConnectX firmware (no host-side library
or counter tool needed; route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).

The tool is shipped as a **CLI binary** under
`/opt/mellanox/doca/tools/`, not a library you link against.
The skill uses the same `kind: library` three-file shape as
the rest of the bundle so the agent's task-verb contract
(`configure / build / modify / run / test / debug`) is uniform
across libraries, services, and tools.

## When to load this skill

Load this skill when the user is — or the agent needs to —
invoke the documented DOCA PCC Counter Tool on a real host or
BlueField Arm with DOCA installed (or inside the public NGC
DOCA container with the right device passthrough), against a
BlueField port whose PCC behaviour the user wants to inspect.
Concretely:

- Listing the PCC counters available for a BlueField port
  whose RDMA / RoCE traffic the user is reasoning about.
- Snapshotting a single counter to confirm the running custom
  PCC algorithm is actually modulating the flows attached to
  that port.
- Watching a counter (or a small set of counters) over an
  interval to localize whether a tuning change had the
  expected on-wire effect.
- Diffing a *before / after* snapshot pair to localize where
  a bottleneck is and to gate any congestion-control tuning
  decision on real evidence rather than inference.
- Capturing a side-effect-free counter snapshot as
  prerequisite evidence for a host-side `doca-pcc` debug
  session per
  [`doca-pcc TASKS.md ## debug`](../../libs/doca-pcc/TASKS.md#debug).

Do **not** load this skill for general DOCA orientation,
custom-PCC algorithm design, the host-side `doca-pcc` library
API, the default factory PCC algorithm in firmware, or DOCA
install. For those, route to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-pcc`](../../libs/doca-pcc/SKILL.md), or
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what the PCC Counter Tool reports: the
  documented counter-granularity surface (per-port,
  per-kernel, per-flow as the public guide on the user's
  installed DOCA version describes them), the read-only-only
  posture (the tool has no documented state-changing
  operations on the PCC algorithm itself), the
  version-availability overlay that redirects to
  [`doca-version`](../../doca-version/SKILL.md) and adds the
  counter-tool ↔ `doca-pcc` library matching rule, the
  layered error taxonomy (tool-not-installed /
  no-PCC-kernel-loaded / wrong-version-with-PCC-library /
  counter-not-exposed-by-kernel / permission /
  sampling-aliasing-or-saturation / version / cross-cutting),
  the tool's role as the observability primitive for
  [`doca-pcc`](../../libs/doca-pcc/SKILL.md) debug sessions,
  and the safety policy that makes any *"tune the
  congestion-control algorithm based on this counter"*
  decision high-stakes (a misread can destabilize a fleet).
- `TASKS.md` — step-by-step workflows for the in-scope task
  verbs: `configure` (route to install + confirm a PCC
  kernel is loaded), `build` (route to install), `modify`
  (refuse — shipped binary), `run`
  (list → snapshot → watch → diff), `test`
  (smoke-before-bulk on a single counter), `debug` (the
  layered diagnosis ladder), plus a `Deferred task verbs`
  block and a `Command appendix` that honors the bundle's
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  preamble.

The skill assumes a host or BlueField where DOCA is already
installed (or the public NGC DOCA container is running with
the right device passthrough), the host-side
[`doca-pcc`](../../libs/doca-pcc/SKILL.md) flow has reached
the *started* lifecycle stage at least once for the BlueField
port the user wants to inspect (otherwise the counters of
interest will not yet exist or will be silent for an
expected reason), and the operator has whatever privileges
the public DOCA PCC Counter Tool guide requires.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Verbatim flag inventories, subcommand names, binary
  names, or counter column names.** The public DOCA PCC
  Counter Tool guide on `docs.nvidia.com` and the installed
  `--help` on the user's version are the joint source of
  truth; copying them here pins the skill to one release and
  silently rots when the tool evolves. The skill routes the
  agent at those sources instead.
- **Pre-baked example output.** Output is install-, version-,
  device-, kernel-, and traffic-state-specific. A captured
  example will mislead an operator on a different platform.
- **Wrappers, parsers, or scripts** in any language that
  consume the counter tool's output. The output format is
  documented; users who want to script against it should read
  the live guide and write the parser against their installed
  version.
- **A specific congestion-control tuning recommendation
  derived from a counter reading.** That is a domain question
  (research / workload tuning) and a high-stakes one — the
  skill prescribes how to *capture and diff* counters; it
  refuses to translate a counter delta into a CC parameter
  change without the user's own domain analysis.
- **A `samples/` or `reference/` subtree.** This is a thin
  loader for a documented CLI; substantive material lives on
  the public page and in `--help`.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (inspecting PCC counters from outside the
   custom algorithm; not designing the algorithm and not
   loading it).
2. **For what the tool reports, the read-only posture, the
   counter-granularity surface, the version-availability
   overlay, the layered error surface, observability, and
   safety posture, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented invocations and the
   smoke-before-bulk workflow — `configure`, `build`,
   `modify`, `run`, `test`, `debug`, plus the `Command
   appendix` — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-pcc`](../../libs/doca-pcc/SKILL.md) — the host-side
  library whose loaded congestion-control kernel emits the
  counters this tool inspects. Pair them in every triage
  session: the host-side `doca-pcc` reports and the counter
  tool's per-port / per-flow / per-kernel snapshots are the
  two halves of the same picture. Conflating the library and
  the tool is the most common PCC first-touch error.
- [`doca-comm-channel-admin`](../doca-comm-channel-admin/SKILL.md) —
  sibling tool skill that pairs an admin / inspect CLI with
  the library that owns the state it inspects (Comch). Same
  paired-with-library shape; same list-then-inspect rhythm
  on the read-only side. Use as a generalization target when
  reasoning about *"how do I drive any DOCA admin / inspect
  tool that pairs with a DOCA library"*.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — routing to the public DOCA PCC Counter Tool guide and
  the rest of the public DOCA documentation set.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. The `## Version compatibility`
  section in [`CAPABILITIES.md`](CAPABILITIES.md) is a
  concise overlay that redirects here for the body and adds
  the counter-tool ↔ `doca-pcc` library matching rule.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's detect → prefer → fall back → report
  contract for structured helper tools. The Command appendix
  in [`TASKS.md`](TASKS.md) honors this contract.
- [`doca-setup`](../../doca-setup/SKILL.md) — env
  preparation, install verification, BlueField mode (the
  BlueField must expose its DPA processor before any
  custom-PCC kernel can run, which in turn is the
  precondition for any counter the tool reports), and the
  *I have no install yet* path with the public NGC DOCA
  container. This skill assumes its preconditions are
  satisfied.
- [`doca-debug`](../../doca-debug/SKILL.md) — the
  cross-cutting debug ladder. The PCC Counter Tool slots in
  at the *runtime* layer as the read-only inspection surface
  before any custom-PCC tuning recommendation is made, and
  the captured snapshot pair (before / after) is the
  load-bearing artifact the cross-cutting ladder consumes.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA programming patterns shared by every
  library / tool surface, including the cross-library
  `DOCA_ERROR_*` taxonomy this tool's error layer overlays
  on top of when host-side `doca-pcc` calls fail in tandem.
