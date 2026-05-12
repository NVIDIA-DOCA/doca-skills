# Public Public-Source Boundaries

Applies to: `applications/**`, `samples/**`, SDK-facing examples, publishable snippets
Read when: editing source intended to demonstrate or consume the DOCA SDK
Load next: `getting-started/sdk-development.md`, `getting-started/validation.md`

The repository treats `applications/` and `samples/` as public-source areas for
license-header checks. Agents editing these trees should preserve the public
license style used by neighboring files and avoid copying private-library
headers into sample or application code.

## Source Areas

- `samples/` contains compact examples for SDK users. Prefer clarity over
  clever reuse, and keep sample code close to the API being demonstrated.
- `applications/` contains larger programs that may combine several DOCA
  components. Follow the application-local structure before adding helpers.
- Public headers under SDK libraries still follow library-specific API rules;
  a public header is not the same thing as a public-source example.

## Public Content Rules

- Do not include private hostnames, private file-share paths, account names, or
  credential setup instructions.
- Do not depend on private CI or review workflow to explain how code should be
  built or validated.
- Prefer commands that start at the repository root and rely on standard tools
  such as Meson, Ninja, Git, and the repository scripts.
- Keep examples portable across supported Linux development environments unless
  the surrounding code is explicitly platform-specific.

## License And Generated Files

The license checker skips many documentation, generated, and configuration file
types, but source files under `samples/` and `applications/` still need the
public source license header unless a local exception already exists. Do not
modify vendored or generated files to satisfy style rules; find the owning
source or generator instead.
