# DOCA Switching capabilities, version overlay, errors, observability, safety

**Where to start:** The pattern overview below names the recurring
switching-class patterns. Pick the pattern first, then drill into
the H2 that owns the substance. For the *how* of executing each
pattern, jump to [TASKS.md](TASKS.md).

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the canonical DOCA version-handling rules
this skill layers a switching overlay on top of, see
[`doca-version`](../../doca-version/SKILL.md). For the *rules*
layer that programs ON TOP OF the topology described here, see
[`doca-flow`](../doca-flow/SKILL.md) — `doca-switching` is the
substrate, `doca-flow` is the steering programmed against that
substrate.

## Pattern overview

Every switching-class question this skill teaches resolves into one
of SIX patterns. The patterns are CLASSES — they apply across every
BlueField generation and every install, not just the worked example
shown.

| Switching pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Topology vs rules layering | Configure the switch topology FIRST with this skill; program packet steering ON TOP with `doca-flow` | [`## Capabilities and modes`](#capabilities-and-modes) layering rule + [SKILL.md](SKILL.md) loader |
| 2. Pick the BlueField mode | SmartNIC vs DPU vs switch — the mode decides which port types and switching primitives exist at all | [`## Capabilities and modes`](#capabilities-and-modes) mode table + [`## Safety policy`](#safety-policy) mode-transition rule |
| 3. Pick the port type | PF / VF / SF / representor — each port type has its own enumeration path and switching-domain rules | [`## Capabilities and modes`](#capabilities-and-modes) port-type table + [TASKS.md ## configure](TASKS.md#configure) |
| 4. Discover capabilities | Query `doca_switching_cap_*` for max ports, supported port types, supported switching modes, supported overlay encapsulations on the active `doca_devinfo` | [`## Capabilities and modes`](#capabilities-and-modes) capability-query rule + [TASKS.md ## configure](TASKS.md#configure) |
| 5. Treat mode transitions as high-stakes | A NIC ↔ switch mode change typically requires firmware reconfiguration and reboot; it is NOT a casual API call | [`## Safety policy`](#safety-policy) mode-transition rule + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 6. Interpret a `DOCA_ERROR_*` from a switching call | Map the error (`BAD_STATE` / `NOT_SUPPORTED` / `INVALID_VALUE` / `NOT_PERMITTED` / `IN_USE`) to its switching-specific cause before retrying or escalating | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Substrate before steering, every time.** The topology described
  here is the substrate; `doca-flow` rules are the steering. A user
  asking "where do my packets go?" needs both, but the answer ORDER
  matters — configure topology first, then program flows. An agent
  that conflates the two layers will mis-route questions about
  representor *visibility* (substrate) to the flow API (steering).
- **Discover the device-installed surface, do not assume.** Every
  pattern above gates on `pkg-config --modversion doca-switching`
  and on the `doca_switching_cap_*` capability snapshot of the
  active device. BlueField generations expose different switching
  surfaces; quoting a feature without checking is the single most
  common hallucination failure mode.

## Capabilities and modes

DOCA Switching configures the BlueField embedded switch dataplane —
the on-chip switch that decides where packets go between the
physical port(s), the host PFs/VFs, and the DPU representors. Before
writing any topology spec, the agent should know which mode and
feature set the BlueField is in.

**The layering rule (load-bearing).** This is the single most
important distinction the agent must teach:

| Layer | Library | What it expresses | Authoritative public guide |
| --- | --- | --- | --- |
| Topology (substrate) | `doca-switching` | Which port objects exist, NIC vs switch mode, which ports are bridged at the switch level, representor associations | [DOCA Switching](https://docs.nvidia.com/doca/sdk/DOCA-Switching/index.html) |
| Steering (rules on top) | `doca-flow` | Per-packet match (5-tuple, headers, metadata) → action (forward to representor, drop, encap/decap, modify), pipes, entry programming | [DOCA Flow](https://docs.nvidia.com/doca/sdk/DOCA-Flow/index.html) |

The agent's rule: **configure the switching topology FIRST with this
skill; program packet-steering rules ON TOP with `doca-flow`.** A
flow rule that targets a representor the switching topology never
exposed will produce a `doca-flow` capability or validate failure,
and the right fix is at the switching layer, not in the flow spec.

**BlueField runtime mode.** The on-chip switch surface depends on
which mode the BlueField is currently in. The mode is configured
via `mlxconfig` on the host and persists across reboots.

| BlueField mode | What the switch surface looks like | Where the mode is set |
| --- | --- | --- |
| SmartNIC (NIC) mode | The host owns the network stack on the physical port; the BlueField switch is largely pass-through; representors and DOCA-Switching primitives may be unavailable or limited | `mlxconfig -d <pcie> q INTERNAL_CPU_MODEL` reports SmartNIC-shaped values |
| DPU mode | The BlueField owns the network stack and represents host PFs/VFs as DPU-side representors; the switch dataplane is programmable | `mlxconfig -d <pcie> q INTERNAL_CPU_MODEL` reports DPU-shaped values |
| Switch (NIC mode on BF3) | Specialized switch-only mode where the BlueField acts as a programmable switch ASIC; the host CPU complex is not in the data path | Per the BlueField generation's documented mode set |

The exact mode names and `mlxconfig` values are install-bound — the
agent should read them out of the live device rather than naming
them from memory. The env-side mode check is owned by
[`doca-setup CAPABILITIES.md ## Capabilities and modes`](../../doca-setup/CAPABILITIES.md#capabilities-and-modes);
this skill's contribution is the consequence for the switching
surface, not the env-side detection mechanics.

**Port-type taxonomy.** Once the BlueField is in a mode that
exposes the switching surface, the switching context enumerates
port objects of these kinds:

| Port type | What it represents | Typical use in a switching topology |
| --- | --- | --- |
| PF (physical function) | The PCIe physical function — one per host-facing or wire-facing PCIe device | The "outside" endpoint of the switch — wire port or host PF |
| VF (virtual function) | A PCIe virtual function spawned under a PF (SR-IOV) | Per-tenant or per-VM endpoint that the switch dataplane bridges |
| SF (scalable function) | A scalable function — a lighter-weight, software-managed analog of VFs | High-density per-tenant endpoint where SR-IOV VFs are too coarse |
| Representor | The DPU-side handle that represents a host PF / VF / SF | The DPU's view of a host endpoint; `doca-flow` rules typically target representors |

The presence and count of each port type depends on the BlueField
generation, the firmware configuration, and the active BlueField
mode. The agent must **always** verify presence via the
capability-query rule below, not assume.

**Switching primitives.** The DOCA Switching API exposes (the exact
symbol names are install-bound — read the headers under
`/opt/mellanox/doca/infrastructure/include/` on the user's
install):

- A per-switch-instance context object (`doca_switching`) that
  represents the BlueField's switch domain. A BlueField typically
  has one such domain.
- Port objects keyed by their kind (PF / VF / SF / representor) and
  by the underlying device handle.
- Bridge / switching-table primitives that associate ports into a
  shared switching domain — i.e., "these ports' traffic is
  evaluated together by the switch dataplane".
- Representor-association primitives that bind a host-side
  PF / VF / SF to a DPU-side representor handle that `doca-flow`
  rules can later target.

**Capability discovery — the only rule.** Before sizing any port
list or assuming a switching mode or overlay encapsulation is
available, call the matching `doca_switching_cap_*` query against
the active `doca_devinfo`:

| Capability | Query family | Why the agent must ask |
| --- | --- | --- |
| Maximum ports the switch can address | `doca_switching_cap_*` (max-ports query) | BlueField generation- and firmware-dependent; oversizing returns `DOCA_ERROR_NOT_SUPPORTED` at start |
| Supported port types (PF / VF / SF / representor) | `doca_switching_cap_*` (port-type query) | Not every generation exposes every port type; quoting a port type without checking is the leading hallucination mode |
| Supported switching modes (NIC vs switch) | `doca_switching_cap_*` (mode query) | The set of modes that *can* be requested is install-bound; the *active* mode is also install-bound (see runtime-mode table above) |
| Supported overlay encapsulations at the switch level (VXLAN, VLAN, …) | `doca_switching_cap_*` (overlay query) | Overlay availability is firmware-bound; not every BlueField generation accelerates the same set of overlays at the switch dataplane |

The exact symbol names of each `doca_switching_cap_*` entry point
are install-bound; the agent should read them out of the installed
headers and the
[DOCA Switching public guide](https://docs.nvidia.com/doca/sdk/DOCA-Switching/index.html)
rather than inventing them.

**Configuration shape.** *Mandatory* configurations before
`doca_ctx_start()` on the switching context: the BlueField mode
must already be the one the topology assumes (mode transitions are
not a runtime spec change — see [`## Safety policy`](#safety-policy)),
and the port-enumeration step must complete without errors.
*Optional* configurations (overlay-encapsulation enablement, bridge
priority) gate on the capability queries above; query the active
value before assuming a default.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The switching-specific overlay** is:

- The set of `doca_switching_*` symbols available on a given
  install is observable from the switching header set under the
  installed DOCA infrastructure tree (look up the path in
  [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package)).
  When the user reports an `undefined reference` or "function not
  found" for a `doca_switching_*` symbol, the first hypothesis is
  **wrong-version documentation** — confirm the installed version
  per [`doca-version`](../../doca-version/SKILL.md), then verify
  the symbol exists in the installed headers, then read the DOCA
  Switching programming guide for *that* release.
- Per-switching-capability availability uses the version-matrix
  lookup procedure in
  [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas)
  (`version-matrix.json`) when a host has the structured helper,
  with `pkg-config --modversion doca-switching` as the build-time
  anchor on every host.
- BlueField generation matters separately from DOCA version. A
  given DOCA release can support multiple BlueField generations,
  and each generation exposes a different switching surface. The
  agent must surface both axes (DOCA version *and* BlueField
  generation) when answering "is feature X available?" — neither
  axis alone is sufficient.
- The release notes for the installed DOCA version are the
  canonical source for switching features added, deprecated, or
  behavior-changed in that release. Route through the
  knowledge-map for the release-notes URL pattern.

Version-specific tables of symbol availability are deliberately
not maintained in this file — they would drift out of date
silently. The discipline is "read the headers and the matching
release notes", not "trust this file's table".

## Error taxonomy

Switching-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *switching surface* meaning the agent must
disambiguate before falling back to the cross-library response.

| Error | Switching context where it shows up | Switching-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | Any switching call on a context that is not in the right lifecycle phase; switching-mode-mismatch calls | Two distinct causes the agent must disambiguate: (a) lifecycle violation — the switching context was operated on outside its allowed window (e.g. a port-config call before `doca_ctx_start()` or after `_stop()`); (b) **switching-mode mismatch** — the operation requires switch mode but the BlueField is in NIC mode (or vice versa). For (b), the fix is *not* in the program — see [`## Safety policy`](#safety-policy). |
| `DOCA_ERROR_NOT_SUPPORTED` | Port-type allocation, overlay-encapsulation request, switching-mode selection | The feature is not available on this BlueField generation / firmware. Re-run the matching `doca_switching_cap_*` query against the active `doca_devinfo`; do not retry the same call on the same device hoping for a different answer. |
| `DOCA_ERROR_INVALID_VALUE` | Port reference passed to a switching-table or bridge call; conflicting table entry | The port reference is stale (port was destroyed), conflicting (same port already in another exclusive switching domain), or out-of-range for the device. Re-enumerate ports per [TASKS.md ## configure](TASKS.md#configure) step 3 before retrying. |
| `DOCA_ERROR_NOT_PERMITTED` | Switching-context creation, port reconfiguration, mode-related calls | The process lacks privilege — switching-topology calls typically require root / sudo on the DPU. The fix is env-side (run with sudo, or add the user to the appropriate group); route to [`doca-setup`](../../doca-setup/SKILL.md). Do not modify the program. |
| `DOCA_ERROR_IN_USE` | Reconfiguring a port that is currently carrying traffic | The port is bound to an active switching-table entry or carrying live traffic. The agent's rule: surface the *traffic-disruption* implication BEFORE recommending a quiesce-and-retry. Forcing the reconfiguration while traffic flows is a real outage; this is exactly the case where the safety policy below applies. |

The agent's rules:

1. **Never recommend a blind retry loop on `DOCA_ERROR_*` from a
   switching call.** Each row above wants investigation, not retry.
   `BAD_STATE` in particular is the highest-information error in
   the switching surface because it surfaces both lifecycle and
   mode-mismatch causes — disambiguate before any retry.
2. **`IN_USE` is a traffic-disruption warning, not a code bug.**
   Treat it as the switching surface's version of the safety
   policy's "reconfiguring a live port is a real change" rule.

## Observability

The switching observability surface is the set of read-only queries
and state readouts that report topology state and per-port status.
There is no "switching counter" of the kind `doca-flow` exposes —
the visibility comes from per-context queries and from the
underlying env-side primitives.

Four primary signals the agent should reach for:

1. **Switching-context state.** Read the per-switch context's
   active mode and capability snapshot via the `doca_switching_cap_*`
   queries from [`## Capabilities and modes`](#capabilities-and-modes).
   This is the canonical "what is the switch currently doing?"
   readout.
2. **Port enumeration.** The current set of port objects (PF / VF /
   SF / representor) the switching context can address. A
   representor that the user expects but the enumeration does not
   surface is almost always an env-side problem (representor not
   created, host-side SR-IOV / SF configuration wrong) — route to
   [`doca-setup`](../../doca-setup/SKILL.md) before any code change.
3. **Switching-table inspection.** The current set of bridge /
   table entries the switching context has installed. This is the
   ground-truth answer to "what did I program the switch to do?";
   it is also the diff target when a `doca-flow` rule on top of
   the topology does not behave as expected (the flow rule may be
   correct; the underlying switching table may not bridge what the
   user thinks it does).
4. **Env-side cross-checks.** Representor presence (`ls
   /sys/class/net/`), PCIe enumeration (`lspci | grep Mellanox`),
   and the BlueField mode (`mlxconfig -d <pcie> q
   INTERNAL_CPU_MODEL`) are the env-side primitives the switching
   layer reads against. The cross-cutting mechanics of these live
   in [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability);
   the switching-specific consequence is that a topology mismatch
   between what the API reports and what the env reports is a
   real partial-install or partial-reconfiguration hazard, not a
   convenience.

For the cross-library debug-time observability (`DOCA_LOG_LEVEL=trace`,
`--sdk-log-level`, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).

## Safety policy

Configuring the BlueField switch dataplane is **not** a free-form
operation. The switching plane sits between the wire and every
host endpoint; a wrong topology can take production traffic
offline, and a wrong mode-transition can require a reboot to
recover from. Three policies follow from that:

1. **Mode transitions are HIGH-STAKES; treat them accordingly.**
   Changing the BlueField between NIC mode and switch mode (or
   between SmartNIC and DPU modes) is **not** a runtime API call
   the agent should recommend casually. It typically requires:
   1. A `mlxconfig` change on the host (often `mlxconfig -d
      <pcie> s <key>=<value>`, sudo).
   2. A firmware reset or full host reboot for the change to take
      effect.
   3. Re-verification of the BlueField mode (`mlxconfig -d <pcie>
      q INTERNAL_CPU_MODEL`) after the reboot.

   The agent's rule: **before recommending a mode transition,
   warn explicitly about the firmware-reconfiguration / reboot
   requirement, confirm the user understands the operation will
   disrupt traffic, and route the env-side steps to
   [`doca-setup`](../../doca-setup/SKILL.md).** A user asking
   "can I just flip the mode in code?" is asking the wrong
   question; the answer is to teach why that question is wrong.
2. **Smoke before scale.** Bringing up a new switching topology
   should go through a minimum-viable smoke before any production
   topology is configured: one bridge, one representor pair, one
   verified packet path (e.g. `tcpdump` on the representor under
   controlled traffic), THEN add `doca-flow` rules on top. The
   smoke is the cheapest way to detect a topology mismatch
   *before* layering steering rules on top of it. Skipping it
   produces failure modes (flow-rule debug points at the topology,
   topology debug points at the flow rule) that are expensive to
   bisect.
3. **Live-port reconfiguration is a traffic-affecting change.**
   `DOCA_ERROR_IN_USE` is the surface's warning that a port the
   user wants to reconfigure is currently carrying traffic. The
   agent's rule: surface the traffic-disruption implication
   before recommending a quiesce-and-retry. Do not paper over
   `IN_USE` with a "just retry until it works" loop — that is the
   same anti-pattern as forcing a mode change without warning the
   user about the consequences.

The agent's job is to **enforce these orderings in the workflow**,
not just describe them. If the user says "skip the smoke, just
program it" or "just flip the mode in code, no reboot", the right
answer is to refuse and explain the cost, not to comply.
