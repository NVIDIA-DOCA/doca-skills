# DOCA Flow capabilities, version compatibility, errors, observability, safety

**Where to start:** The pattern overview below names the recurring
Flow-class patterns. Pick the pattern first, then drill into the H2
that owns the substance. For the *how* of executing each pattern, jump
to [TASKS.md](TASKS.md).

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For step-by-step workflows that *use* these
capabilities (configure, build, modify, run, test, debug) see
[TASKS.md](TASKS.md). For where the underlying public documentation and
installed package paths live, defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) — do
not duplicate URLs or install paths in this file.

## Pattern overview

Every Flow-class question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
pipe spec, not just the worked example shown.

| Flow pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pick the steering mode | HWS vs SWS, decide before quoting any feature | [`## Capabilities and modes`](#capabilities-and-modes) steering-mode bullet |
| 2. Bring up port + representor | Port-init, representor binding, lifecycle order | [TASKS.md ## configure](TASKS.md#configure) |
| 3. Express *<match X, do Y>* as a pipe | Match-criteria + action set + pipe-type pick (basic / hairpin / control / ordered) | [`## Capabilities and modes`](#capabilities-and-modes) pipe-type table + [TASKS.md ## modify](TASKS.md#modify) |
| 4. Validate the spec before commit | `doca_flow_pipe_validate` → `doca_flow_pipe_create`; never the reverse | [`## Safety policy`](#safety-policy) validate-before-commit rule + [TASKS.md ## test](TASKS.md#test) |
| 5. Observe what the HW actually did | Per-pipe / per-entry counters + Flow inspector trace | [`## Observability`](#observability) + [TASKS.md ## debug](TASKS.md#debug) |
| 6. Interpret a `DOCA_ERROR_*` from a Flow call | Map the error to a layer (env / build / link / runtime / program), then route | [`## Error taxonomy`](#error-taxonomy) Flow overlay + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Discover the version-installed surface, do not assume.** Every
  pattern above gates on `pkg-config --modversion doca-flow` and on
  the `doca_caps` capability snapshot of the active device. Quoting
  a feature without checking is the most common hallucination
  failure mode.
- **Validate before commit, every time.** `validate` is a separate
  read-only call; skipping it produces runtime symptoms that look
  like hardware bugs and waste debug time. See
  [`## Safety policy`](#safety-policy).

## Capabilities and modes

DOCA Flow programs the BlueField NIC's accelerated steering hardware.
Before writing any pipe spec, the agent should know which mode and feature
set the device is in:

- **Steering mode.** Flow runs over either hardware steering (HWS, the
  default on supported hardware/firmware combinations) or software steering
  (SWS, fallback). Supported match kinds, action kinds, and pipe types
  depend on the active mode. Confirm the active mode before quoting feature
  support — never assume HWS just because the device supports it.
- **Pipe types.** Basic match-action pipes, hairpin pipes (RX-to-TX
  forwarding without the host CPU touching the packet), control pipes,
  ordered/unordered list pipes. Hairpin and ordered-list pipes have
  additional steering-mode constraints documented per release.
- **Match kinds.** L2 (destination MAC, VLAN), L3 (IPv4/IPv6 source and
  destination, protocol), L4 (TCP/UDP ports, flags), tunnel headers
  (VXLAN, GENEVE, GRE — availability varies by firmware), and metadata
  fields. Always verify the requested match kind is in the device's
  capability set before building the spec.
- **Action kinds.** Forward to representor, drop, modify (header rewrite,
  decap, encap), counter, jump-to-pipe, mirror. Encap/decap availability
  depends on the firmware feature set.
- **Capability discovery at runtime.** Before relying on a capability,
  agents should encourage the user to query it through the installed
  `doca_caps` tool and the Flow capability-query API rather than guessing
  from documentation. The exact tool path lives in the knowledge-map.

When the user has not yet checked steering mode and feature support, the
correct first move is to walk them through capability discovery in
[TASKS.md ## configure](TASKS.md#configure) — not to guess a working pipe
spec.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The Flow-specific overlay** is:

- The set of `doca_flow_*` symbols available on a given install is observable from the Flow header set under the installed DOCA infrastructure tree (look up the path in [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package)). When the user reports an `undefined reference` or "function not found" for a `doca_flow_*` symbol, the first hypothesis is **wrong-version documentation** — confirm the installed version per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure), then verify the symbol exists in the installed headers, then read the Flow programming guide for *that* release.
- Per-Flow-capability availability uses the version-matrix lookup procedure in [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test) step 2, with `pkg-config --modversion doca-flow` as the build-time anchor.
- The release notes for the installed version are the canonical source for
  Flow features added, deprecated, or behavior-changed in that release.
  Route through the knowledge-map for the release-notes URL pattern.

Version-specific tables of symbol availability are deliberately not
maintained in this file — they would drift out of date silently. The
discipline is "read the headers and the matching release notes", not
"trust this file's table".

## Error taxonomy

Flow API calls return either `DOCA_SUCCESS` or a `DOCA_ERROR_*` code.
The agent should treat these as a layered taxonomy when deciding what
to ask the user next:

| Class | Examples | Typical cause | Right next move |
| --- | --- | --- | --- |
| Configuration error | `DOCA_ERROR_INVALID_VALUE` on pipe creation | Spec contradicts itself or violates schema | Re-validate the spec against the pipe-spec rules (`pipe validation` workflow in TASKS.md). |
| Capability error | `DOCA_ERROR_NOT_SUPPORTED` on pipe creation or entry add | Match kind, action kind, or steering mode is unsupported on this device/firmware | Re-run capability discovery (TASKS.md `## configure`); compare requested capability to the device's actual capability set. Do not retry the same spec on the same device. |
| Resource error | `DOCA_ERROR_NO_MEMORY`, `DOCA_ERROR_FULL` on entry add | Pipe entry budget exhausted or actions-memory pool depleted | Inspect counters and pipe statistics (`## Observability` below); enlarge the pool or evict entries before retrying. |
| Lifecycle error | `DOCA_ERROR_BAD_STATE` on start/stop | Object operated on outside its allowed lifecycle window | Re-read the object's lifecycle in TASKS.md; ensure operations happen in the documented order (port started before pipe created, pipe created before entries added, etc.). |
| Hardware/firmware error | `DOCA_ERROR_DRIVER` and similar | The kernel driver, firmware, or PCIe path is in a state Flow cannot recover from | Stop. This is not a Flow-spec problem. Capture device state via the platform's diagnostic CLIs and escalate. |

Flow does not invent error codes outside the `DOCA_ERROR_*` family;
**any error in a Flow API trace that is not a `DOCA_ERROR_*` constant is
either a wrapper layer the user added or a bug worth filing** — do not
silently translate it to a guess.

## Observability

Flow exposes three observable surfaces:

- **Pipe counters.** Each pipe entry can be created with a counter
  attached. Reading the counter back is the canonical way to confirm
  *traffic is matching* the entry. If the counter is zero while the user
  reports traffic should match, the pipe spec is wrong; do not blame the
  packet generator first.
- **Pipe statistics.** Per-pipe statistics (entry count, hit count where
  exposed, errors) describe whether the pipe itself is healthy. Use these
  before blaming individual entries.
- **Tracing / per-pipe diagnostic dump.** Flow's diagnostic dump describes
  the actual programmed entries the hardware sees. Use this when the
  user's understanding of "what I asked the hardware to do" diverges from
  observed behavior — it is the ground truth.

Workflow: when investigating "traffic is going to the wrong place", the
canonical order is *counters first → statistics second → trace dump
third*. Walking the order saves redundant questions.

## Safety policy

Programming the BlueField steering hardware is **not** a free-form
operation. Wrong specs can take traffic offline; wrong actions can drop
or mirror unintended traffic. Two policies follow from that:

1. **Validate before committing to hardware.** Every pipe specification
   that an agent helps construct should be validated by Flow's
   pipe-validation API (or, where the API is unavailable on the installed
   version, by a dry-run sample) **before** the entry-add call hits the
   hardware. The lifecycle is *build → validate → start → add entries →
   read counters*. Skipping validation is the most common cause of "my
   pipe takes the link down" reports.
2. **Hairpin pipes must be staged.** A hairpin pipe (RX-to-TX without the
   host CPU) effectively rewires the steering plane. The validate-before-
   commit ordering for hairpin pipes is stricter than for plain
   match-action pipes:
   1. **Build** the pipe spec with explicit ingress and egress port
      identifiers and an explicit match key. Implicit-match hairpin specs
      are forbidden by this policy because they are silently
      catch-everything.
   2. **Validate** the spec against the active steering mode's hairpin
      rules; reject any spec that would shadow an existing higher-priority
      pipe on either port.
   3. **Stage** entries on a single representor first and read the
      counters under controlled traffic before widening the entry set to
      production representors.
   4. **Commit** the production entries only after the staged entries
      report the expected counters under expected traffic.

   The build-validate-stage-commit ordering is what this policy means by
   "validate before commit" for hairpin pipes specifically.

3. **Capability check before action change.** Any change to a pipe's
   action set must re-run the capability check from
   `## Capabilities and modes` against the *new* action set on the
   currently active steering mode. An action that was supported when the
   pipe was first built can become unsupported if the device or firmware
   was reconfigured between sessions.

The agent's job is to **enforce these orderings in the workflow**, not
just describe them. If the user says "skip the dry-run, just program it",
the right answer is to refuse and explain the cost, not to comply.
