# DOCA Flow workflows

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
   between the user's mental model and the dump is the bug.
4. **Error code mapping.** Any `DOCA_ERROR_*` returned during the
   investigation routes through the taxonomy in
   [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).
5. **Version sanity.** If a previously working spec now fails or behaves
   differently, confirm the installed DOCA version did not change
   (procedure lives in `doca-public-knowledge-map`). A library upgrade
   between sessions is a common and easy-to-miss cause.
6. **Escalation criteria.** If counters move correctly but observed
   behavior is still wrong AND the trace dump matches the spec AND the
   version is unchanged, the bug is below the Flow API surface (driver
   or firmware). Stop attempting Flow-spec changes; capture state and
   escalate via the platform's diagnostic CLIs.

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
