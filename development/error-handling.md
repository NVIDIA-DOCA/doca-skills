# Error Handling And Logging Best Practices

Applies to: DOCA C/C++ source, samples, applications, and SDK-facing snippets
Read when: a user asks for error handling or logging guidance
Load next: `reference/c-cpp-style.md`, `getting-started/sdk-development.md`

This topic router points to the canonical C/C++ style guidance. Do not duplicate or override `reference/c-cpp-style.md`;
load it before writing or reviewing code.

## Best Practices

- Use `doca_error_t` for DOCA-facing error flow when local code does.
- Preserve the first failure when cleanup can also fail.
- Keep cleanup labels in reverse acquisition order.
- Log the failing API, object, or parameter name with actionable context.
- Follow neighboring code for `doca_error_get_name()` or module-specific error formatting.
- In samples and applications, separate setup, submission, progress, runtime, and teardown failures so users can
  identify the failed phase.

## Example Use Cases

Use this guidance when producing:

- A task lifecycle skeleton.
- A sample or demo application cleanup path.
- A review comment on vague logging.
- A troubleshooting explanation for setup or teardown failures.
