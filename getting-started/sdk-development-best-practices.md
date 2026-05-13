# SDK Development Best Practices

Applies to: SDK-facing C/C++ code, samples, applications, and build snippets
Read when: a user asks for general DOCA SDK development best practices
Load next: `getting-started/sdk-development.md`, `framework/README.md`, `reference/c-cpp-style.md`

This topic router points to the canonical SDK development, sample/application, and C/C++ style guidance.

## Dependency Management

Use package-facing build metadata instead of guessed paths. Check `meson.build` and the API inventory before naming a
dependency:

```bash
grep -R "<symbol-or-topic>" libs/*/include/public 2>/dev/null
pkg-config --cflags --libs <pkg-name>
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

Missing dependencies are environment prerequisites. Report the failing command and package name; do not install
packages, edit persistent environment files, or embed absolute include/library paths in source.

## Build System Configuration

Keep Meson changes at the owning layer:

- Use existing options from `meson_options.txt` for global behavior.
- Preserve tab indentation in `meson.build` files.
- Check package-facing `meson.build` files before changing standalone sample or application builds.
- Keep runtime/device prerequisites separate from configure and compile validation.

## Practices To Preserve

- Teach one DOCA concept at a time.
- Discover package metadata and API availability from the local source view.
- Use Meson and `pkg-config` dependency names from the package-facing build files.
- Keep examples readable, with explicit setup and cleanup.
- Report missing dependencies as prerequisites rather than installing packages or guessing paths.
- Keep package-facing guidance free of site-specific infrastructure assumptions.
