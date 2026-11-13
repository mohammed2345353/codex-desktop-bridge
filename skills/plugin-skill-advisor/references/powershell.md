# Windows assistant workflow

When Codex Desktop Bridge is available, use its local PowerShell commands for repeated mechanical steps. Locate the user's repository before giving paths. Do not assume the skill installation folder contains the repository. Commands below run from its root.

```powershell
.\Tools.ps1 -Action Catalog
.\Tools.ps1 -Action Inventory | Select-Object skillFiles,scope
.\Tools.ps1 -Action Search -Query 'motion' | Select-Object name,description,path
.\Tools.ps1 -Action Recommend -Task 'create a skill' -BudgetUsd 0
.\Tools.ps1 -Action Profile
.\Tools.ps1 -Action Export
.\Tools.ps1 -Action Open -ToolId vscode -WhatIf
```

Inventory/search/catalog/recommend/profile do not write reports, launch programs or invoke AI. Export explicitly writes private reports under `.bridge/advisor`. Confirm explicitly saves a dated feature estimate there. Open is a separate user-selected action that launches only an exact catalog destination; never run it merely because a recommendation names a tool. There is no arbitrary command, prompt, file or URL execution from task text or inventory.

For a user who has confirmed the exact feature, processing location and extra cost, show a tailored Confirm command, for example:

```powershell
# Only after the user confirms these facts; do not assume them from Plus alone.
.\Tools.ps1 -Action Confirm -ToolId codex -Access subscription -Processing external -FeatureCostUsd 0 -PlanLabel 'user-confirmed plan' -Ready
```

The CLI uses literal keyword matching and a small route catalog; it does not understand every task or assess every installed skill. The AI assistant supplies reasoning, checks missing requirements, and explains the next command. Unknown/expired/over-budget routes remain conditional. `user-confirmed` is not `live-tested`.

Typical response: what to use; what is missing; why this route fits; exact command to run from the stated folder; expected result; fallback. Suggest downloads only when necessary, with official source and known costs; never install automatically. Local commands themselves make no model calls, but running them through an AI chat can still consume chat usage. AI reasoning, coding, generation, and external services retain their own limits.

Bridge workflow planning uses separate, stricter task-allowance confirmations. An advisor record does not authorize allocation, opening programs or sending tasks to a model.
