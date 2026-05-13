# DOCA C And C++ Style

Applies to: `**/*.c`, `**/*.h`, `**/*.cpp`, `**/*.hpp`, `**/*.cu`, `**/*.cuh`
Read when: editing C, C++, CUDA, or header files in a DOCA source package
Load next: `modules/README.md`

Use this file for samples, applications, tools, and SDK-facing examples in the current source package. Follow
`.clang-format` and the surrounding file style. If a requested change depends on code that is absent from the source
package, report the missing path instead of inventing helper APIs or repository policy.

## Scope

- Prefer the existing local API, naming style, ownership model, and error handling pattern.
- Keep edits focused on the user-requested sample, application, tool, or header surface.
- Treat SDK headers as call evidence. Do not redesign an SDK API unless the user explicitly asks for an API change and
  the current source package contains the owning header and implementation.
- Keep runtime, device, hugepage, package-install, credential, network, and production actions outside source skeletons
  unless the user approves that action class.

## Naming And API Shape

- SDK calls usually use `doca_<module>_<action>()`.
- Local helper names should follow neighboring functions in the same file.
- `create` implies allocation or object creation. Use `set` for plain field updates.
- Prefer small configuration structs over long parameter lists for new user-owned helper interfaces.

## Headers And SDK APIs

- Include the SDK headers that define every API used by the code.
- Use include guards for new local headers.
- Preserve existing `extern "C"` wrappers, Doxygen comments, and `DOCA_STABLE` or `DOCA_EXPERIMENTAL` tags when editing
  SDK headers.
- Do not remove version, experimental, or capability checks that protect an SDK call.

## Error Handling

- DOCA-facing functions generally return `doca_error_t`.
- Use a single cleanup path when resources must be released.
- Preserve the first failing `doca_error_t` when a later cleanup step can also fail, following the local
  `DOCA_ERROR_PROPAGATE()` pattern when available.
- Prefer direct returns for simple wrappers, such as `return doca_action(ctx);`.
- Log specific failure reasons; avoid vague messages like `invalid parameter`.
- When logging a `doca_error_t`, include `doca_error_get_name(ret)` unless neighboring code intentionally uses a
  different formatter.

## Error Handling Checklist

- Initialize owned pointers and handles before the first possible cleanup jump.
- Make each cleanup label responsible for one acquisition layer and let labels fall through in reverse acquisition
  order.
- Log the failing API, object, or parameter name with enough context to act on it.
- In callbacks, record task status and ownership changes clearly. Do not submit new work, progress the same progress
  engine recursively, or free task-owned resources unless the surrounding sample or application pattern does so.
- Separate validation failures from cleanup failures in sample output so users can tell whether setup, submission,
  progress, or teardown failed.

## Agent-Facing Skeletons

When an agent returns C or C++ skeleton code, make it compact but complete enough to audit:

- Include the SDK headers that define every API named in the skeleton.
- Initialize all owned handles, pointers, buffers, and task state before any branch can jump to cleanup.
- Show acquisition and cleanup in reverse order.
- Name callback-owned state explicitly.
- Return `unmet_prerequisites` and `verification_commands` when a full program depends on package files, devices, or
  tools that are not present.

## Logging And Allocation

- Samples, applications, and tools should use the logging macros used by neighboring files, commonly `DOCA_LOG_ERR`,
  `DOCA_LOG_WARN`, or `DOCA_LOG_INFO`.
- Avoid `printf()` for status or errors when neighboring DOCA logging macros exist.
- Use the allocator and cleanup family already used by neighboring code. Do not switch allocator families in a focused
  edit.
- Check allocation results and return `DOCA_ERROR_NO_MEMORY` on allocation failure.
- Match allocator and deallocator families, such as `malloc()` with `free()`, `new` with `delete`, and `new[]` with
  `delete[]`.

## General Practice

- Define constants instead of repeating magic numbers.
- Use named booleans for repeated or non-obvious conditions.
- Do not hard-code hardware identifiers such as PCI addresses, MAC addresses, IP addresses, device paths, or representor
  names. Discover them from arguments, configuration, or read-only discovery output.
- Keep declarations and defines near the top of files, following local layout.
- When a signature changes, verify all visible call sites in the current source package.
