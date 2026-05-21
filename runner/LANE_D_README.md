# Lane D — Lane C v2 / real-lab adapter

`devops/runner/run_with_live_hardware.py` is the **real-lab adapter** for
the Lane C harness contract. Lane C v1 (`run_with_fixtures.py`) lets the
agent reason over **captured** stanza output from a synthesized fixture
pack; Lane C v2 extends the same contract to a **connected BlueField
host**, so the agent reasons over **live** stanza output collected by
the harness itself.

The design invariant is **symmetry**: a Lane C v2 run on a host *with*
hardware and a Lane C v2 run on a host *without* hardware produce
scenario-shaped directories of the same structure, so the downstream
prompt builder, scoring rubric, and mechanical scorer (`v1.score_answer`)
work unchanged. This keeps the harness CI-testable without a lab and
adds zero divergence between the two paths.

## Modes

| Mode          | What it does                                                                                                                  | When to use it                                                                                       |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `auto`        | Detects live capability (lspci + at least one `15b3:*` device + required binaries on PATH). Live if capable; fixtures otherwise. | Default. The right mode for a developer machine or shared CI runner that may or may not have HW.    |
| `live`        | Shells the read-only stanza commands; writes captured output into `<out>/live_captures/<scenario_id>/`. Fails with exit 2 if no HW visible. | The real-lab path. Use on a host with a connected BlueField when you want fresh live captures.       |
| `dry-run`     | Prints the exact argv the harness would run for each stanza row, but does not execute. Fails clean if `lspci` absent.         | Useful for verifying the command shape on a host that has the binaries but you don't want to capture. |
| `fixtures`    | Skips live capture entirely; behaves identically to `run_with_fixtures.py`. Bit-for-bit reproducible against prior Lane C runs.  | The right mode for sandbox CI and for re-running a known Lane C wave without re-capturing.          |

## Lab-access requirement (live mode)

Live mode requires **read-only** access to the binding-layer stanza
binaries on the lab host:

- `lspci` (required — used for the capability check)
- `devlink` (required — `dev show`, `port show`)
- `numactl` (required — `-H`)
- `lsmod` (required — post-filtered to mlx5_*)
- `pkg-config` (required — `--list-all` post-filtered to doca-*)
- `mlxconfig` (optional — `-d <bdf> q` for firmware snapshot; some hosts ship without it)
- `doca_caps` (optional — `--version`, `--list-devs`; only present after DOCA install)

The harness **does not** require root for the read-only stanza on a
standard BlueField host install. `mlxconfig -d <bdf> q` typically wants
root; rows that need root and lack it are recorded in the synthesized
`env.json._v2_meta.skipped_required` and the prompt is still rendered
from whatever rows succeeded.

## Read-only invariant (mutating-token rejection)

The harness ships an explicit `MUTATING_TOKENS` set. Any argv whose
tokens include `set`, `burn`, `reflash`, `fwreset`, `bind`, `unbind`,
`rescan`, `modprobe`, `rmmod`, `insmod`, `echo`, or `tee` is **rejected
at submit time** and recorded in `env.json._v2_meta.rejected_mutating`.
This makes it impossible for a future patch to silently turn the harness
into a mutating tool — a regression here is caught by
`devops/ci/check-live-hardware-harness.sh` check 5.

## CI gate

`devops/ci/check-live-hardware-harness.sh` is the Lane D smoke test the
harness must pass in any CI sandbox:

1. `--mode auto` falls back to fixtures cleanly when no HW is visible.
2. `--mode fixtures` produces a valid manifest from the v1 fixture pack.
3. `--mode live` fails with exit 2 + an explicit error when no HW visible.
4. `--mode dry-run` fails with exit 2 + an explicit error when `lspci` absent.
5. Mutating-token rejection list is intact.
6. The harness imports the v1 builders (no v1/v2 prompt drift).

Run via:

```bash
bash devops/ci/check-live-hardware-harness.sh
```

Expected: `6 pass, 0 fail`.

## End-to-end example (live host)

On a host with a connected BlueField:

```bash
python3 devops/runner/run_with_live_hardware.py \
    --mode live \
    --scenario-id production_lab_bf3 \
    --out-dir devops/runner/reports/lane_c_v2_$(date +%Y-%m-%d)
```

That produces:

- `devops/runner/reports/lane_c_v2_<date>/live_captures/production_lab_bf3/` — captured stanza files + synthesized `env.json`.
- `devops/runner/reports/lane_c_v2_<date>/prompts/production_lab_bf3.md` — the prompt body the agent sees.
- `devops/runner/reports/lane_c_v2_<date>/scoring/production_lab_bf3.md` — the rubric the downstream scorer applies.
- `devops/runner/reports/lane_c_v2_<date>/dispatch_manifest.json` — machine-readable index plus a `_v2_meta` block recording mode chosen, captured / skipped / rejected counts.

Then the downstream Lane C dispatcher (subagent / human / LLM API) is the
same as v1: read the prompt, generate the answer, drop it under
`raw_responses/`, and score with `python3 devops/runner/run_with_fixtures.py
--score-file <answer> --out-dir <same out dir>`.

## End-to-end example (sandbox / no HW)

On a CI sandbox or any host without BlueField, the same command falls
back to fixtures transparently:

```bash
python3 devops/runner/run_with_live_hardware.py \
    --mode auto \
    --out-dir devops/runner/reports/lane_c_v2_smoke
```

Output:

```
[auto] no live capability (lspci (required)); falling back to fixtures at devops/fixtures/hardware

Built 3 scenario artifact set(s) under devops/runner/reports/lane_c_v2_smoke
  bf3_healthy_host              prompt=bf3_healthy_host.md
  bf3_pcie_no_devices           prompt=bf3_pcie_no_devices.md
  bf3_version_mismatch          prompt=bf3_version_mismatch.md

Mode chosen: fixtures
```

The downstream pipeline is identical regardless of which mode was chosen.

## What Lane D explicitly does NOT do

- It does NOT shell mutating commands (firmware burn, eswitch mode change, SR-IOV count change, kernel module load / unload). Those are out of scope; the binding stanza is read-only by design.
- It does NOT invoke an LLM. Like v1, it produces the prompt + rubric + manifest, and the downstream layer (subagent dispatch / human / LLM API) generates and scores the answer.
- It does NOT replace the v1 fixture pack. Fixtures remain the canonical sandbox-CI signal; v2 is the additive real-lab signal.
- It does NOT auto-detect multiple BlueField devices. It picks the FIRST `15b3:*` device returned by `lspci -d 15b3:` and records that choice in `env.json.expected_agent_findings.first_device_bdf`. For multi-device labs, run the harness once per device with distinct `--scenario-id` values.
