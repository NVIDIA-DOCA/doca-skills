# DOCA DPU CLI — Tasks

**Where to start:** The verbs that carry real workflow content are
`## configure` (the load-bearing shell-context + up + version
preamble), `## run` (per-family invocation shapes), `## test`
(smoke-before-bulk loop), and `## debug` (the layered diagnosis
ladder). `## modify` carries a load-bearing routing decision
(networking-change = HIGH-STAKES here, firmware-modify = OUT OF
SCOPE → [`doca-setup`](../../doca-setup/SKILL.md)). `## build` is a
documented routing stub. The `## test` verb is an iterative loop —
each state-changing action on the BlueField re-opens the smoke —
not a one-shot pass; see the eval-loop overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent through
the six task verbs every artifact in this bundle exposes
(`configure / build / modify / run / test / debug`), explicitly
defers task verbs that do not belong here, and ends with the
`Command appendix` honoring the bundle's
[`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
preamble.

For the DOCA DPU CLI, the verbs that carry real workflow content
are `configure`, `modify`, `run`, `test`, and `debug`. `build`
*exists as an anchor* because the agent's task-verb contract is
uniform across libraries, services, and tools — and it carries a
meaningful **routing stub** that names where the user's question
really belongs.

## configure

DOCA DPU CLI's `## configure` is the **load-bearing verb** for
this skill: it is where the shell-context check + the
BlueField-is-up check + the version-state check happen, *before*
any operator subcommand is invoked. Skipping this verb and jumping
to `## run` is the canonical DPU CLI failure mode — it produces
state changes against the wrong shell, against a BlueField that
is not yet up, or against a version state that disagrees with the
host-side DOCA install.

The agent walks the user through three preconditions in order:

1. **Shell-context check (the FIRST check, always).** Confirm the
   agent's prompt is on the BlueField Arm OS, NOT on the host x86
   OS, and NOT inside an unrelated service container. The three
   shells the agent must distinguish are documented in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   Cheap, documented checks the agent can lean on (without
   inventing): `uname -m` (BlueField Arm reports `aarch64`; an
   x86 host reports `x86_64`); `cat /proc/device-tree/model` (on
   the BlueField it returns a documented BlueField model string,
   on the x86 host the path typically does not exist); `hostname`
   matched against the user's known BlueField hostname.
   Wrong-shell-context is [`## debug`](#debug) layer 2 — re-route
   the agent to the correct shell, do NOT keep typing.
2. **BlueField-is-up check via the system / state family.** Once
   the shell is confirmed, walk the system / state family per
   [`## run`](#run) family 1 to confirm uptime, image identity,
   and DOCA version on the DPU side. A BlueField that just
   rebooted may still be mid-init (driver stack not loaded,
   firmware slot mid-flip); the system / state family is the
   documented way to confirm the BlueField is *settled* before
   any state-changing action.
3. **Version-state check.** Quote the DPU-side version against
   the host-side DOCA install per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   and apply the DPU-CLI overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
   The four-way match must hold before any networking-change or
   operator-restart action is defensible; a mismatch is a
   partial-install hazard that
   [`## debug`](#debug) layer 6 routes through.

Cross-cutting configure-time rule: do **not** invent subcommand
names, flag strings, or output columns for any of the checks
above. The cheap shell-context indicators (`uname -m`,
`/proc/device-tree/model`, `hostname`) are POSIX-level and safe
to lean on; everything DPU-CLI-specific must come from the
installed `--help` and the public guide per
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).

## build

The DOCA DPU CLI surface is **shipped pre-installed as part of the
BlueField OS image (BFB)** that NVIDIA publishes. There is no
source tree the external operator is expected to compile, no
build flags, no `meson` or `make` workflow.

Routing for nearby "build" questions:

- *"The subcommand isn't there — do I need to build it?"* → no.
  Route to [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
  for the BFB update path. The fix is to install (or re-install)
  a documented BFB version that ships the subcommand, not to build
  anything locally.
- *"I want to build a tool that **uses** DPU-CLI-style operator
  state from inside my application"* → not a DPU CLI question.
  The DPU CLI is the operator-side wrapper around documented
  BlueField operator surfaces; the programmatic surface is the
  matching DOCA library's API. Route to the matching
  [`libs/<library>`](../../libs/) skill plus
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  for the cross-library pattern.
- *"I want to extend the DPU CLI"* → out of scope for external
  operators; this skill is for consumers of the shipped
  operator-command surface, not contributors to it. The
  [`## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship)
  block in [`SKILL.md`](SKILL.md) explicitly forbids adding a
  build recipe or shipping wrappers around the DPU CLI.

## modify

The DPU CLI's `## modify` carries TWO load-bearing routing
decisions, both of which the agent must surface BEFORE any
state-changing action.

**Decision 1 — networking reconfiguration is HIGH-STAKES, owned
here.** Any command in family 2 (networking config) that *changes*
state — port up / down, PF / VF / SF add / remove, bridge edit,
OVS bridge / interface / flow change — is HIGH-STAKES per
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
The agent's posture:

1. Walk the smoke-before-bulk loop in [`## test`](#test) FIRST.
   The smoke is shell-context + up + version. A networking change
   issued without the smoke is a change against unknown state.
2. Read the current networking state via family 2's read side
   (per [`## run`](#run) family 2) and quote the relevant lines
   back to the user; the change is being proposed AGAINST that
   captured baseline.
3. Surface the impact BEFORE recommending the command: a port
   down may drop in-flight traffic; a VF remove may disconnect a
   guest; an OVS flow edit may break the dataplane; a bridge
   reconfiguration may sever the BlueField's management network
   itself. The agent must name the consumer that will observe
   the change.
4. Recommend the exact subcommand the user should run per the
   public DOCA DPU CLI guide via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
   plus installed `--help` on the user's BlueField. Do NOT
   invent a subcommand name or a flag string.
5. After the change, re-run the read side of family 2 to confirm
   the new state matches the intent. The eval-loop overlay in
   [`## test`](#test) treats every state-changing networking
   action as re-opening the smoke.

**Decision 2 — firmware-slot modification is OUT OF SCOPE here.**
Family 3 in this skill is firmware-slot *inspect* only. Any
question that asks to *change* the firmware slot — flip the
active slot, install a new BFB, rebuild the slot, recover from a
half-installed slot — routes out to
[`doca-setup ## configure`](../../doca-setup/TASKS.md#configure).
That is where the firmware modify workflow lives, with its
documented reset / recovery posture, version-matched packaging,
and host-side tooling (MFT family). This skill's `## modify`
explicitly REFUSES the firmware-modify question and tells the
user where to go.

Routing for other nearby "modify" questions:

- *"The output format is inconvenient — can I change it?"* → no,
  not inside this skill. The documented surface is the surface.
  If the user wants structured output, the right answer is *"check
  whether the installed BFB exposes one per `--help`, otherwise
  write a parser against the documented format on your installed
  version"* — and even the parser is out of scope per
  [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).
- *"Can I patch the DPU CLI to add a flag?"* → out of scope; this
  skill is for consumers of the shipped surface, not contributors
  to it.
- *"I need to change a DOCA service container's config on the
  BlueField"* → not a DPU CLI question. Route to
  [`doca-container-deployment ## modify`](../../services/doca-container-deployment/TASKS.md#modify).

## run

The DPU CLI exposes four documented command families per
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
The flow the agent should walk the user through when the user asks
*"what's going on with this BlueField"*:

1. **Walk the `## configure` preamble first** — shell-context +
   BlueField-up + version-state. None of the runs below is
   meaningful if the agent is on the wrong shell, the BlueField
   is not up, or versions disagree.
2. **Run family 1 (system / state inspect) next.** This is the
   read-only entry point and the only safe first invocation
   beyond the `## configure` preamble. Capture the full output
   verbatim — uptime, image / BFB identity, DOCA version on the
   DPU side, kernel — and use it as the captured baseline the
   rest of the session reasons against.
3. **Run family 2 (networking config) on the READ side** for any
   networking question. Read the ports, the PF / VF / SF
   enumeration, the bridges, and the OVS state per the public
   guide; quote the lines back to the user. Stop here unless the
   user has explicitly committed to a networking *change* — and,
   if they have, route through [`## modify`](#modify) Decision 1
   BEFORE running the write side.
4. **Run family 3 (firmware-slot inspect) for firmware-slot
   questions.** Read which BFB / slot is active and which is
   staged. Do NOT proceed to modify here; route to
   [`## modify`](#modify) Decision 2 → [`doca-setup`](../../doca-setup/SKILL.md)
   if the user wants to flip the slot.
5. **Run family 4 (operator hygiene) for daemon / service
   questions.** Read status and logs FIRST; reach for a restart
   only after [`## test`](#test) confirms the daemon is stuck
   and the user has accepted the consumer impact per
   [`## modify`](#modify) Decision 1's general high-stakes
   posture.
6. **For the exact subcommand inventory, flag names, and output
   column names** read `--help` on the installed BlueField and
   the public DOCA DPU CLI guide via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
   Do **not** invent any of these from generic CLI knowledge —
   the public guide and installed `--help` are the joint source
   of truth, see
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).

When recording the run for downstream consumers, write down: the
DOCA version (per [`doca-version`](../../doca-version/SKILL.md)),
the BFB version observed on the BlueField, the shell context
confirmed (DPU shell), the exact command line used, and the full
unredacted output. The downstream [`## test`](#test) and
[`## debug`](#debug) workflows depend on those five fields.

## test

DOCA DPU CLI's `## test` is **the canonical smoke-before-bulk
loop** for any operator action on the BlueField. *"Test"* in this
skill means *"confirm the BlueField is in a state where the next
operator action is defensible"*, not *"unit-test the DPU CLI"*.

**`## test` is an iterative loop, not a one-shot pass.** Every
state-changing action — a networking change, a daemon restart, a
firmware-slot modify done by [`doca-setup`](../../doca-setup/SKILL.md),
a BlueField reboot — re-opens the smoke. Treating it as a
one-shot pass is the failure mode this loop replaces.

The smoke-before-bulk shape:

1. **Confirm shell context.** Walk
   [`## configure`](#configure) step 1. Cheap, documented checks
   (`uname -m`, `cat /proc/device-tree/model`, `hostname`). The
   prompt MUST be on the BlueField Arm OS. A `x86_64` `uname -m`
   or a missing `/proc/device-tree/model` means the agent is on
   the host shell; re-route, do NOT keep typing.
2. **Confirm the BlueField is up.** Walk
   [`## run`](#run) family 1 — quote uptime, image identity,
   DOCA version on the DPU side. A BlueField mid-boot, mid-mode-
   flip, or in a recovery posture is not in a state where a
   networking change or a daemon restart is defensible; route to
   [`## debug`](#debug) layer 5 (hardware-not-ready) and wait or
   route to [`doca-setup`](../../doca-setup/SKILL.md) for
   recovery.
3. **Confirm versions agree.** Quote the DPU-side version
   against the host-side DOCA install per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   and apply the DPU-CLI overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
   A mismatch is a partial-install hazard the agent must surface
   per [`## debug`](#debug) layer 6.
4. **Only after steps 1-3 read clean** may the agent proceed to
   the family-specific read or write the user actually asked for.
   If any of steps 1-3 surfaces a finding, walk the matching
   debug layer — do not proceed to the user-facing action.

Eval-loop overlay (rows apply to every BlueField, not just one):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 2 → 3 → ## debug | Any precondition fails; walk the debug ladder, then re-run steps 1-3 | [`## debug`](#debug) layers 1-6 |
| 1..3 → networking change → 1 | After any networking change in family 2, re-run the smoke; the change may have affected reachability of the BlueField itself | [`## modify`](#modify) Decision 1 |
| 1..3 → daemon restart → 1 | After any operator-hygiene restart in family 4, re-run the smoke; daemon state and version visibility may have changed | [`## run`](#run) family 4 |
| 1..3 → firmware-modify-by-doca-setup → 1 | After a firmware-slot modify done by [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure) (typically with a reboot), re-run the smoke; the BFB version observed in family 1 changed | [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure) |
| 1..3 → BlueField reboot → 1 | After any reboot, re-run the smoke; the family-1 view is the documented re-confirmation surface | [`## run`](#run) family 1 |
| 1..3 (clean) → save → debug session | Once clean, the captured output is saved and consumed by the cross-cutting debug ladder | [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) |

The agent's rule: every state-changing action on the BlueField
re-opens the smoke. Saving a stale family-1 snapshot from before
a mutation is exactly the failure mode this loop is here to
prevent.

This skill does **not** ship a "test fixture" or pre-recorded
expected output. The expected output is BFB-, hardware-, and
operator-state-specific; pinning one would mislead operators on a
different platform / version. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When a DPU CLI command fails to run, produces stale or unexpected
output, or disagrees with what [`doca-caps`](../doca-caps/SKILL.md)
or the host-side DOCA install reports, walk the
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
layers in order. The shape of the diagnosis:

1. **Command-not-installed.** The subcommand the user expects
   does not exist on the installed BlueField OS image. Confirm
   the BFB version on the BlueField (system / state family per
   [`## run`](#run) family 1) and compare against the public
   DOCA DPU CLI guide on `docs.nvidia.com` for the matching
   release via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
   If the user is on a BFB version that pre- / post-dates the
   subcommand, route to [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
   for a BFB update. Inventing a different subcommand name from
   a different release is NOT on the table.
2. **Wrong-shell-context.** The subcommand exists in the user's
   mental model but the agent is typing it into the wrong shell
   — host x86 OS, or inside a service container, instead of the
   BlueField Arm OS. Re-run the shell-context check in
   [`## configure`](#configure) step 1; re-route to the correct
   shell. Do NOT keep typing on the wrong shell. This is the
   most common silent-fail mode for DPU-CLI sessions and is what
   the FIRST smoke check in [`## test`](#test) is designed to
   catch.
3. **Permission layer.** The subcommand runs but reports it
   cannot read or change state because of insufficient
   privileges. The tool's own message is ground truth; re-run
   with the privileges the public DOCA DPU CLI guide names
   (typically `sudo` on the BlueField Arm for networking-change
   or operator-restart families). Bypassing the privilege check
   is not on the table.
4. **State-stale layer.** The subcommand prints state that does
   not match what the user just observed elsewhere. Wait the
   documented settle window (driver reload, OVS database sync,
   BlueField mode change), re-run, and quote both views to the
   user so they can see the staleness as evidence rather than
   guessing.
5. **Hardware-not-ready layer.** The subcommand runs on the
   right shell, with the right privileges, but the BlueField
   itself is not in a state that lets it answer (mid-boot, mlx5
   driver stack not loaded, firmware slot mid-flip, recovery
   mode). The DPU CLI's own message plus `dmesg` on the
   BlueField are ground truth; route to
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   driver / hardware layer.
6. **Version layer.** The subcommand runs but its view
   disagrees with the host-side DOCA install or with
   [`doca-caps`](../doca-caps/SKILL.md) on the DPU side. Walk
   the four-way match per
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 and apply the DPU-CLI overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
   When the BFB and the host-side DOCA install came from
   different trains, the fix is a consistent reinstall, not a
   subcommand tweak.
7. **Cross-cutting layer.** Layers 1-6 are clean and the user's
   symptom persists. The cause is below the DPU CLI surface —
   driver, firmware, mode, or hardware path on the BlueField; or,
   for a networking symptom, on the wire / on the OVS dataplane.
   Escalate to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   with the captured DPU CLI output as evidence. Looping on DPU
   CLI subcommands at this layer is the wrong move.

In every case: **quote what the DPU CLI said.** Do not paraphrase
state output, do not reorder fields, do not "summarize" into
prose. The whole point of inspecting the BlueField before touching
it is to break the agent out of the
inference-from-host-side-state trap.

## Deferred task verbs

The four verbs below are not DOCA DPU CLI work and should be
routed out before the agent does any of them under this skill's
name.

- **install (host-side DOCA)** ⇒ [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
  (and [`## no-install`](../../doca-setup/TASKS.md#no-install) for
  the public NGC DOCA container path). The DPU CLI is shipped by
  the BlueField OS image; the host-side DOCA install is owned by
  [`doca-setup`](../../doca-setup/SKILL.md).
- **firmware-slot MODIFICATION (flip slot, install BFB, rebuild
  slot)** ⇒ [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure).
  This skill ONLY covers firmware-slot *inspect*; modification
  has its own documented reset / recovery posture and host-side
  tooling, owned there.
- **DOCA service container operations on the BlueField** (deploy,
  update, kubelet-side ops, static-pod manifests, image pull) ⇒
  [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md).
  The DPU CLI is the non-container operator surface; the
  container surface lives in the service-container skill. Pair
  them when the operator question crosses both.
- **DOCA-library-internal capability or state check** (per-device,
  per-library capability flags, library-internal lifecycle
  questions) ⇒ [`doca-caps`](../doca-caps/SKILL.md) on the DPU
  side for the documented per-device per-library surface, or the
  matching [`libs/<library>`](../../libs/) skill for
  library-internal state. The DPU CLI does not duplicate those
  surfaces.

## Command appendix

DOCA-DPU-CLI-specific invocations the verbs above reach for.
Every row is a CLASS — the agent must not invent subcommand
names, flag strings, or output columns beyond `--help` on the
installed BlueField. The four-family symmetry (system /
networking / firmware-inspect / operator-hygiene) plus the
shell-context preamble is the load-bearing piece.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; `doca-capability-snapshot` for per-device capability flags;
   `version-matrix.json` for *"available since"* lookups).
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

| Purpose (class) | Invocation (shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Confirm shell context (FIRST check) | POSIX-level checks — `uname -m` (BlueField Arm = `aarch64`), `cat /proc/device-tree/model` (BlueField returns its model string; absent on x86), `hostname` matched against the known BlueField hostname | [`## configure`](#configure) step 1 + [`## test`](#test) step 1 | `uname -m` reports `aarch64`, `/proc/device-tree/model` exists and matches the BlueField model, `hostname` matches the user's known BlueField hostname; the prompt is on the BlueField Arm OS. |
| Discover available subcommands and flags on this BFB | The DPU CLI's own `--help` (subcommand-and-flag inventory comes from here, not from prose). The exact binary name is documented per the public DOCA DPU CLI guide on the user's installed BFB; the skill deliberately does not pin it | [`## run`](#run) step 6 | Prints the documented inventory; the agent uses this as the only source of truth for subcommand and flag names on this BFB. |
| Family 1 — system / state inspect | The DPU CLI's documented system / state subcommand(s) — uptime, image / BFB identity, DOCA version on the DPU side, kernel | [`## run`](#run) family 1 + [`## test`](#test) step 2 | Exit 0; the BlueField reports an uptime, an image / BFB identity, and a DOCA version consistent with the host-side install per [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility). |
| Family 2 — networking config (read side) | The DPU CLI's documented enumeration subcommand(s) for ports, PF / VF / SF, bridges, and OVS bridges / interfaces / flows | [`## run`](#run) family 2 (read) | Exit 0; the printed networking state matches what the operator expects from prior provisioning; any divergence is the captured baseline the proposed change is evaluated against. |
| Family 2 — networking config (write side, HIGH-STAKES) | The DPU CLI's documented change subcommand for the chosen networking object (port up / down, PF / VF / SF add / remove, bridge edit, OVS flow change), preceded by the smoke in [`## test`](#test) and the captured read-side baseline | [`## modify`](#modify) Decision 1 (HIGH-STAKES) | Post-change re-run of family 2's read side reports the intended new state; the BlueField remains reachable on its documented management network; named consumers observe the change in line with the impact the agent surfaced. |
| Family 3 — firmware-slot inspect (NOT modify) | The DPU CLI's documented firmware-slot inspect subcommand — read the active slot, the staged slot, and the BFB version each holds | [`## run`](#run) family 3 | Exit 0; the active slot matches the BFB the operator expects, with the staged slot empty or reporting a known version; modification goes to [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure), NOT here. |
| Family 4 — operator hygiene (status, logs) | The DPU CLI's documented status / log subcommand(s) for the DPU-side daemons the public guide lists as manageable from this surface | [`## run`](#run) family 4 | Exit 0; each documented daemon reports a steady-state status and the log surface emits within the documented retention window. |
| Family 4 — operator hygiene (restart, state-changing) | The DPU CLI's documented restart subcommand for a single daemon, preceded by the smoke in [`## test`](#test) and an explicit named-consumer impact statement | [`## modify`](#modify) Decision 1 (high-stakes posture, bounded) | The post-restart status surface reports the daemon back in steady state, consumers observe the bounce as the agent surfaced, and the smoke re-runs clean. |
| Save a DPU-state snapshot for debug | Redirect family 1 + family 2 read + family 3 + family 4 status output to a file (e.g. `> dpu-state.txt`) plus the version-state quote captured at configure time | [`## test`](#test) save step + [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) | The saved file is consumed by the cross-cutting debug ladder as the DPU-side operator-state half of the evidence pair. |
| Re-confirm after a state change | Any of the read-side rows above, re-run after a networking change, daemon restart, firmware modify done by [`doca-setup`](../../doca-setup/SKILL.md), or BlueField reboot | [`## test`](#test) eval loop | The post-change output reflects the change; a stale captured baseline is the failure mode. |

Three cross-cutting rules for this appendix:

- **Never invent a subcommand, flag, output column, or binary
  name.** NVIDIA's binary naming for the on-DPU operator CLI has
  varied across BlueField OS / DOCA releases; `--help` on the
  installed BlueField plus the public DOCA DPU CLI guide via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
  are the joint contract for the user's actual BFB.
  Prose-derived names from a different release are the most
  common hallucination failure for this skill.
- **State-changing operations re-open the smoke.** Any family-2
  write, any family-4 restart, any firmware modify done out via
  [`doca-setup`](../../doca-setup/SKILL.md), and any reboot are
  not retryable in place; after each, the agent re-runs the
  three-step smoke per [`## test`](#test).
- **Cross-link instead of duplicate.** Cross-cutting host-side
  commands (`pkg-config --modversion`, `dmesg`, `mlxconfig -d
  <bdf> q`, `lspci | grep Mellanox`) live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  the env-side install / hugepage / driver prep lives in
  [`doca-setup TASKS.md ## Command appendix`](../../doca-setup/TASKS.md#command-appendix);
  the version-handling commands live in
  [`doca-version TASKS.md ## Command appendix`](../../doca-version/TASKS.md#command-appendix);
  this appendix names only DPU-CLI-specific invocations on top.

## Cross-cutting

A few rules that apply across every verb in this file, restated
here so they are visible at the point of action and not buried in
[`SKILL.md`](SKILL.md):

- The **public DOCA DPU CLI guide** plus the installed `--help`
  on the user's BlueField are the joint source of truth. When
  they disagree (e.g. a subcommand landed in a release this
  skill was not written against), the *installed* `--help` wins
  for the user's actual run.
- **Shell context is the FIRST check.** Every other DPU CLI step
  is meaningless on the wrong shell; the smoke-before-bulk loop
  in [`## test`](#test) starts here, always.
- **Read-only first; networking-change HIGH-STAKES; firmware
  modification OUT OF SCOPE.** The agent must name which class
  an operation belongs to before recommending it, and must gate
  every state-changing operation on a clean smoke per
  [`## test`](#test).
- **Quote, do not paraphrase.** The DPU CLI's state output is
  the artifact downstream debug consumes; reformatting it loses
  fidelity that the rest of the bundle's procedures depend on.
- This skill **assumes a BlueField that has booted at least once
  on its documented BFB image**, with DOCA installed on the DPU
  side per the public install guide. If either is in doubt,
  route to [`doca-setup`](../../doca-setup/SKILL.md) before
  running anything else here. For DOCA-libraries capability
  questions on the DPU side, route to
  [`doca-caps`](../doca-caps/SKILL.md) — that is the sibling
  inspect tool, not this one.
