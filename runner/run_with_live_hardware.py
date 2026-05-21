#!/usr/bin/env python3
"""run_with_live_hardware.py — Lane C v2 harness (real-lab adapter).

Lane C v1 (`run_with_fixtures.py`) lets the agent read captured stanza output
from a synthesized fixture pack and reason over it. Lane C v2 extends the same
contract to a CONNECTED BlueField host: the harness shells the binding-layer
stanza commands itself, captures the live output into a scenario-shaped
directory, and then hands the prompt + rubric off to the same downstream
dispatcher Lane C v1 uses.

The design goal is symmetry: a Lane C v2 run on a host WITH lab hardware
produces a scenario directory shaped identically to the fixture pack, so the
downstream prompt builder, scoring rubric, and `score_answer()` mechanical
scorer work unchanged. A Lane C v2 run on a host WITHOUT lab hardware MUST
fall back transparently to the existing fixture pack so the harness remains
fully testable in a sandbox.

Three explicit modes:

  --mode auto         Detect at startup: if `lspci -d 15b3:` returns at least
                      one device AND every required binary is on PATH, shell
                      the stanza live; otherwise fall back to fixtures and
                      warn loudly. Default mode.

  --mode live         Shell the stanza commands; fail (exit 2) if any
                      required binary is missing or `lspci -d 15b3:`
                      returns no devices. Use this in a real lab.

  --mode dry-run      Print the exact command that would be shelled for each
                      stanza row, but do NOT execute. Use in CI to validate
                      the harness contract without touching hardware.

  --mode fixtures     Skip live capture entirely; behave identically to
                      Lane C v1 (`run_with_fixtures.py`). Provided for
                      bit-for-bit reproducibility against prior Lane C runs.

  --mode remote       NEW (May-2026 hardware-lab wave). The harness runs
                      LOCALLY but every read-only probe command is shelled
                      OVER SSH against --remote-host (default user: root,
                      override via --remote-user). The remote host is
                      expected to carry the BlueField hardware; this lets
                      the CI driver (a sandboxed Jenkins agent) reuse the
                      same harness against a connected lab box without
                      requiring the BlueField to live on the build agent
                      itself. SSH auth comes from --ssh-pass-env (an env
                      var name holding the password; default
                      `DOCA_LAB_SSH_PASS` — Jenkins binds the cred id
                      `2f8ea6f8-6a80-43ff-aaa9-32b4a1abc0ac` into this env
                      var via the `withCredentials([usernamePassword(...)])`
                      block in `Jenkinsfile.skills.ci`).
                      Same READ-ONLY guard as --mode live: every argv goes
                      through `is_read_only_argv()` before being sent over
                      the wire.

Live capture writes to:

  <out-dir>/live_captures/<scenario_id>/<one file per stanza row>
  <out-dir>/live_captures/<scenario_id>/env.json   (synthesized from the
                                                   live system shape)

Then the downstream `build_scenario_artifacts()` from run_with_fixtures.py
runs on that directory and produces the prompt + rubric.

Lab-access requirement: live mode requires read-only access to the binding
stanza binaries — `lspci`, `devlink`, `lsmod`, `modinfo`, `mlxconfig` (read-
only `q`), `cat`, `numactl`, `pkg-config`, `doca_caps`. None of these mutate
hardware; they enumerate it. The harness explicitly does NOT shell
`mlxconfig set`, `devlink dev eswitch set`, `mlnx-fw-burn`, or any other
mutating command — the binding stanza is read-only by design, and the
harness preserves that invariant.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent  # doca-skills/
RUNNER_DIR = REPO_ROOT / "runner"
sys.path.insert(0, str(RUNNER_DIR))

# Re-use the v1 stanza catalogue + scenario object + prompt/rubric builders.
# The v2 contract is "produce a fixture-shaped scenario directory; then call
# the v1 builders". Importing keeps the two harnesses in lockstep.
#
# History note: pre-May-2026 the bundle had a sister `devops/` directory
# containing runner + fixtures. That directory has been merged into
# `doca-skills/` and the import path was updated accordingly. Any leftover
# `from devops.runner import ...` style call sites are now incorrect.
try:
    import run_with_fixtures as v1  # noqa: E402
except ImportError as exc:  # pragma: no cover - import-time sanity
    raise SystemExit(
        f"run_with_live_hardware.py requires run_with_fixtures.py as a sibling "
        f"under {RUNNER_DIR}: {exc}"
    )


# --- live capture commands -------------------------------------------------
#
# Each entry is (output_filename, label, command-list, optional-stderr-handling).
# Filenames mirror v1.STANZA_ROWS so the rendered prompts are bit-identical
# between live and fixture modes. Commands are READ-ONLY — never set / burn /
# bind / unbind / reflash. The harness rejects any future addition that
# does not satisfy `is_read_only_argv()`.
#
# Where a stanza row needs `<bdf>` / `<iface>` / `<pf>`, the harness picks
# the FIRST device returned by `lspci -d 15b3:` and the FIRST `mlx5_*` net
# interface. The synthesized env.json records which device was picked so the
# downstream scoring rubric can verify the agent reasoned over that device.

@dataclass
class StanzaCmd:
    fname: str
    label: str
    argv_template: list[str]
    required: bool = True
    requires_root: bool = False

    def materialize(self, ctx: dict) -> list[str]:
        return [arg.format(**ctx) for arg in self.argv_template]


LIVE_STANZA = [
    StanzaCmd("lspci.txt",                 "PCIe presence",
              ["lspci", "-d", "15b3:"], required=True),
    StanzaCmd("devlink-dev.txt",           "Driver / device state",
              ["devlink", "dev", "show"], required=True),
    StanzaCmd("devlink-port.txt",          "Driver / device state (ports)",
              ["devlink", "port", "show"], required=True),
    StanzaCmd("numa.txt",                  "NUMA topology (numactl -H)",
              ["numactl", "-H"], required=False),
    StanzaCmd("mlxconfig-q.txt",           "Firmware / config snapshot (mlxconfig -d <bdf> q)",
              ["mlxconfig", "-d", "{bdf}", "q"], required=False),
    StanzaCmd("lsmod.txt",                 "Kernel module state",
              ["lsmod"], required=True),  # post-filtered to mlx5_* in render
    StanzaCmd("pkg-config.txt",            "Version (env-side, pkg-config --list-all | grep doca)",
              ["pkg-config", "--list-all"], required=True),  # post-filtered to doca-* in render
    StanzaCmd("doca_caps.txt",             "Version (DOCA-side, doca_caps --version)",
              ["doca_caps", "--version"], required=False),
    StanzaCmd("doca_caps-list-devs.txt",   "Capabilities (DOCA enumerator)",
              ["doca_caps", "--list-devs"], required=False),
]

# Argv prefixes we explicitly REJECT so a future patch cannot turn the
# harness into a mutating tool. Add to this list, never remove from it.
MUTATING_TOKENS = {
    "set", "burn", "reflash", "fwreset", "bind", "unbind", "rescan",
    "modprobe", "rmmod", "insmod", "echo", "tee",
}


def is_read_only_argv(argv: list[str]) -> bool:
    """Reject argvs whose first non-binary token matches a mutating verb,
    or that pipe through `tee` / `echo > /sys/...`. Conservative; rejects
    on a false positive rather than risking a hardware mutation."""
    for tok in argv:
        if tok.lower() in MUTATING_TOKENS:
            return False
    return True


# --- remote-host SSH helpers (--mode remote) -------------------------------
#
# Used by Jenkins to drive the same READ-ONLY probe set against a connected
# lab host (default: lver-doca-4 — BlueField-3 ×2 + BlueField-2 ×1)
# without requiring the Jenkins build agent itself to carry hardware.
#
# Auth: password is read from an environment variable name supplied via
# --ssh-pass-env (default DOCA_LAB_SSH_PASS). Jenkins exports the var via
# `withCredentials([usernamePassword(credentialsId: '2f8ea6f8-...', ...)])`.
# We never log the password. We require `sshpass` on PATH; if it's missing
# the harness fails clean and prints the install hint rather than silently
# falling back to interactive prompting (which would hang in CI).

def _ssh_argv(remote_user: str, remote_host: str, ssh_pass_env: str | None,
              identity: str | None) -> list[str]:
    """Build the SSH argv prefix used to wrap every probe command."""
    base = ["ssh",
            "-o", "StrictHostKeyChecking=no",
            "-o", "PreferredAuthentications=password,publickey",
            "-o", "BatchMode=no",
            "-o", "ConnectTimeout=10",
            "-o", "NumberOfPasswordPrompts=1",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "LogLevel=ERROR",
            "-T",
            f"{remote_user}@{remote_host}"]
    if identity:
        # Key-based auth still goes through the same wrapper so the
        # mutating-token guard runs on remote argvs too.
        base = (base[:1]
                + ["-o", "PreferredAuthentications=publickey",
                   "-o", "IdentitiesOnly=yes",
                   "-i", identity]
                + base[1:])
        return base
    if ssh_pass_env:
        if not shutil.which("sshpass"):
            raise SystemExit(
                "ERROR: --mode remote with --ssh-pass-env requires `sshpass` "
                "on PATH (install: apt-get install -y sshpass / brew install "
                "esolitos/ipa/sshpass). Refusing to fall back to interactive "
                "prompt — would hang in CI.")
        pw = os.environ.get(ssh_pass_env, "")
        if not pw:
            raise SystemExit(
                f"ERROR: --ssh-pass-env={ssh_pass_env} is not set in the "
                f"environment. Jenkins must bind credential id "
                f"`2f8ea6f8-6a80-43ff-aaa9-32b4a1abc0ac` into ${ssh_pass_env} "
                f"via withCredentials([usernamePassword(..., passwordVariable: "
                f"'{ssh_pass_env}')]).")
        return ["sshpass", "-p", pw] + base
    return base


def detect_remote_capability(remote_user: str, remote_host: str,
                             ssh_pass_env: str | None,
                             identity: str | None) -> tuple[bool, list[str]]:
    """Equivalent of detect_live_capability() but executes the test commands
    on the remote host over SSH. Returns the same (capable, missing) shape."""
    missing: list[str] = []
    ssh_prefix = _ssh_argv(remote_user, remote_host, ssh_pass_env, identity)
    # 1. Connectivity smoke test.
    try:
        out = subprocess.run(
            ssh_prefix + ["echo OK"],
            capture_output=True, text=True, check=False, timeout=20,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
        missing.append(f"ssh connectivity failed: {exc}")
        return False, missing
    if out.returncode != 0 or "OK" not in (out.stdout or ""):
        err_excerpt = (out.stderr or "").strip().splitlines()[:3]
        missing.append(
            f"ssh smoke test failed (rc={out.returncode}): "
            + "; ".join(err_excerpt)
        )
        return False, missing
    # 2. Remote `lspci -d 15b3:` must show at least one device.
    out = subprocess.run(
        ssh_prefix + ["lspci -d 15b3:"],
        capture_output=True, text=True, check=False, timeout=30,
    )
    if out.returncode != 0 or not (out.stdout or "").strip():
        missing.append("remote `lspci -d 15b3:` returned no Mellanox/NVIDIA device")
        return False, missing
    # 3. Required remote binaries on PATH. We only require the LOAD-BEARING
    #    binding-layer probes — lspci, devlink, lsmod, pkg-config. Anything
    #    else (numactl, mlxconfig, doca_caps) is treated as optional so a
    #    partial-install lab host (no DOCA tools, no numactl) still passes
    #    the capability gate — the captures will simply record their
    #    absence, which is itself useful signal for the agent.
    required = ["lspci", "devlink", "lsmod", "pkg-config"]
    optional = ["numactl", "mlxconfig", "doca_caps", "flint", "mst",
                "bfver", "rshim", "mlxprivhost"]
    all_bins = required + optional
    check_expr = ("bash -c '"
                  + "; ".join(f'command -v {b} >/dev/null && echo HAVE:{b} || echo MISSING:{b}'
                              for b in all_bins)
                  + "'")
    bin_check = subprocess.run(
        ssh_prefix + [check_expr],
        capture_output=True, text=True, check=False, timeout=30,
    )
    have_set = set()
    for line in (bin_check.stdout or "").splitlines():
        line = line.strip()
        if line.startswith("HAVE:"):
            have_set.add(line.split(":", 1)[1])
    for b in required:
        if b not in have_set:
            missing.append(f"remote {b} not on PATH (required)")
    # Report optional gaps as informational only, not failure.
    optional_missing = [b for b in optional if b not in have_set]
    if optional_missing:
        print(f"[remote-detect] optional binaries missing on remote (informational): "
              f"{', '.join(optional_missing)}", file=sys.stderr)
    capable = not any("required" in m for m in missing)
    return capable, missing


def run_cmd_remote(argv: list[str], ssh_prefix: list[str],
                   timeout: int = 30) -> tuple[int, str]:
    """Run argv on the remote host over SSH. Read-only guard is re-applied
    here so a future patch can't add a mutating verb only on the remote
    leg."""
    if not is_read_only_argv(argv):
        return 99, f"REJECTED (remote): argv contains a mutating token: {argv}"
    # Build a remote bash command line. Quote each token individually with
    # shlex.quote so embedded spaces / shell metachars are safe.
    import shlex
    remote_cmdline = " ".join(shlex.quote(t) for t in argv)
    full = ssh_prefix + [remote_cmdline]
    try:
        out = subprocess.run(
            full, capture_output=True, text=True, check=False, timeout=timeout,
        )
        body = out.stdout if out.stdout else out.stderr
        return out.returncode, body
    except subprocess.TimeoutExpired:
        return 124, f"TIMEOUT after {timeout}s: ssh {argv}"
    except Exception as exc:  # pragma: no cover - defensive
        return 1, f"unexpected error (remote): {exc}"


# --- live detection --------------------------------------------------------

def detect_live_capability() -> tuple[bool, list[str]]:
    """Return (capable, missing_pieces). 'capable' is True iff:
       - `lspci -d 15b3:` succeeds AND returns at least one line, AND
       - every binary in the LIVE_STANZA argv[0] is on PATH (excluding optional rows).
    """
    missing: list[str] = []
    if not shutil.which("lspci"):
        missing.append("lspci (required)")
        return False, missing

    # Check at least one Mellanox/NVIDIA NIC is visible.
    try:
        out = subprocess.run(
            ["lspci", "-d", "15b3:"],
            capture_output=True, text=True, check=False, timeout=10,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
        missing.append(f"lspci invocation failed: {exc}")
        return False, missing
    if out.returncode != 0 or not out.stdout.strip():
        missing.append("no 15b3:* device returned by lspci -d 15b3: (host has no BlueField / ConnectX visible)")
        return False, missing

    # Only the LOAD-BEARING binding-layer probes are required. Any optional
    # row (numactl, mlxconfig, doca_caps, ...) being absent is captured as
    # an "informational gap" and reported below, but does NOT fail the
    # capability gate — the bundle's safety nets are explicitly designed
    # to handle partial-install hosts.
    for cmd in LIVE_STANZA:
        bin_name = cmd.argv_template[0]
        if not shutil.which(bin_name):
            tag = "(required)" if cmd.required else "(optional)"
            missing.append(f"{bin_name} {tag}")

    capable = not any(m.endswith("(required)") for m in missing)
    return capable, missing


def pick_first_bdf(ssh_prefix: list[str] | None = None) -> str | None:
    """Find the first 15b3:* BDF, locally or remotely. If `ssh_prefix` is
    set, the lookup is shelled over SSH."""
    if ssh_prefix is not None:
        out = subprocess.run(
            ssh_prefix + ["lspci -d 15b3:"],
            capture_output=True, text=True, check=False, timeout=20,
        )
    else:
        out = subprocess.run(
            ["lspci", "-d", "15b3:"],
            capture_output=True, text=True, check=False, timeout=10,
        )
    if out.returncode != 0 or not out.stdout.strip():
        return None
    line = out.stdout.strip().splitlines()[0]
    # `0000:01:00.0 Ethernet controller: ...`
    return line.split()[0]


# --- live capture ----------------------------------------------------------

def run_cmd(argv: list[str], timeout: int = 30) -> tuple[int, str]:
    if not is_read_only_argv(argv):
        return 99, f"REJECTED: argv contains a mutating token: {argv}"
    try:
        out = subprocess.run(
            argv, capture_output=True, text=True, check=False, timeout=timeout,
        )
        body = out.stdout if out.stdout else out.stderr
        return out.returncode, body
    except FileNotFoundError as exc:
        return 127, str(exc)
    except subprocess.TimeoutExpired:
        return 124, f"TIMEOUT after {timeout}s: {argv}"
    except Exception as exc:  # pragma: no cover - defensive
        return 1, f"unexpected error: {exc}"


def post_filter(fname: str, body: str) -> str:
    """Filter live captures so they look like the v1 fixture pack
    (e.g. `lsmod | grep -E 'mlx5_core|mlx5_ib|mlx_compat'`)."""
    if fname == "lsmod.txt":
        wanted = ("mlx5_core", "mlx5_ib", "mlx_compat", "mlx_compat ")
        return "\n".join(line for line in body.splitlines() if any(tok in line for tok in wanted))
    if fname == "pkg-config.txt":
        return "\n".join(line for line in body.splitlines() if "doca" in line.lower())
    return body


def capture_live(scenario_id: str, out_root: Path, dry_run: bool,
                 ssh_prefix: list[str] | None = None,
                 remote_label: str | None = None) -> dict:
    """Capture the full LIVE_STANZA into a scenario directory.

    If `ssh_prefix` is supplied (set by --mode remote), every probe is shelled
    over SSH to the remote host instead of locally. The output shape is
    identical so the downstream `build_scenario_artifacts()` does not care
    where the captures came from.
    """
    bdf = pick_first_bdf(ssh_prefix)
    if bdf is None:
        where = f"remote host {remote_label}" if ssh_prefix else "local host"
        raise SystemExit(
            f"live capture requires at least one 15b3:* device on {where}; none visible"
        )

    scenario_dir = out_root / "live_captures" / scenario_id
    scenario_dir.mkdir(parents=True, exist_ok=True)

    captured = []
    skipped = []
    rejected = []
    ctx = {"bdf": bdf}

    for cmd in LIVE_STANZA:
        argv = cmd.materialize(ctx)
        if dry_run:
            captured.append({"file": cmd.fname, "argv": argv, "mode": "dry-run"})
            (scenario_dir / cmd.fname).write_text(
                f"# dry-run: would have run: {' '.join(argv)}\n"
            )
            continue
        if not is_read_only_argv(argv):
            rejected.append({"file": cmd.fname, "argv": argv, "reason": "mutating token in argv"})
            continue
        if ssh_prefix is not None:
            rc, body = run_cmd_remote(argv, ssh_prefix)
        else:
            rc, body = run_cmd(argv)
        if rc != 0:
            if cmd.required:
                skipped.append({"file": cmd.fname, "argv": argv, "rc": rc,
                                "body_excerpt": body[:200]})
                # still write what we got so the scenario dir is complete
                (scenario_dir / cmd.fname).write_text(
                    f"# command exited rc={rc}; body follows\n{body}"
                )
                continue
            captured.append({"file": cmd.fname, "argv": argv, "rc": rc, "note": "optional row, non-zero rc"})
            (scenario_dir / cmd.fname).write_text(
                f"# optional row; command exited rc={rc}; body follows\n{body}"
            )
            continue
        body = post_filter(cmd.fname, body)
        (scenario_dir / cmd.fname).write_text(body if body.endswith("\n") else body + "\n")
        captured.append({"file": cmd.fname, "argv": argv, "rc": 0, "bytes": len(body)})

    capture_origin = ("live-shell over SSH to "
                      f"{remote_label}; first device picked: {bdf}") if ssh_prefix \
        else f"live-shell on local host; first device picked: {bdf}"

    # synthesize env.json so the v1 builders can render the prompt+rubric
    env = {
        "scenario_id": scenario_id,
        "shape": ("Live-captured host shape: BlueField/ConnectX device at "
                  f"{bdf}; stanza captures collected at {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}. "
                  "Synthesized from real hardware enumeration, not from a synthesized fixture."),
        "healthy": True,
        "broken": [],
        "bundle_correct_route": ("doca-setup ## recognize -> "
                                 "doca-bare-metal-deployment OR doca-container-deployment "
                                 "depending on user intent; the live host is recognize-able and "
                                 "the agent must walk the recognize front door before proposing "
                                 "a deploy shape"),
        "synthesized_from": capture_origin,
        "expected_agent_findings": {
            "pcie_visible": True,
            "live_capture": True,
            "first_device_bdf": bdf,
            "remote_host": remote_label,
            "next_step": ("agent reads captured stanza output; routes to recognize; "
                          "does not re-prescribe stanza"),
        },
        "_v2_meta": {
            "dry_run": dry_run,
            "remote": bool(ssh_prefix),
            "remote_host": remote_label,
            "captured": captured,
            "skipped_required": skipped,
            "rejected_mutating": rejected,
        },
    }
    (scenario_dir / "env.json").write_text(json.dumps(env, indent=2) + "\n")

    return {
        "scenario_dir": str(scenario_dir),
        "scenario_id": scenario_id,
        "bdf": bdf,
        "captured": captured,
        "skipped_required": skipped,
        "rejected_mutating": rejected,
        "dry_run": dry_run,
        "remote": bool(ssh_prefix),
        "remote_host": remote_label,
    }


# --- fall-back path --------------------------------------------------------

def materialize_fixtures_scenarios(fixtures_root: Path, out_root: Path) -> list[Path]:
    """Copy the v1 fixture scenarios into <out-root>/live_captures/<id>/ so
    the rest of the pipeline (build_scenario_artifacts → prompts + scoring)
    runs against the same shape regardless of live vs fixture mode."""
    dst_root = out_root / "live_captures"
    dst_root.mkdir(parents=True, exist_ok=True)
    copied = []
    for sd in sorted(fixtures_root.iterdir()):
        if not (sd / "env.json").exists():
            continue
        dst = dst_root / sd.name
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(sd, dst)
        copied.append(dst)
    return copied


# --- main ------------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--mode", choices=["auto", "live", "dry-run", "fixtures", "remote"],
                   default="auto",
                   help="Live capture vs fall-back vs dry-run vs remote-SSH "
                        "capture (default: auto).")
    p.add_argument("--scenario-id", default="live_host",
                   help="Scenario id to use for live capture (default: live_host). "
                        "Ignored in --mode fixtures.")
    p.add_argument("--fixtures-root", type=Path,
                   default=REPO_ROOT / "fixtures" / "hardware",
                   help="Path to the v1 fixture pack; used in --mode fixtures and as the auto fall-back.")
    p.add_argument("--out-dir", required=True, type=Path,
                   help="Output dir for prompts / scoring / dispatch_manifest / live_captures.")

    # --- --mode remote args (May-2026 lab-host wave) -----------------------
    p.add_argument("--remote-host", default=None,
                   help="--mode remote target host (e.g. lver-doca-4). "
                        "Required when --mode remote.")
    p.add_argument("--remote-user", default="root",
                   help="SSH user on --remote-host (default: root).")
    p.add_argument("--ssh-pass-env", default="DOCA_LAB_SSH_PASS",
                   help="Env var name containing the SSH password for "
                        "--mode remote. Jenkins binds the cred id "
                        "`2f8ea6f8-6a80-43ff-aaa9-32b4a1abc0ac` into this "
                        "env var via withCredentials([usernamePassword(...)]) "
                        "(default: DOCA_LAB_SSH_PASS).")
    p.add_argument("--ssh-identity", default=None,
                   help="Optional SSH identity file. When set, password env "
                        "is ignored. Useful for non-Jenkins runs where the "
                        "operator already has key-based access.")
    args = p.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)

    # --- build SSH prefix once for remote mode -----------------------------
    ssh_prefix: list[str] | None = None
    remote_label: str | None = None
    if args.mode == "remote":
        if not args.remote_host:
            print("ERROR: --mode remote requires --remote-host.", file=sys.stderr)
            return 2
        remote_label = f"{args.remote_user}@{args.remote_host}"
        ssh_prefix = _ssh_argv(args.remote_user, args.remote_host,
                               args.ssh_pass_env if not args.ssh_identity else None,
                               args.ssh_identity)

    chosen = args.mode
    if chosen == "auto":
        capable, missing = detect_live_capability()
        if capable:
            chosen = "live"
            print(f"[auto] live capability detected; capturing live stanza for scenario={args.scenario_id}")
        else:
            chosen = "fixtures"
            print(f"[auto] no live capability ({'; '.join(missing) or 'unknown'}); falling back to fixtures at {args.fixtures_root}")
    elif chosen == "live":
        capable, missing = detect_live_capability()
        if not capable:
            print("ERROR: --mode live requires live capability:", file=sys.stderr)
            for m in missing:
                print(f"  - {m}", file=sys.stderr)
            print("  Re-run with --mode auto (fall back to fixtures if no HW), "
                  "--mode fixtures (skip live entirely), or --mode remote "
                  "--remote-host <lab-host> (drive a remote host over SSH).",
                  file=sys.stderr)
            return 2
    elif chosen == "remote":
        capable, missing = detect_remote_capability(
            args.remote_user, args.remote_host,
            args.ssh_pass_env if not args.ssh_identity else None,
            args.ssh_identity,
        )
        if not capable:
            print(f"ERROR: --mode remote {remote_label} not capable:", file=sys.stderr)
            for m in missing:
                print(f"  - {m}", file=sys.stderr)
            return 2
    elif chosen == "dry-run":
        # dry-run still needs lspci to pick a bdf for the synthesized argvs;
        # if lspci is not present, the dry-run is meaningless. Fail clean.
        if not shutil.which("lspci"):
            print("ERROR: --mode dry-run requires `lspci` on PATH to materialize "
                  "the command shapes; not found.", file=sys.stderr)
            return 2

    summary: dict = {"mode_chosen": chosen, "out_dir": str(args.out_dir)}

    if chosen == "live":
        live_summary = capture_live(args.scenario_id, args.out_dir, dry_run=False)
        summary["live"] = live_summary
        scenario_root = args.out_dir / "live_captures"
    elif chosen == "remote":
        live_summary = capture_live(args.scenario_id, args.out_dir, dry_run=False,
                                    ssh_prefix=ssh_prefix, remote_label=remote_label)
        summary["live"] = live_summary
        summary["live"]["remote_host"] = remote_label
        scenario_root = args.out_dir / "live_captures"
    elif chosen == "dry-run":
        live_summary = capture_live(args.scenario_id, args.out_dir, dry_run=True)
        summary["live"] = live_summary
        scenario_root = args.out_dir / "live_captures"
    elif chosen == "fixtures":
        copied = materialize_fixtures_scenarios(args.fixtures_root, args.out_dir)
        summary["fixtures"] = {"copied": [str(p) for p in copied]}
        scenario_root = args.out_dir / "live_captures"
    else:
        raise SystemExit(f"unknown mode {chosen}")

    # Run the v1 builders against the unified scenario_root so the downstream
    # prompt+rubric+manifest output is identical regardless of how the
    # scenario directories were populated.
    manifest = []
    by_id: dict[str, v1.Scenario] = {}
    for sd in sorted(scenario_root.iterdir()):
        if not (sd / "env.json").exists():
            continue
        s = v1.load_scenario(sd)
        manifest.append(v1.build_scenario_artifacts(s, args.out_dir))
        by_id[s.scenario_id] = s

    manifest_path = args.out_dir / "dispatch_manifest.json"
    manifest_path.write_text(json.dumps({
        "_v2_meta": summary,
        "scenarios": manifest,
    }, indent=2) + "\n")

    print(f"\nBuilt {len(manifest)} scenario artifact set(s) under {args.out_dir}")
    for entry in manifest:
        print(f"  {entry['scenario_id']:<28}  prompt={Path(entry['prompt_file']).name}")
    print(f"\nMode chosen: {chosen}")
    if chosen in ("live", "dry-run", "remote"):
        live = summary.get("live", {})
        origin = f" via SSH to {live.get('remote_host')}" if live.get("remote") else ""
        print(f"Live capture summary{origin}: bdf={live.get('bdf')} "
              f"captured={len(live.get('captured', []))} "
              f"skipped_required={len(live.get('skipped_required', []))} "
              f"rejected_mutating={len(live.get('rejected_mutating', []))}")
        if live.get("rejected_mutating"):
            print("REJECTED mutating commands:")
            for r in live["rejected_mutating"]:
                print(f"  - {r['file']}: {' '.join(r['argv'])}  ({r['reason']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
