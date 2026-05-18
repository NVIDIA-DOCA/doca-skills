# DOCA App Shield workflows

**Where to start:** The verbs run `configure → build → modify →
run → test → debug`. Skip ahead only when the user is already past a
verb. The `## test` verb is an iterative loop (known-target smoke →
capability re-check → symbol-map re-check → broader enumerator → loop
back if a host kernel upgrade lands), not a one-shot pass — see the
eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the App Shield capability surface, the
DPU-side / host-side asymmetry, the object family, the symbol-map
prerequisite, the capability-query rule, the error taxonomy
(including the `NOT_FOUND`-is-normal rule), observability, and
safety policy, see [CAPABILITIES.md](CAPABILITIES.md). For where to
find docs, the installed DOCA layout, or release notes, route
through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through the
steps in order, verifying preconditions before recommending the next
call.

## configure

Goal: stand up a `doca_apsh_system` on the DPU side, with the host
PCIe path, host OS type, and host kernel symbol map all in a state
where an enumerator against the host is meaningful.

Steps the agent should walk the user through:

1. **Confirm the side: this code runs on the DPU.** Before any code
   change, surface the DPU-side / host-side asymmetry per the
   side-split table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   `doca_apsh_*` calls run on the BlueField Arm side; the host runs
   nothing for App Shield. An agent that walks the user toward
   host-side install is wrong for every release and the user
   discovers it only after wasted effort.
2. **Verify the DPU-side prerequisites.** Walk the prerequisite
   matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy):
   (a) the DPU-side process has the privilege the install profile
   expects (typically sudo on the DPU side); (b) a
   host-OS-version-matching kernel symbol map is present on the
   DPU side; (c) the DPU can enumerate the BlueField PCIe path that
   reaches the host. If any of those is missing, route to
   [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure)
   for the env-side path, or to the public App Shield guide via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
   for the symbol-map artifact's expected shape and freshness.
3. **Confirm the installed DOCA version.** Use the procedure in
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
   Quote the version observed (`pkg-config --modversion doca-apsh`,
   then `doca_caps --version`); do not assume "latest". The
   four-way match rule lives in
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility);
   if the observed sources disagree, route there before any App
   Shield diagnosis.
4. **Discover the device + host-OS capability surface for App
   Shield.** Run `doca_caps --list-devs` (per
   [`doca-caps`](../../tools/doca-caps/SKILL.md)) on the DPU side
   to confirm the device the program will open, then run the
   matching `doca_apsh_cap_*` queries against the candidate
   `doca_devinfo` to discover which introspection targets are
   actually supported on this host OS / kernel version. Quote the
   queried values back to the user; do not assume from a prior
   host. The capability matrix to compare against lives in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
5. **Confirm App Shield is the right library for this workload.**
   Walk the path-selection rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes):
   if the workload is bulk host ↔ DPU memory movement, route to
   [`doca-dma`](../doca-dma/SKILL.md); if it is packet I/O at line
   rate, route via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
   to the network-side DOCA libraries; if it is a real-time event
   stream, recommend a host-resident solution coordinated over
   [`doca-comch`](../doca-comch/SKILL.md). Picking App Shield *for*
   the user when the path-selection rule rules it out is a wrong
   answer regardless of how cleanly the rest of the configure step
   goes.
6. **Configure the `doca_apsh_system` instance.** Mandatory before
   `doca_ctx_start()`: set the host PCIe path, set the host OS
   type, load the host kernel symbol map into the system context.
   These mirror the configuration shape in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   Symbol-map load happens at configure time on the DPU side, not
   on the host side.
7. **Sanity check before any enumerator call.** Confirm with the
   user: which host the DPU is configured to introspect, which
   symbol map file is loaded, and which OS type the user told App
   Shield the host is running. If any of those are unclear, stop
   and ask — do not invent.

If any step fails with a `DOCA_ERROR_*`, route through the error
taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying. In particular, `DOCA_ERROR_NOT_FOUND` from a later
enumerator is *not* a configure-time failure; it is a normal
per-snapshot answer that the requested target does not exist on the
host right now.

## build

Goal: produce a DPU-side binary that links DOCA App Shield against
the user's installed DOCA, using the canonical cross-library build
pattern.

The build pattern for any DOCA C/C++ consumer is **identical**
across libraries — `pkg-config` for include + link flags, meson or
CMake as the build system — and is fully documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the App Shield-specific overlay:

| Slot | Value for App Shield | Why it matters |
| --- | --- | --- |
| `pkg-config` module name | `doca-apsh` | The library's `.pc` file installed by the DOCA host packages. Wrong module name = `pkg-config: Package 'doca-apsh' was not found` |
| Build host | The BlueField Arm side (the DPU). The binary runs on the DPU; building it on the DPU side keeps include / link / ABI in one place | Building on the x86 host and shipping the binary to the DPU is possible but adds a cross-build step that obscures install-mismatch problems |
| Required runtime libs | `libdoca-common`, `libdoca-apsh`, plus whatever `pkg-config --libs doca-apsh` resolves transitively | App Shield depends on Core; the resolver pulls in the right transitive set |
| Header check | `doca_apsh.h` resolvable under `/opt/mellanox/doca/infrastructure/include/` on the DPU side | If `pkg-config --cflags doca-apsh` resolves but the include is missing, the install is partial — route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| Minimum required DOCA version | Query with `pkg-config --modversion doca-apsh`; never hardcode in build files | Cross-version build/runtime mixing breaks per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) |

For non-C consumers (Rust, Go, Python), the link surface is the
same `*.so` files; the FFI wrapper layer is the language-specific
binding and is out of scope for this skill — but the slots above
are still the load-bearing inputs the wrapper needs, and the
DPU-side build host rule still applies.

## modify

Goal: take a shipped DOCA App Shield sample as the verified
starting point and apply a **minimum-diff modification** to express
the user's intent.

The universal modify-a-shipped-sample workflow lives in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify).
Use it as-is. The App Shield-specific overlay is the *modify-from-
sample schema fill* — the slots the agent must elicit from the user
before recommending any code-level edit:

| Slot | What the agent asks the user | App Shield-specific consideration |
| --- | --- | --- |
| 1. Starting sample | Which sample under `/opt/mellanox/doca/samples/doca_apsh/`? | Pick the closest in *enumerator type* (process / module / library / thread) and *host OS* (Linux / Windows / …) to the user's intent. A smaller diff is always safer than a re-architecture |
| 2. Introspection target | Which targets does the user want to enumerate, and which snapshot cadence? | Re-validate against `doca_apsh_cap_*` per [`## configure`](#configure) step 4; an enumerator that works on one host kernel may return `NOT_SUPPORTED` on another |
| 3. Symbol-map handling | Is the sample's loaded symbol map the right one for the host being introspected? Is it the right freshness for the host's current kernel? | Refer to the symbol-map row in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy); a stale map is the most common silent-failure cause after a host kernel upgrade |
| 4. NOT_FOUND handling | Does the user-side code treat `DOCA_ERROR_NOT_FOUND` from an enumerator as a bug, or as a normal "absent right now" answer? | Per [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy), the App Shield-correct behavior is to treat `NOT_FOUND` as data; if the sample retries on `NOT_FOUND`, that is a sample bug that needs to be edited out before the modify lands |
| 5. Build manifest | Keep the sample's existing `meson.build` (which already wires `pkg-config doca-apsh`)? | Yes. Do not switch to a hand-rolled Makefile for *"simplicity"* — it removes the version-check rail |

The agent emits an *intent description + the filled slots*; the
*actual* unified diff against the sample source is produced by the
modify-from-sample renderer (deferred to a future round, per
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify)).
Until the renderer ships, the agent must walk the user through the
diff line-by-line against the sample source they read on disk, and
have the user paste back the result for validation.

## run

Goal: actually execute the built DPU-side binary against the user's
installed DOCA on the BlueField Arm side, with the host PCIe path
reachable, the symbol map loaded, and the privilege state correct.

Steps the agent should walk the user through:

1. **Run on the DPU side, with the privileges App Shield expects.**
   App Shield code does not run on the host. Typically the DPU-side
   binary runs with sudo (or as a user in the privileged group the
   install profile defines). Per the prerequisite matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   privilege mismatches surface as `DOCA_ERROR_NOT_PERMITTED` on
   the first `doca_apsh_system_create` call.
2. **Confirm the active `doca_devinfo` and the host PCIe path.** A
   binary that links cleanly but never enumerates anything is most
   often opening the wrong PCIe path. Re-quote the output of
   `doca_caps --list-devs`
   ([`doca-caps`](../../tools/doca-caps/SKILL.md)) on the DPU side
   and confirm the path the binary opens is the same one that
   reaches the host being introspected.
3. **Confirm the loaded symbol map matches the host kernel.** Ask
   the user to confirm the symbol map file the binary loads is the
   one baked for the host's *current* kernel version, not a
   previous one. After any host kernel upgrade, treat this as the
   first hypothesis for failures.
4. **Capture the structured log.** Set `DOCA_LOG_LEVEL=trace` for
   the first run (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability)).
   This is the cheapest way to make the lifecycle and per-enumerator
   call visible on first failure.
5. **Enumerate one known-running target first.** Before any broad
   scan, ask App Shield for one target the user can independently
   confirm is on the host (e.g. `init` / `systemd` by name on a
   Linux host). A successful enumerate-one confirms the privilege +
   symbol-map + PCIe path are all correct; only then expand to a
   broad scan.

## test

Goal: prove the configured `doca_apsh_system` can actually
introspect the host correctly, and that the symbol map + privilege
state + capability set were sized right for the user's intended
workload.

This is **a loop, not a one-shot pass.** Each iteration narrows
either the privilege state, the symbol-map freshness, the
introspection target, or the enumerator pattern. The loop terminates
when either (a) the user's intended snapshot cadence runs end-to-end
with the expected enumerated objects, or (b) the agent has narrowed
the failure cause to a layer outside App Shield itself (driver /
firmware / host kernel changed / symbol map stale) and escalated to
the matching skill.

Iteration shape:

1. **DPU-side smoke first.** Confirm the binary runs on the DPU
   side with the expected privileges; `doca_apsh_system_create`
   succeeds without `DOCA_ERROR_NOT_PERMITTED`. If it fails, do
   not advance — re-walk the privilege + symbol-map matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
2. **Capability re-check.** Re-run the `doca_apsh_cap_*` queries
   against the active `doca_devinfo`. If a target the user wants
   returns false, that *is* the answer for this host OS / kernel
   version; update the user's intent or update the host install
   before adding code.
3. **Known-target smoke.** Enumerate one target the user can
   independently confirm is on the host (`init` / `systemd` /
   another process the user can `ps` for). If the smoke returns
   the expected handle, the privilege + symbol-map + PCIe path are
   all correct; any later broader scan failure narrows cleanly to
   the per-target axis. Skipping this step is the most common
   reason *"App Shield enumeration returns empty / wrong and we
   don't know why"*.
4. **NOT_FOUND interpretation pass.** Ask for a target you *know*
   does not exist on the host right now. The enumerator MUST
   return `DOCA_ERROR_NOT_FOUND`. Confirm the user-side code
   treats this as data, not as a failure — per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy),
   misinterpreting `NOT_FOUND` is the single most common first-app
   bug.
5. **Broader scan.** Once smokes are green, expand to the user's
   intended scan: all processes, all kernel modules, the per-process
   library / thread list for a sample of processes. Watch for
   `DOCA_ERROR_NOT_SUPPORTED` (a capability boundary was crossed —
   re-narrow to the cap-query axis).
6. **Host kernel upgrade re-test.** If at any point the host is
   upgraded (kernel patch, dist upgrade), re-run iterations 1-5
   AFTER refreshing the symbol map. A passing run before the
   upgrade does not generalize across host kernel versions.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| `DOCA_ERROR_NOT_PERMITTED` on `doca_apsh_system_create` | The DPU-side privilege state or symbol-map load is wrong | Re-walk the prerequisite matrix in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy); do not advance to enumerators |
| `DOCA_ERROR_NOT_FOUND` on a target the user expected | Either the target really is absent right now (normal), or the symbol map is mismatched and App Shield is walking the wrong kernel layout | Cross-check by enumerating a known-running target (e.g. `init` / `systemd`); if THAT returns `NOT_FOUND` too, the symbol map is the suspect, not the per-target query |
| `DOCA_ERROR_NOT_SUPPORTED` on an enumerator | The cap query at configure time was assumed; the device + host-OS reality differs | Re-run `doca_apsh_cap_*` against the *active* `doca_devinfo`; the wrong-host or wrong-OS case is the most common cause |
| Enumerator returns an empty list after smoke was green | The lifecycle or the symbol map regressed between smoke and broad scan; or a host kernel upgrade landed between runs | Wire the lifecycle trace per [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug); confirm the symbol map's host-OS-version match against the current host kernel |
| Same code passes on host A, returns `NOT_FOUND` for known-running targets on host B | Symbol map is for host A's kernel; host B has a different kernel version | Refresh / regenerate the symbol map for host B's kernel; do not edit the App Shield code |

Loop termination: stop iterating once two consecutive iterations of
the same kind don't change anything — that means the cause is below
App Shield. Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) with
the captured layer-1-through-5 evidence.

## debug

Goal: when a DOCA App Shield call returns a `DOCA_ERROR_*` (or an
enumerator surfaces an unexpected snapshot), narrow the cause to a
specific layer and act on it.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
Walk through it in order — install → version → build → link →
runtime → program → driver — *before* recommending App Shield-
specific fixes. This skill's overlay names the App Shield-specific
manifestation at layers 5 (runtime) and 6 (program):

**Layer 5 (runtime) — App Shield overlay.**

- Walk the side rule: is the failing binary really running on the
  DPU side? Host-side execution of `doca_apsh_*` does not exist —
  if the user reports running it on the host, that is the bug.
- Walk the privilege state: is the DPU-side process running with
  the expected privilege level (typically sudo)? A failure on the
  first `doca_apsh_system_create` with `DOCA_ERROR_NOT_PERMITTED`
  is the canonical privilege-gap symptom.
- Walk the symbol-map freshness: was the host kernel upgraded
  since the loaded symbol map was generated? A passing run
  yesterday + a failing run today + an unchanged App Shield binary
  is almost always a host kernel upgrade that invalidated the map.

**Layer 6 (program) — App Shield overlay.**

- The `NOT_FOUND`-is-normal trap: an App Shield program that
  retries on `DOCA_ERROR_NOT_FOUND` is misinterpreting the API
  surface. The per-target enumerator's `NOT_FOUND` return means
  *"the target does not exist on the host right now"*, not *"the
  call failed; retry"*. Walk the matrix in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  against the user's program flow.
- Lifecycle order: configure (PCIe path + OS type + symbol map) →
  start → enumerate → stop → destroy. Out-of-order returns
  `DOCA_ERROR_BAD_STATE`. The most common case is enumerating
  before the `doca_apsh_system` reached `RUNNING`.
- Capability assumption: an enumerator that returns
  `DOCA_ERROR_NOT_SUPPORTED` after a smoke ran is not a hardware
  failure; it is the cap-query result the user did not check at
  configure time. Re-read the matching `doca_apsh_cap_*` against
  the active `doca_devinfo`.

Once the layer is identified, route to the matching debug verb on
the matching skill: install / build / link / driver to
[`doca-setup ## debug`](../../doca-setup/TASKS.md#debug); version
to [`doca-version ## debug`](../../doca-version/TASKS.md#debug);
cross-cutting runtime to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug);
program-layer Core-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug).

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them as follows so
the agent does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring — defer to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the install-tree
  layout in
  [doca-public-knowledge-map ## Layout of an installed DOCA package](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed on the DPU side.
- **symbol-map authoring.** Generating or packaging a host kernel
  symbol map for a given host OS / kernel version — out of scope
  for this skill. Route to the public DOCA App Shield guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **deploy.** Deploying App Shield-using DPU-side applications at
  scale across many BlueField + host pairs, Kubernetes operator
  workflows for security monitoring — out of scope for Phase 1 and
  reserved for a future platform skill.
- **firmware burn / reset.** App Shield depends on the underlying
  ConnectX firmware and BlueField BFB; if the debug ladder lands
  on a driver-layer issue (`DOCA_ERROR_DRIVER` from a
  `doca_apsh_system_create` call, repeated mlx5 errors in
  `dmesg`), the fix is via the env-side skill:
  [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) layer 5,
  then upstream MLNX OFED / firmware documentation reachable
  through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Command appendix

Every command below is **cross-cutting on DOCA App Shield** — it
answers a recurring class of question that comes up in the verbs
above. The agent should treat the *class* as load-bearing; the
worked example is a single instance. Run-as user is the
unprivileged user unless noted; sudo is called out per row.

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

| Command (worked example) | Owning step | Class of question it answers | What healthy output looks like |
| --- | --- | --- | --- |
| `pkg-config --modversion doca-apsh` (DPU side) | `## configure` step 3; `## build` slot 1 | What is the build-time DOCA App Shield version on the DPU? | A semver string matching `doca_caps --version`. Disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2) |
| `pkg-config --cflags --libs doca-apsh` (DPU side) | `## build` | What include + link flags does the linker need? | Includes resolve under `/opt/mellanox/doca/infrastructure/include/`; libs include `-ldoca-apsh -ldoca-common` |
| `doca_caps --list-devs` (DPU side) | `## configure` step 4; `## run` step 2 | Which devices + PCIe paths on the DPU can be used to introspect the host? | One row per visible device with PCIe address and capability flags; the row whose path reaches the host being introspected is the one to configure |
| `doca_caps --version` (DPU side) | `## configure` step 3; `## test` step 2 | What is the *runtime* DOCA version on the DPU? | A semver string matching `pkg-config --modversion doca-apsh` |
| `ls /opt/mellanox/doca/samples/doca_apsh/` (DPU side) | `## modify` slot 1 | Which App Shield samples ship in this install, and which is the closest starting point? | A list of sample directories named after the enumerator pattern + host OS they demonstrate |
| `id` (DPU side) | `## configure` step 2; `## run` step 1 | Is the App Shield process running with the privilege the install profile expects? | The user is root or in the privileged group; otherwise `doca_apsh_system_create` will return `DOCA_ERROR_NOT_PERMITTED` |
| `cat /opt/mellanox/doca/applications/VERSION` (DPU side) | `## configure` step 3; `## debug` layer 1 | What does the install tree itself claim its version is? | A semver string matching the other two version sources |
| `dmesg | tail -n 40` (DPU side, sudo) | `## debug` layer 7 | What did the DPU kernel / driver log around the last App Shield call? | Empty or recent benign messages. Repeated mlx5 / PCIe errors → driver-layer bug; route to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) |
| `DOCA_LOG_LEVEL=trace ./<binary>` (DPU side) | `## run` step 4 | What did the structured DOCA logger emit for the first failing call? | A trace-level line on every lifecycle transition and every enumerator call. Silence after enumerate = context not in RUNNING; per-call `NOT_FOUND` traces = normal "absent on host right now" answers |

For commands shared across libraries (`pkg-config --modversion`,
`doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the App Shield-specific rows on top.
