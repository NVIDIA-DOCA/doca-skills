# Setting Up Environment Variables On Linux Distributions

Applies to: local DOCA SDK build diagnostics on Linux distributions
Read when: a user asks how to set `PKG_CONFIG_PATH` for DOCA builds
Load next: `getting-started/pkg-config.md`, `getting-started/troubleshooting.md`

This topic router points to `getting-started/pkg-config.md`, which owns the
canonical `pkg-config` workflow. Use temporary shell exports for diagnostics;
do not edit persistent shell startup files unless the user explicitly asks.

## Discover Metadata Directories

```bash
find /opt/mellanox/doca -type d -name pkgconfig 2>/dev/null
pkg-config --variable=pc_path pkg-config
```

## Debian And Ubuntu

Common multiarch layouts may use an architecture-qualified directory:

```bash
export PKG_CONFIG_PATH="/opt/mellanox/doca/lib/$(uname -m)-linux-gnu/pkgconfig:/opt/mellanox/doca/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
```

## RHEL-Like Distributions

Common 64-bit layouts may expose package metadata under `lib64`:

```bash
export PKG_CONFIG_PATH="/opt/mellanox/doca/lib64/pkgconfig:/opt/mellanox/doca/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
```

After setting the variable, verify the specific dependency:

```bash
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```
