# Troubleshooting Meson Build Issues

Applies to: Meson configuration and compile failures in DOCA SDK source packages
Read when: `meson setup`, `meson compile`, or a package-facing Meson file fails
Load next: `getting-started/troubleshooting.md`, `getting-started/pkg-config.md`, `modules/README.md`

Use package-facing Meson files as evidence. Do not infer dependencies from memory when a nearby `meson.build` is
present.

## Common Issues

- `Dependency "<name>" not found`: verify the `.pc` metadata with `pkg-config --modversion <name>`.
- Header is found but link fails: verify `pkg-config --cflags --libs <name>` and the dependency name used by Meson.
- Source file missing from a staged tree: copy sources and include directories named by `meson.build`.
- DPDK feature check fails: report the package or symbol check that failed before editing source.

## Dependency Resolution Practice

Keep the response build-focused and reproducible:

- Name the exact failing Meson command.
- Name the dependency or source file that failed.
- Name the Meson file that declared the dependency.
- Provide the next safe diagnostic command.
- Stop before runtime/device mutation.
