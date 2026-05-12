# pkg-config Guidance

Applies to: SDK-facing Meson builds, standalone samples, and dependency checks
Read when: a DOCA build needs local package dependency discovery
Load next: `getting-started/sdk-development.md`, `getting-started/troubleshooting.md`, `getting-started/validation.md`

Use `pkg-config` to prove which SDK packages the local environment exposes. Do
not install packages, edit system package paths, or infer package presence from a
header that happens to be visible.

## Discovery Commands

Start from the dependency names declared by the source package:

```bash
python3 tools/lookup_capability.py --repo-root . --api-index <capability-id>
```

Then check each required package:

```bash
pkg-config --modversion doca-common
pkg-config --cflags --libs doca-common
pkg-config --print-errors --exists doca-common
```

For Meson failures, repeat the check for the package name printed in the Meson
or `pkg-config` error, such as `doca-flow`, `doca-dpdk-bridge`, `doca-argp`, or
`libdpdk`.

## PKG_CONFIG_PATH

Prefer discovering `.pc` directories from the installed SDK instead of guessing
a single platform layout:

```bash
find /opt/mellanox/doca -type d -name pkgconfig 2>/dev/null
pkg-config --variable=pc_path pkg-config
```

If the SDK package is installed outside the default search path, prepend the
discovered directories for the current shell session only:

```bash
export PKG_CONFIG_PATH="/opt/mellanox/doca/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
```

Common Debian or Ubuntu multiarch layouts may use an architecture-qualified
directory:

```bash
export PKG_CONFIG_PATH="/opt/mellanox/doca/lib/$(uname -m)-linux-gnu/pkgconfig:/opt/mellanox/doca/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
```

Common RHEL-like layouts may expose 64-bit metadata under `lib64`:

```bash
export PKG_CONFIG_PATH="/opt/mellanox/doca/lib64/pkgconfig:/opt/mellanox/doca/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
```

These examples are diagnostic shell setup, not source changes. If none of the
candidate directories exist, report the missing `.pc` metadata as an unmet
prerequisite.

## Reporting Missing Dependencies

When dependency resolution fails, include a structured blocker:

```json
{
  "unmet_prerequisites": [
    {
      "kind": "pkg_config_dependency",
      "name": "doca-flow",
      "command": "pkg-config --modversion doca-flow",
      "next_step": "Install or expose the DOCA package that provides doca-flow.pc, then rerun the build."
    }
  ]
}
```

Do not rewrite include paths or library paths directly into a sample to bypass
the package metadata. Fix the environment, package metadata, or Meson dependency
declaration at the owning layer.
