---
name: doca-setup
description: NVIDIA DOCA setup and bring-up on a host or BlueField — install verification, build environment (pkg-config, headers, meson), runtime preconditions (hugepages, devlink, representors), shipped-sample build/run loop, and the generic pattern for deriving a custom first application from a known sample. Library-agnostic; library-specific first-app overrides live in the matching library skill.
kind: library
---

# DOCA setup

## When to load this skill

Load this skill when the user has DOCA installed (or believes they do) and is trying to **get from a healthy install to a running program**. Concretely:

- Verifying that the DOCA install is healthy and that the build environment can find it (`pkg-config`, headers, library paths).
- Preparing the runtime: hugepages, `devlink` device visibility, representor enumeration, kernel-module prerequisites.
- Building one of the shipped DOCA samples under `/opt/mellanox/doca/samples/...` and running it for the first time.
- **Deriving a custom "first application"** from one of those shipped samples — copy, identify the small set of values to change, produce a complete buildable file with explicit placeholders, build it, run it staged.
- Diagnosing common setup-class failures: missing `*.pc` file, hugepages not mounted, representor not visible, header-vs-runtime version mismatch.

Do **not** load this skill for:

- *"What is DOCA?", "where is the developer guide?", "where is the install layout documented?"* — those are routing questions; use [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).
- *Library-internal API questions* (Flow pipe construction, RDMA queue setup, etc.) — those belong in the matching library skill (e.g. [`doca-flow`](../doca-flow/SKILL.md)). This skill stops at "the sample compiles, runs, and you have a templated starting point"; it does not own library API semantics.

## What this skill provides

This is a **thin loader**. The body keeps only the orientation needed to pick the right next file. The substantive setup material lives in two companion files:

- `CAPABILITIES.md` — what the install/build/runtime surface looks like: install profiles (`doca-all`, `doca-ofed`, `doca-networking`), build flavors (release, debug, trace), runtime modes (host vs. DPU vs. switch), the version-compatibility rules between headers/runtime/firmware, the setup-class error taxonomy, what a healthy install looks like under observation, and the safety constraints on environment changes.
- `TASKS.md` — step-by-step workflows for the six in-scope setup verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`. The `modify` verb owns the generic *"derive a custom first app from a sample"* pattern that any DOCA library can extend with library-specific field-swap lists.

This skill assumes DOCA has already been installed under `/opt/mellanox/doca` (the standard location). It does **not** cover *installing* DOCA on a fresh system — that path goes through the knowledge-map skill, which routes the user to the official Installation Guide.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in scope and to choose the right companion file.
2. **For install profiles, build flavors, version-compatibility rules, the setup error taxonomy, and the safety policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step setup workflows — `configure`, `build`, `modify`, `run`, `test`, `debug` — see [TASKS.md](TASKS.md).**
4. If the user is asking for a *"first app"* in a specific library, walk through `TASKS.md ## modify` for the generic copy-and-templatize pattern, then hand off to the library skill (e.g. `doca-flow`) for the library-specific values to swap.

Both companion files cross-link to each other and to `doca-public-knowledge-map` whenever the right answer is *"look it up in the public docs or the installed package layout"* rather than *"setup-specific guidance"*.

## Related skills

- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) — public DOCA documentation routing and the on-disk layout of an installed DOCA package. This skill defers all *"where is X documented"*, *"where on disk is Y"*, and *"how do I check the installed version"* questions to the knowledge-map.
- [`doca-flow`](../doca-flow/SKILL.md) — DOCA Flow on BlueField. Extends this skill's `## modify` (generic first-app derivation) with the Flow-specific list of fields to swap when the source sample is `flow_port_fwd` or `flow_switch_single`.
