# DOCA version handling — capabilities, version compatibility, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your question
(detection sources / four-way match / NGC / per-library overlay /
errors / safety) and read that section end-to-end. The tables in
each section are the load-bearing content; the prose is interpretation.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern, jump
to [TASKS.md](TASKS.md). For the JSON schemas that helper tools
emit (so the agent can prefer the structured one-shot over the
manual chain), see
[`doca-structured-tools-contract`](../doca-structured-tools-contract/SKILL.md).

## Pattern overview

Every version-handling question this skill teaches resolves into
one of FIVE patterns. The patterns are CLASSES — they apply across
every DOCA release, every library, and every host kind.

| Version pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Detect the installed version | Read every source-of-truth and confirm they agree (four-way match) | [`## Capabilities and modes`](#capabilities-and-modes) source-of-truth table + [TASKS.md ## configure](TASKS.md#configure) |
| 2. Validate consistency | Cross-check sources; flag drift; explain partial-install | [`## Version compatibility`](#version-compatibility) four-way match rule + [TASKS.md ## test](TASKS.md#test) |
| 3. Look up capability availability | Compare a required minimum DOCA version against the installed version | [`## Observability`](#observability) version-matrix lookup + [TASKS.md ## test](TASKS.md#test) |
| 4. Diagnose a version-related error | Map symptom (pkg-config missing / mismatch / wrong API / BFB drift) to root cause | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |
| 5. Author the per-library overlay | When adding a new library skill, write its `## Version compatibility` against THIS skill's template | [`## Safety policy`](#safety-policy) per-library overlay pattern + [TASKS.md ## modify](TASKS.md#modify) |

Two cross-cutting rules that apply to *every* pattern above:

- **Never invent a version, never quote "latest".** Always derive
  the version from one of the sources in
  [`## Capabilities and modes`](#capabilities-and-modes); never
  trust agent memory and never copy a version string from a
  public docs URL without confirming it against the user's
  installed sources.
- **The headers win over the docs.** The C headers under the
  install tree's `infrastructure/include/` are the *authoritative*
  statement of which symbols exist on this release. A public docs
  page that mentions a symbol absent from the headers is wrong
  for *this* install — the docs describe a release; the headers
  *are* the release.

## Capabilities and modes

The **canonical source-of-truth table** for DOCA version
detection. Every version question the agent answers must derive
its version string from one of these sources; if two sources
disagree, the install is partial and the answer routes to
[`## Error taxonomy`](#error-taxonomy) before any other diagnosis
continues.

| Source | What it tells you | When to read |
| --- | --- | --- |
| `pkg-config --modversion doca-common` | The *build-time* DOCA version your application will link against. The `doca-common` module ships with every DOCA install and is depended on by every other library, so it is the single most reliable build-time source. | Always read first. The agent's first version-detection step on every host. |
| `pkg-config --modversion doca-<library>` | Same as above but for a specific library. Useful when the agent is reasoning about *one* library and wants to confirm the per-library `.pc` agrees with `doca-common`. | When the user's question is library-scoped (Flow, RDMA, …) and the agent has already read `doca-common`. |
| `cat /opt/mellanox/doca/applications/VERSION` | The *install-tree* DOCA version. A flat text file written by the install scripts. Useful when `pkg-config` is missing or `PKG_CONFIG_PATH` is unconfigured (which itself is a setup problem the agent should fix first via [`doca-setup`](../doca-setup/SKILL.md)). | When `pkg-config` is not reachable. Also as the second leg of the four-way match. |
| `doca_caps --version` | The *runtime* DOCA version. Reads the same version metadata the loaded `*.so` libraries report at runtime. The single most reliable runtime source. | After `pkg-config` — these two together establish whether build-time and runtime agree (the most common drift surface). |
| `mlxprivhost` / `bfb-info` (BlueField only, sudo) | The *BFB-image* DOCA version on the BlueField side of a host ↔ DPU pair. Only relevant on hosts where a BlueField is present. | On BlueField hosts. The fourth leg of the four-way match. |
| Header path `/opt/mellanox/doca/infrastructure/include/doca_version.h` | The *compile-time* DOCA version constants (`DOCA_VERSION_MAJOR / MINOR / PATCH`). Read by C programs at compile time. | When the user is reasoning about *what their program will see at compile time*; otherwise, `pkg-config` is the same information. |

**Discovery shortcut.** When the host has a structured-tools
helper installed (per
[`doca-structured-tools-contract`](../doca-structured-tools-contract/SKILL.md#doca-env-json-schema)),
`doca-env --json` returns all five sources in one JSON object with
a `version.consistent` boolean that pre-computes the four-way
match. Prefer this when present; fall back to the chain above
when not.

## Version compatibility

The **four-way match rule** is the central constraint DOCA
version handling exists to enforce:

> All of (a) `pkg-config --modversion doca-common`, (b) `cat /opt/mellanox/doca/applications/VERSION`, (c) `doca_caps --version`, and (on BlueField hosts) (d) the BFB-image version MUST match within a release. Any disagreement means the install is partial; the fix is to reinstall consistently, NOT a code change.

The cross-version mixing trap is the single most common cause of
*"the program built but does nothing on the wire"* reports for
first-time DOCA users, which is why this rule sits at the top of
the version skill.

**Authoritative upstream source for compatibility windows.**
NVIDIA's own statement of which release pairings are *intended* to
work — quarterly GA cadence, October LTS designation (3-year
support, 7-update LTS train), the semver `X.Y.Z` scheme, the three
compatibility types (source / binary / behavioral), and the two
compatibility directions (backward / forward) — is the
[DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html).
Cite this URL whenever the user asks *"is my LTS still supported"*,
*"what does the version string mean"*, or any host ↔ DPU
compatibility question. This skill detects *what is installed*;
the Compatibility Policy describes *which installs NVIDIA intends
to work together*.

**NGC container semantics.** When the user reached an install via
the public NGC DOCA container (per
[`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install)
Path 0), the four-way match is *of the container*: the headers,
`*.so`, samples, and `doca_caps` are all built and shipped together
at the container tag the user pulled. Mixing artifacts built
inside the container with a `*.so` from a different DOCA install
on the host is the same partial-install trap as case (a) ≠ (c) on
a non-container host.

**Cross-version `*.so` loading is not supported.** A program built
against version *X* must run against runtime version *X*. The
`doca_<library>_cap_*` query family is the right way to ask *"is
this capability supported"* without resorting to header probes or
build-time guards.

## Error taxonomy

Version-related errors the agent should recognize and disambiguate
before continuing to a library- or program-level diagnosis. For
the cross-library `DOCA_ERROR_*` taxonomy itself, see
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *version-level* upstream causes that bubble
up *as* those errors.

| Symptom | Most-likely version cause | First action |
| --- | --- | --- |
| `pkg-config: Package 'doca-common' was not found` | `PKG_CONFIG_PATH` is not configured OR the install is missing the `doca-common` package | Run `ls /opt/mellanox/doca/infrastructure/lib/pkgconfig/`. If `doca-common.pc` exists, fix `PKG_CONFIG_PATH` (see [`doca-setup ## configure`](../doca-setup/TASKS.md#configure)). If not, reinstall via `doca-all`. |
| `pkg-config --modversion doca-common` returns *X*; `doca_caps --version` returns *Y* (*X ≠ Y*) | Partial install: build-time and runtime are from different DOCA releases | Reinstall consistently. Do NOT work around in code. See [TASKS.md ## debug](TASKS.md#debug) ladder step 2. |
| Program compiles with `DOCA_VERSION_MAJOR = X`; same program returns `DOCA_ERROR_NOT_SUPPORTED` from a call that the docs say is available since *X* | The headers are from version *X*; the runtime `*.so` is from version *Y* < *X* | Same partial-install diagnosis as above; the header path is *not* what the runtime is. |
| BFB image version differs from host package version by more than one minor release | Host ↔ DPU compatibility window may not cover this pair | Cite the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html); if the user is outside the supported window, the answer is to bring the BFB and host into agreement, not to patch around the mismatch. |
| `doca-flow.pc` exists; `pkg-config --modversion doca-flow` works; `doca_caps --version` is silent or errors | DOCA runtime is not on `LD_LIBRARY_PATH` OR is from a different install | Verify with `ldconfig -p | grep doca`; route to [`doca-setup ## debug`](../doca-setup/TASKS.md#debug) layer 3. |
| Public docs say capability *C* exists; on the user's host, `doca_<library>_cap_*` returns false | The user's installed version pre-dates the capability | Look up the minimum version in the version-matrix (see [TASKS.md ## test](TASKS.md#test)); if installed < min, the answer is to upgrade or to use a different approach. |
| User pastes a URL like `docs.nvidia.com/doca/sdk/.../archive/v2.5.0/...` | Version-pinned doc URL; describes an old release | Tell the user the URL is version-pinned and fetch the current-release equivalent via [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md). |

## Observability

The version handling observability surface is the set of commands
that *read* version state, and the structured-tools fields that
*report* it in one shot. There is no DOCA "version counter" — the
visibility comes from probing the sources in
[`## Capabilities and modes`](#capabilities-and-modes).

Three primary signals the agent should reach for:

1. **The four-way match status.** Either `version.consistent`
   from `doca-env --json` (preferred) or the agent computing it
   itself from the manual chain. The single most informative
   one-line answer to *"is my install consistent"*.
2. **The version-matrix lookup result.** Either a row in
   `version-matrix.json` (preferred) or the manual fallback of
   fetching the per-library docs page and extracting the
   *"available since"* prose (per
   [`doca-structured-tools-contract ## version-matrix.json schema`](../doca-structured-tools-contract/SKILL.md#schemas)).
   **Current shipping state (PR2):** the schema is shipped; the
   populated `version-matrix.json` data file does NOT yet ship in
   the public bundle, so in practice the agent always falls back
   to fetching the *"available since"* prose from the per-library
   docs via [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).
   That fallback is correct (the answer comes from NVIDIA's
   freshest source) but slower than a local lookup; the design
   for landing the data file together with the offline verifier
   is captured in `future-plan/version-offline-database.md`. The
   agent never treats the missing data file as a "no answer" — it
   walks the manual fallback.
3. **The capability-query result.** The per-library
   `doca_<library>_cap_*` API answers *"is this supported on this
   device + this version"* at runtime. The version-matrix is the
   *promise*; the capability query is the *reality*. When they
   disagree, the capability query wins.

For the env-side observability primitives (`LD_LIBRARY_PATH`,
`PKG_CONFIG_PATH`, `ldconfig -p`) see
[`doca-setup CAPABILITIES.md ## Observability`](../doca-setup/CAPABILITIES.md#observability).
For the cross-cutting debug-time observability (`--sdk-log-level`,
the `doca-<lib>-trace` flavor, `DOCA_LOG_LEVEL`) see
[`doca-debug CAPABILITIES.md ## Observability`](../doca-debug/CAPABILITIES.md#observability).

## Safety policy

Version handling's safety surface is **anti-hallucination**.
The single most common bundle failure mode without this skill is
the agent quoting a version from memory or from a public-docs URL
without confirming it against the user's installed sources. The
rules below exist to prevent that.

- **Never quote "latest".** "Latest" is not a version. The user's
  installed version is the version. If the user actually does not
  know what they have installed, route to
  [TASKS.md ## configure](TASKS.md#configure) before answering any
  other question.
- **Never copy a version from a URL.** A URL like
  `docs.nvidia.com/doca/sdk/.../v3.3/...` describes what was
  current when the page was published, not what the user has.
- **Never assume the four-way match.** Always verify the user's
  sources agree before answering a *"is X supported"* question.
  The cost of asking the user to run two commands is much smaller
  than the cost of telling them a feature exists when their
  install pre-dates it.
- **Never recommend a workaround for a partial install.** When the
  four-way match fails, the *only* safe answer is to reinstall
  consistently. Pinning `LD_LIBRARY_PATH` to a different `*.so`,
  manually copying a header, or any other workaround perpetuates
  the bug and makes the next failure harder to diagnose.

**The per-library overlay pattern.** Every library / service / tool
skill in the bundle has a `## Version compatibility` section in its
own `CAPABILITIES.md`. To stop those sections from drifting from
this skill, the bundle convention is:

> A library / service / tool skill's `## Version compatibility` section
> MUST be 3-5 lines that (a) cross-link to this skill for the
> four-way match rule + detection chain + NGC semantics, and (b)
> add at most one library-specific overlay rule (e.g. *"the DOCA
> Comch library was renamed from DOCA Comm Channel in DOCA 2.5;
> the `pkg-config` module name is `doca-comch` on 2.5+"*). It MUST
> NOT redefine the four-way match rule or restate the detection
> chain.

The mechanical enforcer is the lint warning in
`devops/ci/check-skill.sh` that flags repeated `/opt/mellanox/doca`
references in a library skill's CAPABILITIES.md; if you find
yourself accumulating warnings on a new skill's `## Version
compatibility`, you are duplicating instead of cross-linking.

## Deferred topic boundaries

This skill scopes itself to DOCA version handling. Adjacent topics
the agent will get asked but should route elsewhere:

- **Installing DOCA, choosing packages, post-install verification.**
  Owned by [`doca-setup`](../doca-setup/SKILL.md). This skill
  assumes something is installed somewhere; the version question
  is *what was installed and is it consistent*.
- **Per-library capability availability** (which symbols exist in
  Flow at version *X*). The version-matrix lookup procedure in
  [TASKS.md ## test](TASKS.md#test) is generic; the per-library
  *interpretation* belongs in the matching library skill's
  `## Capabilities and modes`.
- **Cross-library `DOCA_ERROR_*` taxonomy.** Owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill's `## Error taxonomy` is the *version-level* upstream
  causes that bubble up *as* those errors.
- **General debug ladder** (install / version / build / link /
  runtime / program / driver). Owned by
  [`doca-debug ## debug`](../doca-debug/TASKS.md#debug). This
  skill owns layer 2 (*version mismatch*); the other layers
  redirect.
- **Routing to public docs and the on-disk install layout.**
  Owned by [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).
  This skill cites the Compatibility Policy URL once via that
  map; it does not duplicate the routing.
