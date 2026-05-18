# DOCA DPU CLI — Capabilities

**Where to start:** The DOCA DPU CLI is the documented on-DPU
operator command surface for the BlueField. The pattern overview
below names the recurring DPU-CLI questions. Pick the pattern
first, then drill into the H2 that owns the substance. For the
*how* of executing each pattern, jump to [TASKS.md](TASKS.md). For
DOCA-libraries capability questions (per-device, per-library), the
sibling [`doca-caps`](../doca-caps/SKILL.md) is the right tool, not
this one.

This file is loaded by [`SKILL.md`](SKILL.md). It documents *what
command families the DPU CLI surface covers*, *the read-only vs
state-changing split*, *what versions ship the surface*, *the
layered error and observability surfaces*, and *the safety policy
that makes networking reconfiguration and firmware-slot modification
HIGH-STAKES*. For step-by-step invocations and the
smoke-before-bulk workflow, see [`TASKS.md`](TASKS.md).

## Pattern overview

Every DOCA-DPU-CLI question this skill teaches resolves into one of
FIVE patterns. The patterns are CLASSES — they apply to every
BlueField OS image the public DOCA DPU CLI guide documents, not
just one model or one DOCA release.

| DPU CLI pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Confirm shell context | Confirm the shell the agent is operating from is on the DPU side (BlueField Arm), NOT the host x86 side — and NOT inside an unrelated container — BEFORE any operator command | [`## Capabilities and modes`](#capabilities-and-modes) shell-context section + [`## Error taxonomy`](#error-taxonomy) layer 2 + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. System / state inspect | Read the BlueField's documented system surface — uptime, image / BFB info, DOCA version on the DPU side, kernel — before any operator action | [`## Capabilities and modes`](#capabilities-and-modes) family 1 + [TASKS.md ## run](TASKS.md#run) family 1 + [TASKS.md ## test](TASKS.md#test) step 2 |
| 3. Networking config inspect or change | Read or change the documented networking surface — ports, PF / VF / SF, bridges, OVS interaction; reads are safe, changes are HIGH-STAKES | [`## Capabilities and modes`](#capabilities-and-modes) family 2 + [`## Safety policy`](#safety-policy) high-stakes-modify rule + [TASKS.md ## run](TASKS.md#run) family 2 |
| 4. Firmware-slot inspect (not modify) | Read which BFB image / firmware slot is active or staged; modification is owned by [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure), NOT by this skill | [`## Capabilities and modes`](#capabilities-and-modes) family 3 + [TASKS.md ## modify](TASKS.md#modify) routing-out rule |
| 5. Diagnose stale / missing / wrong-shell / version-mismatched output | Map the symptom (empty list, command-not-installed, wrong-shell error, stale state, hardware-not-ready, version mismatch) to the right layer before any code or config change | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Shell context is the FIRST check, always.** Every other DPU CLI
  pattern is meaningless if the agent is on the wrong shell (host
  x86 OS, or an unrelated container). Confirm the prompt is on the
  BlueField Arm OS BEFORE quoting any output as DPU state.
- **Read-only first; state-changing second; firmware modification
  out of scope.** System / state / firmware-slot inspect and the
  read side of networking are safe and can be re-run freely.
  Networking *changes* (port up / down, VF add / remove, bridge
  edit, OVS flow change) DO change state and are HIGH-STAKES.
  Firmware-slot *modification* (flipping the active slot,
  installing a new BFB) is owned by
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  — this skill REFUSES to run those.

## Capabilities and modes

The DOCA DPU CLI is the documented operator-command surface that
NVIDIA's public DOCA DPU CLI guide exposes on the BlueField OS
image (reached via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)).
NVIDIA's exact binary naming for the on-DPU operator CLI has
varied across BlueField OS / DOCA releases; this skill therefore
treats the surface as the **documented operator-command set** for
the BlueField — not as a single named binary — and routes the
agent at the public guide and the installed `--help` on the user's
BlueField for the exact subcommand inventory the user's version
ships. This is the load-bearing scope decision; see the
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship)
rationale.

### Shell context (where the surface runs)

The DPU CLI surface is **on the BlueField OS image, on the
BlueField Arm side, not on the host x86 OS**. This skill's
load-bearing precondition — and the FIRST check in
[`TASKS.md ## configure`](TASKS.md#configure) — is that the agent's
shell is on the DPU side. The three shells the agent has to
distinguish:

- **Host shell.** The x86 (or Arm) operating system the BlueField
  is physically installed in. PCIe sees the BlueField as a device;
  the DPU CLI surface is NOT here. Host-side tooling (`lspci`,
  `mlxconfig`, `mlxfwmanager` from MFT, `flint`) is documented
  elsewhere; do not call it *"the DPU CLI"*.
- **DPU shell.** The BlueField Arm operating system itself,
  reached typically via `ssh ubuntu@<bluefield-arm-ip>`, via the
  documented BlueField console, or via a serial console. THIS is
  where the DPU CLI surface lives.
- **Container shell on either side.** A DOCA service container
  (DTS, BlueMan, Firefly, …) running on the BlueField Arm has its
  own shell context; operator commands inside that container
  surface only what the container exposes. For cross-cutting
  operator operations on the BlueField outside the container, the
  agent has to exit the container shell first. For kubelet-side
  service-container operations, route to
  [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md).

### Four command families

The DPU CLI surface exposes **four documented operator command
families** at the class level. The exact subcommand inventory
inside each family is documented per the public DOCA DPU CLI guide
on the user's installed BlueField OS release and surfaced by the
installed `--help` on the user's BlueField; the skill deliberately
does not pin specific subcommand names.

| Family | Class shape | Read-only vs state-changing | Where the workflow lives |
| --- | --- | --- | --- |
| 1. System / state inspect | Uptime, BlueField OS image identity, BFB info as visible from the DPU side, DOCA version on the DPU side, kernel info — the operator's *"is this BlueField alive and what is it"* surface | Read-only; safe to run freely | [TASKS.md ## run](TASKS.md#run) family 1 + [TASKS.md ## test](TASKS.md#test) step 2 |
| 2. Networking config (inspect AND change) | Ports, PF / VF / SF enumeration and lifecycle, bridge enumeration and edit, OVS interaction (bridges / interfaces / flows). This is the family where the read side is safe and the write side is HIGH-STAKES — the agent MUST surface that distinction | Read side safe; write side HIGH-STAKES (state-changing) per [`## Safety policy`](#safety-policy) | [TASKS.md ## run](TASKS.md#run) family 2 + [TASKS.md ## modify](TASKS.md#modify) high-stakes routing |
| 3. Firmware-slot inspect (NOT modify) | Read which BFB / firmware slot is currently active, which slot is staged, what version each holds. *Inspect only.* MODIFICATION (flip the active slot, install a new BFB) is owned by [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure), NOT by this skill | Read-only inspection here; modification is **out of scope** for this skill | [TASKS.md ## run](TASKS.md#run) family 3 + [TASKS.md ## modify](TASKS.md#modify) refusal-and-route |
| 4. Operator hygiene | Status / logs of the documented DPU-side services (DOCA daemons, kubelet on the BlueField if present), restart of those services. The operator's *"is this thing running, what did it say last, can I bounce it"* surface | Status / logs read-only; restart is state-changing but bounded (single service) and not as high-stakes as a networking change | [TASKS.md ## run](TASKS.md#run) family 4 |

The four families are deliberately **disjoint** in scope and
posture; the agent's first job in any DPU-CLI session is to pick
which family the user's question lives in, then walk the matching
workflow in [TASKS.md](TASKS.md).

### Sibling DOCA tools on the DPU side

The DPU CLI is one of several DOCA tools the agent can reach on
the DPU side; the other one this skill explicitly pairs with is
[`doca-caps`](../doca-caps/SKILL.md). The distinction is
load-bearing:

- [`doca-caps`](../doca-caps/SKILL.md) is a **focused
  DOCA-libraries capability dump** — per-device, per-library, what
  the DOCA install reports the device can do. It does NOT cover
  system uptime, networking config, firmware slot, or operator
  hygiene.
- This skill is the **broader BlueField operator CLI surface** —
  the four families above. It does NOT cover per-device
  per-library capability flags at the level `doca-caps` reports
  them.

A complete DPU-side inspection typically uses both; this skill
does not duplicate the capability-dump surface that
[`doca-caps`](../doca-caps/SKILL.md) owns.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The DOCA-DPU-CLI-specific overlay** is:

- **The DPU CLI surface is shipped on the BlueField OS image
  (BFB).** Which subcommands are present, which output columns
  they emit, and which operator hygiene services are
  manageable depend on the BFB version on the user's BlueField,
  not on the host-side DOCA package. When the user reports
  *"this DPU CLI command is missing"*, the right next step is to
  confirm the BFB version on the BlueField (not the DOCA version
  on the host) per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
  and route to [`doca-setup`](../../doca-setup/SKILL.md) for a
  BFB update if needed.
- **The DPU CLI's view of the DPU and the host's view of DOCA
  must be cross-checked.** The four-way match in
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)
  applied to a DPU-CLI session means: host-side
  `pkg-config --modversion doca-common`, host-side
  `cat /opt/mellanox/doca/applications/VERSION`, DPU-side
  `doca_caps --version` (per [`doca-caps`](../doca-caps/SKILL.md)),
  and the BFB / image version reported by the DPU CLI's system /
  state family must agree on the train. When they disagree, the
  agent must surface the partial-install hazard, not paper over
  it — see [`## Error taxonomy`](#error-taxonomy) layer 6.
- **Where it runs:** on the BlueField Arm side, inside the
  BlueField OS image, NOT on the host x86 OS. There is no
  host-side variant of this surface; host-side operator tooling is
  documented elsewhere and is not in this skill's scope.
- **NVIDIA's binary naming for the on-DPU operator CLI has
  varied across BlueField OS / DOCA releases.** This skill
  therefore does not commit to a specific binary name; the
  authoritative inventory is the public DOCA DPU CLI guide on the
  user's installed BFB version plus the installed `--help` on the
  user's BlueField. Quote both; do not infer from a different
  release's name.

## Error taxonomy

The DPU CLI's error surface is broader than a side-effect-free
introspection tool because the surface includes a state-changing
networking family (family 2 write side) and an operator-hygiene
restart surface (family 4 restart side). The error layers the
agent should distinguish, in escalating order:

1. **Command-not-installed.** The subcommand the user expects does
   not exist on the installed BlueField OS image. Cause: the BFB
   version on the BlueField is older or newer than the version
   the user is reading docs against; the public DOCA DPU CLI
   guide on `docs.nvidia.com` and the installed `--help` on the
   user's BlueField are the joint source of truth; resolve the
   gap by confirming the BFB version (see
   [`## Version compatibility`](#version-compatibility)) and
   routing to [`doca-setup`](../../doca-setup/SKILL.md) for a BFB
   update if needed. Inventing a different subcommand name from
   a different release is the canonical hallucination here; the
   agent must NOT do it.
2. **Wrong-shell-context (host vs DPU vs container).** The
   subcommand exists in the user's mental model but the agent is
   typing it into the wrong shell — most commonly the host x86
   shell instead of the BlueField Arm shell, or inside a DOCA
   service container instead of on the BlueField OS directly.
   The fix is to confirm the prompt's shell context (per
   [`## Capabilities and modes`](#capabilities-and-modes)) and
   re-run on the right side; routing for the cross-side cases
   belongs in [`TASKS.md ## configure`](TASKS.md#configure) step
   1. This is the most common silent-fail mode for DPU-CLI
   sessions and is what the FIRST smoke check in
   [`TASKS.md ## test`](TASKS.md#test) is designed to catch.
3. **Permission layer.** The subcommand runs on the right shell
   but reports it cannot read or change state because the
   invoking user lacks the privileges the public DOCA DPU CLI
   guide requires (typically `sudo` on the BlueField Arm for
   anything in the networking-change or operator-restart
   families). The tool's own message is ground truth; re-run
   with the privileges the public guide names, do not bypass.
4. **State-stale layer.** The subcommand reports state that does
   not match what the user just observed elsewhere (e.g. an OVS
   bridge the user just deleted is still listed; a VF the user
   just added is missing). Typical cause: the underlying view is
   cached, or a previous state-changing command needs to settle
   (driver reload, OVS database sync, BlueField mode change).
   The fix is to wait the documented settle window and re-run;
   the agent must surface that the inspection is being re-run
   for staleness, not for a different answer.
5. **Hardware-not-ready layer.** The subcommand runs on the
   right shell, with the right privileges, but the BlueField
   hardware itself is not in a state that lets it answer — the
   BlueField did not finish booting, the mlx5 driver stack is
   not loaded, the firmware slot is mid-flip from a previous
   modify, or the device is in a recovery / fallback mode. The
   DPU CLI's own message plus `dmesg` on the BlueField are ground
   truth; routing: [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   driver / hardware layer.
6. **Version layer.** The subcommand runs and prints state but
   the state disagrees with what the host-side DOCA install (or
   the host-side
   [`doca-caps`](../doca-caps/SKILL.md) sibling check) reports.
   This is the partial-install hazard. Walk the four-way match
   per [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 and apply the DPU-CLI overlay in
   [`## Version compatibility`](#version-compatibility).
7. **Cross-cutting layer.** Layers 1-6 are clean, the subcommand
   reports clean output, and the user's symptom persists. The
   cause is below the DPU CLI surface — driver, firmware, mode,
   or hardware path on the BlueField; or, for a networking
   symptom, on the wire / on the OVS dataplane. Escalate to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   with the captured DPU CLI output as evidence; do not loop on
   DPU CLI subcommands hoping for a different answer.

The DPU CLI does **not** itself return `DOCA_ERROR_*` values to a
calling program — those are owned by DOCA libraries the user's
program links against. The DPU CLI's CLI exit codes and printed
messages are its own narrow surface; the agent maps those into the
layers above before interpreting any program-side `DOCA_ERROR_*`.

## Observability

The DPU CLI is itself an **operator-side observability primitive**
for the BlueField — it is *what other skills load to observe* the
BlueField's system / networking / firmware-slot / operator-hygiene
state before any code or config change. Specifically:

- [`doca-setup ## test`](../../doca-setup/TASKS.md#test) and
  [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
  prescribe reading the system / state and firmware-slot families
  here as part of the env-side smoke; this skill is the
  documented place to do that on the DPU side.
- [`doca-container-deployment TASKS.md ## test`](../../services/doca-container-deployment/TASKS.md#test)
  uses the operator-hygiene family here to confirm the kubelet
  and the documented DPU-side daemons are running before a
  service-container deployment is declared healthy. The DPU CLI
  view and the kubelet view are the two halves of the BlueField
  operator picture.
- [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
  consumes the captured DPU CLI inspection as the DPU-side
  operator-state half of the cross-cutting evidence pair (paired
  with the program-side trace per
  [`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability)
  and the host-side env view per
  [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability)).
- The captured DPU CLI output is the artifact downstream debug
  consumes. Save it (file, paste buffer, conversation artifact);
  without it, the next debug step starts guessing.

The DPU CLI does not emit metrics, traces, or DOCA logs of its own
beyond the printed CLI output. For program-side observability
(`DOCA_LOG_LEVEL`, `--sdk-log-level`, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For host-side / driver-side observability (port stats, hugepage
allocation, NUMA topology), see
[`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).

## Safety policy

The DPU CLI is the **most state-sensitive tool surface in the
on-DPU operator catalog** this bundle currently teaches an agent
to drive directly, because it includes a networking-change family
and an operator-restart family. The agent's posture:

- **Smoke-before-bulk is MANDATORY** before any networking
  reconfiguration or before any operator-restart action. The
  smoke is the three-step preamble in
  [`TASKS.md ## test`](TASKS.md#test): (1) confirm shell context,
  (2) confirm the BlueField is up via the system / state family,
  (3) confirm versions agree per
  [`## Version compatibility`](#version-compatibility). Skipping
  the smoke and reaching directly for a networking-change
  subcommand is the canonical DPU-CLI failure mode — the agent
  has no idea what state it is changing.
- **Networking reconfiguration is HIGH-STAKES.** A port up / down,
  a VF add / remove, a bridge edit, or an OVS flow change can
  drop traffic for in-flight workloads, disconnect the BlueField
  from its management network, or leave the BlueField in a state
  that requires a console / serial recovery. The agent must
  surface the impact BEFORE recommending the command, and must
  have walked the smoke first.
- **Firmware-slot modification is OUT OF SCOPE for this skill.**
  This skill ONLY covers firmware-slot *inspect* (read-only).
  *Modification* (flip the active slot, install a new BFB,
  rebuild the slot) is owned by
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  because the modify workflow requires a BlueField reset, a
  documented recovery posture, and version-matched packaging that
  this skill does not own. Routing those questions out is part
  of [`TASKS.md ## modify`](TASKS.md#modify).
- **Operator-restart is bounded but not free.** Restarting a
  documented DPU-side daemon (a DOCA service) interrupts the
  thing it serves; the agent must surface which daemon is being
  restarted and what its consumers will observe BEFORE running
  the restart. Service-container restarts on the BlueField
  belong to
  [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md),
  not here.
- **Quote what the DPU CLI said. Do not paraphrase state.** When
  the user later asks *"is this BlueField healthy"*, the correct
  answer is to point at the captured DPU CLI output line, not to
  summarize it. Paraphrasing state output is how stale evidence
  ends up justifying a high-stakes change.
- **Do not invent subcommand names, flag strings, or output
  columns.** The documented surface is the surface; the public
  DOCA DPU CLI guide via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
  plus installed `--help` on the user's BlueField is the joint
  source of truth. NVIDIA's binary naming has varied across
  releases; inventing a binary or flag name from prose or from a
  different release's docs is the canonical hallucination this
  skill is designed to prevent.

## Public-source pointer

The single canonical public source for the DOCA DPU CLI is the
**DOCA DPU CLI** page on `docs.nvidia.com`, reachable through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
Do not invent subcommand names, flag strings, output columns, or
binary names beyond what that page documents on the user's
installed BFB version. For DOCA-libraries capability questions
(per-device, per-library), the sibling
[`doca-caps`](../doca-caps/SKILL.md) is the right surface, not
this one. For host-side BlueField operator tooling (MFT,
`mlxconfig`, `flint`), the right routing is
[`doca-setup`](../../doca-setup/SKILL.md), not this skill.
