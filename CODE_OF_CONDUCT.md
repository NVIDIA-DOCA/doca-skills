# Code of Conduct

The NVIDIA DOCA Agent Skills bundle is part of the NVIDIA Skills ecosystem and
adheres to the [Contributor Covenant](https://www.contributor-covenant.org/),
version 2.1.

The full text lives at
<https://www.contributor-covenant.org/version/2/1/code_of_conduct/>; the
canonical NVIDIA-wide adoption lives at
<https://github.com/NVIDIA/skills/blob/main/CODE_OF_CONDUCT.md>. This file
exists so that the standalone DOCA bundle satisfies the publishing-onboarding
contract without forcing the reader to leave the repository.

## TL;DR

- Be respectful and constructive. Disagree on the technical content, not on
  the person.
- The bundle ships *guidance for AI agents that run on a customer's real
  hardware*. A safety bug here can take down a customer's BlueField. Treat
  contributions about hardware safety, version pinning, and rollback paths
  with the same care you would give a production change.
- No private commercial information, no embargoed feature names, no
  NVIDIA-internal URLs. Public sources only, enforced by
  [`ci/check-skill.sh`](ci/check-skill.sh).
- Follow [`CONTRIBUTING.md`](CONTRIBUTING.md) for the rules of engagement and
  [`AUTHORING.md`](AUTHORING.md) for the deep contributor contract.

## Reporting

Conduct issues that are **not** safety bugs in skill content:

- Open an Issue on this repository and tag it `coc`.
- If the issue involves a specific contributor and you want it handled
  privately, email the maintainers listed in `CODEOWNERS` (or, if none,
  NVIDIA's open-source maintainers via the address listed at
  <https://github.com/NVIDIA/skills/blob/main/CODE_OF_CONDUCT.md>).

Safety bugs in skill content — wrong rollback procedure, missing safety
pre-flight, hot-applied `mlxconfig`-class change — go through the
`safety-bug` Issue flow described in [`SECURITY.md`](SECURITY.md). Those are
treated as on-call work, not Code-of-Conduct matters.

## Scope

This Code of Conduct applies to:

- All interactions on this repository (Issues, Pull Requests, Discussions,
  review comments, commit messages).
- Out-of-band channels used to coordinate work on this repository (email
  threads, internal NVIDIA channels mirrored back to this repo, public
  forums where this repository is being discussed).
