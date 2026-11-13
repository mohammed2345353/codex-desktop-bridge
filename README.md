# Codex Desktop Bridge — AI Workflow Planner

[العربية](README.ar.md) · Version **0.2.0** · Windows · Local files · MIT

Turn the AI tools you already have into a clear, numbered workflow. Discover tool
evidence, manually confirm access and limits, prepare a goal-specific brief for
an AI of your choice, then turn its reviewed task list into an offline flowchart.
Each step shows its tool, instructions and prerequisites. Mark a reviewed result
complete to see what is ready next.

This is the primary project in this repository, replacing the old session-helper
focus. Existing helpers still work; their [original guide](docs/LEGACY-BRIDGE.md)
is preserved separately. No global installation, background server or API key
is required by the planner.

## Start

1. Download **Code → Download ZIP** from GitHub and extract the folder.
2. With PowerShell 7 installed, double-click **Start.cmd**, or run:

   ```powershell
   .\scripts\Start-Workflow.ps1
   ```

3. Use the menu: discover tools → confirm access → prepare your goal → review
   the AI's task JSON → generate your workflow. The demo needs no accounts.

The launcher never installs PowerShell or changes execution policy. If device
policy blocks scripts, it reports the failure. Direct scripts support PowerShell
5.1 and 7 where policy allows. Menu choices such as yes/local/subscription are
shown explicitly.

## Included

- Read-only registry/PATH evidence for Codex, Claude, Gemini, Antigravity,
  VS Code, Adobe creative tools and Ollama.
- Manual access, capabilities, processing location, model label, cost and task
  allowance. No credentials, inferred subscriptions or login inspection.
- A goal-specific brief for your chosen AI to recommend tools/models/websites,
  explain alternatives and return a reviewed task list. Handoff is manual.
- Cost/limit-aware planning with local-only private tasks and blocked prerequisites.
- One offline HTML flowchart: numbered steps, branch/join dependencies,
  completion/undo, progress download/restore and Print / Save PDF.
- Pinned Graphlib and Google icon assets with full licenses and integrity checks.

## Commands without the menu

```powershell
.\scripts\Start-Workflow.ps1 -Action Discover
.\scripts\Start-Workflow.ps1 -Action Prepare -Goal 'Create an educational reel'
.\scripts\Start-Workflow.ps1 -Action Configure
.\scripts\Start-Workflow.ps1 -Action Plan -TasksPath 'C:\MyTasks\reviewed.json'
.\scripts\Start-Workflow.ps1 -Action Demo
```

Files stay under `.bridge/workflow/`, excluded from Git. Reports, briefs and
flowcharts get unique names. Account changes require a save confirmation and
preserve a backup. Menu confirmations expire after 12 hours; the planner accepts
at most 24 hours. Default additional-spend budget: **$0**. `-BudgetUsd` only plans
a budget; it never authorizes a purchase or an API call.

[Detailed guide](docs/AI-WORKFLOW.md) · [Foundation audit](docs/FOUNDATIONS.md)

## Privacy and limits

No automatic task sending, application opening, screen capture, browser-session
reading, AI invocation or clipboard writing. Screenshots and extension inspection
require a separately chosen, approved read-only scope. Source links open on click.

Discovery is partial evidence, not proof of authenticity, entitlement or model
readiness. Web and portable tools may need manual confirmation. Costs and task
allowances are estimates, not live quotas or reservations. Routing is a simple
sequential heuristic, not a global optimizer or a model benchmark. Free-form
decomposition/advice comes from the manual brief handoff, not a built-in cloud
service. Review briefs before sharing: they contain your goal and confirmations.

## Validation

```powershell
.\tests\Run-Tests.ps1
.\tests\Test-AIWorkflow.ps1
.\tests\Test-StartWorkflow.ps1
node .\tests\Test-WorkflowUI.cjs
```

[Validation evidence](VALIDATION.md) · [Changes](CHANGELOG.md) · [MIT license](LICENSE)

Created by Mohammed Al-Saray. Independent community project, not an official
OpenAI, Google, Adobe or Desktop Commander product.
