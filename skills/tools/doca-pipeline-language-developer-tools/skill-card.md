## Description: <br>
Guides an agent driving the DOCA Pipeline Language (DPL) Developer Tools — DPL Nspect, DPL Debugger, DPL Admin, P4 Runtime Shell, and the DPL Runtime Controller SDK — to inspect and debug DPL programs running on a BlueField DPU. <br>

This skill is ready for commercial/non-commercial use. <br>

## Owner
NVIDIA <br>

### License/Terms of Use: <br>
Apache 2.0 AND CC-BY-4.0 <br>
## Use Case: <br>
Developers and engineers inspecting and debugging DOCA Pipeline Language (DPL) programs on a BlueField DPU use this skill to drive the DPL Developer Tools — inspecting runtime state (tables, keys, counters), visualizing packet flow, dynamically modifying dpl_rtd configuration, and building custom P4Runtime applications — while routing authoring, install, version, and hardware/firmware changes to other skills. <br>

### Deployment Geography for Use: <br>
Global <br>

## Requirements / Dependencies: <br>
**Requires API Key or External Credential:** [Not Specified] <br>
**Credential Type(s):** [None identified] <br>

Do not include secrets in prompts/logs/output; use least-privilege credentials; rotate keys as appropriate. <br>

## Known Risks and Mitigations: <br>
Risk: Review before execution as proposals could introduce incorrect or misleading guidance into skills. <br>
Mitigation: Review and scan skill before deployment. <br>

## Reference(s): <br>
- [DOCA SDK Documentation](https://docs.nvidia.com/doca/sdk/index.html) <br>
- [NVIDIA DOCA Enterprise Networking Forum](https://forums.developer.nvidia.com/c/infrastructure/doca/370) <br>
- [Capabilities companion](CAPABILITIES.md) <br>
- [Tasks companion](TASKS.md) <br>


## Skill Output: <br>
**Output Type(s):** [Analysis, Shell commands, Configuration instructions] <br>
**Output Format:** [Markdown with inline command examples] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [None] <br>

## Evaluation Agents Used: <br>
- Claude Code (`aws/anthropic/bedrock-claude-sonnet-5-5`) <br>
- Codex (`openai/openai/gpt-5.5`) <br>



## Evaluation Tasks: <br>
5 evaluation tasks (3 positive, 2 negative), each attempt run in its own isolated sandbox pod (k8s-sandbox). <br>

## Evaluation Metrics Used: <br>
Reported benchmark dimensions: <br>
- Security: Is it safe to use — checks for unsafe operations, secret leakage, and unauthorized access. <br>
- Correctness: Is the answer correct — final-answer correctness against the reference answer. <br>
- Discoverability: Was the right skill loaded when needed — expected skill selected and decoys avoided. <br>
- Effectiveness: Did the skill help complete the task — equal-weight mean of goal completion and expected workflow adherence. <br>
- Efficiency: Did it avoid wasted tool calls and token usage — tool-call productivity and token efficiency. <br>

Underlying evaluation signals used in this run: <br>
- `security`: Unsafe operations, secret leakage, and unauthorized access. <br>
- `skill_execution`: Whether the expected skill was selected, decoys were avoided, and the workflow executed. <br>
- `accuracy`: Final-answer correctness against the reference answer. <br>
- `goal_accuracy`: Whether the user's goal was achieved. <br>
- `behavior_check`: Whether the expected workflow behavior was followed. <br>
- `skill_efficiency`: Tool-call productivity (legacy wire id; routing is scored under Discoverability). <br>



## Evaluation Results: <br>
| Measure | Claude Code (Baseline -> Skill Uplift) | Codex (Baseline -> Skill Uplift) |
|---|---:|---:|
| Overall | 90.3% (uplift unavailable) | 93.4% (uplift unavailable) |
| Security | 100.0% -> 100.0% (+0.0 points) | 100.0% -> 100.0% (+0.0 points) |
| Correctness | 20.0% -> 100.0% (+80.0 points) | 72.0% -> 100.0% (+28.0 points) |
| Discoverability | 100.0% (uplift unavailable) | 95.0% (uplift unavailable) |
| Effectiveness | 23.7% -> 91.0% (+67.3 points) | 31.2% -> 93.0% (+61.8 points) |
| Efficiency | 60.7% (uplift unavailable) | 79.1% (uplift unavailable) |

## Skill Version(s): <br>
3bc1c5d (source: git SHA, committed 2026-10-22) <br>

## Ethical Considerations: <br>
NVIDIA believes Trustworthy AI is a shared responsibility and we have established policies and practices to enable development for a wide array of AI applications. When downloaded or used in accordance with our terms of service, developers should work with their internal team to ensure this skill meets requirements for the relevant industry and use case and addresses unforeseen product misuse. <br>

(For Release on NVIDIA Platforms Only) <br>
Please report quality, risk, security vulnerabilities or NVIDIA AI Concerns [here](https://app.intigriti.com/programs/nvidia/nvidiavdp/detail). <br>
