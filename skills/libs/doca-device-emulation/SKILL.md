---
name: doca-device-emulation
description: NVIDIA DOCA Device Emulation on BlueField — the UMBRELLA library for building emulated PCIe devices that the host sees as real PCIe peripherals while the implementation runs as DPU-side user-space code, covering three public sub-libraries (PCI Generic for raw PCIe emulation, virtio-net for emulated virtio NICs, virtio-fs for emulated virtio filesystems), the shared umbrella architecture (host binds its standard kernel driver; DPU runs the backend), the per-sub-library DOCA Core context, doorbell / DMA primitives for host ↔ DPU interaction, per-sub-library capability discovery via the `doca_devemu_*_cap_*` families, the per-sub-library `pkg-config` module selection rule, env preconditions (DPU-side privileges plus BlueField firmware-level enablement of the chosen emulation type), the distinction from the packaged services built on top (DOCA SNAP Service / DOCA Virtio-net Service), and debugging `DOCA_ERROR_*` returns from the device-emulation API.
kind: library
---

# DOCA Device Emulation

**Where to start:** This skill assumes DOCA is already installed
on the host AND on the BlueField, the user is doing **hands-on
emulated-PCIe-device work** from the DPU side (writing the
backend that the host's kernel driver will talk to over the
emulated PCIe surface), and the user knows which CLASS of
emulated device they want to build. Open
[`TASKS.md`](TASKS.md) if the user wants to *do* something
(configure / build / modify / run / test / debug); open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is
*what can Device Emulation express* on this DOCA version + this
BlueField generation + this firmware. If the user has not
installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. **Before
anything else, the agent must route the user to the right
sub-library** — DOCA Device Emulation is an *umbrella* that
covers PCI Generic (raw PCIe device emulation), virtio-net
(emulated virtio network device), and virtio-fs (emulated
virtio filesystem device); each sub-library has its own
context, its own `pkg-config` module, and its own capability
surface. The sub-library selection rule lives in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
If the user wants a packaged solution rather than a library
(e.g. *"I want NVMe SNAP on my host without writing the
backend myself"*, or *"I want a managed virtio-net daemon"*),
route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
to the DOCA SNAP Service / DOCA Virtio-net Service guides
— those services are *built on top of* this library and are a
different artifact than what this skill covers.

## Example questions this skill answers well

The CLASSES of Device Emulation questions this skill is built
to answer, each with one worked example. The agent should
treat the *class* as the load-bearing piece — the worked
example is a single instance.

- **"How do I expose a custom emulated PCIe device from the
  BlueField DPU to the host?"** — worked example: *"expose a
  virtio-net device from the BlueField so the host sees a
  virtio NIC backed by my own DPU-side code"*. Answered by
  the sub-library selection rule + the umbrella lifecycle in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the bring-up steps in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"Which sub-library do I need — PCI Generic, virtio-net,
  or virtio-fs?"** — worked example: *"the host needs to see
  a custom block-like device that does not match any standard
  virtio class"*. Answered by the sub-library selection table
  in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the routing decision in
  [`TASKS.md ## configure`](TASKS.md#configure) step 2.
- **"Does this BlueField + firmware actually let me emulate
  the device class I want, and what capabilities does my DOCA
  install expose for it?"** — worked example: *"can I emulate
  a virtio-fs device on this BlueField, and which of its
  feature bits is supported?"*. Answered by the dual-axis
  precondition rule (firmware-level emulation type must be
  enabled AND `doca_devemu_<sub>_cap_*` against the active
  `doca_devinfo` must agree) in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the env-precondition checklist in
  [`TASKS.md ## configure`](TASKS.md#configure) step 1.
- **"Is this `doca-device-emulation` library the right tool,
  or should I use the DOCA SNAP Service / DOCA Virtio-net
  Service?"** — worked example: *"I want NVMe storage to the
  host without writing any DPU-side backend code"*. Answered
  by the library-vs-service path-selection rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the deferred-topic boundaries in
  [`CAPABILITIES.md ## Deferred topic boundaries`](CAPABILITIES.md#deferred-topic-boundaries)
  which route to
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the packaged-service guides.
- **"Why does my virtio-net emulation create call return
  `DOCA_ERROR_NOT_PERMITTED` even though my DPU-side process
  has `doca_dev` access?"** — worked example: *"sudo on the
  DPU is fine but the virtio-net emulation slot is disabled
  in BlueField firmware"*. Answered by the dual-axis
  permission matrix in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the firmware-side env fix routed via
  [`TASKS.md ## configure`](TASKS.md#configure) step 1.
- **"Is this Device Emulation sub-library / capability on my
  installed DOCA version?"** — worked example: *"is the
  virtio-fs emulation surface available on the DOCA install I
  have, against this BlueField generation?"*. Answered by the
  version-compatibility overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
  which cross-links the canonical detection chain in
  [`doca-version`](../../doca-version/SKILL.md) and adds the
  per-sub-library `pkg-config` + `doca_devemu_*_cap_*` overlay.
- **"What does this `DOCA_ERROR_*` from a `doca_devemu_*` call
  mean and which layer caused it?"** — worked example:
  *"`DOCA_ERROR_NOT_SUPPORTED` from a virtio-net emulation
  create call — is it the BlueField generation, the firmware
  slot, or the DOCA version?"*. Answered by the Device
  Emulation overlay on the cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md).

## Audience

This skill serves **external developers building applications
that consume the DOCA Device Emulation library** — i.e., users
whose DPU-side code calls `doca_devemu_pci_*`,
`doca_devemu_virtio_*`, or `doca_devemu_virtio_fs_*` (directly
in C / C++, or through FFI / bindings from another language)
to expose an emulated PCIe device to the host that the host's
existing kernel drivers can drive as if it were a real PCIe
peripheral. It is *not* for NVIDIA developers contributing to
DOCA Device Emulation itself, and it is *not* the right
artifact for users who want a packaged emulated-device daemon
they do not have to write the backend for (the DOCA SNAP
Service and the DOCA Virtio-net Service are the packaged
options that build on top of this library).

**Language scope.** DOCA Device Emulation ships as a C library
with three public `pkg-config` modules — one per sub-library —
selected by which emulation class the user is building (see
the sub-library selection table in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)).
The shipped samples under
`/opt/mellanox/doca/samples/doca_device_emulation/` are
written in C. C and C++ consumers are the canonical case and
the worked examples in `TASKS.md` assume that path.
Other-language consumers (Rust, Go, Python, …) consume the
same `*.so` files through FFI or language-specific bindings;
the skill's contribution in that case is to keep the
sub-library selection, umbrella lifecycle, capability-discovery,
permission, and error-taxonomy guidance language-neutral, and
to route the agent to the public C ABI as the authoritative
surface that any wrapper will eventually call.

## When to load this skill

Load this skill when the user is doing hands-on DOCA Device
Emulation work from the DPU side, in any language. Concretely:

- Deciding which Device Emulation sub-library (PCI Generic,
  virtio-net, virtio-fs) the user needs — the umbrella
  selection question is *this skill's load-bearing first move*.
- Initializing the per-sub-library DOCA Core context on the
  DPU (one context per emulated device per sub-library) and
  configuring the doorbell / DMA primitives the host's PCIe
  driver will interact with.
- Reading per-sub-library capability surface via the
  `doca_devemu_pci_cap_*`, `doca_devemu_virtio_cap_*`, or
  `doca_devemu_virtio_fs_cap_*` query families against the
  active `doca_devinfo` BEFORE assuming a particular feature
  bit or device characteristic is available.
- Choosing between writing the backend with `doca-device-emulation`
  yourself and adopting a packaged service (DOCA SNAP Service
  / DOCA Virtio-net Service) that already wraps this library.
- Debugging a `DOCA_ERROR_*` returned from a `doca_devemu_*`
  call — in particular disambiguating *firmware-level
  emulation type not enabled* from *BlueField generation does
  not support this sub-library at all* from *DPU-side process
  lacks privilege* from *host-side kernel driver did not bind*.
- Designing or extending non-C bindings (Rust, Go, Python, …)
  that wrap one of the device-emulation sub-libraries — for
  the sub-library selection, umbrella lifecycle, capability-
  discovery, permission, and error-taxonomy rules the wrapper
  must honor.

Do **not** load this skill for general DOCA orientation,
install of DOCA itself, the host-side kernel driver for the
emulated device class (virtio-net / virtio-blk / virtio-fs
kernel drivers ship with the host kernel and are not part of
DOCA), the packaged SNAP / Virtio-net services (they are
separate artifacts with their own service guides), or for
standard NIC behavior on the BlueField data path (use
[`doca-flow`](../doca-flow/SKILL.md) +
[`doca-eth`](../doca-eth/SKILL.md) instead — Device Emulation
is for *custom* emulated devices, not for shaping the
BlueField's built-in NIC personality).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive Device
Emulation-specific material lives in two companion files:

- `CAPABILITIES.md` — what Device Emulation can express on
  this version + this BlueField generation + this firmware:
  the umbrella architecture (host sees an emulated PCIe
  device; DPU runs the backend), the sub-library selection
  rule (PCI Generic vs virtio-net vs virtio-fs), the per-
  sub-library Core context shape, the doorbell / DMA
  primitives that bridge host ↔ DPU, the per-sub-library
  capability-query family (`doca_devemu_*_cap_*`), the
  per-sub-library `pkg-config` module name, the Device
  Emulation error taxonomy mapped onto the cross-library
  `DOCA_ERROR_*` set, the observability surface, the
  library-vs-packaged-service path-selection rule, and the
  safety policy that gates env preconditions (DPU-side
  privileges, BlueField firmware-level emulation type
  enablement, BlueField generation actually supporting the
  emulation class).
- `TASKS.md` — step-by-step workflows for the six in-scope
  Device Emulation verbs: `configure`, `build`, `modify`,
  `run`, `test`, `debug`. Plus a `Deferred task verbs` block
  that points out-of-scope questions at the right next skill.

The skill assumes a host + BlueField pair where DOCA is
already installed at the standard location on both sides, the
BlueField firmware has the emulation type the user wants to
build enabled, the user has the privileges their public
install profile expects (in particular, sudo on the DPU side
to perform PCIe-level emulation), and the host kernel ships
the standard driver for the emulated device class the user is
building. It does not cover installing DOCA, flipping
firmware-level configuration, or installing host-side kernel
drivers — those paths go through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA Device Emulation application source
  code, in any language.** The verified source is the shipped
  C samples at
  `/opt/mellanox/doca/samples/doca_device_emulation/` (with
  sub-directories per sub-library). The agent's job is to
  route the user to those files and prescribe a minimum-diff
  modification on them via the universal modify-a-sample
  workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the Device Emulation-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **A specific emulated-device backend.** This library
  *provides the framework* for emulated PCIe devices; it does
  *not* implement a specific storage backend, a specific
  packet processor, or a specific filesystem. The agent must
  refuse to invent backend bodies and must route any *"what
  should my backend do"* question to the user's domain
  expertise and to the public sub-library guides reachable
  via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **Standalone build manifests** (`meson.build`,
  `CMakeLists.txt`, `Cargo.toml`, …) parked inside the skill.
  The agent constructs the build manifest *in the user's
  project directory* against the user's installed DOCA, where
  `pkg-config --modversion <the chosen sub-library's module>`
  is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of
  any kind. A mock or incomplete artifact in this skill's
  tree, even one labeled "reference", is misleading: users
  will read it as buildable.
- **DOCA SNAP Service / DOCA Virtio-net Service surface.**
  Those services are *separate artifacts* built on top of
  this library, with their own public service guides. Routing
  for them lives in
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md);
  conflating either service with the `doca-device-emulation`
  library is the single most common Device Emulation first-app
  design error.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (custom emulated PCIe device built on the
   `doca-device-emulation` library, not the packaged SNAP /
   Virtio-net services, not the host-side kernel driver, not
   standard NIC behavior).
2. **For the umbrella architecture, the sub-library selection
   rule (PCI Generic vs virtio-net vs virtio-fs), the per-
   sub-library Core context shape, the doorbell / DMA
   primitives, the per-sub-library capability-query rule,
   the per-sub-library `pkg-config` modules, the library-vs-
   packaged-service path-selection rule, the error taxonomy,
   the observability surface, and the safety policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify,
   run, test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-version`](../../doca-version/SKILL.md) for the
canonical DOCA version-handling rules (with the Device
Emulation overlay that the chosen sub-library's `pkg-config`
module plus the firmware-level emulation slot plus the
`doca_devemu_*_cap_*` query are all part of *"is this
emulation supported here"*), and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public DOCA
Device Emulation umbrella guide, the per-sub-library guide
linked from it, the DOCA SNAP / Virtio-net Service guide, or
in the on-disk install layout" rather than "Device Emulation-
specific guidance".

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation
  source and the on-disk layout of an installed DOCA
  package. The Device Emulation umbrella URL is
  <https://docs.nvidia.com/doca/sdk/DOCA-Device-Emulation/index.html>;
  per-sub-library guides are linked from the umbrella, and
  the packaged DOCA SNAP / Virtio-net services are listed
  under the DOCA Services umbrella as separate artifacts.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, DPU-side privilege checks, BlueField
  firmware configuration (including the per-sub-library
  emulation type enable), and the *I have no install yet*
  path with the public NGC DOCA container. This skill assumes
  its preconditions are satisfied AND that the firmware-level
  emulation type for the user's chosen sub-library is enabled.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule and adds
  the Device Emulation-specific per-sub-library `pkg-config`
  + `doca_devemu_*_cap_*` overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect /
  prefer / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library:
  the canonical `pkg-config` + meson build pattern, the
  universal modify-a-shipped-sample first-app workflow, the
  universal Core-context lifecycle, the cross-library
  `DOCA_ERROR_*` taxonomy, and the program-side debug order.
  This skill layers Device Emulation specifics on top.
- [`doca-comch`](../doca-comch/SKILL.md) — the right library
  when the user wants a *control-plane channel* between a
  host process and a DPU process over PCIe but does NOT want
  the host to see the DPU as an emulated PCIe device with a
  standard host kernel driver. Device Emulation hides the
  DPU behind a real-looking PCIe device class; Comch is an
  explicit host ↔ DPU IPC.
- [`doca-flow`](../doca-flow/SKILL.md) and
  [`doca-eth`](../doca-eth/SKILL.md) — the right libraries
  when the user wants to shape traffic on the BlueField's
  built-in NIC personality, not expose a *custom* emulated
  PCIe device. Device Emulation is for *new* emulated PCIe
  devices the host did not previously see; Flow / Eth are
  for the BlueField's existing NIC surface.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). Device Emulation-specific debug
  (firmware-level emulation type not enabled, sub-library
  mis-selected, host kernel driver not binding to the
  emulated device, virtio feature-negotiation failures)
  overlays on top of that ladder.

The DOCA SNAP Service and the DOCA Virtio-net Service are
**not in scope** for this skill — those are packaged daemons
built on top of `doca-device-emulation` for users who do not
want to write the backend themselves. They have their own
public service guides reachable via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
Conflating either service with this library is the single
most common Device Emulation first-app design error.
