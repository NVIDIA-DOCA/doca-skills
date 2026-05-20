# devops/fixtures/hardware — captured-output fixtures for the binding-layer stanza

This folder holds **synthesized but realistic** outputs for each row of the bundle's [hardware binding-layer command stanza](../../../doca-skills/AGENTS.md#hardware-binding-layer-command-stanza). Each scenario is a folder of `.txt` capture files (one per stanza command) plus a small `env.json` that describes the scenario shape so test harnesses can pick the right fixture.

The fixtures exist to validate Lane C of the bundle eval plan: *promoting the agent from "prescribes the stanza" to "reads stanza output and reasons from it."* The C″ / C‴ measurements show the agent prescribes the stanza correctly; this folder is what lets us measure the read-and-reason loop without a real BlueField.

**Provenance.** Every line in every file here is either (a) copy-pasted from a public NVIDIA DOCA / BlueField document, or (b) synthesized from a public document shape with anonymized BDF / serial / MAC values. No real customer or lab capture is in this folder. Real-lab integration is a separate adapter and lives outside this tree (see `devops/runner/run_with_fixtures.py` for the integration point).

## Scenarios

| Folder | Scenario | Bundle-correct answer shape |
| ------ | -------- | ---------------------------- |
| `bf3_healthy_host/` | x86 host with a BF3 SmartNIC visible at PCIe, OFED + mlx5_core loaded, DOCA installed, `doca_caps --list-devs` returns the device, all four version-chain commands agree. | Recognize → bare-metal deployment path; verification contract green at step 1 (preconditions); deploy-loop bridge not fired. |
| `bf3_pcie_no_devices/` | Host where `lspci -d 15b3:` returns nothing — the device is not bound, kernel module not loaded, or the device is in the wrong eswitch mode. | Debug-loop fires on Layer 7 (driver) / Layer 4 (link); single-variable mutation (load mlx5_core) is the first hypothesis; re-capture after `modprobe`. |
| `bf3_version_mismatch/` | `pkg-config --modversion doca-common` returns 2.7.0, `doca_caps --version` returns 2.9.0, BFB version 3.0.0 — three-way disagreement in the four-source detection chain. | Refuse to proceed with the verification contract until the version chain is coherent; route to `doca-version TASKS.md ## debug` layer 2. |

## Per-file convention

Each scenario folder contains the same set of stanza-output files (missing files in a scenario mean "this scenario's command produced no output," which is itself a signal):

| File | Stanza row | Producer |
| ---- | ---------- | -------- |
| `lspci.txt` | PCIe presence | `lspci -d 15b3:` |
| `devlink-dev.txt` | Driver / device state | `devlink dev show` |
| `devlink-port.txt` | Driver / device state (representors) | `devlink port show` |
| `numa.txt` | NUMA topology | `cat /sys/class/net/<iface>/device/numa_node` + `numactl -H` |
| `mlxconfig-q.txt` | Firmware / configuration snapshot | `mlxconfig -d <bdf> q` |
| `lsmod.txt` | Kernel module state | `lsmod \| grep -E 'mlx5_core\|mlx5_ib\|mlx_compat'` |
| `pkg-config.txt` | Version (env-side) | `pkg-config --modversion doca-common && pkg-config --list-all \| grep doca` |
| `doca_caps.txt` | Version (DOCA-side) | `doca_caps --version` |
| `doca_caps-list-devs.txt` | Capabilities | `doca_caps --list-devs` |
| `env.json` | Machine-readable scenario tag (host shape, what's healthy, what's broken) | hand-authored |

## How to use these fixtures in a test

```python
from pathlib import Path
import json

SCENARIO = Path("devops/fixtures/hardware/bf3_healthy_host")
env = json.loads((SCENARIO / "env.json").read_text())
stanza_capture = "\n\n".join(
    f"$ {producer}\n{(SCENARIO / fname).read_text().rstrip()}"
    for fname, producer in [
        ("lspci.txt",                "lspci -d 15b3:"),
        ("devlink-dev.txt",          "devlink dev show"),
        ("devlink-port.txt",         "devlink port show"),
        ("numa.txt",                 "for iface in ...; cat ...numa_node; numactl -H"),
        ("mlxconfig-q.txt",          "mlxconfig -d <bdf> q"),
        ("lsmod.txt",                "lsmod | grep -E 'mlx5_core|mlx5_ib|mlx_compat'"),
        ("pkg-config.txt",           "pkg-config --modversion doca-common; pkg-config --list-all | grep doca"),
        ("doca_caps.txt",            "doca_caps --version"),
        ("doca_caps-list-devs.txt",  "doca_caps --list-devs"),
    ]
    if (SCENARIO / fname).exists()
)
```

A test harness then feeds `stanza_capture` into the agent's prompt as *"this is what the binding-layer stanza returned on this host"* and confirms the agent's answer correctly reads, reasons over, and routes against the fixture content (it does NOT re-prescribe the commands; it reasons from them).

Concrete end-to-end harness: `devops/runner/run_with_fixtures.py` — dispatches one Cursor subagent per scenario through this fixture loop and produces a pass/fail per scenario.

## Adding a new scenario

1. Create a new folder under `devops/fixtures/hardware/` (kebab-case, descriptive: `bf3_iommu_off`, `bf2_legacy_eswitch`, `cx7_no_doca`, …).
2. Copy + adapt the same nine files from the closest existing scenario.
3. Add an `env.json` declaring `{ "shape": "...", "healthy": true|false, "broken": ["which-layer", "..."], "bundle_correct_route": "...", "synthesized_from": "<public-doc-url-or-shape-name>" }`.
4. Add a new row to the scenarios table above.
5. If the scenario's bundle-correct answer relies on a new keystone, add a corresponding gate check to `devops/ci/check-keystones.sh` so the keystone can't silently disappear.
