# DOCA setup workflows

Read this file when the loader sent you here from [SKILL.md](SKILL.md). For the underlying surface (install profiles, build flavors, version-compatibility rules, error taxonomy, observability cues, safety constraints), see [CAPABILITIES.md](CAPABILITIES.md). For where to find official documentation, the on-disk install layout, or release notes, route through [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

Each verb below describes the **shape of the workflow**, not a copy-paste recipe. The agent's job is to walk the user through the steps in order, verifying preconditions before recommending the next call. Library-specific overrides (e.g. which sample is the right starting point for *Flow* first apps, which fields to swap) live in the matching library skill, *not* here.

## configure

Goal: prepare the user's host environment so that builds can find DOCA and runs can find the resources they need.

Steps the agent should walk the user through:

1. **Confirm install presence and version.** Use the procedure in [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) (do not duplicate). Quote the observed `pkg-config --modversion doca-common`; do not assume "latest". The version-compatibility rules in [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility) determine whether what the user has on disk is a coherent install or a partial upgrade that needs reinstalling first.

2. **Set `PKG_CONFIG_PATH` for the build environment.** The DOCA `*.pc` files live at `/opt/mellanox/doca/infrastructure/lib/pkgconfig/`. Add this to `PKG_CONFIG_PATH` in the user's shell profile (or in the build invocation itself) so that `pkg-config --modversion doca-flow` (or any other DOCA module) succeeds. Verify with `pkg-config --list-all | grep -i doca`. If the list is empty, the path or the install profile is wrong — see [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).

3. **Set `LD_LIBRARY_PATH` for the runtime, if using the trace build flavor.** During first-app development, prefer the trace flavor — see [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes) for the rationale. Either link with the `doca-<lib>-trace` `pkg-config` module at build time, or set `LD_LIBRARY_PATH=/opt/mellanox/doca/lib/<arch>-linux-gnu/trace:$LD_LIBRARY_PATH` at runtime.

4. **Mount and reserve hugepages.** Required by all DPDK-based DOCA libraries (Flow in particular). The agent must read [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy) item 2 before recommending the change; hugepages are global state. The minimum-viable sequence is:

   ```bash
   echo '1024' | sudo tee -a /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
   sudo mkdir -p /mnt/huge
   sudo mount -t hugetlbfs -o pagesize=2M nodev /mnt/huge
   ```

   Verify with `mount | grep huge` and `cat /proc/meminfo | grep -i huge`.

5. **Confirm device and representor visibility.** `devlink dev show` lists the network devices the kernel sees; `cat /sys/class/net/*/phys_port_name` shows the names of any active representors. If the user expects representors and the listing is empty, switching the eswitch to `switchdev` mode is required (`devlink dev eswitch set <pcie> mode switchdev`) — but only with the user's explicit consent, since the change disrupts existing flows.

6. **Sanity-check before any build work.** Confirm with the user: which BlueField (or which host PCIe slot), which install version, which mode (host / DPU / switch). If any of these is unclear, stop and ask.

## build

Goal: build a shipped DOCA sample so that the user has a known-good binary to run before they write any custom code.

Steps the agent should walk the user through:

1. **Pick a sample matching the library the user wants to learn.** The shipped samples live under `/opt/mellanox/doca/samples/<library>/<sample_name>/`. The agent must pick the *smallest* sample that exercises the feature the user asked about — never the most feature-complete one. For Flow first apps, the recommended source samples are listed in [`doca-flow TASKS.md ## build`](../doca-flow/TASKS.md#build); for other libraries, refer to the matching library skill.

2. **Read the sample's own `meson.build` and `README` first.** Every shipped sample has its own build manifest and a short README. The agent must read these (or have the user paste them) before issuing any build command — do not assume the canonical `meson /tmp/build && ninja -C /tmp/build` works for every sample, because some require additional `-D` options or specific toolchains.

3. **Build into a temporary out-of-tree directory.** Never build into `/opt/mellanox/doca/`. The standard pattern:

   ```bash
   cd /opt/mellanox/doca/samples/<library>/<sample_name>/
   meson /tmp/build-<sample_name>
   ninja -C /tmp/build-<sample_name>
   ```

4. **Surface build errors against the setup error taxonomy first.** If `meson` reports a missing dependency or `ninja` reports an undefined reference, do not attempt to "patch the sample" — these are setup-class symptoms, not code bugs. Map them to [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy) and fix the underlying `PKG_CONFIG_PATH`, install profile, or build flavor first.

## modify

Goal: take a working shipped sample and **derive a custom first application** for the user, by editing a verbatim copy of the sample on the user's own DOCA-installed Linux host. The substance of the modified file is NVIDIA's BSD-3 sample (verified, compiled, shipped) with a small, named set of user-domain values swapped. The agent does **not** author DOCA library source code from scratch.

**Language scope of this verb.** The shipped DOCA samples are written in C; this is the only application source code NVIDIA ships in this repository. The "modify a sample" workflow below is therefore the C / C++ first-app track. For consumers writing their first DOCA application in another language (Rust, Go, Python, …), this verb is *not* the right path — those users should still use `## configure` and `## build` (against the shipped C samples) to verify their install is healthy, and then route to the matching library skill's "non-C consumers" guidance for FFI / bindings work (e.g. [`doca-flow TASKS.md ## build` Track 2](../doca-flow/TASKS.md#build)). The agent must not pretend the modify-a-sample workflow produces a Rust crate, a Go module, or a Python package; the workflow's output is a modified copy of NVIDIA's C sample.

The generic pattern below is library-agnostic *across DOCA libraries* (Flow, RDMA, Comch, …) but C-specific *within a library*. Library-specific values (which sample, which fields the user must change, which actions to keep) live in the matching library skill — for Flow, see [`doca-flow TASKS.md ## build`](../doca-flow/TASKS.md#build).

### Precondition

This verb requires *all* of:

| Precondition | Check |
| --- | --- |
| Linux host the agent can reach (the user's machine, an SSH session, a Cursor remote, a container — any environment where the agent can `ls` the install tree) | shell available |
| DOCA installed | `ls /opt/mellanox/doca` returns a populated tree |
| The source sample is present | `ls /opt/mellanox/doca/samples/<library>/<sample_name>/` lists `meson.build` and the source files |
| `pkg-config` knows DOCA | `pkg-config --modversion doca-<library>` returns a version string |

If any precondition fails, **do not proceed and do not invent a substitute**. Route to [`## no-install`](#no-install) below; that section is what the agent does instead. Authoring application source code in *any* language (C, C++, Rust, Go, Python, …) from documentation prose to "fill the gap" is the failure mode this verb is here to prevent — it violates [`AGENTS.md`](../../../AGENTS.md) ground rule #3 and would ship code that has never been compiled / linked / FFI-loaded against the live DOCA library.

### Steps (preconditions met)

1. **Identify the source sample.** Use the smallest shipped sample that already does something close to what the user asked for. Confirm it builds clean (`## build` above) and runs clean (`## run` below) *before* any modification. The library skill names the right starting sample for common shapes; do not pick from memory.

2. **Read the actual contents of the sample.** Before describing the file, list it (`ls`) and read the `meson.build` plus each `.c`/`.h`. The shape of the sample on the user's installed version is the truth, not what an older release looked like or what a docs page describes.

3. **Copy the sample out of `/opt/mellanox/doca/` into a writable location.**

   ```bash
   cp -r /opt/mellanox/doca/samples/<library>/<sample_name>/ ~/dev/my-first-<library>-app/
   cd ~/dev/my-first-<library>-app/
   ```

   Never edit the install tree itself ([CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy) item 1). The copy is the user's source code from this point forward.

4. **Identify the *minimum* set of values to change in the copy.** Library-specific list lives in the library skill. For *every* library the recipe is the same shape: keep all init/teardown boilerplate; keep the validation calls; keep the error handling; only swap the small set of user-domain values (target MAC, target port_id, queue depths, packet-size limits, etc.). Every byte not changed is a byte not debugged.

5. **Apply the swap as a minimum-diff edit on the copied file.** Where the user has given you a real value, substitute the literal. Where the user has not yet given you a value but the build would otherwise fail to compile, leave a `/* TODO: replace with your <thing>; see <how-to-find-it> */` comment around a syntactically-valid placeholder constant. The placeholder rule is **only for values that block compilation if absent** (constants, `#define`s the rest of the file references); it is not a license to leave function bodies or DOCA API call sequences unfilled. The init/teardown/validation/error-handling calls all stay verbatim from the upstream sample.

   Example placeholders (note: the *surrounding code* is the upstream sample's, untouched):

   ```c
   /* TODO: replace with your destination MAC. Use `ip link show <iface>` on
    * the originating host to obtain the real value. */
   uint8_t target_mac[6] = { 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 };

   /* TODO: replace REPRESENTOR_PORT_ID with the port_id reported by the
    * sample's enumeration printout for your representor. */
   #define REPRESENTOR_PORT_ID 1
   ```

6. **Update the build manifest minimally.** The simplest correct change to the sample's `meson.build` is to rename the executable; do not refactor build options. If the original sample required `-D enable_<flag>=true`, keep that option in your build invocation. If the user's project must build *standalone* (outside the DOCA samples meson tree), the `meson.build` becomes a small standalone manifest that depends on `doca-<library>` via `pkg-config` — the canonical pattern is documented in the library skill's `## build`. The agent should construct this `meson.build` inline against the user's project, *not* by copying a template from this skill.

7. **Build and run staged.** Build with `## build`. Run with `## run` against a single representor with controlled traffic ([CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy) item 4). Read the output. Only after the staged run succeeds may the user widen the scope (more entries, more representors, real traffic). Library-specific staging discipline lives in the library skill.

8. **Document what was changed.** A two-line `README` next to the modified sample saying *"Derived from `<source-sample>` on `<date>` against DOCA `<version>`. Modified fields: `<list>`."* lets the user re-derive against the next DOCA release without having to re-read the agent's chat history.

## no-install

Goal: behave correctly when the [`## modify` preconditions](#precondition) are not met — i.e., the user has asked for a "first app" or any other modify-class task on a host where DOCA is not installed (a fresh laptop, a CI runner, a remote machine with no DOCA package, etc.). This applies regardless of the user's chosen language: Python, Rust, Go, and Node consumers all need the DOCA `*.so` to bind against, and a fresh laptop with no install can't provide that any more than it can provide the C samples.

The wrong behavior — and the failure mode that this section exists to prevent — is for the agent to author DOCA application source code from documentation prose (in *any* language: C, C++, Rust, Go, Python wrapper, etc.), mark unknowns with placeholder comments, and present it as a "first app". That output looks complete to the user, won't compile or link against any real DOCA install, and breaks the user's trust in every other answer the skill produces. Don't.

### What the agent does instead

1. **State the limitation explicitly, once.** Tailor the wording to the user's language but keep the substance the same: "DOCA needs a Linux host with the DOCA install tree, a `pkg-config doca-<library>` that resolves, and (for any language other than C/C++) the `*.so` libraries available for FFI / bindings to load. I can't write your first app from this environment because the verified pieces — the shipped C samples in the C/C++ track, or the `*.so` and headers your bindings will link against in any other language — live on a host I can't reach. Here's exactly what I *can* do, and exactly what you do next."

2. **Hand the user the procedure they will execute on the install host.** Library- and language-aware:
   - **C / C++ track** — the procedure mirrors the `## modify` "Steps" section above, with library-specific values filled in from the matching library skill (e.g. [`doca-flow TASKS.md ## build` Track 1](../doca-flow/TASKS.md#build) for Flow).
   - **Other-language track** — the procedure is: install DOCA, confirm `pkg-config --cflags --libs doca-<library>` resolves, locate the headers under `/opt/mellanox/doca/infrastructure/include/`, then route to the matching library skill's non-C guidance (e.g. [`doca-flow TASKS.md ## build` Track 2](../doca-flow/TASKS.md#build) for Flow) for the bindings/FFI-side work the user does in their own toolchain.
   In both cases, *no* application source code is written in this conversation — the procedure is what the user runs against the real install once they reach it.

3. **Walk the user through reaching an install host.** Three honest paths, named in order of cost:

   | Path | When it fits | What to walk the user through |
   | --- | --- | --- |
   | **A. Existing Linux+DOCA host** (lab box, dev server, BlueField over `rshim`) | Most common case at NVIDIA | SSH or Cursor-remote into it; rerun `## modify` from there. |
   | **B. Cloud Linux instance, no NIC** | User wants to build samples, read the API, or experiment with bindings; can't run against hardware | Pick any Linux distro listed under the [DOCA Host Supported OS table](https://docs.nvidia.com/doca/sdk/installation-guide-for-linux/index.html). Install via the Installation Guide; the **build-only** parts of `## modify` (and the bindings-build parts of the non-C track) work; the actual runtime needs hardware (Path C). |
   | **C. Linux + ConnectX/BlueField hardware** | User wants the real end-to-end runtime | Either user-owned hardware, an internal lab allocation, or the [DOCA Downloads page](https://developer.nvidia.com/doca-downloads) for the BFB image to bring up a BlueField. The agent does *not* recommend specific cloud SKUs by name unless they are listed in the public Supported OS table; cloud GPU/ARM SKUs do not generically include DOCA-eligible NICs and the agent must not pretend otherwise. |

4. **Do not scaffold a project on the un-installed host.** Do not produce `meson.build`, `CMakeLists.txt`, `Cargo.toml`, `setup.py`, `go.mod`, an application source file in any language, project directories, or any artifact that would mislead the user into thinking a build is one command away. The agent's *only* artifacts in this state are: (a) the install/path procedure for the user to run on the install host, and (b) the menu above. The skill's claim is "I'll be useful the moment you reach a real install"; making artifacts now would dilute that claim with files that are not buildable in this environment.

5. **Promise the resumption.** Tell the user: "When you're on the install host, paste me the output of `pkg-config --modversion doca-<library>` and `pkg-config --cflags --libs doca-<library>`, plus (C/C++ track) `ls /opt/mellanox/doca/samples/<library>/<sample_name>/` or (other-language track) the `*.so` filename your bindings will load. I'll resume from `## modify` step 1 (C/C++) or from the matching library skill's bindings guidance (other languages) with the real install in hand."

## run

Goal: launch a built sample (shipped or derived) and read its output meaningfully.

Steps the agent should walk the user through:

1. **Pre-run checklist.** Hugepages mounted, devices visible, representors enumerated — re-verify with the [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability) commands. A failed pre-run check is faster to diagnose than a runtime error.

2. **Use the sample's own CLI flags.** Each shipped sample documents its `-h` flags. The agent must use those, not invent new ones — the most common runtime error is a flag rename across DOCA versions.

3. **Run with verbose logging the first time.** Add `--sdk-log-level 70` (DOCA `LOG_TRACE`) on the first run of any new code path. Re-running with reduced verbosity once the path is known to work is a deliberate later step.

4. **Where logs go.** DOCA libraries log to stderr by default. Some long-running services log via `journald` or a configured log directory; check `/var/log/doca*` or the service's own README before assuming output is missing.

5. **Common runtime errors map to setup-class symptoms.** Map any startup failure against [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy) before falling back to library-internal `DOCA_ERROR_*` diagnosis. *"Cannot find any working PCI driver"*, *"No free 2048 kB hugepages"*, *"representor X not found"* — all setup, not library.

## test

Goal: verify the install is healthy enough that *any* library-level work is meaningful. Catch problems at the lowest layer before they propagate up.

Steps the agent should walk the user through:

1. **Install health check.** Run the [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability) install-layer commands. Empty output where output is expected = install is wrong; do not proceed.

2. **Capability snapshot.** `doca_caps` and (for Flow) the Flow capability-query API. Save the output. Library-internal capability cross-checks live in the library skill — for Flow, [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../doca-flow/CAPABILITIES.md#capabilities-and-modes).

3. **Smoke-test by building and running one shipped sample.** A *known-good* sample built and run cleanly is the cheapest possible end-to-end install validation. The agent should pick the smallest sample that exists for the library family the user cares about (e.g. `flow_dispatch` or `flow_port_fwd` for Flow; the equivalent for RDMA when that skill ships).

4. **Loopback / no-traffic run first.** Run the sample once with no real traffic offered to it. Successful start, clean shutdown, and zero counter increments is the expected baseline. Only then introduce traffic.

## debug

Goal: when something does not work, walk the layered diagnosis tree top-down so the agent does not jump to library-internal code-fix recommendations against a setup-class symptom.

Investigation order — **always**:

1. **Install layer.** Re-run the [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability) install-layer commands. If `pkg-config --modversion doca-common` itself fails, no library-internal advice is meaningful.
2. **Version layer.** `pkg-config --modversion doca-<lib>` against the user's runtime `doca_caps --version`. Mismatch = partial upgrade or stale build env; reinstall consistently before code changes.
3. **Build layer.** Did the user build into `/tmp/build*` (correct) or in-tree (wrong; permission errors will mislead)? Did they pick the right build flavor (release vs trace)?
4. **Runtime layer.** Hugepages mounted? Modules loaded? Representors visible? The matrix in [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy) maps each symptom to its likeliest cause.
5. **Library layer.** Only after (1)–(4) are clean: route the conversation to the library skill. For Flow, [`doca-flow TASKS.md ## debug`](../doca-flow/TASKS.md#debug) owns the `DOCA_ERROR_*` decision tree.

If the agent finds itself recommending a code change before completing (1)–(4), it is jumping layers — back up.

## Deferred task verbs

- **`install`.** Installing DOCA itself on a fresh host or BlueField is a knowledge-map question — the canonical Installation Guide and the package profile choice are documented there. Defer to [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package) and the Installation Guide URL it routes to.
- **Library API specifics.** Constructing a Flow pipe, RDMA queue setup, etc. — outside the scope of this skill. After this skill's verbs have produced a known-good environment, hand off to the matching library skill (e.g. [`doca-flow`](../doca-flow/SKILL.md)) for API-level guidance.
- **`deploy` / `rollback`.** Provisioning multiple BlueFields, coordinated firmware/BFB updates across a fleet, or staged rollback — out of scope. Reserved for a future platform skill (`doca-platform-deploy` or similar). Until that ships, the agent should stop and tell the user this is fleet-orchestration scope and recommend they engage their platform team rather than guess.
