# DOCA Log capabilities, version overlay, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your question
(two-tier model / objects / path selection / pkg-config probe /
errors / observability / sinks) and read that section
end-to-end. The tables in each section are the load-bearing
content; the prose around them is interpretation.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern
(the verbs `configure / build / modify / run / test / debug`),
jump to [TASKS.md](TASKS.md). For the canonical DOCA
version-handling rules that this skill layers a DOCA Log overlay
on top of, see [`doca-version`](../../doca-version/SKILL.md). For
the cross-cutting debug ladder DOCA Log feeds into, see
[`doca-debug`](../../doca-debug/SKILL.md).

## Pattern overview

Every DOCA Log question this skill teaches resolves into one of
FIVE patterns. The patterns are CLASSES — they apply across
every DOCA release and every DOCA app, regardless of which
library the user is calling.

| Pattern | When it applies (class shape) | Where the substance lives |
| --- | --- | --- |
| 1. Pick the tier | Is the symptom about *DOCA library internals* (SDK tier) or *the user's own emission lines* (app tier)? Set the matching tier; do NOT crank both. | [`## Capabilities and modes`](#capabilities-and-modes) two-tier table + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 2. Register before emit | Every emission via `DOCA_LOG_*` is from a source ID that must be created via `doca_log_source_register` first. Unregistered IDs return `DOCA_ERROR_INVALID_VALUE`. | [`## Capabilities and modes`](#capabilities-and-modes) objects table + [TASKS.md ## configure](TASKS.md#configure) step 4 |
| 3. Pick DOCA Log vs language-native | DOCA-app context → DOCA Log so output interoperates with DOCA's central level controls and downstream consumers. Non-DOCA codebase with no DOCA context → language-native logging is fine. | [`## Capabilities and modes`](#capabilities-and-modes) path-selection table |
| 4. Probe the `pkg-config` module | DOCA Log may publish a standalone `doca-log.pc` on some releases and be folded into `doca-common.pc` on others. The agent must probe both before naming the link line. | [`## Version compatibility`](#version-compatibility) `pkg-config` probe rule + [TASKS.md ## build](TASKS.md#build) slot table |
| 5. Diagnose a DOCA Log error | Map symptom (`INVALID_VALUE`, `BAD_STATE`, `NO_MEMORY`) to root cause — unregistered source, emission before init, exhausted sink. | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **The two tiers are independent levels on independent
  emission paths.** A DOCA Log message emitted from *inside
  the DOCA library* is gated by the SDK level; a DOCA Log
  message emitted from *the user's own source* is gated by the
  app level. They do not share a single setter and they do not
  share a single default. Confusing the two is the single most
  common DOCA Log first-app failure.
- **Source-register is a one-shot per source.** Each logical
  source (typically one per `.c` file, or one per component) is
  registered once at startup via `doca_log_source_register`,
  yielding a source ID that every subsequent `DOCA_LOG_*` from
  that source passes. Re-registering an existing source, or
  emitting before the source is registered, is the
  `DOCA_ERROR_INVALID_VALUE` failure mode.

## Capabilities and modes

DOCA Log is **DOCA's standardized logging primitive**. Every
DOCA library (and every shipped DOCA sample and reference
application) emits its own log lines through DOCA Log, so log
output from a DOCA app interoperates with DOCA's centralized
level controls and downstream consumers (DOCA Log Service, DOCA
Telemetry Service).

**The two-tier log-level model — the single most load-bearing
rule.** DOCA Log carries two *independent* verbosity tiers,
each with its own setter and its own default. The agent MUST
walk this table BEFORE writing any code:

| Tier | What it controls | How to set at runtime | Typical default | Symptom when confused |
| --- | --- | --- | --- | --- |
| **SDK log level** | Verbosity of DOCA *library internals* — log lines emitted from inside the DOCA libraries themselves as they call into hardware, manage state, validate inputs, … | `--sdk-log-level <level>` CLI flag on any DOCA sample / reference app; `DOCA_LOG_LEVEL_SDK` env var; programmatic setter equivalent | `WARNING` | User sets `--sdk-log-level DEBUG` to see their own DEBUG lines and is flooded with internal DOCA spam instead, or *"my own DEBUG lines do not appear"* despite the flag |
| **App log level** | Verbosity of *user code* — log lines the user emits via `DOCA_LOG_*` macros from their own source files | App-side registry setter (e.g. `doca_log_level_set_global_lower_limit` on the app-tier registry); per-source via `doca_log_source_set_level` once the source ID is in hand | `INFO` | User sets app level to `INFO`, then wonders why their `DOCA_LOG_DBG`-shaped lines never print; or user expects `--sdk-log-level` to reach their own lines and it does not |

The agent's diagnostic rule: when the user reports *"my log
levels do nothing"*, the FIRST hypothesis is *tier confusion*
(setting one tier when they meant the other) — NOT a DOCA Log
bug, NOT a hardware bug, NOT a sample issue. Walk the table
above before any code-side investigation.

**The objects DOCA Log exposes.** The public surface is small
and stable. The agent must not invent additional objects; the
load-bearing call shapes are the rows below.

| Object | What it is | Lifecycle call | Used by |
| --- | --- | --- | --- |
| Log registry | Per-app singleton-shaped registry that owns the source-ID table and the app-tier level | Created implicitly on first DOCA Log call (or via the app-side registry setup helper exposed in any shipped sample's `*_main.c`) | The user's app, once per process |
| Log source | Per-source identity (typically one per `.c` file or one per component) under which `DOCA_LOG_*` lines are emitted | `doca_log_source_register(<name>, &source_id)` — called once at component init time, BEFORE any `DOCA_LOG_*` from that source | The user's app, once per logical source |
| `DOCA_LOG_*` macros | User-facing emission macros — INFO, DEBUG, ERR (ERROR), CRIT (CRITICAL), and the rest of the level family — each takes a source ID + a printf-style format and varargs | n/a (compile-time macro expansion) | The user's app, every emission |
| `doca_log_level_*` functions | Runtime-adjustment surface for the app-tier level (global lower limit, per-source level) | n/a (call any time after registry exists) | The user's app, on a level-change event (signal, RPC, config reload) |

**Path-selection — DOCA Log vs language-native logging.** DOCA
Log is not the only logging framework available; the agent must
walk this rule before recommending DOCA Log setup.

| Use DOCA Log when … | Use language-native logging when … |
| --- | --- |
| Building a DOCA app (or modifying a shipped DOCA sample / reference application) where the user *wants* their own log output to interoperate with DOCA's centralized level controls (`--sdk-log-level`) and downstream consumers (DOCA Log Service, DOCA Telemetry Service) | The codebase is non-DOCA — no `doca_*` calls, no DOCA-side context, no need to route output through DOCA's central controls. A plain `printf`, `fprintf(stderr, …)`, `syslog`, `spdlog`, Python `logging`, or Rust `tracing` is fine. |
| The user is reading or modifying a shipped sample's `*_main.c` and wants the same logging shape the rest of DOCA uses — uniform per-line format, uniform level vocabulary, uniform interop with `--sdk-log-level` | The user needs a logging feature DOCA Log does not provide (structured key/value records natively, on-disk rotation policies, async batching, custom routing rules). In that case the right move is to bridge — route the language-native log output *through* `DOCA_LOG_*` macros via a custom sink — accepting the extra wiring cost. |
| First-app teaching: every shipped DOCA sample is a worked example of DOCA Log usage; learning it is part of *what does it mean to write a DOCA-quality app* | The app is a thin scratch script around `doca_caps`-style read-only inspection, where adding `doca_log_source_register` overhead does not earn back its complexity |

The agent's anti-pattern alert: silently swapping a sample's
`DOCA_LOG_*` calls for `printf` *for simplicity* is a wrong
answer. It severs the sample's interop with `--sdk-log-level`,
divorces the user's output from the DOCA Log Service / Telemetry
Service consumers, and makes the modified sample look unlike
every other DOCA artifact on the host. DOCA Log is foundational
in the same shape that DOCA Arg Parser is — it shows up in
*every* shipped sample, and replacing it in a DOCA-app context is
almost never the right tradeoff.

**Configuration shape.** *Mandatory* before any `DOCA_LOG_*`
emission: each logical source is registered via
`doca_log_source_register`, yielding a source ID. *Optional*
configurations: per-source level overrides via
`doca_log_source_set_level`; global lower-limit changes via the
app-tier registry; custom backend / sink registration when the
default `stderr` sink is not sufficient (see [`## Safety
policy`](#safety-policy)). Defaults come from the library — the
agent should quote the *observed* default, not assume the value.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The DOCA Log-specific overlay** is:

- **The `pkg-config` module name is not portable across DOCA
  releases.** On some DOCA releases DOCA Log publishes a
  standalone module `doca-log.pc`; on others its functionality
  is folded into `doca-common.pc` (which is always present
  whenever DOCA is installed at all). The agent MUST probe the
  user's install before naming a link line: run
  `pkg-config --exists doca-log` first; if that returns nonzero,
  fall back to `pkg-config --exists doca-common` (which on any
  healthy DOCA install always succeeds). The library
  functionality is the *same* — only the linker line differs.
  See [TASKS.md ## build](TASKS.md#build) for the worked
  probe-and-fall-back pattern.
- **The level enum is not uniform across older trains.** The
  always-present level set the agent can rely on is
  `CRITICAL` / `ERROR` / `WARNING` / `INFO` / `DEBUG`. Some
  releases also expose `TRACE` (more verbose than `DEBUG`) and a
  `DISABLE` sentinel for *"no emission at all from this
  tier"* — but the agent must cap-check before recommending
  them on an unknown install. The verification is *read the
  installed `doca_log.h`* per the headers-win-over-docs rule in
  [`doca-version`](../../doca-version/SKILL.md); the public docs
  may name a level that has not yet landed on the user's train.
- **Every shipped DOCA sample on the install uses DOCA Log.**
  This is not a version overlay but a version-stable
  *load-bearing observation*: any shipped sample's `*_main.c`
  under `/opt/mellanox/doca/samples/<library>/<sample>/` is a
  worked example of `doca_log_source_register` +
  `DOCA_LOG_*` + `--sdk-log-level` wiring, ready to be read on
  disk. The agent should reach for the closest sample as the
  modify-from-sample base, not invent a fresh file.
- **`doca-common.pc` must match `doca_caps --version`** at the
  four-way-match check (per
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)).
  If a standalone `doca-log.pc` is present, *it too* must
  match — a partial-install pattern where `doca-log.pc` lingers
  from a previous release while `doca-common.pc` advances is
  exactly the kind of mismatch the four-way-match rule is
  designed to catch.

## Error taxonomy

DOCA Log-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *DOCA Log surface* meaning that the
agent must disambiguate before falling back to the
cross-library response.

| Error | DOCA Log context where it shows up | DOCA Log-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_INVALID_VALUE` | `doca_log_source_register` with a name that does not match the registry's expectations; per-source level setter with an out-of-range level enum; any `DOCA_LOG_*` macro invoked with an unregistered source ID | The level enum is one of the always-present set or the cap-checked optional set (see [`## Version compatibility`](#version-compatibility)); the source ID must come from a prior successful `doca_log_source_register`. Walk the registration call and the level enum against the headers on the user's install. |
| `DOCA_ERROR_BAD_STATE` | Any `DOCA_LOG_*` emission before the DOCA Log subsystem is initialized (or after it is torn down); per-source level changes before the source is registered | Lifecycle violation. Walk the call sequence against the universal lifecycle in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); the most common case is a static-initializer log line that runs before `main()`-time DOCA Log init. |
| `DOCA_ERROR_NO_MEMORY` | A `DOCA_LOG_*` emission against a custom sink that queues messages internally and is currently saturated | This is *rare* with the default `stderr` sink (which does not queue). When it does fire, the user has installed a custom sink that has its own backpressure rule; the fix is to drain the sink (or to drop / coalesce at the app layer), not to retry blindly. |
| `DOCA_ERROR_NOT_SUPPORTED` | A level enum that is not present on the user's installed train (e.g. `TRACE` on a release that caps at `DEBUG`) | Drop to the always-present level set (`CRITICAL` / `ERROR` / `WARNING` / `INFO` / `DEBUG`) or upgrade the install. The headers-win rule applies — quote the enum the user's `doca_log.h` actually exposes, not what the public docs show. |

The agent's rule: **never recommend a retry loop on
`DOCA_ERROR_*` from a DOCA Log call**. None of the failure
modes above become success on retry — `INVALID_VALUE` and
`BAD_STATE` want an investigation; `NO_MEMORY` wants
backpressure handling at the sink; `NOT_SUPPORTED` wants a
different level enum. Retrying masks the bug and produces
secondary log lines that are themselves prone to the same
failure.

## Observability

DOCA Log *is* DOCA's observability surface for log lines — it is
how *every* other DOCA library reports state, and how the user's
own app reports state when it follows the shipped-sample idiom.
The agent's job in any DOCA Log session is to know which sink
the output goes to, which tier controls which lines, and which
downstream consumers can read the output.

**The default sink is `stderr`.** DOCA Log emits to `stderr` by
default; the format is the per-line shape every shipped DOCA
sample produces (timestamp, level, source, message). The user
inherits this format automatically the moment they call
`doca_log_source_register` and emit via `DOCA_LOG_*` — no extra
wiring required.

**The verbosity surface is the two-tier model.** Re-read the
two-tier table in [`## Capabilities and modes`](#capabilities-and-modes):

- The SDK tier reaches the DOCA library internals; control via
  `--sdk-log-level <level>` (on any DOCA sample / reference
  app), `DOCA_LOG_LEVEL_SDK` env var, or the programmatic SDK
  setter equivalent.
- The app tier reaches the user's own emission lines; control
  via the app-side registry setter (global lower limit) or the
  per-source setter (`doca_log_source_set_level` per source ID).

The diagnostic rule: when the agent escalates verbosity, it
should **change one tier at a time**, observe, and only widen
the second tier if the first did not produce the missing
signal. Cranking both tiers simultaneously buries the user's
own lines in DOCA-library internal trace and masks the very
thing the user is trying to see.

**Downstream consumers.** DOCA Log output is the input to the
DOCA Log Service and the DOCA Telemetry Service (per
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)):
when the user pipes / forwards their app's `stderr` (or routes
through a custom sink), those services can consume the lines
without any in-app wiring. This is part of *why* DOCA Log is
preferable to `printf` in a DOCA-app context — the downstream
shape is the same as every other DOCA artifact on the host.

**Cross-link to the cross-cutting debug ladder.** The
verbosity-escalation surface is owned by this skill
(specifically the two-tier model above). The *layered debug
ladder* DOCA Log feeds into is owned by
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability) —
which calls back to this skill for the two-tier mechanics and
for the per-tier setters.

**Custom sinks.** When the default `stderr` sink is not enough
(e.g. the user wants log lines to land in a file, a Unix-domain
socket, or a remote shipper), DOCA Log supports installing a
custom backend / sink at registry-init time. The custom sink
owns its own permissions and its own backpressure rule;
installing a sink that the user's process does not have
permission to write to is the leading cause of *"my log lines
silently disappear"*. See [`## Safety policy`](#safety-policy)
for the permission framing.

## Safety policy

DOCA Log's safety surface is narrow — most of the library writes
to `stderr` and has no privileged side effects. But there are
three guardrails the agent must surface.

- **Custom-sink writes inherit the sink's own permission
  envelope.** When the user installs a custom backend (file,
  socket, remote shipper) instead of relying on the default
  `stderr`, the writes happen under that sink's own permission
  rules — file permissions on the target path, socket-side
  permission on the destination, network ACLs on the remote
  shipper. The DOCA Log API itself adds no permission elevation;
  the user must ensure the process has whatever rights the sink
  needs. A sink whose `open()` succeeds but whose `write()`
  fails silently is the worst kind of *"my log lines disappear"*
  symptom. Validate the sink with a small write at registration
  time, before any production traffic.
- **Do not log secrets through `DOCA_LOG_*`.** Format strings
  passed to `DOCA_LOG_*` macros take printf-style varargs;
  there is no automatic redaction. Anything the user passes
  becomes part of the line and may be forwarded to the DOCA Log
  Service or DOCA Telemetry Service downstream. Treat
  `DOCA_LOG_*` as a public-equivalent emission surface and apply
  the user's normal redaction discipline at the call site, not
  inside the library.
- **The default `stderr` sink does not queue.** Emitting at very
  high rate against the default sink is bounded by `stderr`'s
  own write semantics; there is no in-library buffer the user
  can overflow. When the user installs a custom queueing sink,
  the queue *can* overflow — surfaced as
  `DOCA_ERROR_NO_MEMORY` per [`## Error taxonomy`](#error-taxonomy)
  — and the right response is sink-side backpressure, not a
  retry loop.
