---
name: doca-flow
description: NVIDIA DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, counter and trace inspection, version compatibility, and debugging DOCA_ERROR_* failures from the Flow API.
kind: library
---

# DOCA Flow

## When to load this skill

Load this skill when the user is doing **hands-on DOCA Flow work on a
BlueField host with DOCA already installed**. Concretely:

- Bringing up a DOCA Flow port and selecting devices or representors.
- Creating a pipe, defining match criteria and actions, programming entries.
- Validating a pipe specification *before* programming the hardware.
- Reading pipe counters or traces to investigate observed traffic behavior.
- Checking which Flow features and API symbols are available on a specific
  installed DOCA version.
- Debugging a `DOCA_ERROR_*` returned from a Flow API call and deciding
  whether the cause is a configuration mistake, a missing prerequisite, or
  an unsupported feature on this hardware or steering mode.

Do **not** load this skill for general DOCA orientation, "where do I find
docs", install-layout, or non-Flow library questions. For those, use
[`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation needed to
pick the right next file. The substantive Flow-specific material lives in
two companion files:

- `CAPABILITIES.md` — what Flow can express on this version: HW versus
  software steering, supported match and action kinds, Flow API symbol
  availability per DOCA version, the DOCA error taxonomy with Flow
  overlays, the Flow observability surface (counters, pipe statistics),
  and the safety policy that gates HW programming.
- `TASKS.md` — step-by-step workflows for the six in-scope Flow verbs:
  `configure`, `build`, `modify`, `run`, `test`, `debug`. Plus a
  `Deferred task verbs` block that points install/deploy/rollback questions
  at the right next skill.

The skill assumes a host where DOCA is already installed at the standard
location and the user has root access to bring up devices. It does not
cover installing DOCA — that path goes through the knowledge-map skill.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in scope.
2. **For the full pipe specification schema, the Flow capability matrix,
   the Flow error taxonomy, observability, and safety policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run, test,
   debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other and to
`doca-public-knowledge-map` whenever the right answer is "look it up in
the public docs or the installed package layout" rather than "Flow-specific
guidance".

## Related skills

- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) — the
  routing table for every public DOCA documentation source and the on-disk
  layout of an installed DOCA package. Always available alongside this
  skill; this skill expects to be able to defer documentation-finding and
  install-layout questions there instead of duplicating them.
