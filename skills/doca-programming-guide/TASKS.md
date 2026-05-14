# DOCA programming guide workflows

Read this file when the loader sent you here from [SKILL.md](SKILL.md). For the underlying surface — the shape of DOCA, the universal lifecycle, the cross-library version-compat rule, the `DOCA_ERROR_*` taxonomy, the program-side observability surface, and the program-side safety policy — see [CAPABILITIES.md](CAPABILITIES.md). For env-class workflows (install verification, `pkg-config` wiring, hugepages, the *I have no install yet* procedure with the NGC container fallback), see [`doca-setup`](../doca-setup/SKILL.md). For routing, docs URLs, the on-disk install layout, and how to check the installed DOCA version, see [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

Each verb describes the **shape of the workflow**, not a copy-paste recipe. Library-specific overrides (which sample to start from, which fields to swap, which capabilities to check, which errors to expect) live in the matching library skill — never here.

## configure

Goal: get the program itself into the right starting state — the right version, the right build flavor, the right capability picture — *after* the env-class precondition (a clean `pkg-config doca-<library>` on the user's host) is already satisfied.

1. **Confirm the env precondition.** This skill assumes [`doca-setup ## configure`](../doca-setup/TASKS.md#configure) has already run and `pkg-config --modversion doca-<library>` returns a version. If it doesn't, **stop** and route the user to [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install) (the NGC container fallback is the universal first option there) or [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) (if the env is broken in a recoverable way). Do not work around an env failure with a code change.

2. **Quote the installed DOCA version.** Use the procedure in [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md). API names, sample filenames, and capability-matrix answers all depend on this — the version the user has on disk is the only honest source.

3. **Pick the build flavor.** Trace flavor (`doca-<library>-trace`) for first-app development; release flavor (`doca-<library>`) for performance work. Rationale and selection criteria are in [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes); env-side mechanics (where the trace `*.so` lives, `LD_LIBRARY_PATH`) are in [`doca-setup ## configure`](../doca-setup/TASKS.md#configure).

4. **Discover the library's capabilities on this host.** Run `doca_caps`, plus the library's own capability-query API (Flow has one, RDMA has one, Comch has one) — the library skill names the call. Record the active mode, the supported features, and the budgets *before* designing the program; designing for features-not-on-this-hardware is the most common cause of *"the spec validates but won't program"*.

5. **Restate the user's intent in library-neutral terms.** Confirm *what runs where* (host or DPU), *which devices / queues / pipes / channels are involved*, *what the success criterion is*. If any of these is unclear, stop and ask. The library skill takes over from here for the library-specific configuration.

## build

Goal: produce a buildable artifact from DOCA application source — yours or a copy of a shipped sample — using the canonical `pkg-config` + meson pattern that any DOCA program follows.

This verb has two tracks because DOCA is a C ABI consumed from many languages. Pick the right one before issuing any command.

### Track 1 — C / C++ consumers (canonical)

The shipped DOCA samples and reference applications are C, built with meson. Your custom application uses the same shape.

1. **Stage the build out-of-tree.** Never build into `/opt/mellanox/doca/`. Standard pattern:

   ```bash
   meson /tmp/build-<project>
   ninja -C /tmp/build-<project>
   ```

2. **Declare the DOCA dependency in `meson.build` via `pkg-config`.** Use the library's own `pkg-config` module name (`doca-flow`, `doca-rdma`, `doca-comch`, …) — not a hand-typed `-l...` flag list. The `pkg-config` module is the source of truth for include paths and link flags; hard-coded paths drift across releases.

3. **Honor the build flavor decision from [`## configure`](#configure) step 3.** Trace flavor links against the `doca-<library>-trace` module; release flavor links against `doca-<library>`.

4. **Map any build-time error to the env taxonomy first.** If meson reports a missing dependency or ninja reports an undefined symbol, the symptom is almost always env-class (wrong install profile, wrong `PKG_CONFIG_PATH`, wrong build flavor) — route to [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) before touching the source.

### Track 2 — Other languages (Rust, Go, Python, …)

DOCA does not ship official bindings in non-C languages inside this repository. The consumption path is FFI / language-specific bindings against the same `*.so` libraries the C samples link against.

1. **Confirm the install host gives you the C ABI surface.** `pkg-config --cflags --libs doca-<library>` returns the include path and link flags; the headers under `/opt/mellanox/doca/infrastructure/include/` are the authoritative symbol declarations; the `*.so` files under `/opt/mellanox/doca/lib/<arch>-linux-gnu/` are what your binding loads at runtime. Verify all three are present before any binding-side work. If any of those checks fails, route to [`doca-setup ## debug`](../doca-setup/TASKS.md#debug).

2. **Pick the binding strategy honestly.** If a community or user-built binding for the user's language exists, point at its repository (the agent **must** verify it exists by fetching its repo or package registry — never invent a binding name). Otherwise the user is doing direct FFI: `bindgen` for Rust, `cgo` for Go, `cffi` / `ctypes` for Python, equivalents for other languages.

3. **Generate or write the binding in the user's own toolchain.** This skill does not author wrappers. The agent describes the C-side surface (header path, `*.so` filename, lifecycle order, error pattern) and lets the user's binding tooling do its job. The library skill (e.g. [`doca-flow`](../libs/doca-flow/SKILL.md)) supplies the API-surface guidance the wrapper has to honor.

4. **Read the C samples even if you're not writing C.** The order of API calls in `/opt/mellanox/doca/samples/doca_<library>/<sample>/` is the same regardless of the calling language. The wrapper translates the shape; it does not invent a different shape.

## modify

Goal: take a working shipped sample and **derive a custom first application** for the user, by editing a verbatim copy of the sample on the user's own DOCA-installed Linux host (bare-metal, VM, *or NGC container*). The substance of the modified file is NVIDIA's BSD-3 sample (verified, compiled, shipped) with a small, named set of user-domain values swapped. The agent does **not** author DOCA library source code from scratch.

**Language scope of this verb.** The shipped DOCA samples are written in C; this is the only application source code NVIDIA ships in this repository. The modify-a-sample workflow below is therefore the C / C++ first-app track. For consumers writing their first DOCA application in another language (Rust, Go, Python, …), this verb is *not* the right path — those users should still build a shipped sample (Track 1 of [`## build`](#build)) to verify their install is healthy, and then use Track 2 of [`## build`](#build) plus the matching library skill's bindings / FFI guidance for the wrapper-side work the user does in their own toolchain. The agent must not pretend the modify-a-sample workflow produces a Rust crate, a Go module, or a Python package; the workflow's output is a modified copy of NVIDIA's C sample.

The generic pattern below is library-agnostic *across DOCA libraries* (Flow, RDMA, Comch, …) but C-specific *within a library*. Library-specific values (which sample, which fields the user must change, which actions to keep) live in the matching library skill — for Flow, see [`doca-flow ## build`](../libs/doca-flow/TASKS.md#build).

### Precondition

This verb requires *all* of:

| Precondition | Check |
| --- | --- |
| Linux environment the agent can reach (the user's machine, an SSH session, a Cursor remote, *or a running NGC DOCA container* — any environment where the agent can `ls` the install tree) | shell available |
| DOCA installed | `ls /opt/mellanox/doca` returns a populated tree |
| The source sample is present | `ls /opt/mellanox/doca/samples/<library>/<sample_name>/` lists `meson.build` and the source files |
| `pkg-config` knows DOCA | `pkg-config --modversion doca-<library>` returns a version string |

If any precondition fails, **do not proceed and do not invent a substitute**. Route to [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install); that section is what the agent does instead, and its Path 0 (NGC DOCA container, `nvcr.io/nvidia/doca/doca`) is the universal way to satisfy these preconditions on macOS, Windows, or Linux without DOCA. Authoring application source code in *any* language (C, C++, Rust, Go, Python, …) from documentation prose to "fill the gap" is the failure mode this verb is here to prevent — it violates [`AGENTS.md`](../../AGENTS.md) ground rule #3 and would ship code that has never been compiled / linked / FFI-loaded against the live DOCA library.

### Steps (preconditions met)

1. **Identify the source sample.** Use the smallest shipped sample that already does something close to what the user asked for. Confirm it builds clean ([`## build`](#build) above) and runs clean ([`## run`](#run) below) *before* any modification. The library skill names the right starting sample for common shapes; do not pick from memory.

2. **Read the actual contents of the sample.** Before describing the file, list it (`ls`) and read the `meson.build` plus each `.c`/`.h`. The shape of the sample on the user's installed version is the truth, not what an older release looked like or what a docs page describes.

3. **Copy the sample out of `/opt/mellanox/doca/` into a writable location.**

   ```bash
   cp -r /opt/mellanox/doca/samples/<library>/<sample_name>/ ~/dev/my-first-<library>-app/
   cd ~/dev/my-first-<library>-app/
   ```

   Never edit the install tree itself ([`doca-setup CAPABILITIES.md ## Safety policy`](../doca-setup/CAPABILITIES.md#safety-policy) item 1). The copy is the user's source code from this point forward. *Inside an NGC container*, mount a host directory at `cp` time (e.g. `docker run -v $HOME/dev:/work …`) so the modified copy persists when the container exits.

4. **Identify the *minimum* set of values to change in the copy.** Library-specific list lives in the library skill. For *every* library the recipe is the same shape: keep all init / teardown boilerplate; keep the validation calls; keep the error handling; only swap the small set of user-domain values. Every byte not changed is a byte not debugged.

5. **Apply the swap as a minimum-diff edit on the copied file.** Where the user has given you a real value, substitute the literal. Where the user has not yet given you a value but the build would otherwise fail to compile, leave a `/* TODO: replace with your <thing>; see <how-to-find-it> */` comment around a syntactically-valid placeholder constant. The placeholder rule is **only for values that block compilation if absent** (constants, `#define`s the rest of the file references); it is not a license to leave function bodies or DOCA API call sequences unfilled. The init / teardown / validation / error-handling calls all stay verbatim from the upstream sample.

   Example placeholders (note: the *surrounding code* is the upstream sample's, untouched):

   ```c
   /* TODO: replace with your destination MAC. Use `ip link show <iface>` on
    * the originating host to obtain the real value. */
   uint8_t target_mac[6] = { 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 };

   /* TODO: replace REPRESENTOR_PORT_ID with the port_id reported by the
    * sample's enumeration printout for your representor. */
   #define REPRESENTOR_PORT_ID 1
   ```

6. **Update the build manifest minimally.** The simplest correct change to the sample's `meson.build` is to rename the executable; do not refactor build options. If the original sample required `-D enable_<flag>=true`, keep that option in your build invocation. If the user's project must build *standalone* (outside the DOCA samples meson tree), the standalone `meson.build` depends on `doca-<library>` via `pkg-config` ([`## build`](#build) Track 1 step 2). The agent constructs that manifest *in the user's project directory*, not from a template pinned in this skill.

7. **Build and run staged.** Build with [`## build`](#build). Run with [`## run`](#run) against the smallest possible scope (one representor, one queue, one channel — whatever the library's unit of damage is per [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy) item 2). Read the output. Only after the staged run succeeds may the user widen the scope. *NGC-container caveat:* the build half of this step works inside the container; the actual hardware-runtime half does not — the container has no access to a real NIC / DPU. For runtime, the user has to graduate from Path 0 (container) to Path A or Path C in [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install).

8. **Document what was changed.** A two-line `README` next to the modified sample saying *"Derived from `<source-sample>` on `<date>` against DOCA `<version>`. Modified fields: `<list>`."* lets the user re-derive against the next DOCA release without having to re-read the agent's chat history.

## run

Goal: launch a built DOCA program (shipped sample or derived custom app) and read its output meaningfully.

1. **Pre-run checklist.** Re-verify the env preconditions via [`doca-setup ## test`](../doca-setup/TASKS.md#test) (hugepages mounted, devices visible, representors enumerated). A failed pre-run check is faster to diagnose than a runtime error. *Inside an NGC container*, several of these checks are vacuously satisfied (no real NIC) — that's expected; runs that need real hardware will fail at start, and the right move is to graduate the user to a hardware path per [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install).

2. **Use the program's own CLI flags.** Each shipped sample documents its `-h` flags. The agent must use those, not invent new ones — the most common runtime error is a flag rename across DOCA versions.

3. **Run with verbose logging the first time.** Add `--sdk-log-level 70` (DOCA `LOG_TRACE`) on the first run of any new code path. Re-running with reduced verbosity once the path is known to work is a deliberate later step; see [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability).

4. **Where logs go.** DOCA libraries log to stderr by default. Some long-running services log via `journald` or a configured log directory; check `/var/log/doca*` or the service's own README before assuming output is missing.

5. **Map runtime failures to the right layer.** Startup failures of the form *"cannot find any working PCI driver"*, *"no free 2048 kB hugepages"*, *"representor X not found"* are **env-class** and route to [`doca-setup ## debug`](../doca-setup/TASKS.md#debug). Failures of the form `DOCA_ERROR_*` returned from a library API call are **program-class** and route to [`## debug`](#debug) below (with the library-specific overlay in the matching library skill).

## test

Goal: validate the program — and the system context around it — **before** committing to hardware / runtime side-effects.

1. **Validate the spec / configuration before commit.** Every DOCA library that programs hardware (Flow in particular) exposes a *validate* call separate from the *commit / start / program* call. Use validate first; never enter a commit path with an un-validated spec. This is the cross-library validate-before-commit rule from [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy). Library skills extend it with library-specific *what to validate*.

2. **Capability cross-check.** Re-confirm that every feature your program intends to use is supported by the active mode and version on this host. Validation answers *"is the spec internally consistent"*; capability cross-check answers *"will this hardware / library actually accept it"*.

3. **Smoke-test by building and running one shipped sample first.** A *known-good* sample built and run cleanly is the cheapest end-to-end check that the install + your build env + your runtime preconditions are all healthy. Pick the smallest sample that exists for the library family the user cares about — the library skill names it. Inside an NGC container the build half is the meaningful check; the runtime half is reserved for a hardware path.

4. **Negative test.** Construct one deliberately failing input and confirm the library rejects it with the expected `DOCA_ERROR_*`. This is the cheapest way to detect a stale or wrong-version library before going live.

## debug

Goal: when a DOCA program fails *after* the env is known healthy, walk the layered diagnosis tree top-down so the agent does not jump to library-internal code-fix recommendations against a symptom it can explain at a higher layer.

Investigation order — **always**:

1. **Env layer (sanity check, then move on).** Re-run the env-class checks via [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) layers 1–4 (install / version / build / runtime). Only continue here if those are clean; an env-class failure is not a programming bug.

2. **Version layer (program-side).** `pkg-config --modversion doca-<library>` against the runtime `doca_caps --version`. Mismatch ⇒ partial upgrade or stale build env; reinstall consistently before code changes ([CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility)).

3. **Lifecycle order layer.** Did the program call the library's APIs in the universal order *cfg-create → init → start → use → stop → destroy*? Out-of-order calls produce `DOCA_ERROR_BAD_STATE`. The library skill names which specific calls map to which lifecycle phase.

4. **Capability layer.** Did the program ask for a feature the active mode does not support? Re-run capability discovery from [`## configure`](#configure) step 4 and cross-check; an unsupported feature returns `DOCA_ERROR_NOT_SUPPORTED`. Code-side workarounds for `NOT_SUPPORTED` are almost always wrong — change intent, switch hardware/mode, or escalate.

5. **Error-description layer.** For any returned `doca_error_t`, call `doca_error_get_descr()` and quote what it actually says — do not paraphrase from memory. The cross-library error meanings are in [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy); the library-specific overlay is in the matching library skill (Flow's `DOCA_ERROR_*` decision tree, for example, lives in [`doca-flow ## debug`](../libs/doca-flow/TASKS.md#debug)).

6. **Library layer.** Only after (1)–(5) are clean: route the conversation to the library skill for library-internal API semantics.

If the agent finds itself recommending a library-internal code change before completing (1)–(5), it is jumping layers — back up.

## Deferred task verbs

- **`install`.** Installing DOCA on a fresh host, or reaching an install from a no-install host (NGC container fallback at `nvcr.io/nvidia/doca/doca` for macOS / Windows / Linux without DOCA, lab box, cloud Linux without NIC, hardware path) — env scope. Defer to [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install) and the Installation Guide via [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).
- **Env preparation.** `PKG_CONFIG_PATH`, hugepages, devlink, representor enumeration — env scope. Defer to [`doca-setup ## configure`](../doca-setup/TASKS.md#configure).
- **Library API specifics.** Constructing a Flow pipe, RDMA queue setup, Comch channel construction, etc. — library scope. After this skill's verbs have produced a buildable, runnable program shape, hand off to the matching library skill (e.g. [`doca-flow`](../libs/doca-flow/SKILL.md)) for API-level guidance.
- **`deploy` / `rollback`.** Provisioning multiple BlueFields, coordinated firmware / BFB updates across a fleet, or staged rollback — out of scope. Reserved for a future platform skill (`doca-platform-deploy` or similar). Until that ships, the agent should stop and tell the user this is fleet-orchestration scope and recommend they engage their platform team rather than guess.
