---
name: doca-setup
description: NVIDIA DOCA setup and bring-up — env preparation only. Install verification, build environment (`pkg-config`, headers, hugepages, devlink), runtime preconditions (representor enumeration, kernel-module visibility), env-class debugging (install / version / build / runtime layers), and the *I have no install yet* procedure with the public NGC DOCA container (`nvcr.io/nvidia/doca/doca`) as the universal Stage-1 fallback for any user on macOS, Windows, or Linux without DOCA — alongside lab-host, cloud-Linux, and hardware paths. Env-class only; for the canonical build pattern, the universal modify-a-shipped-sample first-app workflow, the cross-library `DOCA_ERROR_*` pattern, and the program-side debugging order, see `doca-programming-guide`.
kind: library
---

# DOCA setup

## When to load this skill

Load this skill when the user is dealing with the **environment around DOCA** — installing it, verifying the install is healthy, preparing the build / runtime preconditions, debugging env-class failures, or figuring out *how to reach an install* from a host that doesn't have one yet. Concretely:

- Verifying that the DOCA install is healthy and that the build environment can find it (`pkg-config`, headers, library paths).
- Preparing the runtime: hugepages, `devlink` device visibility, representor enumeration, kernel-module prerequisites.
- Diagnosing common setup-class failures: missing `*.pc` file, hugepages not mounted, representor not visible, header-vs-runtime version mismatch.
- The *I have no install yet* path: the user is on macOS, Windows, or a Linux box without DOCA, and needs to reach an environment where DOCA is actually installed. The canonical Stage-1 answer is the public **NGC DOCA container** at `nvcr.io/nvidia/doca/doca` (works on any OS that runs Docker; no NVIDIA hardware required for the build / read / learn loop). See [`TASKS.md ## no-install`](TASKS.md#no-install).

Do **not** load this skill for:

- *"What is DOCA?", "where is the developer guide?", "where is the install layout documented?"* — those are routing questions; use [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).
- *"How do I derive a custom first application from a sample?", "how do I structure a DOCA build?", "what does `DOCA_ERROR_BAD_STATE` mean?"* — those are **programming-class** questions and live in [`doca-programming-guide`](../doca-programming-guide/SKILL.md), which owns the universal `## modify` (first-app derivation), the canonical `## build` pattern, the universal lifecycle, and the cross-library `DOCA_ERROR_*` taxonomy.
- *Library-internal API questions* (Flow pipe construction, RDMA queue setup, etc.) — those belong in the matching library skill (e.g. [`doca-flow`](../libs/doca-flow/SKILL.md)). This skill stops at *"the install is healthy and the env is ready"*; it does not own program semantics.

## What this skill provides

This is a **thin loader**. The body keeps only the orientation needed to pick the right next file. The substantive env material lives in two companion files:

- `CAPABILITIES.md` — what the install / build / runtime *environment* surface looks like: install profiles (`doca-all`, `doca-ofed`, `doca-networking`), where the build flavors (release vs trace) live on disk and how to point `LD_LIBRARY_PATH` at them, the env-side version-detection rules, the env-class error taxonomy (`pkg-config` not finding `doca-flow`, hugepages not reserved, representors not visible), what a healthy install looks like under observation, and the safety constraints on environment changes (hugepages global, `mlxconfig` reset, eswitch mode change).
- `TASKS.md` — env workflows: `configure` (env prep), `test` (install health snapshot), `debug` (env-class layered diagnosis), and `no-install` (the *I have no install yet* procedure with the NGC container as Path 0). Three other anchors (`build`, `modify`, `run`) exist for lint compliance and route to [`doca-programming-guide`](../doca-programming-guide/SKILL.md), which owns those verbs after the env / program split.

This skill assumes nothing about whether DOCA is installed — the `## no-install` workflow exists precisely for the *fresh laptop* case.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is env-class, not programming-class or routing-class.
2. **For install profiles, build-flavor disk locations, env-side version-detection, the env-class error taxonomy, and the env-side safety policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For env workflows — `configure`, `test`, `debug`, and the critical `no-install` (NGC container path) — see [TASKS.md](TASKS.md).** The `build`, `modify`, and `run` anchors in `TASKS.md` are stubs that route to [`doca-programming-guide`](../doca-programming-guide/SKILL.md); their substance lives there.
4. Once the env is healthy, hand off to [`doca-programming-guide`](../doca-programming-guide/SKILL.md) for the build pattern, the first-app workflow, and the program-side error / debug order; then to the matching library skill (e.g. [`doca-flow`](../libs/doca-flow/SKILL.md)) for library-specific API guidance.

Both companion files cross-link to each other and to `doca-public-knowledge-map` whenever the right answer is *"look it up in the public docs or the installed package layout"* rather than *"setup-specific guidance"*.

## Related skills

- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) — public DOCA documentation routing and the on-disk layout of an installed DOCA package. This skill defers all *"where is X documented"*, *"where on disk is Y"*, and *"how do I check the installed version"* questions to the knowledge-map.
- [`doca-programming-guide`](../doca-programming-guide/SKILL.md) — general DOCA programming patterns once the env is healthy: the canonical `pkg-config doca-<library>` build pattern, the universal *derive a custom first app from a sample* workflow (with C / C++ + non-C tracks), the universal lifecycle, and the cross-library `DOCA_ERROR_*` taxonomy. Anything beyond *"is the install healthy and the env ready"* lives there.
- [`doca-flow`](../libs/doca-flow/SKILL.md) — DOCA Flow on BlueField. Builds on this skill for env preparation and on `doca-programming-guide` for the universal first-app derivation, then layers Flow-specific overrides on top.
