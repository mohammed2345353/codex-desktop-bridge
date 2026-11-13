# Tool Advisor — local commands, AI guidance

[العربية](TOOL-ADVISOR.ar.md)

Version 0.3.0 adds an assistant workflow to the existing planner. Ask Codex's
`plugin-skill-advisor` what to use, what is missing, and which PowerShell command
to run next. Repeated mechanical work can then run directly in PowerShell.
The scripts require Windows PowerShell 5.1 or PowerShell 7; no Python, API key,
model server, global installation, or additional subscription is required.

## Quick use

Run from the extracted repository folder:

```powershell
.\Tools.ps1 -Action Catalog
.\Tools.ps1 -Action Inventory | Select-Object skillFiles,scope
.\Tools.ps1 -Action Search -Query 'motion' | Select-Object name,description,path
.\Tools.ps1 -Action Recommend -Task 'create a skill' -BudgetUsd 0
.\Tools.ps1 -Action Profile
.\Tools.ps1 -Action Export
.\Tools.ps1 -Action Open -ToolId vscode -WhatIf
```

`Inventory` scans the user Codex skills, `.agents/skills`, and plugin cache roots.
Use `-Roots` to select explicit roots and `-ConfigPath` for optional MCP header
names. Only skill metadata, hashes, paths, and configuration server names are
reported. No account contents, tokens, environment values, browser history,
project files, or model requests are inspected. Symlinks/junctions are skipped;
warnings describe unavailable roots. Basic frontmatter extraction leaves complex
YAML values empty for later inspection. Local files and cached files are not
proof of installation or session availability.

`Export` saves unique Markdown and JSON reports under `.bridge/advisor`.
They contain private local paths: do not publish or bundle them. `-StateDirectory`
selects another local destination. All mutation actions support `-WhatIf`.
Inventory/search/catalog/recommend/profile do not save files or open programs.

## Feature confirmations, not subscription guesses

Only after confirming the exact feature and estimated extra cost yourself:

```powershell
.\Tools.ps1 -Action Confirm -ToolId codex -Access subscription -Processing external -FeatureCostUsd 0 -PlanLabel 'my confirmed tier' -Ready
.\Tools.ps1 -Action Recommend -Task 'create a skill' -BudgetUsd 0
```

Omit `-Ready` to record a route that is not ready. Leave cost unspecified when
unknown. Product/tier labels are self-reported, not verified entitlements. Never
enter account addresses, keys or payment information. Each confirmation is a new
file, preserving history, and expires in 12 hours by default (maximum 24).
`-Privacy local-only` excludes confirmed external processing.

Recommendation is literal keyword matching against a small curated route
catalog. It is not AI decomposition, a full plugin recommender, or a benchmark.
Unknown, stale and over-budget access never becomes the primary suggestion.
`user-confirmed` does not mean a live service test passed. The Codex assistant
can reason over the local evidence and inspect relevant tools for a broader task.
The original planner's account/task-allowance confirmations remain separate;
advisor estimates do not authorize automatic workflow allocation.

The starter menu uses the same `.bridge/advisor` state as Tools.ps1. Use
`Start-Workflow.ps1 -AdvisorStateDirectory <folder>` to select another advisor
location; `-StateDirectory` continues to select the original planner state.

## Explicit opening and installation

```powershell
.\Tools.ps1 -Action Open -ToolId vscode
.\scripts\Install-Skills.ps1 -Workspace 'C:\MyProject' -WhatIf
.\scripts\Install-Skills.ps1 -Workspace 'C:\MyProject'
```

Open launches only an exact route from `catalog/advisor.json`: fixed HTTPS sites
or known executable paths (Adobe 2026/2027 and common VS Code paths). It sends no
task, arguments or private files, and does not prove the program finished loading
or that login works. It never invokes commands from a task or scanned skill.
Other installation paths may need a reviewed catalog change; nothing is downloaded.

Install-Skills installs both bundled skills under the chosen project's
`.agents/skills`. Differing existing files require explicit `-Replace` and are
backed up under `.bridge/skill-backups`; unrelated files are preserved. Start a
new Codex chat to refresh discovery. Global skill folders and MCP settings are
not changed. The legacy Initialize-Bridge installer remains unchanged.

Local commands make no model calls. Asking Codex to reason, write code, or run
commands can still consume Codex usage. External AI features retain their own
quotas and billing; subscriptions are not interchangeable API credits. No quota
bypass or guaranteed savings is provided. Package code is MIT under the root
license; installed third-party skills and services retain their own licenses.
