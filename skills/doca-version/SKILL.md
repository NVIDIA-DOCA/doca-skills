---
name: doca-version
description: Single source of truth for DOCA version handling across the bundle — the canonical version-detection chain (pkg-config --modversion + cat applications/VERSION + doca_caps --version, plus BFB version on BlueField hosts), the four-way match rule, NGC container version semantics, the headers-win-over-docs rule, partial-install detection, the per-library version-compatibility overlay pattern that every library / service / tool skill follows, and the routing to the DOCA Compatibility Policy.
kind: library
---

# DOCA version

**Where to start:** This skill is the bundle's single source of
truth for DOCA *version handling*. Open
[`TASKS.md`](TASKS.md) if the user wants to *do* something with the
version (detect / validate / diagnose mismatch); open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what does
version handling cover* (the four-way match, the detection chain,
NGC semantics, the per-library overlay pattern). Every other skill
in the bundle that touches version routes here — they MUST NOT
redefine the rules.

## Example questions this skill answers well

The CLASSES of version-handling questions this skill is built to
answer, each with one worked example. The agent should treat the
*class* as the load-bearing piece — the worked example is a single
instance.

- **"What DOCA version do I actually have installed?"** — worked
  example: *"the docs say 3.3 but I'm not sure what's on this
  host"*. Answered by the canonical detection chain in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  source-of-truth table.
- **"My program built but does nothing on the wire — is my install
  consistent?"** — worked example: *"`pkg-config --modversion`
  says 3.3.0; `doca_caps --version` says 3.2.0"*. Answered by the
  four-way match rule in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  + the partial-install diagnosis in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Is this DOCA capability / API / sample on the version I
  have?"** — worked example: *"is the symmetric-RSS hash mode in
  Flow 2.6.0"*. Answered by the version-matrix lookup procedure in
  [`TASKS.md ## test`](TASKS.md#test) (which uses the
  `version-matrix.json` schema defined in
  [`doca-structured-tools-contract`](../doca-structured-tools-contract/SKILL.md#schemas)
  with fallback to per-library docs via
  [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md)).
- **"Can I run my host package version X against BFB version Y?"** —
  worked example: *"host is 3.3.0 LTS, BlueField BFB is 3.1.0"*.
  Answered by the routing to the
  [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html)
  documented in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
- **"I'm inside the NGC DOCA container — what does the version
  match look like?"** — worked example: *"do I still need to check
  pkg-config / applications/VERSION / doca_caps separately?"*.
  Answered by the NGC container rule in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  + the container path in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"How do I write a per-library version-compatibility section
  for a new skill?"** — worked example: *"adding `doca-comch` to
  the bundle, what does its `## Version compatibility` look
  like?"*. Answered by the per-library overlay pattern in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the worked-example template in
  [`TASKS.md ## modify`](TASKS.md#modify).

## When to load this skill

Load this skill whenever version handling is the load-bearing
concern. Concretely:

- The user asks any *"what version do I have"* / *"is it
  consistent"* / *"is X supported on Y"* / *"can I mix"* question.
- A library / service / tool skill's `## Version compatibility`
  section cross-links here for the rule body (rather than
  duplicating it).
- A `DOCA_ERROR_*` debug session has narrowed to *"the partial-install
  hypothesis"* and the agent needs the canonical version-mismatch
  diagnosis ladder.
- A new skill is being added to the bundle and its author needs
  the per-library overlay pattern.

Do **not** load this skill for general DOCA orientation, for
install procedures (use [`doca-setup`](../doca-setup/SKILL.md)),
or for library-specific API questions (use the matching library
skill).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive
version-handling material lives in two companion files:

- `CAPABILITIES.md` — the version-handling surface: the canonical
  source-of-truth table for version detection, the four-way match
  rule, NGC container semantics, the per-library overlay pattern,
  the routing to the DOCA Compatibility Policy, the error
  taxonomy for version-related failures (pkg-config missing,
  partial install, BFB/host mismatch, NGC mixing), the
  observability surface (which command to read for which version
  source), and the safety policy ("never invent a version, never
  quote `latest`").
- `TASKS.md` — step-by-step workflows for the six in-scope
  version verbs: `configure` (detect on this host), `build`
  (build-time match), `modify` (update a version pin in a build
  manifest), `run` (runtime check), `test` (four-way validation +
  version-matrix lookup), `debug` (diagnose mismatch / partial
  install). Plus a `Deferred task verbs` block.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in
   scope.
2. **For the version-detection sources, four-way match rule, NGC
   semantics, per-library overlay pattern, error taxonomy,
   observability, and safety policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-structured-tools-contract`](../doca-structured-tools-contract/SKILL.md) —
  the JSON schemas for the helper tools the agent should prefer
  when present. This skill's `## test` workflow uses the
  `version-matrix.json` schema defined there; do not redefine the
  schema here.
- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) —
  the routing table to public DOCA docs, including the
  Compatibility Policy. This skill cites the Compatibility Policy
  URL once via that map; it does not duplicate the routing.
- [`doca-setup`](../doca-setup/SKILL.md) — env-side install /
  verify / NGC container path. This skill assumes its
  preconditions are satisfied (i.e., something is installed
  somewhere; the version question is *what was installed and is
  it consistent*).
- [`doca-programming-guide`](../doca-programming-guide/SKILL.md) —
  program-side guidance (quote the version observed, header-wins,
  capability-discovery rules). The program-side `## Version
  compatibility` section there is now a 3-5 line redirect to this
  skill plus the program-side overlay (quote vs assume; never use
  agent-memory version).
- [`doca-debug`](../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. Layer 2 (*version mismatch*) of that ladder is
  owned by this skill's `## debug` workflow.
