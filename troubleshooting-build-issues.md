# Troubleshooting Build Issues

Applies to: DOCA SDK sample and application build failures
Read when: a user asks for general DOCA build troubleshooting
Load next: `troubleshooting/build-validation.md`, `troubleshooting/meson-build-issues.md`, `getting-started/troubleshooting.md`

Use this as the general troubleshooting entrypoint. More specific Meson,
pkg-config, sample-staging, and build-validation rules live in the loaded files.

## Common Build Issues

- Missing `pkg-config` metadata for a DOCA dependency.
- Missing helper sources in a staged sample tree.
- Meson dependency names that differ from guessed library names.
- Runtime prerequisites being confused with build prerequisites.
- Package views that do not include the requested module.

## Resolution Pattern

Collect exact evidence, classify the blocker, and report the next safe command.
Do not install packages, mutate device state, edit persistent environment
configuration, or claim a build passed when only discovery succeeded.

Use this evidence shape for concise user-facing reports:

```json
{
  "failing_command": "<exact command>",
  "focus_path": "<sample-or-application-path>",
  "unmet_prerequisites": [
    {
      "kind": "pkg_config_dependency",
      "name": "<pkg-name>",
      "next_step": "Expose the package metadata, then rerun the build validation."
    }
  ]
}
```
