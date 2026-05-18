# DOCA BlueMan Service — Tasks

**Where to start:** The order is `configure → build → modify → run →
test → debug`. The `## test` verb is an iterative loop, not a
one-shot pass — see the eval-loop overlay in `## test` below. For
BlueMan, `build` and `modify` are about *deployment configuration*
(container runtime invocation, config-file fragments, RBAC role
assignment) and *adapting a documented recipe to the user's
environment*, not about compiling source.

These verbs cover the in-scope BlueMan operational workflows for an
external operator deploying and using BlueMan. Every step assumes
the operator has consulted the live public BlueMan guide on
`docs.nvidia.com` and is using it as the authoritative reference;
this file prescribes the *order* and *what to look up where*, not a
copy-paste runbook.

## configure

Preparing the BlueField target, picking the four-axis configuration,
and laying out the deployment.

1. **Confirm the env is healthy first.** This skill expects DOCA to
   be installed on the BlueField target and a container runtime to
   be available. If that has not been verified, run
   [`doca-setup ## test`](../../doca-setup/TASKS.md#test) first. If
   the user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path.
2. **Confirm BlueMan is the right surface.** Walk the path-selection
   rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   If the user actually wants programmatic / scripted configuration
   changes (CI / CD, lights-out automation), stop and route to
   [`doca-dms`](../doca-dms/SKILL.md). If the user wants continuous
   streaming telemetry, stop and route via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
   to DTS. BlueMan is for human operators with a browser doing
   read-mostly monitoring; anything else is the wrong surface.
3. **Walk the canonical container deployment pattern.** Open the
   DOCA Container Deployment Guide via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
   and confirm the user's container runtime, host-OS permission
   model, and image-pull path against it. The BlueMan-specific
   layering (image name, exposed port, mount points) is documented
   in the public BlueMan guide on top of that pattern.
4. **Plan the four config axes.** Per the schema in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   commit to a decision on each axis BEFORE bringing the container
   up:
   - **Listen interface + port** — which BlueField NIC / IP the
     dashboard binds to (OOB management interface is the common
     production choice; in-band is possible but read the network-
     exposure note in
     [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
     first).
   - **TLS** — production should always use HTTPS; lab can run
     plain HTTP per the public guide's documented allowance.
     Plain HTTP exposed on a shared network is the documented
     network-exposure failure mode.
   - **Authentication backend** — per the public BlueMan guide
     (basic / local accounts, LDAP, or SSO). Read the *Security
     Best Practices* subsection before committing.
   - **RBAC / role assignment** — pick the documented role for
     each operator account; least-privilege is the safe default.
5. **Plan the operator account list.** Before deployment, write
   down which operator(s) will receive a dashboard account and
   which documented role each gets. A deployment that lands without
   a planned account list invites the failure mode "the dashboard
   is up but nobody can log in" (no accounts) or "everyone is an
   admin" (no role discipline).

## build

BlueMan is a service, not a library. There is no BlueMan
*application* artifact for the operator to build — the dashboard
ships inside the documented container image, and users interact via
their existing browser.

If the user is asking how to build a **custom DOCA application**
(linking against `libdoca-*`), that is *not* a BlueMan question —
route them to
[`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
and the matching `libs/<library>` skill.

If the user is asking how to build a **custom dashboard** on top of
DOCA: BlueMan does not export a public client SDK for that
use case. The right destination is
[`doca-dms`](../doca-dms/SKILL.md) (so the custom dashboard talks to
the device via the documented gRPC programmatic surface rather than
scraping BlueMan's web UI).

## modify

BlueMan does not have a "modify a sample" workflow analogous to DOCA
libraries; there is no BlueMan sample program a user starts from.
The BlueMan analog of "modify" is **adapt the documented deployment
recipe to the user's environment**:

1. **Start from the documented recipe.** Identify the public
   BlueMan guide's deployment recipe that matches the user's
   container runtime and four-axis config choices. Quote it; do
   not author a new one.
2. **Diff against the user's environment.** Note the specific
   substitutions the user must make: listen-interface address,
   port number, TLS certificate paths, auth-backend endpoint
   (LDAP server URL / SSO IdP URL / local account list), per-role
   operator assignments.
3. **Apply minimum-change.** Change only what the user's
   environment forces. Every additional deviation from the
   documented recipe widens the surface for an unintended exposure
   — most often, binding the dashboard to an in-band interface
   "because that's what was easy to reach from my laptop".
4. **Re-validate against the documented Security Best Practices.**
   Each substitution is a chance to accidentally weaken the
   documented posture (binding plain HTTP to a shared network;
   over-granting an RBAC role; using a lab auth backend in
   production).

## run

Bringing up the BlueMan container and the dashboard.

1. **Pull the documented container image at the documented tag.**
   The canonical image source is the public DOCA Container
   Deployment Guide and the NGC catalog page for BlueMan, reached
   through
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
   Do not invent an image name or tag from memory.
2. **Launch the container per the documented runtime path.** The
   DOCA Container Deployment Guide is the source of truth for the
   `crictl` / `kubelet` / SystemD container-unit invocation; the
   public BlueMan guide layers the BlueMan-specific config-mount,
   exposed port, and listen-interface binding on top.
3. **Confirm the container is `Running`.** Use the documented
   runtime command (e.g. `crictl ps` filtered to the BlueMan
   container) to confirm the container started and is not in a
   restart loop. If it failed, drop directly to
   [`## debug`](#debug) layer Container — there is no point asking
   the next question until the container is up.
4. **Confirm the dashboard is reachable.** From a host that can
   reach the configured listen interface, open the dashboard URL
   in a browser. A documented status / health endpoint (per the
   public BlueMan guide) is appropriate for a `curl` probe; for
   TLS deployments, confirm the certificate chain validates the
   way the browser expects.
5. **Confirm one operator account can log in.** Use the first
   planned operator account from `## configure` step 5. A
   successful login + at least one device-state page rendering is
   the documented "the dashboard works" signal.

For any subsequent operator account or role change: BlueMan is the
read-mostly observability surface; **adding operators is not the
same as making BlueField configuration changes**. For configuration
changes (link MTU, RoCE, port speed, service enable / disable),
route to [`doca-dms`](../doca-dms/SKILL.md) — even if a control
exists in the BlueMan UI, DMS is the canonical change surface.

## test

BlueMan has no "compile and unit-test" workflow — testing is
operational.

**`## test` is an iterative loop, not a one-shot pass.** Every
configuration mutation (listen interface, port, TLS, auth backend,
RBAC role assignment) re-opens the smoke sweep. Skipping the re-run
after a mutation is the failure mode this loop replaces.

The eval-loop overlay (rows apply to every BlueMan deployment, not
just one topology):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 4 → 1 | Capability-snapshot drift (step 4) often reveals an as-deployed gap that needs a configuration change; loop back to step 1 | [`## test`](#test) step 4 |
| 2 → ## debug | When the auth smoke does NOT reject what it should, the deployment is unsafe — escalate to `## debug` immediately, do not run later steps | [`## debug`](#debug) |
| 3 → ## configure → 3 | When the RBAC role assignment does not gate features as documented, the role wiring is wrong — loop back to `## configure` step 4 and re-run | [`## configure`](#configure) |
| 1..4 → ## run | Each loop iteration ends with a documented smoke; if all four pass, hand off to live `## run` traffic (real operators using the dashboard) | [`## run`](#run) |

The agent's rule: every mutation re-opens the sweep. A configuration
change followed by *"it probably still works"* is exactly the
failure mode the iterative loop is here to prevent.

1. **Smoke-test the deployment end-to-end.** Container up
   (`## run` step 3) → dashboard reachable in a browser
   (`## run` step 4) → one operator login works (`## run` step 5)
   → at least one device-state page (link status, or port counters,
   or services running) renders with non-empty data. **Only after
   all four pass** should the operator add more users or expose
   the dashboard on a wider network.
2. **Smoke-test the auth backend.** Confirm the chosen
   authentication backend rejects unauthenticated / wrong-credential
   requests as documented. For TLS deployments, confirm that an
   HTTP request to the HTTPS endpoint is rejected (or redirected)
   per the public guide. A "log in succeeded with the wrong
   password" outcome is a deployment-unsafe failure — stop and
   escalate to [`## debug`](#debug) layer Auth.
3. **Smoke-test RBAC.** Confirm that a least-privileged operator
   account sees the documented subset of dashboard pages and that
   pages outside that subset are documented-style refused (not
   shown / 403 / empty per the documented behavior of the public
   guide). An over-privileged or under-privileged outcome is a
   role-assignment bug to fix in [`## configure`](#configure) step
   4.
4. **Capability snapshot.** Save the *as-deployed* answer to:
   which listen interface + port the dashboard is on, which TLS
   posture is in effect, which auth backend is wired, which
   operator accounts exist, which RBAC role each operator has,
   which dashboard pages render with real data on this BlueField.
   This snapshot is the artifact that lets future debug sessions
   skip rediscovery.

## debug

Layered diagnosis. Walk the layers in this order; do not skip down
without clearing the layer above.

1. **Container layer.** Is the BlueMan container actually `Running`?
   Symptoms: `crictl ps` shows `Exited` / `Created` / restart loop;
   container log shows config-parse, image-pull, or missing-mount
   errors. Causes: bad image name / tag (invented from memory
   rather than quoted from the NGC catalog and the Container
   Deployment Guide), mis-mounted config file, image-pull
   credentials missing, container runtime not configured per the
   Container Deployment Guide. Resolution: walk the DOCA Container
   Deployment Guide via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md);
   if the failure is env-class, drop to
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug).
2. **Reachability layer.** Container is `Running` but the browser
   cannot reach the dashboard URL. Symptoms: browser timeout,
   connection refused, TLS handshake failure. Causes: BlueMan is
   bound to the wrong listen interface for where the operator's
   browser is coming from; a firewall on the path is blocking the
   listen port; TLS certificate material is missing / wrong /
   expired. Resolution: confirm the listen interface against
   `## configure` step 4 axis 1; confirm the firewall / route from
   the operator's network to the BlueField listen interface;
   confirm TLS material exists and the browser's trust store
   accepts the certificate chain.
3. **Authentication layer.** Dashboard is reachable but login
   fails. Symptoms: dashboard's documented login-rejected response;
   documented audit / login log line shows the rejection. Causes:
   wrong credentials, auth backend mis-wired (LDAP / SSO endpoint
   unreachable, local account does not exist), credential mismatch.
   Resolution: walk the auth backend's troubleshooting in the
   public BlueMan guide for the specific backend in use.
4. **Authorization / missing-feature layer.** Operator logs in but
   the expected dashboard page is empty, missing, or refused.
   Causes: the operator's RBAC role does not grant access to that
   page (the most common cause of *"the dashboard works but
   features are missing"*); OR the underlying DOCA service that
   BlueMan tries to monitor for that page is not running on the
   BlueField. Resolution: confirm the role assignment against the
   documented role catalog in the public guide first; if the role
   is correct, confirm the underlying service the page reads from
   is up — for DOCA-service monitoring pages, that means checking
   the matching service (DMS, DTS, Firefly, …) is itself running.
5. **Underlying-service layer.** A dashboard page renders an error
   sourced from a service BlueMan monitors. The failure is in the
   monitored service, not in BlueMan; route to that service's own
   skill (e.g. [`doca-dms`](../doca-dms/SKILL.md) for DMS-monitoring
   pages, the DTS guide via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
   for telemetry-monitoring pages).
6. **Library-level errors.** If a service BlueMan calls into
   surfaces `DOCA_ERROR_*`, the relevant cross-library taxonomy
   lives in
   [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
   The library-specific overlay (e.g. for Flow) lives in the
   matching `libs/<library>` skill.

## Command appendix

BlueMan-specific commands the verbs above reach for, grouped by
purpose so the agent picks the right family without searching prose.
Every row is a class — the agent must not invent flags beyond what
the row names; flag discovery is `--help` on the installed runtime
or the documented container-unit file, not prose recall.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST
   (`doca-env --json` for version + devices + libraries + drivers
   + hugepages in one shot on the BlueField target;
   `doca-capability-snapshot` for per-device capability flags;
   `version-matrix.json` for *"available since"* lookups).
2. If the probe succeeds, the structured tool's output is the
   authoritative answer and the agent SHOULD NOT also run the
   manual command in the row below. Report *"using structured
   `<tool>`"*.
3. If the probe fails, fall back to the manual command in the row.
   Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Purpose | Command (class shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Container lifecycle | `crictl ps` filtered to the BlueMan container, or the documented SystemD container-unit `systemctl status` | [`## run`](#run) step 3 / [`## debug`](#debug) layer Container | Container in `Running` state, no recent restarts, container log free of config-parse errors. |
| Container logs | The documented container-runtime log command (`crictl logs <id>` or `journalctl` integration per the public guide) | [`## debug`](#debug) layer Container / Reachability | Startup banner present; no repeated config-parse / image-pull / missing-mount errors after the initial startup window. |
| Dashboard reachability | `curl -kI https://<listen-interface>:<port>/` against the documented health / status path | [`## run`](#run) step 4 / [`## debug`](#debug) layer Reachability | HTTP response per the documented status endpoint; TLS handshake succeeds against the documented certificate. |
| Listener address | `ss -tlnp` (or `netstat -tlnp`) on the BlueField filtered to the BlueMan container's PID / port | [`## debug`](#debug) layer Reachability | Listener bound to the configured interface + port; nothing else competing for the port. |
| Browser smoke | Open the dashboard URL in a real browser (no curl substitute for this step) | [`## run`](#run) step 4 | Dashboard renders past the login page; TLS lock icon present (production posture); login page references the documented BlueMan branding. |
| Auth smoke | A login attempt with a known-bad credential, then with the known-good operator account from `## configure` step 5 | [`## test`](#test) step 2 | Bad credential is rejected with the documented response; good credential lands on the dashboard. |
| RBAC smoke | Log in as a least-privileged operator role; navigate to a page documented as outside the role's scope | [`## test`](#test) step 3 | The page is documented-style refused (not shown / 403 / empty per the documented behavior); over-privileged or under-privileged outcomes are role-assignment bugs. |
| Underlying-service liveness | The matching `systemctl status` / `crictl ps` for the DOCA service whose page is empty (DMS, DTS, Firefly, …) | [`## debug`](#debug) layer Authz / Underlying-service | The monitored service is `Running` / `active`. If it is not, route to that service's own skill. |
| Version snapshot | `doca_caps --version` on the BlueField + the deployed BlueMan container tag (recorded at pull time) | [`## debug`](#debug) layer Container / [`## test`](#test) step 4 | Both anchors agree with the version of the public BlueMan guide the agent is reading; per [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 when they diverge. |
| Cross-cutting health | `dmesg | tail -n 40` (sudo) on the BlueField for kernel / driver / network errors around the container start window | [`## debug`](#debug) layer Container | Empty or benign recent messages; mlx5 / network / OOM errors → env-class bug, drop to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug). |

Three cross-cutting rules for this appendix:

- **Never invent an image name, tag, or BlueMan config field.** The
  public BlueMan guide and the NGC catalog page are the contract.
  Prose-derived image strings or config fields are the most common
  hallucination failure for this skill.
- **Container logs before host logs.** When triaging, read the
  documented container-runtime log first; only drop to host-side
  `dmesg` / `journalctl` once the container log confirms the
  failure is below the container layer.
- **Cross-link instead of duplicate.** Cross-cutting commands
  (`doca_caps --version`, `pkg-config --modversion`,
  `cat /opt/mellanox/doca/applications/VERSION`) live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  this appendix names only the BlueMan-specific ones.

## Deferred task verbs

- **Making BlueField configuration CHANGES** (MTU, RoCE, port
  speed, service enable / disable) — **not a BlueMan task**, even
  if a dashboard control exists. The canonical change surface is
  DMS; route to [`doca-dms`](../doca-dms/SKILL.md). The BlueMan
  skill's read-mostly framing is non-negotiable per
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- **Installing DOCA on the BlueField target** — out of scope here.
  Route to
  [`doca-setup ## configure`](../../doca-setup/TASKS.md#configure)
  for env preparation and
  [`doca-setup ## test`](../../doca-setup/TASKS.md#test) for
  install health verification, or
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path.
- **Building a custom DOCA application** — not a BlueMan question.
  Route to
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the canonical build pattern, plus the matching
  `libs/<library>` skill for the API surface.
- **Continuous telemetry streaming or forwarding** — not BlueMan's
  job. BlueMan is a *snapshot dashboard*. Route to the DOCA
  Telemetry Service (DTS), discoverable through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **Host-side lights-out management** (host BMC / IPMI / iLO
  equivalents) — out of scope for any DOCA artifact. BlueMan is
  BlueField-side; host-side management goes through the host
  vendor's BMC tooling, not through this skill.

## Cross-cutting

- The public BlueMan guide is the single source of truth. Any
  image name, container flag, config field, auth backend, or role
  detail the agent quotes must come from there, not from generic
  container / web-dashboard knowledge.
- BlueMan is **read-mostly**. Configuration *changes* belong to
  [`doca-dms`](../doca-dms/SKILL.md), not to a dashboard control.
- Plain HTTP is acceptable only for lab use; production deployment
  is HTTPS per the documented Security Best Practices.
- The four config axes (listen interface + port, TLS, auth backend,
  RBAC) are orthogonal — every mutation on any axis re-opens the
  smoke sweep in [`## test`](#test).
- For URL routing to the BlueMan guide, the Container Deployment
  Guide, and other public DOCA documentation, see
  [doca-public-knowledge-map ## DOCA services](../../doca-public-knowledge-map/SKILL.md#doca-services).
