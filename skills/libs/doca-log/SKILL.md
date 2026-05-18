---
name: doca-log
description: NVIDIA DOCA Log — DOCA's standardized logging primitive used by every shipped DOCA library, sample, and reference application. Covers the two-tier log-level model (SDK level for DOCA library internals via `--sdk-log-level` / `DOCA_LOG_LEVEL_SDK`; app level for user code via the app-side registry), the `doca_log_source_register` lifecycle for per-source IDs, the `DOCA_LOG_*` emission macros, `pkg-config` ambiguity (the library may ship as a standalone `doca-log` module on some DOCA releases and folded into `doca-common` on others — the agent must verify on the user's install), interop with DOCA Log Service and DOCA Telemetry Service consumers, and the path-selection rule against printf / syslog / language-native logging in a DOCA-app context.
kind: library
---

# DOCA Log

**Where to start:** This skill assumes DOCA is already installed and
the user is doing **hands-on DOCA Log work** — wiring DOCA's
logging primitive into a DOCA app or sample, tuning verbosity, or
debugging *"why don't my log messages appear"*. Open
[`TASKS.md`](TASKS.md) if the user wants to *do* something
(configure / build / modify / run / test / debug); open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
does DOCA Log express* on this install. If the user has not
installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the symptom is
"my DOCA app misbehaves at runtime and I am turning on logging to
diagnose it", DOCA Log is part of the answer but the cross-cutting
ladder lives in [`doca-debug`](../../doca-debug/SKILL.md) — read
this skill alongside it.

## Example questions this skill answers well

The CLASSES of DOCA Log questions this skill is built to answer,
each with one worked example. The agent should treat the *class*
as the load-bearing piece — the worked example is a single
instance.

- **"How do I wire DOCA Log into a DOCA app or sample without
  inventing the API?"** — worked example: *"I want my own
  per-component INFO / DEBUG lines emitted alongside the DOCA
  library's own log lines, in a freshly modified `doca_dma`
  sample"*. Answered by the source-register-before-emit
  lifecycle in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  objects table.
- **"Why don't my DEBUG lines appear even though I set
  `--sdk-log-level DEBUG`?"** — worked example: *"I set the SDK
  log level to DEBUG, my own DEBUG messages still aren't
  printed"*. Answered by the two-tier SDK-vs-app model in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  two-tier table — the SDK level controls *DOCA library
  internals*; the user's own DEBUG lines are controlled by the
  *app* level, which is a different setter.
- **"Why is my console flooded with DOCA library spam when I
  only wanted to see my own lines at DEBUG?"** — worked
  example: *"I cranked `--sdk-log-level DEBUG` for visibility
  and now every internal DOCA call dumps trace; I cannot find
  my own log lines"*. Same two-tier rule — the user wants
  SDK=WARNING (default) and app=DEBUG, not both at DEBUG. The
  agent's diagnostic ladder is in
  [`TASKS.md ## debug`](TASKS.md#debug) layer 6 overlay.
- **"Should I use DOCA Log or just `printf` / `fprintf(stderr,
  …)` / `syslog()` for my DOCA app?"** — worked example: *"my
  team already uses `syslog`; do I really need DOCA Log on
  top?"*. Answered by the path-selection rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  — for a DOCA-app context, DOCA Log is the right primitive
  because it interoperates with DOCA's centralized level
  controls and downstream DOCA-side consumers (DOCA Log Service,
  DOCA Telemetry Service); for a non-DOCA codebase with no DOCA
  context, language-native logging is fine.
- **"Is the DOCA Log module called `doca-log` or `doca-common`
  on my install?"** — worked example: *"`pkg-config --exists
  doca-log` returned nonzero; is DOCA Log even installed?"*.
  Answered by the `pkg-config` ambiguity rule in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  — DOCA Log functionality may ship folded into `doca-common`
  rather than as a standalone `doca-log.pc`. The agent must
  probe both before concluding it is missing.
- **"What does this `DOCA_ERROR_*` from a DOCA Log call mean?"** —
  worked example: *"`doca_log_source_register` returned
  `DOCA_ERROR_INVALID_VALUE`"*. Answered by the DOCA Log
  overlay on the cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md).

## Audience

This skill serves **external developers building applications
that consume DOCA**, who want their app's log output to flow
through DOCA's standardized logging primitive instead of through
ad-hoc `printf` / `syslog` / language-native logging. Concretely,
users whose code calls `doca_log_*` and the `DOCA_LOG_*` macros
(directly in C/C++, or through FFI/bindings from another
language) so that their app's log output participates in DOCA's
centralized level controls and downstream consumers (DOCA Log
Service, DOCA Telemetry Service). It is *not* for NVIDIA
developers contributing to DOCA Log itself.

**Language scope.** DOCA Log ships as part of the DOCA C
libraries. The shipped DOCA samples and reference applications
are written in C and use DOCA Log throughout — the agent should
direct users to read any of those samples' `*_main.c` as the
canonical DOCA Log usage pattern (DOCA Log has no dedicated
sample subdirectory; it shows up *inside* every shipped sample).
C and C++ consumers are the canonical case and the worked
examples in `TASKS.md` assume that path. Other-language
consumers (Rust, Go, Python, …) consume the same `*.so` through
FFI; the skill's contribution in that case is to keep the
two-tier level model, the source-register lifecycle, and the
path-selection rule language-neutral.

## When to load this skill

Load this skill when the user is doing hands-on DOCA Log work, in
any language. Concretely:

- Wiring DOCA Log into a fresh DOCA app or modifying an existing
  DOCA sample to add the user's own per-component log lines via
  `doca_log_source_register` + the `DOCA_LOG_*` macros.
- Controlling verbosity at runtime via `--sdk-log-level`,
  `DOCA_LOG_LEVEL_SDK`, or the app-side level setter — and
  deciding which of the *two tiers* (SDK / app) to change for a
  given diagnostic question.
- Choosing between DOCA Log and a language-native logging
  framework (`printf`, `fprintf(stderr, …)`, `syslog`, `spdlog`,
  Python `logging`, Rust `tracing`, …) in a DOCA-app context.
- Probing the install to determine whether DOCA Log ships as a
  standalone `pkg-config` module (`doca-log`) on this release or
  is folded into `doca-common`, so the build manifest names the
  right module.
- Debugging *"my log lines do not appear at the level I expect"*
  symptoms, which are almost always the two-tier model being
  conflated rather than a DOCA Log bug.
- Designing or extending non-C bindings (Rust, Go, Python, …)
  that wrap DOCA Log — for the two-tier model, the source-
  register lifecycle, and the level-mapping the wrapper must
  honor.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, non-Log library questions, or the cross-cutting
debug ladder. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), the matching library
skill, or [`doca-debug`](../../doca-debug/SKILL.md) respectively.

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive DOCA Log
material lives in two companion files:

- `CAPABILITIES.md` — what DOCA Log can express on this install:
  the two-tier (SDK / app) log-level model, the registry +
  source-register lifecycle, the `DOCA_LOG_*` macro family, the
  level enum and which levels are always present vs which are
  optional on older trains, the path-selection rule against
  language-native logging, the `pkg-config` ambiguity rule
  (`doca-log` vs `doca-common`), the DOCA Log error taxonomy
  (mapped onto the cross-library `DOCA_ERROR_*` set), the
  observability surface (`stderr` sink by default; interop with
  DOCA Log Service and DOCA Telemetry Service), and the safety
  policy on writes to custom sinks.
- `TASKS.md` — step-by-step workflows for the six in-scope DOCA
  Log verbs: `configure`, `build`, `modify`, `run`, `test`,
  `debug`. Plus a `Deferred task verbs` block that points
  out-of-scope questions at the right next skill.

The skill assumes a host or BlueField where DOCA is already
installed at the standard location and the user has the
privileges their public install profile expects. It does not
cover installing DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA Log application source code, in any
  language.** The verified DOCA Log usage shows up inside every
  shipped DOCA sample at
  `/opt/mellanox/doca/samples/<library>/<sample>/*_main.c` and
  inside every shipped reference application. The agent's job is
  to route the user to those files and prescribe a minimum-diff
  modification on them via the universal modify-a-sample
  workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the DOCA Log overlay in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **Standalone build manifests** (`meson.build`,
  `CMakeLists.txt`, `Cargo.toml`, …) parked inside the skill.
  The agent constructs the build manifest *in the user's project
  directory* against the user's installed DOCA, where the
  `pkg-config` probe described in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope.
2. **For the two-tier log-level model, the source-register
   lifecycle, the `DOCA_LOG_*` macro family, the `pkg-config`
   ambiguity rule, the path-selection rule against language-
   native logging, the error taxonomy, observability, and safety
   policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-version`](../../doca-version/SKILL.md) for the canonical
version-handling rules,
[`doca-debug`](../../doca-debug/SKILL.md) for the runtime-debug
story DOCA Log is the foundation of, and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or
the installed package layout" rather than "DOCA Log-specific
guidance".

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source
  and the on-disk layout of an installed DOCA package. The DOCA
  Log public guide is at
  <https://docs.nvidia.com/doca/sdk/DOCA-Log/index.html>; the
  routing table row for DOCA Log already cross-links to this
  skill.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, and the *I have no install yet* path
  with the public NGC DOCA container. This skill assumes its
  preconditions are satisfied.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule and adds
  the DOCA Log-specific `pkg-config` ambiguity overlay
  (`doca-log` vs `doca-common`).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow, the universal
  lifecycle, the cross-library `DOCA_ERROR_*` taxonomy, and the
  program-side debug order. This skill layers DOCA Log specifics
  on top — especially that *every* shipped sample's `*_main.c`
  is the canonical DOCA Log usage pattern.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver) and the verbosity-escalation surface. DOCA
  Log is the *foundation* `doca-debug` builds on for the
  runtime-debug story; this skill is where the *two-tier model*
  itself lives, and `doca-debug` cross-links here when the
  user's question is *"how do I turn up logging"* rather than
  *"how do I walk the ladder"*.
