# Codex Desktop Bridge

## New: local AI workflow planner (preview)

Discover installed tool evidence without launching tools, confirm your own access,
and turn a reviewed task list into an offline, numbered flowchart. It recommends
tools by capability, cost, privacy and manually declared task allowance. You hand
off the instructions and mark each reviewed result complete; dependent steps then
become ready. Undoing a prerequisite also resets its descendants.

```powershell
# Read-only: no command execution, login inspection or network requests.
.\scripts\Get-AIToolMap.ps1 -AsJson
# Self-contained demo: synthetic accounts, no device discovery.
.\examples\Show-DemoWorkflow.ps1 | Set-Content -LiteralPath demo.html -Encoding UTF8
# Your plan: fill a LOCAL copy of examples/confirmations.example.json first.
.\scripts\New-AIWorkflow.ps1 -TasksPath .\examples\tasks.json -ConfirmationsPath .\.bridge\accounts.json -Format Html |
    Set-Content -LiteralPath workflow.html -Encoding UTF8
```

Open the HTML yourself. It supports progress download/restore, AI planning advice
export, and Print / Save PDF. No CDN, server, auto-send, clipboard write or AI call.
Accounts in the example start disabled. Subscription, model readiness, processing
location, feature access and remaining allowances are never inferred from an app.
Web-only tools may be manually confirmed. Read [the workflow guide](docs/AI-WORKFLOW.md)
and [the source audit](docs/FOUNDATIONS.md). Existing launch helpers below remain
available and separate; the planner does not call them.

Windows task coordination for Codex: a reusable skill, project setup, diagnostics, and session launch modes that reduce repeated interruptions.

[العربية](README.ar.md)

[![Windows checks](https://github.com/mohammed2345353/codex-desktop-bridge/actions/workflows/windows.yml/badge.svg)](https://github.com/mohammed2345353/codex-desktop-bridge/actions/workflows/windows.yml)

**Status: 0.1.0 preview.** This project supplies workflow instructions and PowerShell helpers. Desktop Commander and computer-use capabilities come from separately available tools; they are not bundled or remotely exposed by this repository.

## Quick start

Requirements: Windows, PowerShell 5.1 or 7, Codex CLI installed and signed in. Review downloaded scripts first. The scripts do not require administrator mode or change execution policy.

Download the source with Git, then choose an existing project folder:

```powershell
git clone https://github.com/mohammed2345353/codex-desktop-bridge.git
Set-Location codex-desktop-bridge
```

Run from that repository:

```powershell
.\scripts\Test-BridgeEnvironment.ps1 -Workspace 'C:\Projects\MyProject'
.\scripts\Initialize-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Standard -WhatIf
.\scripts\Initialize-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Standard
.\scripts\Start-Bridge.ps1 -Workspace 'C:\Projects\MyProject'
```

Setup adds `.agents/skills/codex-desktop-bridge/` and `.bridge/settings.json` to the selected workspace. Commit the skill if your team wants it; keep `.bridge/` ignored because it contains local paths. Setup preserves existing identical skills and refuses to overwrite differing ones. There is no global skill installation or global approval-policy change.

Invoke `$codex-desktop-bridge` in Codex or let it match a Windows automation task. A workspace can be used without Git when launched directly from that folder; normal Codex repository discovery rules still apply.

## Choose a mode

| Mode | Behavior |
| --- | --- |
| Standard (default) | Work inside the workspace; show required approvals |
| Review | Use automatic review for eligible requests; requests can still be denied |
| Quiet | Never request escalation; blocked operations return failures |

```powershell
.\scripts\Start-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Review -DryRun
.\scripts\Start-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Quiet
.\scripts\Start-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -AdditionalDirectory 'D:\SelectedAssets'
```

`DryRun` returns the exact argument array without starting a model session. Launch flags apply only to that new CLI session, not an existing ChatGPT/Codex conversation. Review requires a Codex version supporting automatic review. Managed policies take precedence. Automatic review can consume additional model usage. None of these modes enables full device access. Workspace-write limits writes; it is not a guarantee that all reads are confined to the project. Remote MCP tools have separate boundaries.

## Connect existing tools

Use the skill with tools already available in the current session. For a separately installed, reviewed stdio MCP server, register its actual executable and arguments:

```powershell
.\scripts\Connect-DesktopCommander.ps1 -ServerExecutable 'C:\Tools\YourServer.exe' -WhatIf
.\scripts\Connect-DesktopCommander.ps1 -ServerExecutable 'C:\Tools\YourServer.exe'
```

This optional command changes Codex user MCP registration, refuses an existing server name, and does not install/download software. For Remote Desktop Commander, connect the provider using its own supported setup and select the intended device; the stdio helper is not a replacement for that setup. Verify connection using a harmless tool read. Shell restrictions do not automatically constrain remote MCP servers.

## Keyboard approval

After Codex displays an approval request, use the keys shown in its focused terminal prompt. A universal ChatGPT hotkey is not supplied. A future companion can bind a shortcut to a specific App Server pending approval; see [keyboard design](skills/codex-desktop-bridge/references/keyboard.md). Global shortcuts are planned, not implemented in 0.1.0.

## Validation

```powershell
.\tests\Run-Tests.ps1
```

Tests use temporary workspaces and a mock CLI; they verify argument boundaries, repeatable setup, preservation of modified skills, mode selection, missing tools, and MCP registration. They do not prove a live desktop connection, model behavior, or successful elevation.

## Remove

Remove only the installed `.agents/skills/codex-desktop-bridge` directory and `.bridge/settings.json` from the workspace after checking for local edits. No background service is installed. If you registered the optional MCP server, remove that named registration through Codex (`codex mcp remove desktop-commander`).

## Project and sources

Created by Mohammed Al-Saray. MIT license. Independent community project; not an official OpenAI or Desktop Commander product.

Documentation checked 2026-11-13:
- [Approvals and sandbox](https://learn.chatgpt.com/docs/agent-approvals-security)
- [Skills and discovery](https://learn.chatgpt.com/docs/build-skills)
- [MCP setup](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
- [App Server](https://learn.chatgpt.com/docs/app-server)

The source is public at [mohammed2345353/codex-desktop-bridge](https://github.com/mohammed2345353/codex-desktop-bridge). The preview is distributed as source. GitHub publication is separate from ChatGPT plugin-directory submission.
