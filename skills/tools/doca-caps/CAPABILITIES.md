# DOCA Capabilities Print Tool — Capabilities

This file is loaded by [`SKILL.md`](SKILL.md). It documents *what
`doca_caps` is*, *what it reports*, *what versions it ships in*, *what
its narrow error and observability surfaces look like*, and *the
read-only safety posture* that makes it the canonical first step in
other skills' workflows. For step-by-step invocations and the
capability-snapshot workflow, see [`TASKS.md`](TASKS.md).

## Capabilities and modes

`doca_caps` is shipped as a single read-only CLI binary at
`/opt/mellanox/doca/tools/doca_caps` on every DOCA install (host or
BlueField Arm) since DOCA 2.6.0. There is no daemon, no library to
link against, and no programmatic API. The user's entire interaction
model is *invoke the binary, read the printed output*.

The tool reports **five documented capability families**, per the
public DOCA Capabilities Print Tool guide:

1. **DOCA device list** — for every DOCA device, prints the PCIe
   address and per-device attributes (`ibdev_name`, `iface_name`,
   `iface_index`, `pci_func_type` (PF / VF / SF), `uplink_ib_port`,
   `mac_addr`, `ipv4_addr`, `ipv6_addr`).
2. **DOCA representor device list** — for every DOCA device, prints
   the PCIe address of every available DOCA representor and
   per-representor attributes (`ib_port`, `host_index`, `pf_index`,
   `vf_index`, `pci_func_type`, `hotplug`, `vuid`, `iface_name`,
   `iface_index`).
3. **DOCA library list** — prints the DOCA libraries supported by
   the running OS and their availability for specific OS targets.
   This is the documented authoritative answer to *"which DOCA
   libraries does this install actually support on my OS?"*
4. **DOCA library capabilities** — for every DOCA device, prints the
   capabilities it supports in every DOCA library. This is the
   documented authoritative answer to *"can DOCA library X actually
   do Y on this device?"*
5. **DOCA logger list** — prints the available logger names of DOCA
   libraries. Useful when configuring `doca_log_*` filters.

The two invocations the public guide explicitly walks through are
`--list-devs` and `--list-rep-devs`, both of which can be scoped to
a single PCIe address with `--pci-addr`. The exact, current flag
inventory and example output live in the public guide and in the
tool's own `--help` on the installed version — see
[`TASKS.md ## run`](TASKS.md#run).

The tool has **no execution modes** beyond the flag-driven
selection of which capability family to print. There is no
`--watch`, no streaming subscription, no JSON output mode in the
documented surface; if a feature like that lands in a future DOCA
release, treat the public guide and `--help` as ground truth and do
not assume legacy generic-CLI flags work.

## Version compatibility

- **Available since:** DOCA 2.6.0. On older DOCA installs the binary
  is not present; the right answer for "I can't find `doca_caps`" is
  to check the install version (e.g. via `pkg-config --modversion
  doca-common` or `cat /opt/mellanox/doca/applications/VERSION`) and
  route to [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
  if the version is < 2.6.0 or the install is missing.
- **Where it runs:** on the x86 / Arm host that has DOCA installed,
  *or* on the BlueField Arm side. Same binary, same flags; the set
  of devices it sees differs by execution context.
- **Output format stability:** the documented capability families
  (the five listed above) are stable across the recent DOCA train.
  The exact textual / column layout of the output is **not**
  contractually frozen and may evolve with releases — do not assume
  field positions or whitespace patterns survive a DOCA bump. If an
  agent needs to consume the output programmatically, the right move
  is to re-verify against the user's installed version, not to rely
  on a parser pinned to the version this skill was written against.
- **Per-OS library support:** capability family 3 ("DOCA library
  list") explicitly varies with the OS the install runs on; do not
  copy a library-availability claim from one host to another.

## Error taxonomy

`doca_caps`'s error surface is narrow because the tool is read-only,
takes no configuration, and does no orchestration. The error layers
the agent should distinguish, in escalating order:

1. **Tool-not-installed.** `doca_caps` does not exist at
   `/opt/mellanox/doca/tools/doca_caps`. Cause: DOCA is not installed
   on this host, the install is < 2.6.0, or the path was changed by
   the operator. Routing: [`doca-setup ## install`](../../doca-setup/TASKS.md#install).
2. **Permission / driver layer.** Tool runs but cannot enumerate
   devices because the underlying driver stack (`mlx5_core`, IB
   stack, etc.) is not loaded, the user lacks the privileges the
   install profile expects, or the BlueField mode is incompatible
   with the requested capability family. The tool's own message
   (and `dmesg` for the driver layer) is ground truth; do not guess.
3. **Empty / partial output, no error.** The tool exits 0 but reports
   zero devices or a representor list shorter than the operator
   expects. Cause: no DOCA-supported devices on this host (e.g. the
   public NGC DOCA container with no PCIe passthrough), or the device
   the user expected is excluded by the chosen `--pci-addr` scope.
   This is a *capability-snapshot finding*, not a tool failure —
   route the answer to the consumer of the snapshot
   ([`doca-setup ## test`](../../doca-setup/TASKS.md#test) or
   [`doca-programming-guide ## debug`](../../doca-programming-guide/TASKS.md#debug)).
4. **Library-capability mismatch.** Tool runs successfully and prints
   capabilities, but the user is asking *"why does library X say it
   doesn't support feature Y on my device?"*. That question belongs
   in the matching `libs/<library>` skill — `doca_caps` only reports
   the coarse per-device per-library capability surface, not the
   library-internal reasoning.

`doca_caps` does **not** participate in the cross-library
`DOCA_ERROR_*` taxonomy that DOCA libraries return through their C
API; it is a CLI, not a library call. For that taxonomy and the
program-side debug order, see
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).

## Observability

`doca_caps` is itself an **observability primitive** for the rest of
the bundle — it is *what other skills load to observe* the install
and the hardware before doing anything that changes state.
Specifically:

- [`doca-setup ## test`](../../doca-setup/TASKS.md#test) prescribes
  running `doca_caps --list-devs` (and `--list-rep-devs` where
  representors are in scope) as the documented install smoke-test.
- [`doca-programming-guide ## debug`](../../doca-programming-guide/TASKS.md#debug)
  prescribes running `doca_caps` early and **preserving its output
  as a capability snapshot** so subsequent debug steps have ground
  truth instead of guesses.
- The matching `libs/<library>` skills (e.g.
  [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-flow/CAPABILITIES.md#capabilities-and-modes))
  point back at `doca_caps` as the documented source of *coarse*
  per-device per-library capability claims, while reserving
  fine-grained library-internal capability checks for the library's
  own programmatic API.

The tool does not emit metrics, traces, or logs of its own beyond
the printed output. For the program-side observability surface (DOCA
log levels, `doca_log_*`, `DOCA_LOGGER_*` env vars) see
[`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability).

## Safety policy

`doca_caps` is the **safest tool the bundle prescribes**:

- **Read-only.** The tool prints; it does not configure, allocate,
  claim, or modify any DOCA, kernel, firmware, or device state. This
  property is what makes it the canonical first step before any
  workflow that *does* mutate state.
- **No persistent side effects on the host.** No files written to
  `/etc`, no daemons started, no devices reserved. Re-running it is
  free.
- **Safe to run inside the public NGC DOCA container.** Because it
  takes no configuration and writes nothing, an agent can run it as
  the very first action even on a host where the operator has not
  yet decided whether to keep DOCA installed; running it inside the
  NGC container is the documented zero-install path.
- **Quote what the tool said. Do not paraphrase capability claims.**
  If the user later asks *"does my setup support feature Y?"*, the
  correct answer is to point at the line of the snapshot that says
  so. If the snapshot does not show feature Y, the answer is *"this
  install / device combination does not report support for Y"* —
  not *"it should work, try it"*.
- **Do not invent flags.** The documented invocations are the
  authoritative surface. If the user asks for an output format or
  a flag the public guide does not list, the safe answer is "the
  installed `--help` is the source of truth — let me check it
  there", not a guess based on generic CLI conventions.

## Public-source pointer

The single canonical public source for `doca_caps` is the **DOCA
Capabilities Print Tool** page on `docs.nvidia.com`, reachable
through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
Do not invent flags, output formats, or capability families beyond
what that page documents.
