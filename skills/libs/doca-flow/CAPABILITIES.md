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
| 4. Validate the spec before commit | DOCA Flow does not ship a separate `doca_flow_pipe_validate` C API at this release — validation is done at constructor time inside `doca_flow_pipe_create` (and the staged-entry / dry-run pattern in the shipped samples). Treat constructor failure as the validate step; do not invent a separate validate call. | [`## Safety policy`](#safety-policy) validate-before-commit rule + [TASKS.md ## test](TASKS.md#test) |
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

- **Device placement — check this FIRST, before steering mode.** DOCA
  Flow's hardware-steering plane is owned by *one* side of a BlueField:
  the embedded DPU (Arm) cores, not the x86 host, whenever the card is in
  **separated-host / NIC mode** (`INTERNAL_CPU_MODEL = SEPARATED_HOST` in
  `mlxconfig`). On such a card the **host** function cannot bring up a Flow
  port at all — `doca_flow_port_start` (or the first `doca_flow_pipe_create`
  on a switch port) fails at the capability-query stage with the
  signature in [`## Error taxonomy`](#error-taxonomy) (`Failed to get hws
  cap` / `dest action ROOT … err -121`). This is NOT a spec, steering-mode,
  or pipe bug and no amount of pipe-spec editing fixes it. The agent must
  decide *where Flow runs* before anything else: run on the DPU Arm side
  (the native place for DOCA Flow on a separated-host BlueField), or — if
  the workload genuinely must run host-side — change the card's mode
  (`mlxconfig` + reboot, possibly a firmware update) through the
  [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md) overlay.
  The placement check is step 1 of [TASKS.md ## configure](TASKS.md#configure);
  do not skip it just because `doca_caps` *lists* the device — being
  enumerable is not the same as the opened function having a usable
  steering plane.
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
- **Action kinds.** Forward to representor (`DOCA_FLOW_FWD_PORT`),
  forward to another pipe (`DOCA_FLOW_FWD_PIPE`), forward to a *target*
  (`DOCA_FLOW_FWD_TARGET` — see § *Forward-to-target actions* below),
  RSS (`DOCA_FLOW_FWD_RSS`), drop (`DOCA_FLOW_FWD_DROP`), modify
  (header rewrite, decap, encap), counter, jump-to-pipe, mirror.
  Encap/decap availability depends on the firmware feature set.
- **Capability discovery at runtime.** Before relying on a capability,
  agents should encourage the user to query it through the installed
  `doca_caps` tool and the Flow capability-query API rather than guessing
  from documentation. The exact tool path lives in the knowledge-map.

When the user has not yet checked steering mode and feature support, the
correct first move is to walk them through capability discovery in
[TASKS.md ## configure](TASKS.md#configure) — not to guess a working pipe
spec.

## Forward-to-target actions (pass-to-kernel and friends)

DOCA Flow exposes a *forward-to-target* action kind
(`DOCA_FLOW_FWD_TARGET`) that is **the only safe forward action for
demos or production filters that run inline on a port carrying live
host traffic** (e.g. a BlueField PF that the host is currently using
for SSH, package mirrors, or telemetry). Picking the wrong forward
action on a live management port can disrupt the host's network
session; getting this right is therefore part of the
[`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md) overlay,
not just a doca-flow detail.

**Pattern (three public API symbols, no invention):**

| Symbol | Where it comes from | What it does |
|---|---|---|
| `DOCA_FLOW_FWD_TARGET` | `doca_flow.h` (`enum doca_flow_fwd_type`) | Tells the pipe that the forward action is *send-to-target* rather than send-to-port / RSS / drop. |
| `enum doca_flow_target_type` (e.g. `DOCA_FLOW_TARGET_KERNEL`) | `doca_flow.h` | Names which built-in target the action resolves to. `DOCA_FLOW_TARGET_KERNEL` is the *pass-traffic-back-to-the-host-Linux-kernel* target — matched packets are observed by the pipe (counters, mirror, …) and **continue up the kernel networking stack on the same port** instead of being diverted away. |
| `doca_flow_get_target(target_type, &target_ptr)` | `doca_flow.h` | Resolves a `doca_flow_target_type` enum value to a `struct doca_flow_target *` that the pipe's `doca_flow_fwd` action carries in its `.target` field. |

**Canonical wiring** (the agent quotes the verbatim shape from the
shipped sample at
`/opt/mellanox/doca/samples/doca_flow/flow_fwd_target/` — see
[`TASKS.md ## build`](TASKS.md#build) Track 1 — it does not invent the
field names from this table):

```c
struct doca_flow_fwd      fwd      = {0};
struct doca_flow_fwd      fwd_miss = {0};
struct doca_flow_target  *kernel_target;
doca_error_t              result;

result = doca_flow_get_target(DOCA_FLOW_TARGET_KERNEL, &kernel_target);
if (result != DOCA_SUCCESS) { /* report + bail per CAPABILITIES.md ## Error taxonomy */ }

fwd.type           = DOCA_FLOW_FWD_TARGET;
fwd.target         = kernel_target;          /* matched traffic continues to the kernel */
fwd_miss.type      = DOCA_FLOW_FWD_TARGET;
fwd_miss.target    = kernel_target;          /* unmatched traffic ALSO continues to the kernel —
                                                this is what makes the filter "inline" and safe
                                                to enable on a live management port */
```

**When to pick this action (binding decision table):**

| The user is building … | On … | Pick |
|---|---|---|
| An *inline filter* that should count / observe matched traffic without diverting it from the host | A live host management port (the user can still SSH into the host while the filter is up) | **`DOCA_FLOW_FWD_TARGET` + `DOCA_FLOW_TARGET_KERNEL`** for both `fwd` AND `fwd_miss` (the demo / DPU-traffic-gate shape) |
| A VNF that *replaces* the kernel data path on a dedicated DOCA-managed port | A BlueField PF or VF that the host does NOT use | `DOCA_FLOW_FWD_PORT` to the egress representor (the classic VNF shape) |
| A connection-tracked NAT / 5-tuple flow | A BlueField with HWS + CT enabled | the CT module of `doca-flow` (see `## flow-ct` below); CT wraps the underlying forward action transparently |

**Required safety overlays when the user picks `FWD_TARGET` on a live
management port:**

- [`doca-hardware-safety ## Safety policy`](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) — even with the pass-to-kernel action, capture per-port counters BEFORE and AFTER, keep an out-of-band recovery path, and revert via `stop_doca_flow_ports()` + `doca_flow_destroy()` if any host-side counter regresses.
- [`AGENTS.md ## The universal verification contract`](../../../AGENTS.md#the-universal-verification-contract) — the green signal for an `FWD_TARGET` inline filter is **sustained counter growth under controlled traffic**, not a single-packet match. A single matched packet can be coincidence on a live port; agents declaring "done" on a one-packet read are violating the contract.
- [`TASKS.md ## test`](TASKS.md#test) — the staged-entry-on-a-single-port pattern still applies; widen to both ports only after the single-port smoke is green.

**Anti-patterns the agent must refuse:**

1. *"Just point `fwd_miss.type = DOCA_FLOW_FWD_DROP` to silently
   discard the unmatched traffic — it's simpler."* → **NO.** On a live
   management port, dropping unmatched traffic disconnects the host
   (SSH dies, monitoring breaks, the user's terminal hangs). The
   *miss* path on a live port MUST be `FWD_TARGET → KERNEL` so the
   host's existing networking keeps working.
2. *"Invent a different target kind because the user asked for
   something like `DOCA_FLOW_TARGET_HOST_RAW`."* → **NO.** The
   `enum doca_flow_target_type` is fixed by the installed
   `doca_flow.h`; query the header on the user's install instead of
   inventing values. If the kind the user needs is not in the
   installed enum, the agent surfaces that fact and routes to the
   [DOCA Flow Programming Guide](https://docs.nvidia.com/doca/sdk/doca-flow/index.html)
   for the version-specific list.

## flow-ct

DOCA Flow Connection Tracking (the CT module of `doca-flow`,
header `doca_flow_ct.h`) is the **COMPANION** surface that
EXTENDS the stateless steering surface in
[`## Capabilities and modes`](#capabilities-and-modes) above
with hardware-accelerated 5-tuple connection tracking, aging
timers, and NAT-aware actions (SNAT / DNAT) on tracked
connections. It is NOT a separate library; it ships inside the
doca-flow library and is enabled by a one-time global
`doca_flow_ct_init(cfg)` performed after doca-flow is
initialized, and wraps existing pipes with CT semantics.

**Layering rule — doca-flow first, CT init before port start —
non-negotiable.** `doca_flow_ct_init(cfg)` is a one-time global
call that must run AFTER `doca_flow_init()` but BEFORE any port
is started; CT entries can only be added once the ports and the
wrapped doca-flow pipes are up. When the user has not yet
initialized doca-flow, route to
[`TASKS.md ## configure`](TASKS.md#configure) FIRST. Do NOT
propose that CT replaces or rewires the doca-flow setup — CT
extends it. An agent that treats CT as a standalone library, as
a per-port context, or that recommends rebuilding the doca-flow
setup from scratch to add CT — has the layering wrong for every
version of CT.

**Path selection — stateless vs CT vs Linux kernel conntrack.**

| User intent | Right artifact |
| --- | --- |
| Stateless steering only (match-and-forward, no per-connection state) | This skill's stateless surface in [`## Capabilities and modes`](#capabilities-and-modes) alone |
| Hardware-accelerated stateful firewall offload, hardware NAT gateway, per-connection telemetry tied to flow rules, conntrack-aware dataplane actions | the CT module of `doca-flow` (this section) on top of stateless doca-flow |
| Software / kernel-side conntrack is acceptable (low connection rate, host CPU has headroom) | Linux netfilter (`nf_conntrack`, `iptables -m state`, `nft ct`) — different code path, out of scope here. Do NOT use the doca-flow CT module as a wrapper around kernel conntrack |
| Traffic dominated by one-packet flows (CT entries would churn faster than aging can keep up) | This skill's stateless surface alone — CT entries have a non-zero per-flow cost |

**The global CT module — one per process, initialized before
port start.**

| Object | Lifetime | What it owns |
| --- | --- | --- |
| CT module (configured via `struct doca_flow_ct_cfg`, enabled by `doca_flow_ct_init`) | Process-global; initialized once after `doca_flow_init` and before any port start; torn down by `doca_flow_ct_destroy(void)` before `doca_flow_destroy` | The CT bookkeeping for the process: the CT entry table, the aging-timer configuration, and the CT-aware pipes that wrap the ports' pipes |

CT is **global**, not per-port: a host driving CT across several
doca-flow ports still calls `doca_flow_ct_init` exactly once, and
there is NO per-port `doca_flow_ct` context. The per-port choice
the agent must surface is which ports' pipes get wrapped with CT
semantics — not "one CT context per port".

**The 5-tuple CT match — the only match the agent should quote
as default.**

| Match field | What it carries |
| --- | --- |
| Source IP (v4 / v6) | The connection's source address — half of the connection identity |
| Destination IP (v4 / v6) | The connection's destination address — the other half |
| Source port | TCP / UDP source port — separates concurrent flows from the same source host |
| Destination port | TCP / UDP destination port — separates concurrent flows to the same destination host |
| Protocol | IP protocol number (TCP=6, UDP=17, …) — the same (IP, port, IP, port) tuple may legitimately exist for different protocols |
| VRF / VNI (overlay only) | Routing-domain identifier (VRF) or overlay network identifier (VNI) for VXLAN / GENEVE / … — required when the same 5-tuple may exist in multiple overlay tenants |

If the user asks for a CT match that is *less* than 5-tuple
(e.g. *"track by source IP only"*), that is almost always a
stateless steering question dressed up as CT — route back to
[`## Capabilities and modes`](#capabilities-and-modes). If they
ask for *more*, confirm via the cap-query before promising it.

**CT-aware actions — state-tracking, NAT, overlay-aware.**

| Action class | How to confirm support |
| --- | --- |
| State-tracking only (new → established → related → closed) | Base CT capability — gated by `doca_flow_ct_cap_is_dev_supported(devinfo)` |
| SNAT (rewrite source address / port; reverse is symmetric) | Same device-support query; NAT direction is requested through `doca_flow_ct_cfg_set_direction` and the CT actions, not a separate cap query |
| DNAT (rewrite destination address / port; reverse is symmetric) | Same device-support query; configured via `doca_flow_ct_cfg_set_direction` and the CT actions |
| SNAT + DNAT combined (full-cone, hairpin, double NAT) | Same device-support query; confirm the combined behavior empirically — there is no per-variant cap symbol |
| Overlay-aware CT (inner 5-tuple over VXLAN / GENEVE / …) | Same device-support query; confirm overlay handling against the shipped CT sample |

**Capability discovery — one device-support query.** CT exposes a
single capability symbol, `doca_flow_ct_cap_is_dev_supported(devinfo)`,
which answers only "does this device support CT at all". There is
NO per-axis `doca_flow_ct_cap_*` family — the agent must NOT claim
separate cap symbols for flow count, aging range, NAT variants, or
overlays. Call `doca_flow_ct_cap_is_dev_supported` against the
active `doca_devinfo` BEFORE proposing any CT use; everything below
is then sized through the `doca_flow_ct_cfg_*` setters and verified
empirically, not through additional cap queries:

| Concern | How it is actually handled |
| --- | --- |
| Max concurrent CT flows | Sized through the CT cfg / actions-memory setters (e.g. `doca_flow_ct_cfg_set_actions_mem_size`); oversubscription surfaces as `DOCA_ERROR_FULL` / `_NO_MEMORY` at runtime, so validate against the workload's peak |
| Aging-timer configuration | Set via `doca_flow_ct_cfg_set_aging_query_delay` and the aging plugin ops; an unworkable value surfaces as `DOCA_ERROR_INVALID_VALUE` at init/configure |
| NAT variants (SNAT / DNAT / combined) | Requested through `doca_flow_ct_cfg_set_direction` and the CT actions; an unsupported request surfaces as `_NOT_SUPPORTED` at entry add — there is no per-variant cap query |
| Overlay encapsulations for CT | Confirmed against the shipped CT sample and runtime behavior, not a per-overlay cap symbol |

**Version pairing — CT ships inside doca-flow.** CT is part of the
doca-flow library, so there is no separate `doca-flow-ct`
pkg-config module to version independently. `pkg-config
--modversion doca-flow` MUST equal `doca_caps --version`; CT is
built and versioned against that single doca-flow module. A
version skew between the doca-flow library and the rest of the
install is the canonical *"my CT entry returns `_DRIVER` on a
device the cap-query says supports it"* root cause. Route
disagreement to
[`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
layer 2 BEFORE any CT-layer diagnosis.

**CT-specific error overlay.** Add to the cross-library taxonomy
in [`## Error taxonomy`](#error-taxonomy):

| Error | CT-specific cause |
| --- | --- |
| `DOCA_ERROR_BAD_STATE` | Layering / lifecycle violation: `doca_flow_ct_init` called after a port was already started (it must run before port start), OR a CT entry add before the ports and wrapped pipes are up, OR calling `doca_flow_ct_destroy` out of order relative to `doca_flow_destroy` |
| `DOCA_ERROR_NOT_SUPPORTED` | NAT variant / overlay / aging range / CT feature is unsupported on this device + firmware combo. Re-run `doca_flow_ct_cap_is_dev_supported(devinfo)` to confirm the device supports CT at all; surface which DOCA version is installed. Do not retry the same spec on the same device |
| `DOCA_ERROR_FULL` (or `_NO_MEMORY`) | CT entry table at capacity. Read the per-CT-entry counters to identify idle / stale entries; either wait for aging to evict them, evict explicitly, or — if the workload genuinely needs more concurrent flows than the device supports — re-run the cap query for the max-concurrent-flows axis and consider whether the workload fits this device at all |
| `DOCA_ERROR_INVALID_VALUE` | Malformed 5-tuple (zero protocol, mismatched IP versions on src / dst), NAT translation that conflicts with an existing entry (two entries cannot map the same translated 5-tuple to two different connections), unsupported overlay configuration, or aging timer outside the cap-advertised range |
| `DOCA_ERROR_IN_USE` | CT entry remove while the entry is still being referenced by in-flight traffic. Quiesce the affected 5-tuple (or wait for the aging timer to evict the entry naturally), then retry. Do NOT force-remove — doing so can corrupt the per-connection state on the wire |

**Safety overlay.** Inherits this skill's existing
[`## Safety policy`](#safety-policy) plus three CT-specific rules:

1. **Aging-table sizing.** The cap-advertised max concurrent
   flows is the ceiling; the user's expected peak (not average)
   concurrent-flow count is the input. If the estimate exceeds
   the ceiling, surface the device-fit gap — do NOT over-commit
   the table. The aging timer must fit BOTH the cap-advertised
   range AND the granularity.
2. **Do not invent NAT translations to resolve a conflict.**
   `DOCA_ERROR_INVALID_VALUE` on an entry add with a NAT action
   is almost always a policy bug (two NAT rules that should not
   coexist). Surface the conflict to the user; the policy layer
   is the right place to fix it.
3. **This skill does not define a firewall policy.**
   The CT module *tracks* connections and *applies* the actions
   the user asks for; it does NOT implement policy. When the
   user asks *"what rules should I write"*, refuse to invent a
   policy and route to their networking / security expertise.

For the configure / build / modify / run / test / debug shape
specific to CT, see
[`TASKS.md ## flow-ct`](TASKS.md#flow-ct).

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
| Placement / steering-plane-unavailable error | Port refuses to start — `doca_flow_port_start` (or the first switch-port `doca_flow_pipe_create`) returns `DOCA_ERROR_DRIVER` / a failed start, and the SDK log shows `Failed to query WQE based flow table capabilities` → `Failed to get hws cap` (devx `op_mod=0x37`, `BAD_PARAM_ERR`), or `failed to create dest action ROOT, flag 64, err -121` | The opened function has no usable hardware-steering plane — almost always running **host-side against a BlueField in `SEPARATED_HOST` / NIC mode**, where the steering plane belongs to the DPU Arm. Identical on every card on such a host, in BOTH `vnf` and `switch` modes, and forcing `sws` does NOT bypass it (port-start still queries the HWS cap) | **Do not touch the pipe spec or steering-mode string.** This is the device-placement signature: check `INTERNAL_CPU_MODEL` per [`## Capabilities and modes`](#capabilities-and-modes) device-placement bullet + [TASKS.md ## configure](TASKS.md#configure) step 1. Run DOCA Flow on the DPU Arm side, or change the card's mode via [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md). |
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

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

Programming the BlueField steering hardware is **not** a free-form
operation. Wrong specs can take traffic offline; wrong actions can drop
or mirror unintended traffic. Two policies follow from that:

1. **Validate before committing to hardware.** DOCA Flow has no
   separate read-only pipe-validation API; validation happens at
   constructor time inside `doca_flow_pipe_create`, whose
   `DOCA_ERROR_INVALID_VALUE` / `DOCA_ERROR_NOT_SUPPORTED` return IS
   the validate signal. Treat a successful `doca_flow_pipe_create`
   (optionally backed by the staged-entry / dry-run sample pattern)
   as the validation step **before** the entry-add call hits the
   hardware. The lifecycle is *build (create = validate) → start →
   add entries → read counters*. Skipping it is the most common cause
   of "my pipe takes the link down" reports.
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
