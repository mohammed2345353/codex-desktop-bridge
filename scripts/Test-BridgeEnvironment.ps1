#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Workspace, [switch]$AsJson)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Bridge.Common.ps1')
$workspacePath = Resolve-BridgeWorkspace $Workspace
$codex = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
$node = Get-Command node -ErrorAction SilentlyContinue | Select-Object -First 1
$codexVersion = $null
$cliReady = $false
if ($codex) {
    $versionOutput = @(& $codex.Source --version 2>&1)
    $cliReady = $LASTEXITCODE -eq 0
    $codexVersion = ($versionOutput | Where-Object { "$_" -match '^codex-cli ' } | Select-Object -First 1)
}
$report = [ordered]@{
    schemaVersion = 1
    windows = $env:OS -eq 'Windows_NT'
    powerShell = $PSVersionTable.PSVersion.ToString()
    codexFound = [bool]$codex
    codexRunnable = $cliReady
    codexVersion = "$codexVersion"
    nodeFound = [bool]$node
    skillPresent = Test-Path -LiteralPath (Join-Path $workspacePath '.agents\skills\codex-desktop-bridge\SKILL.md')
    desktopCommander = 'Not probed: verify the intended device through its available tools.'
    computerUse = 'Not probed: requires a supported desktop tool in the current session.'
    keyboardApproval = 'Use the keys shown by the focused Codex approval prompt; no global hotkey installed.'
}
if ($AsJson) { $report | ConvertTo-Json } else { [pscustomobject]$report }
