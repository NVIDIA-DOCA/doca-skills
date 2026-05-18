---
name: doca-dpu-cli
description: NVIDIA DOCA DPU CLI — the documented on-DPU operator command surface for the BlueField, accessed from the BlueField Arm shell (NOT the host shell). Frames four broad command families per the public DOCA DPU CLI guide — system / state inspect (uptime, image info, version), networking config (ports, PF / VF / SF, bridges, OVS), firmware-slot inspect (NOT modify — modification routes to doca-setup), and operator hygiene (logs, status, restart). Read-only inspection is safe and forms the smoke-before-bulk preamble (confirm shell context, confirm BlueField is up, confirm versions BEFORE any operator action); networking reconfiguration and firmware-slot modification are HIGH-STAKES and routed accordingly. Pairs with doca-caps (sibling DPU-side inspect), doca-setup (firmware modify), doca-version (canonical version chain), doca-container-deployment (kubelet-side ops). Subcommand names, flag strings, and output columns come from the public guide plus installed --help, never agent memory.
kind: library
---

# DOCA DPU CLI

**Where to start:** This is a tool skill for the documented BlueField
operator command surface — what NVIDIA's public DOCA DPU CLI guide
calls the on-DPU administrative CLI for the BlueField itself. Open
[`TASKS.md`](TASKS.md) and start at [`## run`](TASKS.md#run) for the
shell-context → list → inspect entry point, or at
[`## test`](TASKS.md#test) for the smoke-before-bulk loop the agent
must walk BEFORE any networking reconfiguration or firmware-slot
inspection. Open [`CAPABILITIES.md`](CAPABILITIES.md) when the
question is *what command families this surface exposes* and *what
the read-only vs state-changing split looks like*. If the user has
not installed DOCA on the BlueField yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user wants to
*modify* the firmware slot (not inspect it), route to
[`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
because firmware modification is owned there, not here.

## Example questions this skill answers well

The CLASSES of DPU-CLI questions this skill is built to answer,
each with one worked example. The class is the load-bearing piece;
the worked example is one instance.

- **"Am I on the host shell or the DPU shell — and how do I tell
  before I run anything?"** — worked example: *"I sshed into a
  server with a BlueField and I'm not sure whether my prompt is
  inside the BlueField Arm OS or on the host x86 OS"*. Answered by
  the shell-context check in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  layer 2 (wrong-shell-context).
- **"What does the documented BlueField operator CLI actually
  cover?"** — worked example: *"is networking reconfiguration in
  scope, or is that something else?"*. Answered by the four
  command families in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the four families table in
  [`TASKS.md ## Command appendix`](TASKS.md#command-appendix).
- **"What's the safe first thing to run on a BlueField I've just
  logged into?"** — worked example: *"confirm shell context, then
  uptime + version + image info, then list the network state"*.
  Answered by the smoke-before-bulk loop in
  [`TASKS.md ## test`](TASKS.md#test) +
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- **"I need to change a networking config (port / PF / VF / SF /
  bridge / OVS) on the BlueField — what's the high-stakes
  posture?"** — worked example: *"add a VF and wire it into a
  bridge"*. Answered by the high-stakes-modify rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the gating ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) +
  [`TASKS.md ## modify`](TASKS.md#modify) routing.
- **"I want to inspect the BlueField firmware-slot state, but not
  modify it — where does that live?"** — worked example: *"read
  which BFB / firmware slot is active without flipping anything"*.
  Answered by the firmware-slot-inspect family in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the modify-out-of-scope routing in
  [`TASKS.md ## modify`](TASKS.md#modify) (firmware modification
  is owned by
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)).
- **"How does the DPU CLI's view line up with doca-caps and with
  the DOCA install version on the BlueField?"** — worked example:
  *"DPU CLI says image X; doca_caps version says Y — which one is
  authoritative?"*. Answered by the version overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
  which redirects to [`doca-version`](../../doca-version/SKILL.md),
  plus the sibling-tool cross-check pattern with
  [`doca-caps`](../doca-caps/SKILL.md).

## Audience

This skill serves **external operators and AI agents who need to
operate a BlueField DPU from its own on-DPU shell**, with a
documented, shell-context-aware posture instead of typing commands
into whichever prompt happens to be in front of them. Concretely:

- A platform operator who just provisioned a BlueField and needs a
  documented, low-risk first set of inspections to confirm the DPU
  is up before any production workload lands on it.
- A DPU operator running networking changes (ports, PF / VF / SF,
  bridges, OVS interaction) who needs to commit to the high-stakes
  posture BEFORE issuing a state-changing command — and who needs
  a clean separation between *inspect-only* commands and
  *reconfigure* commands.
- An AI agent driving an operational triage session on a
  BlueField, where the agent must confirm shell context (DPU
  shell, not host shell), confirm the BlueField is up, and confirm
  versions BEFORE recommending any operator action.

It is **not** for users learning DOCA library APIs (use the
matching [`libs/<library>`](../../libs/) skill), and **not** the
right place for kubelet-side DOCA service container operations on
the BlueField (use
[`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md)
for those). It is also **not** a substitute for the live public
DOCA DPU CLI guide on `docs.nvidia.com`.

The DPU CLI is shipped as a documented operator-command surface on
the BlueField OS image, not as a single binary the user links
against. The skill uses the same `kind: library` three-file shape
as the rest of the bundle so the agent's task-verb contract
(`configure / build / modify / run / test / debug`) is uniform
across libraries, services, and tools — even when individual
verbs collapse to a routing stub.

## When to load this skill

Load this skill when the user is — or the agent needs to — operate
the BlueField DPU from its own on-DPU shell context (typically via
ssh to the BlueField Arm, the `mlnx_snap`-style console, or a
serial console). Concretely:

- Confirming the agent's shell is on the DPU side (BlueField Arm),
  not on the host x86 side, BEFORE running any operator command.
- Walking system / state inspection on a freshly-booted BlueField
  (uptime, image info, DOCA version on the DPU side).
- Reading the networking config the BlueField is currently
  carrying — ports, PF / VF / SF, bridges, OVS bridges /
  interfaces / flows — before any reconfiguration.
- Inspecting (read-only) the firmware-slot state — which BFB image
  is active, which slot is staged — without flipping it.
- Reading the operator-hygiene surface — service / daemon status,
  logs, restart of the documented DPU-side services — at a level
  the public DOCA DPU CLI guide documents.
- Walking the smoke-before-bulk loop BEFORE any state-changing
  networking reconfiguration or before recommending firmware-slot
  modification through [`doca-setup`](../../doca-setup/SKILL.md).

Do **not** load this skill for general DOCA orientation, library
API work, host-side install, kubelet-side service container
deployment, or firmware-slot *modification*. For those, route to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
the matching [`libs/<library>`](../../libs/) skill,
[`doca-setup`](../../doca-setup/SKILL.md), or
[`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what the DPU CLI surface covers (the four
  documented command families — system / state inspect, networking
  config, firmware-slot inspect, operator hygiene), the read-only
  vs state-changing split, the version-availability overlay that
  redirects to [`doca-version`](../../doca-version/SKILL.md), the
  layered error taxonomy (command-not-installed /
  wrong-shell-context (host vs DPU vs container) / permission /
  state-stale / hardware-not-ready / version / cross-cutting), the
  tool's role as the operator-side observability primitive for the
  BlueField, and the safety policy that makes networking
  reconfiguration and firmware-slot modification HIGH-STAKES.
- `TASKS.md` — step-by-step workflows for the in-scope task verbs:
  `configure` (shell-context + up + version smoke), `build` (route
  to BlueField OS / DOCA install), `modify` (refuse for firmware,
  high-stakes for networking), `run` (per-family invocation
  shapes), `test` (smoke-before-bulk loop), `debug` (the layered
  diagnosis ladder), plus a `Deferred task verbs` block routing
  out-of-scope questions and a `Command appendix` that honors the
  bundle's
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  preamble.

The skill assumes a BlueField that has booted at least once on its
documented BlueField OS image, with DOCA installed on the DPU side
per the public DOCA installation guide. If either is in doubt,
route to [`doca-setup`](../../doca-setup/SKILL.md) before running
anything else here.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts bundle.
To keep the boundary clean, it deliberately does not contain — and
pull requests should not add:

- **Verbatim subcommand names, flag strings, or output column
  names.** The public DOCA DPU CLI guide on `docs.nvidia.com`
  (reached through
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
  and the installed `--help` on the user's BlueField are the joint
  source of truth; copying them here pins the skill to one DOCA
  release and silently rots when the DPU CLI surface evolves. The
  skill routes the agent at those sources instead. NVIDIA's actual
  binary naming for the on-DPU operator CLI has varied across
  releases — committing to a specific binary name in this skill
  would mislead users on a different release.
- **Pre-baked example output.** Output is BFB-version-,
  hardware-, and operator-state-specific. A captured example
  pinned to one BlueField in one configuration misleads operators
  on a different platform.
- **Wrappers, parsers, or scripts** in any language that consume
  the DPU CLI output. The output format is documented; users who
  want to script against it should read the live guide and write
  the parser against their installed version per
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md).
- **A `samples/` or `reference/` subtree.** This is a thin loader
  for a documented operator-command surface; substantive material
  lives on the public page and in the installed `--help`.
- **A firmware-modify recipe.** Firmware-slot *modification* is
  owned by [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure).
  This skill ONLY covers firmware-slot *inspect* (read-only).
  Adding a modify recipe here would put a high-stakes state
  change behind the wrong loader.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in
   scope (the user wants to operate a BlueField from its own
   on-DPU shell, not learn DOCA library APIs and not modify
   firmware).
2. **For the four command families, the read-only vs
   state-changing split, version availability, the layered error
   surface, observability, and safety posture, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented invocation shapes and the
   smoke-before-bulk workflow — `configure`, `build`, `modify`,
   `run`, `test`, `debug`, plus the `Command appendix` — see
   [TASKS.md](TASKS.md).**

## Related skills

- [`doca-caps`](../doca-caps/SKILL.md) — the sibling DPU-side
  inspect tool. `doca-caps` is a focused DOCA-libraries
  capability dump (per-device, per-library); this skill is the
  broader BlueField operator CLI surface (system, networking,
  firmware-slot inspect, operator hygiene). Pair them on the DPU
  side — `doca-caps` answers *"what does DOCA see"*; this skill
  answers *"what is the BlueField itself currently doing"*.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, the *I have no install yet* path, AND the
  canonical owner of firmware-slot *modification*. Any question
  this skill receives about *changing* the firmware slot routes
  there.
- [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md)
  — the kubelet-side runtime for DOCA service containers on the
  BlueField. The DPU CLI is the BlueField-side equivalent for
  *non-container* operator operations; the container-side
  operations (kubelet, static-pod manifests, image pull) live in
  the service-container skill. Pair them when the user's
  operator question crosses both surfaces.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. The
  [`## Version compatibility`](CAPABILITIES.md#version-compatibility)
  section in [`CAPABILITIES.md`](CAPABILITIES.md) is a concise
  overlay that redirects here for the body (four-way match, NGC
  semantics, headers-win-over-docs, BFB ↔ host-package alignment).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's detect → prefer → fall back → report contract for
  structured helper tools. The Command appendix in
  [`TASKS.md`](TASKS.md) honors this contract.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — routing to the public DOCA DPU CLI guide and the rest of the
  public DOCA documentation set. This skill does not duplicate
  the URL; it routes through the map.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. DPU CLI failures route into this ladder at the
  runtime and program layers; this skill adds the DPU-side
  operator overlay.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA programming patterns. The DPU CLI sits BELOW
  any DOCA program the user runs on the BlueField; this skill is
  the operator-side surface, the programming guide is the
  developer-side surface.
