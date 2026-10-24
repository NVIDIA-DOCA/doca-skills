## Description: <br>
Deploys and configures the NVIDIA DOCA Telemetry Service (DTS) across its three deployment shapes — BlueField built-in kubelet static pod, host docker container on x86_64/aarch64, and DPF DPUService/helm chart — plus the shared dts_config.ini configuration layer of providers, exporters, and level labels. <br>

This skill is ready for commercial/non-commercial use. <br>

## Owner
NVIDIA <br>

### License/Terms of Use: <br>
Apache 2.0 AND CC-BY-4.0 <br>
## Use Case: <br>
Developers, infrastructure engineers, and DPU/cluster operators use this skill to deploy, configure, upgrade, and debug the DOCA Telemetry Service on BlueField, on an x86_64/aarch64 docker host, or inside a DPF-managed cluster, including tuning providers, exporters, and level labels and verifying that metrics are exported. <br>

### Deployment Geography for Use: <br>
Global <br>

## Requirements / Dependencies: <br>
**Requires API Key or External Credential:** [Yes] <br>
**Credential Type(s):** [Other [root/sudo access or Kubernetes cluster credentials]] <br>

Do not include secrets in prompts/logs/output; use least-privilege credentials; rotate keys as appropriate. <br>

## Known Risks and Mitigations: <br>
Risk: Review before execution as proposals could introduce incorrect or misleading guidance into skills. <br>
Mitigation: Review and scan skill before deployment. <br>

## Reference(s): <br>
- [CAPABILITIES.md](CAPABILITIES.md) <br>
- [TASKS.md](TASKS.md) <br>
- [DOCA Telemetry Service Guide](https://docs.nvidia.com/doca/sdk/doca+telemetry+service+guide/index.html) <br>
- [DOCA Container Deployment Guide](https://docs.nvidia.com/doca/sdk/doca+container+deployment+guide/index.html) <br>
- [NGC doca_telemetry container](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/doca/containers/doca_telemetry) <br>
- [NGC doca-telemetry helm chart](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/doca/helm-charts/doca-telemetry) <br>
- [NVIDIA DOCA Platform (DPF)](https://github.com/NVIDIA/doca-platform) <br>


## Skill Output: <br>
**Output Type(s):** [Shell commands, Configuration instructions, Analysis] <br>
**Output Format:** [Markdown with inline shell and YAML code blocks] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [None] <br>

## Evaluation Agents Used: <br>
- Claude Code (`aws/anthropic/bedrock-claude-opus-5-5`) <br>
- Codex (`openai/openai/gpt-6.1-sol`) <br>



## Evaluation Tasks: <br>
6 evaluation tasks (4 positive, 2 negative), one attempt per task, each attempt run in its own isolated k8s-sandbox pod. <br>

## Evaluation Metrics Used: <br>
Reported benchmark dimensions: <br>
- Security: Whether the skill is safe to use, checking for unsafe operations, secret leakage, and unauthorized access. <br>
- Correctness: Whether the final answer is correct against the reference answer. <br>
- Discoverability: Whether the right skill was loaded when needed and decoys were avoided. <br>
- Effectiveness: Whether the skill helped complete the task, as the equal-weight mean of goal completion and expected workflow adherence. <br>
- Efficiency: Whether the skill avoided wasted tool calls and token usage. <br>

Underlying evaluation signals used in this run: <br>
- `security`: Unsafe operations, secret leakage, and unauthorized access. <br>
- `skill_execution`: Whether the expected skill was selected, decoys were avoided, and the workflow executed. <br>
- `skill_efficiency`: Tool-call productivity (legacy wire id; routing is scored under Discoverability). <br>
- `accuracy`: Final-answer correctness against the reference answer. <br>
- `goal_accuracy`: Whether the user's goal was achieved. <br>
- `behavior_check`: Whether the expected workflow behavior was followed. <br>
- `token_efficiency`: Actual uncached prompt plus completion token usage. <br>



## Evaluation Results: <br>
| Measure | Claude Code (Baseline → Skill Uplift) | Codex (Baseline → Skill Uplift) |
|---|---:|---:|
| Overall | 86.6% (uplift unavailable) | 79.6% (uplift unavailable) |
| Security | 91.7% → 100.0% (+8.3 points) | 91.7% → 83.3% (-8.4 points) |
| Correctness | 76.7% → 83.3% (+6.6 points) | 66.7% → 80.0% (+13.3 points) |
| Discoverability | 100.0% (uplift unavailable) | 95.0% (uplift unavailable) |
| Effectiveness | 38.3% → 68.3% (+30.0 points) | 48.9% → 73.6% (+24.7 points) |
| Efficiency | 81.1% (uplift unavailable) | 66.2% (uplift unavailable) |

## Skill Version(s): <br>
2a83c6b (source: git SHA, committed 2026-10-24); targets DOCA 3.5 (metadata.doca_version) <br>

## Ethical Considerations: <br>
NVIDIA believes Trustworthy AI is a shared responsibility and we have established policies and practices to enable development for a wide array of AI applications. When downloaded or used in accordance with our terms of service, developers should work with their internal team to ensure this skill meets requirements for the relevant industry and use case and addresses unforeseen product misuse. <br>

(For Release on NVIDIA Platforms Only) <br>
Please report quality, risk, security vulnerabilities or NVIDIA AI Concerns [here](https://app.intigriti.com/programs/nvidia/nvidiavdp/detail). <br>
