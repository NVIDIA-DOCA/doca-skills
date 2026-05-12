# DOCA C And C++ Style

Applies to: `**/*.c`, `**/*.h`, `**/*.cpp`, `**/*.hpp`, `**/*.cu`, `**/*.cuh`
Read when: editing NVIDIA-owned C, C++, CUDA, or header files
Load next: `modules/README.md`

Follow the project `.clang-format` and the surrounding file style. When these rules apply to a code change, mention that
DOCA coding conventions were applied.

## Naming And API Shape

- SDK APIs use `doca_<module>_<action>()`.
- Private or static helpers use `<module>_<action>()` or `priv_doca_<module>_<action>()`.
- `create` implies allocation or object creation. Use `set` for plain field updates.
- Prefer configuration structs over long parameter lists for new interfaces.

## Headers And SDK API

- Use include guards, not `#pragma once`.
- SDK API guards use `DOCA_<MODULE>_H_`.
- Local header guards follow sibling-file conventions and usually mirror the filename in upper case.
- SDK headers need `extern "C"` wrappers, Doxygen documentation, and the correct `DOCA_STABLE` or `DOCA_EXPERIMENTAL`
  tags.

## Error Handling

- DOCA-facing functions generally return `doca_error_t`.
- Use a single cleanup path when resources must be released.
- Use `DOCA_ERROR_PROPAGATE()` when cleanup can fail and the first error must be preserved.
- Prefer direct returns for simple wrappers, such as `return doca_action(ctx);`.
- Log specific failure reasons; avoid vague messages like `invalid parameter`.
- When logging a `doca_error_t`, prefer the symbolic tag from `doca_error_get_name(ret)` unless neighboring code
  intentionally uses a different pattern.
- Stop, cleanup, destroy, and unregister helpers may return on the first failed teardown step when surrounding code
  treats any non-success return as fatal. Do not rewrite those paths into a "run every cleanup and return the first
  error" pattern unless the local API requires it.

## Error Handling Checklist

For non-trivial C or C++ edits, check these points before finalizing:

- Initialize owned pointers and handles before the first possible cleanup jump.
- Make each cleanup label responsible for one acquisition layer and let labels fall through in reverse acquisition
  order.
- Preserve the first failing `doca_error_t` when a later cleanup step can also fail, following the local
  `DOCA_ERROR_PROPAGATE()` pattern.
- Log the failing API, object, or parameter name with enough context to act on it. Include `doca_error_get_name(ret)` or
  the neighboring module's accepted error formatter for DOCA status values.
- In callbacks, record task status and ownership changes clearly. Do not submit new work, progress the same PE
  recursively, or free task-owned resources unless the surrounding sample or library callback pattern does so.
- Separate validation failures from cleanup failures in sample output so users can tell whether setup, submission,
  progress, or teardown failed.

## Agent-Facing Skeletons

When an agent returns C or C++ skeleton code for a user, make it compact but complete enough to audit:

- Include the SDK headers that define every API named in the skeleton.
- Initialize all owned handles, pointers, buffers, and task state before any branch can jump to cleanup.
- Show acquisition and cleanup in reverse order. Each cleanup label should own one resource layer and fall through only
  to labels for earlier acquisitions.
- Preserve the first failing `doca_error_t` when later cleanup can also fail, using the local `DOCA_ERROR_PROPAGATE()`
  pattern where available.
- Name callback-owned state explicitly. Callback examples should store task completion status and ownership changes;
  they should not free resources that the surrounding API still owns.
- Keep runtime, device, hugepage, package-install, credential, network, and production actions outside source skeletons
  unless the user explicitly approved that state change.
- If a full program would be too long or depends on unavailable package files, return a compact skeleton plus
  `unmet_prerequisites` and `verification_commands` instead of inventing missing helper code.

## Logging

- Register modules near the top of implementation files with `DOCA_LOG_REGISTER(MODULE);`.
- Library code should use `DOCA_DLOG_ERR/WARN/INFO()` macros.
- Samples and applications should use `DOCA_LOG_ERR/WARN/INFO()` macros.
- Do not use `printf()` in libraries except where an existing allow-list or test pattern makes it intentional.
- In copied sibling functions, verify that log text matches the checked variable and condition. Common mistakes include
  checking `producer` while logging `consumer`, checking `rx` while logging `tx`, or reporting `len == 0` when the
  branch checks `len != 0`.

## Memory And Scope

- Library code should use `priv_doca_*alloc` and `priv_doca_free` instead of direct `malloc`, `calloc`, or `free`.
- Samples and applications may use standard libc allocation when neighboring code does.
- Check allocation results and return `DOCA_ERROR_NO_MEMORY` on allocation failure.
- Match allocator and deallocator families. For example, `priv_doca_aligned_zalloc()` must be released with
  `priv_doca_aligned_free()`, `priv_doca_zalloc()` with `priv_doca_free()`, `malloc()` with `free()`, `new` with
  `delete`, and `new[]` with `delete[]`.
- In `goto` cleanup chains, label names should describe the resource they clean, and labels should appear in reverse
  acquisition order. For every `goto`, confirm that the target label and fall-through labels only touch resources that
  have already been initialized at that point.
- Do not modify vendored code under `third_party/` unless the task explicitly targets that vendor copy.

## General Practice

- Define constants instead of repeating magic numbers in production code.
- Use named booleans for repeated or non-obvious conditions.
- Do not hard-code hardware identifiers such as PCI addresses, MAC addresses, IP addresses, device paths, or representor
  names in source. Discover them from arguments, configuration, or runtime sensors.
- Keep declarations and defines near the top of files, following local layout.
- Place static helpers before exported function implementations unless local style clearly differs.
- When fixing a bug, search for similar code paths in sibling modules.
- When a signature changes, verify all call sites.
