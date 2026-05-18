# DOCA Flow workflows

**Where to start:** The verbs run `configure → build → modify → run
→ test → debug`. Skip ahead only when the user is already past a
verb. The `## test` verb is an iterative loop (validate → cross-check
→ counter wiring → negative test → loop back if the spec changed), not
a one-shot pass — see the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the underlying capability matrix, version
compatibility, error taxonomy, observability surface, and safety policy
that these workflows assume, see [CAPABILITIES.md](CAPABILITIES.md). For
where to find docs, the installed DOCA layout, or release notes, route
through [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

Each verb below describes the **shape of the workflow**, not a copy-paste
recipe. The agent's job is to walk the user through the steps in order,
verifying preconditions before recommending the next call.

## configure

Goal: bring up a DOCA Flow port on a BlueField host and confirm the
environment is in a state where pipe construction is meaningful.

Steps the agent should walk the user through:

1. **Confirm the installed DOCA version.** Use the procedure in
   `doca-public-knowledge-map` (do not duplicate it here). Quote the
   version observed; do not assume "latest".
2. **Discover device capabilities.** Run the installed `doca_caps`
   capability tool and the Flow capability-query API; record the active
   steering mode (HWS or SWS), the supported match kinds, the supported
   action kinds, and the maximum pipe/entry budgets. The capability
   matrix to compare against lives in
   [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes).
3. **Enumerate ports and representors.** Confirm the BlueField port the
   user wants to program is visible to the host (`devlink dev show` and
   the installed Flow port-enumeration sample), and that the
   representors the user expects to forward to are present.
4. **Bring up the Flow port.** Use the Flow port-init API with the
   device handle obtained in step 3. The lifecycle is *port created →
   port started → ready for pipe creation*; do not create pipes before
   the port reports started.
5. **Sanity check before any pipe work.** Confirm with the user: which
   ingress port, which egress representor(s), which traffic class. If
   any of those are unclear, stop and ask — do not invent.

If any step fails with a `DOCA_ERROR_*`, route through the error
taxonomy in [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy)
before retrying.

## build

Goal: construct a pipe specification that expresses the user's intent
without committing to hardware yet.

Steps:

1. Restate the user's intent in match/action terms. ("Match destination
   MAC = X, forward to representor Y, count.")
2. **Verify each match kind and action kind against the active
   steering mode's capability set** from
   [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes).
   If the device does not support a kind, stop and offer alternatives;
   do not generate a spec that will fail at validate.
3. Allocate the pipe spec via the Flow pipe-create API with explicit
   match-mask and action-mask declarations. Implicit-anything in a
   pipe spec is the leading cause of misprogrammed steering.
4. Attach a counter to every entry that the user wants to *observe* in
   production. Counters are the cheapest observability and the
   workflow in `## debug` assumes they exist.
5. Do **not** call the entry-add API yet. The spec is built, not
   programmed. Hand off to `## test` for validation.

**When the user asks for a "first Flow app" specifically:** the answer
depends on the user's language and on whether the user can reach a
DOCA-installed Linux host. Two preconditions, two language tracks; the
agent must establish both before recommending any concrete next step.

**Precondition gate.** Both tracks require a DOCA-installed Linux
environment (bare-metal, VM, or NGC container — see
[`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install) Path 0
for the universal NGC fallback) where the agent can read the sample
tree and `pkg-config --modversion doca-flow` resolves. If the
precondition is not met, route to
[`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install) *before*
offering any source code. Do **not** author a Flow application from
documentation prose, in any language, to fill the gap. Ground rule #3
of [`AGENTS.md`](../../../AGENTS.md), the version-compatibility rule in
[`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
and [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship)
all forbid it; the resulting source would not compile or link against a
real install.

### Track 1 — C / C++ consumers (the canonical case)

This is the first-app shape for which NVIDIA ships verified reference
code. The recipe is the universal *derive a custom first app from a
sample* pattern in [`doca-programming-guide ## modify`](../../doca-programming-guide/TASKS.md#modify)
(which is where that workflow lives after the env / program split —
deriving a first app is a programming verb, not an env verb), with
these Flow-specific overrides:

- **Source sample.** For the simplest *match-and-forward-to-port*
  shape: `/opt/mellanox/doca/samples/doca_flow/flow_port_fwd/`. For
  *switch mode + representor*: `/opt/mellanox/doca/samples/doca_flow/flow_switch_single/`
  (use the helpers in `flow_switch_common.{c,h}`). The agent must `ls`
  the directory and read the actual sample contents on the user's
  install before describing them; sample layouts can change between
  releases.
- **Fields the user must swap (the explicit-placeholder list).**
  Destination MAC for the entry match (the `target_mac`-shaped
  constant in the sample's source); representor `port_id` for the
  forward action; the pipe name string passed to
  `doca_flow_pipe_cfg_set_name()`. *Keep* all init/teardown
  boilerplate, the `doca_flow_entries_process()` loop, the per-entry
  status callback, and the validation flow described in
  [`## test`](#test). The substance of the file remains the upstream
  sample's verified code; the agent edits a small set of literals.
- **Build flavor.** Use the trace flavor for the first run — link with
  `doca-flow-trace` via `pkg-config`, or set `LD_LIBRARY_PATH` per
  [`doca-setup CAPABILITIES.md ## Capabilities and modes`](../../doca-setup/CAPABILITIES.md#capabilities-and-modes).
  Switch to release only after the staged run succeeds.
- **Standalone build manifest.** If the user wants to build outside
  the shipped DOCA samples meson tree, the agent constructs a small
  standalone build manifest *in the user's project directory* that
  `pkg-config`s `doca-flow` (the module name is documented in the
  [DOCA Flow Programming Guide](https://docs.nvidia.com/doca/sdk/doca-flow/index.html)
  §"Initialization Flow"). For C/C++ projects the canonical choice is
  meson; cmake or autotools work equivalently against the same
  `pkg-config` module. The agent does **not** copy a build template
  out of this skill; the skill ships agent guidance, not artifacts.

### Track 2 — Other languages (Rust, Go, Python, …)

NVIDIA does not ship a verified first-app sample in non-C languages
inside this repository, and the skill does not ship one either. The
agent's job for a non-C consumer is therefore *not* to author the
wrapper from documentation prose — it is to make sure the consumer
understands the API surface their wrapper will call, and to route the
language-specific build/FFI work back to the consumer.

- **API surface.** The authoritative API is the public C ABI of the
  `doca-flow` library. Citations belong against the public
  [DOCA Flow Programming Guide](https://docs.nvidia.com/doca/sdk/doca-flow/index.html)
  for behavior and lifecycle; the installed C headers under
  `/opt/mellanox/doca/infrastructure/include/` (`doca_flow.h`,
  `doca_flow_*.h`) are the canonical source for symbol signatures.
  Any non-C wrapper has to honor the same lifecycle, capability gate,
  and validation rules described in
  [`CAPABILITIES.md`](CAPABILITIES.md) and [`## test`](#test); these
  are properties of the library, not of the language.
- **Bindings.** If the user's chosen language has a community or
  user-built binding, point them at it (the agent must verify it
  exists by fetching its repository or package registry — do *not*
  invent a binding name). If not, the user is doing direct FFI:
  `bindgen` for Rust, `cgo` for Go, `cffi`/`ctypes` for Python, etc.
  The agent does not generate the bindings in this conversation; it
  describes the C-side surface (`*.so` linkage, header path,
  `pkg-config --cflags --libs doca-flow`) the binding tooling needs.
- **Reference: read the C samples.** Even a non-C consumer benefits
  from reading
  `/opt/mellanox/doca/samples/doca_flow/flow_port_fwd/` to understand
  the *order* of API calls and which fields matter — that order is
  the same regardless of the calling language. The wrapper translates
  it; it does not invent a different shape.
- **Runtime is the same.** All of [`## test`](#test), [`## run`](#run),
  and [`## debug`](#debug) below apply unchanged. The validation gate,
  the staged run, the counters-first debugging order — these are
  library properties, not language properties.

## modify

Goal: change an existing pipe — adding, removing, or rewriting entries —
without taking the steering plane offline.

Steps:

1. Read current pipe statistics and counters before any change. The
   diff after the change is what tells the user whether the modification
   did what they meant.
2. **Re-run capability discovery if the modification changes the action
   set.** A new action kind (e.g., adding `encap`) requires re-checking
   the capability matrix and re-validating against the *new* action
   shape — see the third item in [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy).
3. Construct a delta spec, not a full re-spec. Removing and re-adding a
   pipe is a much heavier operation than adding/removing entries.
4. Validate the modified spec via the same path as `## test ## validate`
   below.
5. Commit the change in the smallest possible unit (one entry at a
   time for live pipes that carry production traffic).
6. Re-read counters and statistics; confirm the diff matches intent.

## run

Goal: actually program the validated spec into the hardware and observe
that traffic does what it should.

Steps:

1. Confirm `## test ## validate` has passed for the current spec; do
   not enter `run` from an un-validated spec.
2. Start the pipe via the Flow pipe-start API. Pipe lifecycle is
   *created → validated → started → entries added*; out-of-order calls
   produce `DOCA_ERROR_BAD_STATE`.
3. Add entries in the order documented by the user's intent (most
   specific match first if the steering mode does *not* honor declared
   priority; otherwise priority field as documented).
4. **Stage entries on a single representor before widening to all
   representors** — this is the safety policy item 2 in
   [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy)
   for hairpin pipes; the same staging discipline applies to any
   high-fanout match-action pipe carrying production traffic.
5. Read counters under expected traffic. If they do not move, jump to
   `## debug`.

## test

Goal: validate a pipe spec — and the system context around it — before
hardware programming.

**`## test` is an iterative loop, not a one-shot pass.** The agent's
job is to run the 4 steps below in order, and *loop back to step 1
whenever the spec is mutated by the cross-check or counter-wiring
findings*. Treating validate-once as good-enough is the failure mode
this loop replaces; every spec mutation re-opens validate.

The eval-loop overlay (rows apply to every pipe spec, not just one):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | Negative-test discovery (step 4) often surfaces a real spec drift; loop back to step 1 | [`## test`](#test) step 4 |
| 1 → 2 → 1 | Capability cross-check (step 2) may force a steering-mode or action change; loop back to step 1 | [`## test`](#test) step 2 |
| 1 → 3 → 1 | Counter-wiring gap (step 3) often reveals a missing per-entry counter the user wanted; loop back to step 1 with the counter added | [`## test`](#test) step 3 |
| 4 → ## debug | When the negative test does not reject what it should, the Flow library itself is suspect — escalate to the Flow `## debug` overlay | [`## debug`](#debug) |

The agent's rule: every mutation between steps re-opens validate.
Skipping the re-validate after a mutation is exactly the failure mode
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
validate-before-commit exists to prevent.

Steps:

1. **Pipe spec validation.** Use the Flow pipe-validate API for the
   installed version (or, if unavailable on this version, the
   dry-run sample under the installed Flow samples directory whose path
   is documented in `doca-public-knowledge-map`). The validation must
   complete without errors before any entry-add call. This is the
   "validate before commit" rule from
   [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy).
2. **Capability cross-check.** Re-confirm that every match kind, action
   kind, and tunnel header in the validated spec is supported by the
   active steering mode and firmware. Validation answers "is the spec
   internally consistent"; capability cross-check answers "will this
   hardware actually accept it".
3. **Counter wiring check.** Walk the spec and confirm every entry the
   user wants to observe has a counter attached. The `## debug` workflow
   below assumes counters exist; reach this conclusion now, not later.
4. **Negative test.** Construct one deliberately failing entry (wrong
   match kind, unsupported action) and confirm validation rejects it.
   This is the cheapest way to detect a stale or wrong-version Flow
   library before going live.

## debug

Goal: investigate "traffic is not doing what I asked" and arrive at a
root cause that is either fixable in the spec or escalatable.

> **Routing summary.** This anchor is the **Flow-specific debug overlay**:
> counters, pipe statistics, programmed-entry dumps, Flow's `DOCA_ERROR_*`
> mapping. For the **cross-cutting debug ladder** (install / version /
> build / link / runtime / program / driver) plus the cross-cutting tooling
> surface (`gdb`, `valgrind`, `--sdk-log-level`, the `doca-flow-trace`
> build flavor, container-vs-native debug, core dumps, the Developer Forum
> escalation), see [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug).
> The agent should walk the cross-cutting ladder first whenever the symptom
> layer is not yet known; this Flow overlay layers on top once the symptom
> is confirmed to be inside the Flow API surface.

Walk in this order — do not skip steps:

1. **Counters first.** Read the entry-level counters (built in `## build`
   step 4). If the counter for the suspected entry is zero, the entry
   is not matching. Stop blaming the data plane; the spec is wrong.
2. **Pipe statistics second.** If counters are non-zero but behavior is
   still wrong, read the pipe-level statistics from
   [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability) to
   determine whether the pipe itself is healthy.
3. **Programmed-entry dump third.** Use the Flow trace / diagnostic dump
   to inspect what the hardware actually has programmed. The diff
   between the user's mental model and the dump is the bug. The trace
   build flavor (`pkg-config doca-flow-trace`) is what makes the dump
   verbose; the runtime mechanics live in
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
4. **Error code mapping.** Any `DOCA_ERROR_*` returned during the
   investigation routes through the taxonomy in
   [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).
   The cross-library taxonomy (which family routes to which debug layer)
   is owned by
   [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
   this Flow file only adds the Flow-specific overlay.
5. **Version sanity.** If a previously working spec now fails or behaves
   differently, confirm the installed DOCA version did not change. The
   four-source version-coherence check (`pkg-config --modversion doca-common`,
   `cat /opt/mellanox/doca/applications/VERSION`, `doca_caps --version`,
   BFB version) is owned by
   [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug) Layer 2; the
   version-detection mechanics live in
   [`doca-public-knowledge-map ## Where to find the version`](../../doca-public-knowledge-map/SKILL.md#where-to-find-the-version).
   A library upgrade between sessions is a common and easy-to-miss cause.
6. **Escalation criteria.** If counters move correctly but observed
   behavior is still wrong AND the trace dump matches the spec AND the
   version is unchanged, the bug is below the Flow API surface (driver
   or firmware). Stop attempting Flow-spec changes; capture state per
   [`doca-debug ## test`](../../doca-debug/TASKS.md#test) (the read-only
   triple) and escalate via
   [`doca-debug ## debug` *Where to ask for help*](../../doca-debug/TASKS.md#debug)
   to the public DOCA Developer Forum.

## flow-ct

The DOCA-Flow-CT-specific overlay on the parent verbs. Use AFTER
the parent's [`## configure`](#configure) → [`## debug`](#debug)
sequence has been walked for the stateless doca-flow port; this
section adds only what CT changes on top. For the capability
surface, layering rule, multi-axis cap discovery, CT-specific
error overlay, and safety policy, see
[`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct).

**configure overlay.**

1. **Confirm doca-flow is up on the target port.** Per the
   layering rule in
   [`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct), CT
   attaches on top of an already-up doca-flow port. If the
   port has not been initialized through [`## configure`](#configure),
   route the user back there FIRST — do NOT propose CT against
   an un-started port, and do NOT recommend rewiring the
   doca-flow setup *"to add CT"*. CT extends; it does not
   replace.
2. **Multi-axis cap-discovery for CT.** Call the matching
   `doca_flow_ct_cap_*` queries against the active
   `doca_devinfo` for EACH axis the workload uses: max
   concurrent flows, aging-timer range AND granularity, NAT
   variants (SNAT / DNAT / combined — separate checks), and
   per-overlay CT support (do NOT promote a single overlay
   cap-yes to *"all overlays supported"*). Surface ALL queried
   axes back to the user — quoting only the flow ceiling is a
   misroute.
3. **Size the aging table to the user's expected peak, not
   average.** CT entries persist until aging evicts them or
   policy removes them. Confirm peak concurrent-flow estimate
   against the cap-advertised max BEFORE creating the context;
   if the estimate exceeds the ceiling, surface the device-fit
   gap — do not over-commit.
4. **Create the per-port `doca_flow_ct` context.** Per
   [`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct) one
   context per tracked port. Configure aging-timer-base in the
   cap-advertised range and at a supported granularity; set the
   table size from step 3.
5. **Configure NAT actions only if the cap-query said yes** for
   the specific variant (SNAT, DNAT, combined). Do NOT propose
   double-NAT (SNAT + DNAT on the same connection) before
   confirming the combined-NAT axis explicitly.
6. **Start the context, then attach CT-aware pipe builders.**
   `doca_ctx_start` on the `doca_flow_ct` per the Core lifecycle
   in [`doca-programming-guide`](../../doca-programming-guide/SKILL.md);
   wrap existing doca-flow pipes via the CT pipe-builder API to
   produce CT-aware versions. The original stateless pipes
   remain valid; CT-aware pipes are added on top.

**build overlay.**

| Slot | Value |
| --- | --- |
| pkg-config modules | BOTH `doca-flow-ct` AND `doca-flow` — quote both `--cflags` and both `--libs` separately. Mixing one `.pc` with the other's headers / libraries is the canonical "I link, but my first `doca_flow_ct_*` call returns `_DRIVER`" |
| Version anchors | `pkg-config --modversion doca-flow-ct` MUST equal `pkg-config --modversion doca-flow`, AND both MUST equal `doca_caps --version`. Mismatch → escalate to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 BEFORE diagnosing the CT layer itself |
| Header includes | The CT-only headers add to (not replace) the doca-flow headers the parent [`## build`](#build) prescribes; both header trees are required |
| `.pc` discovery | `pkg-config --list-all | grep doca-flow` confirms BOTH `.pc` files are visible to the build; missing `doca-flow-ct.pc` is the *"include resolved, link failed"* shape |

**modify overlay.** Take the closest shipped CT sample (an
installed CT sample in the public DOCA samples bundle whose 5-
tuple shape, NAT requirement, and overlay encapsulation match
the user's workload), apply a minimum-diff onto the user's
existing doca-flow setup:

- Do NOT recreate the user's pipe scheme from scratch — port the
  sample's CT bookkeeping (context creation, aging-table sizing,
  CT pipe-builder wrap calls) onto the existing flow.
- Each NAT variant added (SNAT, DNAT, combined) requires its own
  pre-modify cap-query.
- A 5-tuple shape change (e.g. adding overlay-aware CT to a
  previously plain CT setup) requires a new per-overlay cap-query.
- After modify: validate the wrapped pipe via
  `doca_flow_pipe_validate` BEFORE attempting `pipe_create`, per
  the parent's pipe-validate rule.

**run / test overlay.** Per
[`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct):

1. **Single-flow CT smoke.** ONE 5-tuple, ONE CT entry add, ONE
   matching traffic flow, ONE counter increment. The parent's
   stateless smoke from [`## test`](#test) step 1 MUST already
   pass first.
2. **Multi-flow smoke** ONLY after single-flow is green: a small
   set of distinct 5-tuples (e.g. 16), one entry per flow,
   confirm per-CT-entry counters increment in lockstep with the
   matching traffic.
3. **Aging smoke** with a deliberately short aging timer
   (within the cap-advertised range): add a CT entry, send one
   matching packet, stop traffic, wait at least the aging
   period plus granularity, confirm the entry is evicted via
   the CT-entry counter API or programmed-entry dump.
4. **NAT-aware smoke** (per supported NAT variant — separate
   tests for SNAT, DNAT, combined): add an entry whose action
   rewrites the variant the cap-query reported as supported,
   confirm the outbound traffic carries the rewritten 5-tuple,
   confirm reverse traffic is matched on the original tuple.
5. **Negative tests** the agent should propose explicitly:
   add an entry with an out-of-range aging timer (expect
   `_INVALID_VALUE` — confirms the cap-range is the runtime
   authority); add entries past the cap-advertised max
   concurrent flows (expect `_FULL` — confirms table sizing
   was honest); attempt a NAT variant the cap-query reported
   as unsupported (expect `_NOT_SUPPORTED` — confirms the
   cap-query is the right gate).
6. **Sustained-run loop** ONLY after all four smokes are green:
   stream traffic that exercises CT entry add / aging eviction
   in a continuous loop while watching per-CT-entry counters,
   per-entry aging timestamps, and connection-state transitions
   per [`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct).
   This is the only stage where the agent should propose
   running the user's full workload.

**debug overlay.** Layered on the parent's [`## debug`](#debug)
ladder:

- `DOCA_ERROR_BAD_STATE` from a CT-layer call is *always* a
  layering / lifecycle violation: doca-flow port not started,
  OR `doca_flow_ct` context not started before CT entry add,
  OR port stop before CT context stop. Walk the lifecycle in
  this order — port-start → ct-context-create → ct-context-start
  → ct-entry-add → … → ct-context-stop → port-stop — BEFORE
  inspecting any individual CT call.
- `DOCA_ERROR_FULL` on entry add is *always* a table-sizing /
  aging-pressure mismatch with the workload. Read the per-CT-
  entry counters to identify stale entries; either wait for
  aging eviction, evict explicitly, or — if the workload truly
  needs more flows than the device supports — surface the
  device-fit gap honestly.
- Traffic not matching a freshly-added CT entry is *almost
  always* a 5-tuple-shape disagreement between the entry add
  and the traffic on the wire. Read both sides verbatim — the
  cap-query is NOT the right diagnostic here; the entry shape
  vs traffic shape comparison is. Same shape as the parent
  *"pipe matches nothing"* diag in [`## debug`](#debug), with
  CT's 5-tuple match instead of an arbitrary pipe match.
- NAT translation conflicts surface as `DOCA_ERROR_INVALID_VALUE`
  on entry add. Per
  [`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct), do
  NOT invent a translation to resolve the conflict — surface
  the policy conflict to the user.
- Aging timer outside the cap-range surfaces as
  `DOCA_ERROR_INVALID_VALUE` at context configure (NOT at
  entry add). Re-quote the cap-advertised range AND
  granularity; the cap query is the runtime authority over any
  prose recall of supported ranges.

## Command appendix

Flow-specific commands the verbs above reach for, grouped by purpose
so the agent picks the right family without searching prose. Every row
is a class — the agent must not invent flags beyond what the row
names; the *flag-discovery* rule is `--help` against the installed
binary or `pkg-config` against the installed `.pc`, not prose recall.

| Purpose | Command | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Discover installed Flow version | `pkg-config --modversion doca-flow` | [`## configure`](#configure) step 1 | Matches the version pinned in other places (`doca_caps --version`, `applications/VERSION`). |
| Discover Flow link flags (release flavor) | `pkg-config --libs doca-flow` | [`## build`](#build) | Returns the canonical `-l` list. Hand-typed `-l` lines are the failure mode. |
| Discover Flow link flags (trace flavor) | `pkg-config --libs doca-flow-trace` | [`## debug`](#debug) step 3 + [doca-debug ## configure](../../doca-debug/TASKS.md#configure) step 3 | Selects the trace `.so` that emits per-pipe / per-entry trace output. |
| Discover device + steering-mode capabilities | `doca_caps --list-devs` | [`## configure`](#configure) step 2 + [doca-caps](../../tools/doca-caps/SKILL.md) | Lists every device DOCA sees with the active steering mode and supported match / action kinds. |
| Enumerate ports / representors | `devlink dev show` + the installed Flow port-enumeration sample | [`## configure`](#configure) step 3 | Shows the BlueField port and every representor the user expects to forward to. |
| Validate a pipe spec (read-only) | `doca_flow_pipe_validate` (or the dry-run sample on versions where validate is not exposed) | [`## test`](#test) step 1 | Returns success; failure means the spec is internally inconsistent — do not call `pipe_create`. |
| Raise log verbosity for a Flow run | `--sdk-log-level 70` on the program command line | [`## run`](#run) + [doca-debug CAPABILITIES.md ## Observability](../../doca-debug/CAPABILITIES.md#observability) | TRACE / DEBUG lines appear in stderr; the Flow lifecycle calls are visible. |
| Read per-entry / per-pipe counters | The Flow counter API (Flow API reference) | [`## debug`](#debug) step 1 | Counter for the suspected entry is non-zero under expected traffic. |
| Dump the programmed-entry table | `doca-flow-inspector` (or the trace flavor's dump path) | [`## debug`](#debug) step 3 | Output matches the user's mental model of the pipe. Diff = bug. |

Three cross-cutting rules for this appendix:

- **Never invent Flow flags.** The Flow API is large and version-gated;
  `--help` on the installed binary and `pkg-config --list-all | grep
  doca` are the only safe sources.
- **Never paraphrase a Flow `DOCA_ERROR_*`.** Quote
  `doca_error_get_descr()` verbatim — the layer-classifier in
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug) layer 5
  needs the exact text.
- **Cross-link instead of duplicate.** Cross-cutting commands (the
  read-only triple, `dmesg`, `mlxconfig -d <pcie> q`) live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  this appendix names only the Flow-specific ones.

## Deferred task verbs

The following verbs are out of scope for this skill but are commonly
asked in the same conversations. Route them as follows so the agent
does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring — defer to
  [doca-public-knowledge-map ## Layout of an installed DOCA package](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed.
- **deploy.** Deploying BlueField images, provisioning DPUs at scale,
  Kubernetes operator workflows — out of scope for Phase 1 and reserved
  for a future platform skill. For now, point the user at the DOCA
  Platform Framework entry in `doca-public-knowledge-map` and stop
  there.
- **rollback.** Coordinated steering-plane rollback across multiple
  DPUs and host nodes — out of scope for Phase 1 and reserved for a
  future platform skill. For single-DPU spec rollback within a session,
  the right verb in this skill is `## modify` with a delta that
  removes the offending entries; do not invent a "rollback" workflow.
