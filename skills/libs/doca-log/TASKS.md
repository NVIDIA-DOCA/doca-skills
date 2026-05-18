# DOCA Log workflows

**Where to start:** The verbs run `configure → build → modify →
run → test → debug`. Skip ahead only when the user is already
past a verb. The `## test` verb is an iterative loop (single-tier
smoke → flip-the-other-tier check → loop back if the two-tier
model is not behaving as expected), not a one-shot pass — see
the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the two-tier log-level model, the
registry + source-register lifecycle, the `DOCA_LOG_*` macro
family, the `pkg-config` ambiguity rule, the path-selection rule
against language-native logging, the error taxonomy,
observability, and safety policy, see
[CAPABILITIES.md](CAPABILITIES.md). For the cross-library DOCA
patterns layered under everything below (the universal lifecycle,
the cross-library `DOCA_ERROR_*` taxonomy, the modify-a-shipped-
sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
For the cross-cutting debug ladder DOCA Log feeds into, see
[`doca-debug`](../../doca-debug/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through
the steps in order, verifying preconditions before recommending
the next call.

## configure

Goal: stand up DOCA Log in a DOCA app (or in a freshly modified
DOCA sample) so the user's own emission lines run alongside the
DOCA library's own log lines, with the two tiers under
independent control.

Steps the agent should walk the user through:

1. **Confirm DOCA Log is the right primitive for this app.**
   Walk the path-selection rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   If the codebase has no DOCA-side context (no `doca_*` calls,
   no DOCA libraries linked), DOCA Log is not the right
   answer — language-native logging is. Recommending DOCA Log
   *for* the user when the path-selection rule rules it out
   is a wrong answer regardless of how cleanly the rest of the
   configure step goes.
2. **Confirm the installed DOCA version.** Use the procedure in
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
   Quote the version observed (`pkg-config --modversion
   doca-common`, then `doca_caps --version`); do not assume
   "latest". The four-way match rule lives in
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility);
   if the observed sources disagree, route there before any
   DOCA Log diagnosis.
3. **Walk the two-tier model with the user, BEFORE any code.**
   Per the two-tier table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the agent must surface that SDK level controls *DOCA
   library internals* (default `WARNING`; setter
   `--sdk-log-level` / `DOCA_LOG_LEVEL_SDK`) and app level
   controls *user code emissions* (default `INFO`; setter is
   the app-side registry). Confusing the two is the
   number-one first-app debug failure. The agent should
   confirm the user's intent (do they want to see *DOCA
   library internal* lines, *their own* lines, or both) and
   pick the tiers accordingly.
4. **Register each log source ONCE before any emission.** For
   the user's own source files (typically one per `.c` file or
   per component), call `doca_log_source_register(<name>,
   &source_id)` at component init time. Per the lifecycle in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   objects table, an unregistered source ID passed to a
   `DOCA_LOG_*` macro returns `DOCA_ERROR_INVALID_VALUE`. The
   register call sits BEFORE any `DOCA_LOG_*` from that
   source; do not invert the order.
5. **Pick the level enum from the always-present set first.**
   Per the level-enum rule in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   `CRITICAL` / `ERROR` / `WARNING` / `INFO` / `DEBUG` are
   always present; `TRACE` and `DISABLE` are not portable
   across older trains. The agent should default to the
   always-present set unless the user has explicitly verified
   the extra levels in the installed `doca_log.h`.

If any step fails with a `DOCA_ERROR_*`, route through the error
taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying.

## build

Goal: compile a DOCA Log consumer against the user's installed
DOCA, with `pkg-config` as the source of truth for include + link
flags — but with explicit handling for the `doca-log` vs
`doca-common` ambiguity.

The build pattern for any DOCA C/C++ consumer is fully
documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the DOCA Log-specific overlay:

| Slot | Value | Why it matters |
| --- | --- | --- |
| `pkg-config` module name (probe order) | First try `pkg-config --exists doca-log`. If exit 0, use `doca-log` for `--cflags` / `--libs`. Otherwise fall back to `pkg-config --exists doca-common` (which is always present on any healthy install) and use `doca-common`. | DOCA Log functionality may ship as a standalone `doca-log.pc` on some releases and be folded into `doca-common.pc` on others. The agent must verify on the user's install — quoting one or the other from memory is the canonical wrong answer. See [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) `pkg-config` probe rule. |
| Include flags | `pkg-config --cflags <module>` for whichever module the probe selected | Resolves to headers including `doca_log.h` under `/opt/mellanox/doca/infrastructure/include/` |
| Link flags | `pkg-config --libs <module>` for whichever module the probe selected | Pulls in the matching `*.so` set; do not hand-type the `-l` line |
| Companion libraries | `doca-common` is implied whenever DOCA is linked at all; any other DOCA library the app *also* uses adds its own `pkg-config` module | DOCA Log is an *every-DOCA-app* concern, so the link line typically already includes the right module via the user's main library's `pkg-config` transitive resolution |

For non-C consumers (Rust, Go, Python), the wrapper consumes the
same `*.so` set through FFI; the build-time version visibility
goes through the language's own FFI generator (e.g. `bindgen`
against `doca_log.h`). The two-tier model and the source-
register lifecycle still apply — the wrapper consumes a `*.so`
that has its own runtime version per
[`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).

## modify

Goal: take the closest-fitting shipped DOCA sample (any of them
— DOCA Log shows up in every shipped sample's `*_main.c`) and
apply a **minimum diff** to add the user's own DOCA Log lines,
without rewriting from scratch.

The universal modify-a-shipped-sample workflow is in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify);
this skill provides the DOCA Log-specific slot fill.

| Slot | Value | Source |
| --- | --- | --- |
| Sample tree | Any shipped sample's `*_main.c` under `/opt/mellanox/doca/samples/<library>/<sample>/`. DOCA Log has no dedicated sample directory — it is wired into every shipped sample. | Confirmed by `ls /opt/mellanox/doca/samples/` and reading any sample's `*_main.c` |
| Pick the closest sample | Whichever sample the user is *already* modifying for their primary library (DMA, Comch, Flow, RDMA, …). DOCA Log piggy-backs on that sample's existing logging setup; do not pick a sample on the basis of "best DOCA Log usage" — every sample is canonical. | Per the path-selection table in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) |
| Identify the modify surface | Add one `doca_log_source_register` call at component init time (typically near `main()` or in a per-`.c` init function); replace ad-hoc `printf` / `fprintf(stderr, …)` lines with the matching `DOCA_LOG_*` macro against the new source ID | The sample's existing `*_main.c` is the carrier; the user's new emissions are the diff |
| Pick the level enum from the always-present set | `CRITICAL` / `ERROR` / `WARNING` / `INFO` / `DEBUG` — see the level-enum rule in [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) | Reading `doca_log.h` on the user's install per the headers-win rule in [`doca-version`](../../doca-version/SKILL.md) |
| Keep the build manifest unchanged | The sample's existing `meson.build` already wires the right `pkg-config` module (`doca-common` at minimum); do not switch to a hand-rolled Makefile for *"simplicity"* — it removes the version-check rail | Per the build slot table in [`## build`](#build) |

The agent's anti-pattern alert: a *"clean rewrite"* that swaps
the sample's `DOCA_LOG_*` calls for `printf` is almost always
the wrong shape. It severs interop with `--sdk-log-level`, with
downstream consumers (DOCA Log Service, DOCA Telemetry
Service), and with the per-line format every other DOCA
artifact on the host produces. Keep the minimum diff; keep
DOCA Log.

## run

Goal: execute the built program and demonstrate both tiers
responding to their respective setters, before the user starts
adding real protocol logic.

Steps the agent should walk the user through:

1. **Confirm the active DOCA install** the binary is linking
   against. Re-quote `pkg-config --modversion <module>` (the
   module the probe in [`## build`](#build) selected) and
   `doca_caps --version`; they must agree. A mismatch means
   the binary is loading a different `libdoca_*.so` than the
   one its build-time `pkg-config` saw — debug via
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   before assuming a DOCA Log bug.
2. **Set the SDK tier explicitly on first run.** Pass
   `--sdk-log-level <level>` (most shipped samples / reference
   apps accept it) or `DOCA_LOG_LEVEL_SDK=<level>` in the
   environment. The default is `WARNING`; for a first run the
   agent should default the SDK tier to `WARNING` (do not
   crank to DEBUG) so the user's own lines are not buried in
   DOCA-library internal trace. See
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability).
3. **Set the app tier explicitly on first run.** Use the app-
   side registry setter (e.g.
   `doca_log_level_set_global_lower_limit` on the app-tier
   registry, or per-source via `doca_log_source_set_level`).
   For a first run the agent should default the app tier to
   `DEBUG` so the user can see their own DEBUG-shaped lines;
   then drop to `INFO` for steady-state operation.
4. **Smoke one emission per level the user cares about.**
   Emit one `DOCA_LOG_INFO`, one `DOCA_LOG_DBG`, and one
   `DOCA_LOG_ERR` from the user's own source. Confirm the
   line shape (timestamp / level / source / message) matches
   the per-line format the shipped DOCA samples produce. If
   the lines are missing entirely, the first hypothesis is
   *tier confusion* (per [`## debug`](#debug) layer 6
   overlay), not a DOCA Log bug.
5. **Capture the output for the test loop.** `stderr` is the
   default sink; redirect to a file (`2> log.txt`) so the
   subsequent `## test` iterations have a stable artifact to
   diff against.

For the runtime version + `LD_LIBRARY_PATH` cross-checks that
underlie *"the program built but does nothing"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run).

## test

Goal: prove the two-tier model is behaving as expected — that
the SDK setter reaches DOCA library internals and *only*
internals, and that the app setter reaches the user's own lines
and *only* user lines — before claiming the *"wire DOCA Log
into the app"* journey is done.

This is **a loop, not a one-shot pass.** Each iteration flips
one of the two tiers and verifies the response. The loop
terminates when the user has observed both tiers responding
independently AND the user's own emission lines appear at the
level the app tier was set to.

Iteration shape:

1. **Set SDK = WARNING, App = DEBUG; run; observe.** This is
   the canonical first-app shape. The user should see DOCA
   library internal log lines only at WARNING and above
   (rare; mostly silent on a healthy run), and *all* of the
   user's own `DOCA_LOG_DBG`-shaped emissions. If the user
   sees only WARNING-and-above from their own code instead,
   the app tier did not take — to [`## debug`](#debug) ladder
   layer 6.
2. **Flip to SDK = DEBUG, App = WARNING; re-run; observe.**
   Now the picture should invert: DOCA library internal log
   lines flood (DEBUG every call), and the user's own DEBUG
   lines disappear (only WARNING-and-above from user code).
   If the user *still* sees their own DEBUG lines, the app
   tier is being implicitly controlled by the SDK setter
   somewhere — investigate for a misnamed setter or a stale
   build.
3. **Per-source override smoke.** Pick one source ID; raise
   its per-source level via `doca_log_source_set_level` while
   leaving the global app lower limit unchanged. Confirm that
   source's emissions respond to the per-source level
   independently of the global. Catches the case where the
   per-source setter and the global setter are not behaving
   as documented on this train.
4. **Custom-sink smoke (if used).** If the user has installed
   a custom backend / sink instead of the default `stderr`,
   emit one `DOCA_LOG_INFO` and confirm the line reaches the
   sink (file written / socket received / shipper line
   forwarded). A custom sink that `open()`s but never
   `write()`s is the silent-disappearance failure mode in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy);
   catch it here.
5. **Cross-version run** (if the user has multiple installs):
   re-run steps 1–3 on each install; quote the version per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   in the report. The `pkg-config` module name may differ
   (`doca-log` vs `doca-common`) but the two-tier behavior
   must be identical.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Step-1 ran; user sees DOCA-library DEBUG spam | The user (or the runner) cranked `--sdk-log-level` past WARNING; the SDK tier is at DEBUG / TRACE | Re-narrow: drop SDK back to WARNING and confirm; the user's own DEBUG lines should remain visible because the app tier is independent |
| Step-1 ran; user sees NONE of their own DEBUG lines | The app tier did not take. Most common case: app-side setter was called BEFORE the source was registered, so per-source level overrides did not apply | Re-walk [`## configure`](#configure) step 4 (source-register-before-emit); confirm the level setter runs after registration |
| Step-2 ran; user STILL sees their own DEBUG lines | A misnamed env var or setter is leaking SDK control into the app tier; or the build is stale and is using a previous level configuration | Rebuild against the currently installed DOCA; re-run; if it persists, route to [`## debug`](#debug) layer 6 |
| Per-source override (step 3) does nothing | The setter was called against a source ID that does not correspond to the emitting source (typo, wrong source registered) | Re-register; quote the source name back to the user; verify the ID returned matches the one used in the level setter |
| Custom-sink (step 4) writes nothing yet `open()` succeeded | Permission envelope on the sink path is wrong (file owner, socket ACL, shipper network ACL); per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) | Fix the sink's own permissions; do not invent a DOCA Log bug |

Loop termination: stop iterating once the SDK tier and the app
tier each respond independently to their own setters on at
least one round-trip. Beyond that, escalate suspicious
behavior to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured `stderr` redirect + version state as evidence.

## debug

Goal: when a DOCA Log call returns `DOCA_ERROR_*` or when log
lines do not appear at the level the user expects, isolate the
cause to a single layer before recommending any code change.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
Walk through it in order — install → version → build → link →
runtime → program → driver. This skill provides the DOCA Log
overlay at the *runtime* and *program* layers.

**Layer 5 (runtime) — DOCA Log overlay.**

- *Log lines do not appear at all.* First hypothesis is tier
  confusion: the SDK setter was used where the app setter was
  needed (or vice versa). Re-walk the two-tier model in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  before any code change.
- *Log lines appear at the wrong level.* The level enum
  passed to the per-source setter may not match the level in
  the `DOCA_LOG_*` macro the user is emitting. Cross-check
  the level enum against the always-present set in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
- *Log lines flood from DOCA library internals.* The SDK tier
  is at DEBUG / TRACE; drop it back to WARNING and re-run.
  This is *not* a DOCA Log bug; the tier is doing exactly what
  it was asked to do.

**Layer 6 (program) — DOCA Log overlay.**

- *`DOCA_ERROR_INVALID_VALUE` from `DOCA_LOG_*` emission.* The
  source ID is unregistered. Walk the call sequence: did
  `doca_log_source_register` run *before* this emission?
  Static initializers that emit at file-scope often run before
  `main()`-time registration and trip this — fix by deferring
  the emission to a function called after registration.
- *`DOCA_ERROR_BAD_STATE` from any DOCA Log call.* The DOCA
  Log subsystem is not initialized at the moment of the call
  (typically: emission from a destructor / `atexit` handler
  that runs after teardown; or emission from a static
  initializer that runs before init). Walk the universal
  lifecycle in
  [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes).
- *`DOCA_ERROR_NO_MEMORY` from a custom sink.* The custom
  sink's queue is saturated. This is NOT a DOCA Log bug — it
  is a sink-side backpressure problem. Drain the sink (or
  drop / coalesce at the app layer); do not retry. See
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- *Hand-off to the cross-cutting debug ladder.* When the
  symptom is *"my DOCA app misbehaves at runtime and I am
  using DOCA Log to find out why"*, DOCA Log is the
  observability surface — the layered ladder lives in
  [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
  This skill names *how to turn DOCA Log up*; that one names
  *which layer the symptom belongs to*.

Once the layer is identified, route to the matching debug
verb on the matching skill: install / build / link / driver to
[`doca-setup ## debug`](../../doca-setup/TASKS.md#debug);
version to
[`doca-version ## debug`](../../doca-version/TASKS.md#debug);
cross-cutting runtime to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug);
program-layer DOCA-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug).

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them as follows
so the agent does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring — defer to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the
  install-tree layout in
  [doca-public-knowledge-map ## Layout of an installed DOCA package](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed.
- **deploy.** Shipping a DOCA app at scale, routing DOCA Log
  output to centralized log aggregation systems (DOCA Log
  Service deployments, third-party shippers, K8s sidecars) —
  out of scope for this skill; partial guidance in
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the DOCA Log Service and DOCA Telemetry Service.
- **service-side logging.** Configuring log destinations for
  DOCA *services* (DMS, DTS, Firefly, …) is owned by the
  matching service skill, not by this library skill. This skill
  is the primitive the user wires into *their own* DOCA app.
- **performance tuning.** High-rate log emission, batched
  shipping, async sinks — DOCA Log itself is a synchronous
  primitive; performance-shaped concerns are owned by the
  custom-sink implementation, not by DOCA Log API surface.

## Command appendix

Every command below is **cross-cutting on DOCA Log** — it
answers a recurring class of question that comes up in the verbs
above. The agent should treat the *class* as load-bearing; the
worked example is a single instance. Run-as user is the
unprivileged user unless noted.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env
   --json` for version + libraries + sample paths in one
   shot; `version-matrix.json` for *"available since"*
   lookups when the user asks about a specific level enum).
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

| Command (worked example) | Owning step | Class of question it answers | What healthy output looks like |
| --- | --- | --- | --- |
| `pkg-config --exists doca-log; echo $?` | `## build` slot 1 | Does this install publish a standalone `doca-log.pc`, or is DOCA Log folded into `doca-common.pc`? | Exit 0 means standalone; exit nonzero means use `doca-common` |
| `pkg-config --exists doca-common; echo $?` | `## build` slot 1 | Sanity check that DOCA is installed at all (the fallback `pkg-config` module is always present on a healthy install) | Exit 0 |
| `pkg-config --cflags --libs <module>` | `## build` | What include + link flags does the linker need for whichever module the probe selected? | `-I` paths under `/opt/mellanox/doca/infrastructure/include/`; `-l` line including `-ldoca_common` and any standalone DOCA Log lib |
| `grep -RH 'doca_log_source_register\|DOCA_LOG_INFO' /opt/mellanox/doca/samples/ \| head` | `## modify` | Which shipped samples have canonical DOCA Log usage to read as a reference? | Multiple hits across `samples/<library>/<sample>/*_main.c` — DOCA Log is in every sample |
| `<binary> --sdk-log-level WARNING 2> log.txt` | `## run` step 2 | What does the SDK tier emit at WARNING (production default)? | Mostly silent on a healthy run; warnings are rare and load-bearing when they fire |
| `<binary> --sdk-log-level DEBUG 2> log.txt` | `## test` step 2 | What does the SDK tier emit at DEBUG (DOCA library internal trace)? | A flood of per-call DOCA library internal log lines; the user's own DEBUG lines remain controlled by the app tier and are *not* affected by this flag |
| `DOCA_LOG_LEVEL_SDK=DEBUG <binary> 2> log.txt` | `## run` step 2 | Same as above via env var (for samples that don't accept `--sdk-log-level`) | Same shape |
| `grep -E '^\[[0-9]' log.txt \| head` | `## test` step 1 | Are DOCA Log lines being emitted at all, in the canonical per-line format? | Per-line timestamp / level / source / message rows |

For commands shared across libraries (`pkg-config
--modversion`, `doca_caps`, `cat
/opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL` / `DOCA_LOG_LEVEL_SDK`) the cross-library
overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the DOCA Log-specific rows on top.
