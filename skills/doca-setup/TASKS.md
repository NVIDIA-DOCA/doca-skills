# DOCA setup workflows

Read this file when the loader sent you here from [SKILL.md](SKILL.md). For the underlying env surface (install profiles, build-flavor disk locations, version-detection commands, error taxonomy, observability cues, env-side safety constraints), see [CAPABILITIES.md](CAPABILITIES.md). For the *programming-class* counterparts (the canonical build pattern, the universal modify-a-shipped-sample first-app workflow, the universal lifecycle, the cross-library `DOCA_ERROR_*` debug order), see [`doca-programming-guide`](../doca-programming-guide/SKILL.md). For where to find official documentation, the on-disk install layout, or release notes, route through [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

Each verb below describes the **shape of the workflow**, not a copy-paste recipe. The agent's job is to walk the user through the steps in order, verifying preconditions before recommending the next call.

This skill scopes itself to **env work**. Three of the six lint-required task verbs (`## build`, `## modify`, `## run`) describe their own substance in [`doca-programming-guide`](../doca-programming-guide/SKILL.md) after the env / program split — the anchors here exist for lint compliance and route there. The verbs this skill *owns* are `## configure`, `## test`, `## debug`, and the critical `## no-install` (the NGC container path included).

## configure

Goal: prepare the user's host environment so that builds can find DOCA and runs can find the resources they need. **Precondition for this verb is that the host has DOCA installed.** If it doesn't, route to [`## no-install`](#no-install) first.

Steps the agent should walk the user through:

1. **Confirm install presence and version.** Use the procedure in [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) (do not duplicate). Quote the observed `pkg-config --modversion doca-common`; do not assume *"latest"*. The version-detection rules in [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility) determine whether what the user has on disk is a coherent install or a partial upgrade that needs reinstalling first.

2. **Set `PKG_CONFIG_PATH` for the build environment.** The DOCA `*.pc` files live at `/opt/mellanox/doca/infrastructure/lib/pkgconfig/`. Add this to `PKG_CONFIG_PATH` in the user's shell profile (or in the build invocation itself) so that `pkg-config --modversion doca-flow` (or any other DOCA module) succeeds. Verify with `pkg-config --list-all | grep -i doca`. If the list is empty, the path or the install profile is wrong — see [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).

3. **Set `LD_LIBRARY_PATH` for the runtime, if using the trace build flavor.** The program-side rationale for picking trace vs release lives in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); the env mechanics here are: either link with the `doca-<lib>-trace` `pkg-config` module at build time, or set `LD_LIBRARY_PATH=/opt/mellanox/doca/lib/<arch>-linux-gnu/trace:$LD_LIBRARY_PATH` at runtime.

4. **Mount and reserve hugepages.** Required by all DPDK-based DOCA libraries (Flow in particular). The agent must read [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy) item 2 before recommending the change; hugepages are global state. The minimum-viable sequence is:

   ```bash
   echo '1024' | sudo tee -a /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
   sudo mkdir -p /mnt/huge
   sudo mount -t hugetlbfs -o pagesize=2M nodev /mnt/huge
   ```

   Verify with `mount | grep huge` and `cat /proc/meminfo | grep -i huge`.

5. **Confirm device and representor visibility.** `devlink dev show` lists the network devices the kernel sees; `cat /sys/class/net/*/phys_port_name` shows the names of any active representors. If the user expects representors and the listing is empty, switching the eswitch to `switchdev` mode is required (`devlink dev eswitch set <pcie> mode switchdev`) — but only with the user's explicit consent, since the change disrupts existing flows.

6. **Sanity-check before any program work.** Confirm with the user: which BlueField (or which host PCIe slot), which install version, which mode (host / DPU / switch). If any of these is unclear, stop and ask. Once these are confirmed, hand off to [`doca-programming-guide ## configure`](../doca-programming-guide/TASKS.md#configure) for the program-side configuration.

## build

> **Anchor exists for lint compliance.** The substance of this verb — the canonical `pkg-config doca-<library>` + meson build pattern, in two language tracks (C/C++ direct, non-C via FFI) — moved to [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build) when the env / program split happened. *Building a DOCA application is a programming verb, not an env verb.*
>
> If the user is asking *"how do I build a DOCA application?"*, route them there. If the user is asking *"why does my build fail with `pkg-config not finding doca-flow`?"* (an env-class symptom), the answer is in this skill — see [`## debug`](#debug) layer 3 and [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).

## modify

> **Anchor exists for lint compliance.** The substance of this verb — the universal *derive a custom first application from a shipped sample* workflow, with C/C++ + non-C language tracks and an explicit precondition gate — moved to [`doca-programming-guide ## modify`](../doca-programming-guide/TASKS.md#modify) when the env / program split happened. *Deriving a first app from a sample is a programming verb, not an env verb.*
>
> If the user is asking *"how do I derive a custom first app from a sample?"*, route them there (it's the meaty version with the precondition table, the C/C++ track steps, and the non-C track routing). The env-side preconditions that workflow assumes — install reachable, `pkg-config` resolves, samples present — are owned here; if the preconditions aren't met (e.g. the user has no DOCA install yet), [`## no-install`](#no-install) below is the right next step.

## run

> **Anchor exists for lint compliance.** The substance of this verb — running a built DOCA program, picking the right `--sdk-log-level`, mapping startup failures to env-class vs program-class — moved to [`doca-programming-guide ## run`](../doca-programming-guide/TASKS.md#run) when the env / program split happened. *Running a DOCA program is a programming verb; the env-class pre-run checklist (hugepages, devices, representors) is what this skill owns and what `## test` below verifies.*

## no-install

Goal: behave correctly when the user wants to do *anything* program-side (build a sample, derive a first app, run a program) but the env-class preconditions aren't met — i.e., the user is on a fresh laptop, a CI runner, a remote machine, or any host without DOCA installed. This applies regardless of the user's chosen language: Python, Rust, Go, and Node consumers all need the DOCA `*.so` to bind against, and a fresh host with no install can't provide that any more than it can provide the C samples.

The wrong behavior — and the failure mode this section exists to prevent — is for the agent to author DOCA application source code from documentation prose (in *any* language: C, C++, Rust, Go, Python wrapper, etc.), mark unknowns with placeholder comments, and present it as a *first app*. That output looks complete to the user, won't compile or link against any real DOCA install, and breaks the user's trust in every other answer the skill produces. Don't.

### What the agent does instead

1. **State the limitation explicitly, once.** Tailor the wording to the user's language but keep the substance the same: *"DOCA needs a Linux environment with the DOCA install tree, a `pkg-config doca-<library>` that resolves, and (for any language other than C/C++) the `*.so` libraries available for FFI / bindings to load. I can't write your first app from this environment because the verified pieces — the shipped C samples in the C/C++ track, or the `*.so` and headers your bindings will link against in any other language — live in an environment I can't reach yet. The good news is there's a public Stage-1 fallback that works on any OS with Docker — the NGC DOCA container — and three other paths depending on what you actually need. Here's the menu, and what I can do once you reach any of them."*

2. **Hand the user the procedure they will execute on the install host.** Library- and language-aware, with the substance owned by [`doca-programming-guide`](../doca-programming-guide/SKILL.md):
   - **C / C++ track** — the procedure is [`doca-programming-guide ## modify`](../doca-programming-guide/TASKS.md#modify) (the *modify-a-shipped-sample* workflow), with library-specific overrides from the matching library skill (e.g. [`doca-flow ## build`](../libs/doca-flow/TASKS.md#build) for Flow).
   - **Other-language track** — the procedure is [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build) Track 2 (FFI / bindings against the public C ABI), then library-specific guidance from the matching library skill.

   In both cases, *no* application source code is written in this conversation — the procedure is what the user runs against the real install once they reach it.

3. **Walk the user through reaching an install environment.** Four honest paths, named in order of *cost to start trying* (Path 0 is the universal default for any non-Linux user; the others are situational).

   | Path | When it fits | What the agent walks the user through |
   | --- | --- | --- |
   | **0. NGC DOCA container** (`nvcr.io/nvidia/doca/doca`) — **canonical first option for any user on macOS, Windows, or Linux without DOCA.** | The user wants to build samples, modify a sample, read the API surface, generate FFI bindings, learn — *anything except real-traffic runtime against a real NIC*. Works on any OS that runs Docker. Free; no NVIDIA hardware required. | (1) Install Docker (Docker Desktop on macOS / Windows; native Docker on Linux). (2) Browse the public NGC catalog at <https://catalog.ngc.nvidia.com/> and search `doca` — pick the tag that matches the user's needs (host-flavor for typical first-app work, DPU-flavor only if the user is targeting BlueField OS; CUDA-enabled if the user also needs CUDA; OS distribution; arch — the `arm64` variants run natively on Apple Silicon). (3) `docker pull nvcr.io/nvidia/doca/doca:<tag>`. The public DOCA images are anonymously pullable at the time of writing; if a particular tag asks for auth, sign up for a free NGC account at <https://ngc.nvidia.com>, generate an API key, and `docker login nvcr.io -u '$oauthtoken' -p <api-key>` once. (4) `docker run -it --rm -v $HOME/dev:/work nvcr.io/nvidia/doca/doca:<tag> bash`; inside the container the user has a real `/opt/mellanox/doca` install — `pkg-config --modversion doca-<library>` works, `ls /opt/mellanox/doca/samples/` works, and the workflows in [`## configure`](#configure), [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build), and [`doca-programming-guide ## modify`](../doca-programming-guide/TASKS.md#modify) all work. **Limitations to surface upfront:** no real NIC inside the container, so DPDK / DOCA calls that need real hardware will fail at runtime — that is *expected* and the right move at that point is to graduate the user to Path A or Path C below. |
   | **A. Existing Linux + DOCA host** (lab box, dev server, BlueField over `rshim`) | The user already has a DOCA-installed host — most common case at NVIDIA, less common for external users. | SSH or Cursor-remote into it; rerun the [`## configure`](#configure) workflow there, then hand off to [`doca-programming-guide ## modify`](../doca-programming-guide/TASKS.md#modify). |
   | **B. Fresh Linux instance, no NIC** (laptop running Ubuntu, cloud VM, etc.) | The user wants a *persistent, native* install (not container-scoped) but doesn't have NVIDIA hardware. | Pick any Linux distro listed under the [DOCA Host Supported OS table](https://docs.nvidia.com/doca/sdk/installation-guide-for-linux/index.html). Install via the Installation Guide; the **build-only** parts of [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build) and [`doca-programming-guide ## modify`](../doca-programming-guide/TASKS.md#modify) work; the actual runtime needs hardware (Path C). For most users, **Path 0 is faster and lighter** unless the user explicitly wants a non-container install. |
   | **C. Linux + ConnectX or BlueField hardware** | The user wants the real end-to-end runtime, including programmed flows and real packet behavior. | Either user-owned hardware, an internal lab allocation, or the [DOCA Downloads page](https://developer.nvidia.com/doca-downloads) for the BFB image to bring up a BlueField. The agent does *not* recommend specific cloud SKUs by name unless they are listed in the public Supported OS table; cloud GPU/ARM SKUs do not generically include DOCA-eligible NICs and the agent must not pretend otherwise. |

4. **Do not scaffold a project on the un-installed host.** Do not produce `meson.build`, `CMakeLists.txt`, `Cargo.toml`, `setup.py`, `go.mod`, an application source file in any language, project directories, or any artifact that would mislead the user into thinking a build is one command away. The agent's *only* artifacts in this state are: (a) the install / path procedure for the user to run in the chosen environment, and (b) the menu above. The skill's claim is *"I'll be useful the moment you reach a real install — including the NGC container, which is one `docker pull` away"*; making artifacts now would dilute that claim with files that are not buildable in this environment.

5. **Promise the resumption.** Tell the user: *"When you're inside the NGC container, the lab host, the cloud Linux VM, or the hardware host, paste me the output of `pkg-config --modversion doca-<library>` and `pkg-config --cflags --libs doca-<library>`, plus (C/C++ track) `ls /opt/mellanox/doca/samples/<library>/<sample_name>/` or (other-language track) the `*.so` filename your bindings will load. I'll resume from [`doca-programming-guide ## modify`](../doca-programming-guide/TASKS.md#modify) step 1 (C/C++) or from the matching library skill's bindings guidance via [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build) Track 2 (other languages) with the real install in hand."*

## test

Goal: verify the install is healthy enough that *any* program-level work is meaningful. Catch problems at the lowest layer before they propagate up.

Steps the agent should walk the user through:

1. **Install health check.** Run the [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability) install-layer commands. Empty output where output is expected = install is wrong; do not proceed. If no install is reachable at all, this is a [`## no-install`](#no-install) situation.

2. **Capability snapshot.** `doca_caps` and (for Flow) the Flow capability-query API. Save the output. Library-internal capability cross-checks live in the library skill — for Flow, [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../libs/doca-flow/CAPABILITIES.md#capabilities-and-modes).

3. **Smoke-test by building and running one shipped sample.** A *known-good* sample built and run cleanly is the cheapest possible end-to-end install validation. Use the canonical build pattern in [`doca-programming-guide ## build`](../doca-programming-guide/TASKS.md#build) (Track 1 for C/C++) and the run pattern in [`doca-programming-guide ## run`](../doca-programming-guide/TASKS.md#run). Inside an NGC container, the build half is the meaningful smoke test; the run half against real traffic requires a hardware path.

4. **Loopback / no-traffic run first.** Run the sample once with no real traffic offered to it. Successful start, clean shutdown, and zero counter increments is the expected baseline. Only then introduce traffic.

## debug

Goal: when something does not work, walk the layered diagnosis tree top-down so the agent does not jump to library-internal code-fix recommendations against an env-class symptom. The complementary program-class debug order (lifecycle, capability, error-description, library) lives in [`doca-programming-guide ## debug`](../doca-programming-guide/TASKS.md#debug).

Investigation order — **always**:

1. **Install layer.** Re-run the [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability) install-layer commands. If `pkg-config --modversion doca-common` itself fails, no library-internal advice is meaningful. If no install is reachable, this is a [`## no-install`](#no-install) situation.
2. **Version layer.** `pkg-config --modversion doca-<lib>` against the user's runtime `doca_caps --version`. Mismatch ⇒ partial upgrade or stale build env; reinstall consistently before code changes.
3. **Build layer.** Did the user build into `/tmp/build*` (correct) or in-tree (wrong; permission errors will mislead)? Did they pick the right build flavor (release vs trace; the program-side rationale lives in [`doca-programming-guide`](../doca-programming-guide/SKILL.md))? Build-time symptoms map to [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).
4. **Runtime layer.** Hugepages mounted? Modules loaded? Representors visible? The matrix in [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy) maps each symptom to its likeliest cause.
5. **Program / library layer.** Only after (1)–(4) are clean: route the conversation to [`doca-programming-guide ## debug`](../doca-programming-guide/TASKS.md#debug) for the universal lifecycle / capability / error-description / library order, and from there to the matching library skill (e.g. [`doca-flow ## debug`](../libs/doca-flow/TASKS.md#debug)) for library-specific overlays.

If the agent finds itself recommending a code change before completing (1)–(4), it is jumping layers — back up.

## Deferred task verbs

- **`install`.** Installing DOCA itself on a fresh host or BlueField is a knowledge-map question — the canonical Installation Guide and the package profile choice are documented there. Defer to [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package) and the Installation Guide URL it routes to. The fastest way to reach an install on a non-Linux host (or any host without DOCA) is [`## no-install`](#no-install) Path 0 (NGC container).
- **Build / first-app derivation / running a program.** These are *programming verbs*, not env verbs, and live in [`doca-programming-guide`](../doca-programming-guide/SKILL.md). After this skill's `## configure` and `## test` have produced a known-good environment, hand off there.
- **Library API specifics.** Constructing a Flow pipe, RDMA queue setup, etc. — outside the scope of this skill. After this skill's verbs have produced a known-good environment, hand off to [`doca-programming-guide`](../doca-programming-guide/SKILL.md) for the cross-library patterns and then to the matching library skill (e.g. [`doca-flow`](../libs/doca-flow/SKILL.md)) for API-level guidance.
- **`deploy` / `rollback`.** Provisioning multiple BlueFields, coordinated firmware/BFB updates across a fleet, or staged rollback — out of scope. Reserved for a future platform skill (`doca-platform-deploy` or similar). Until that ships, the agent should stop and tell the user this is fleet-orchestration scope and recommend they engage their platform team rather than guess.
