#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Workspace,
    [ValidateSet('Standard','Review','Quiet')][string]$Mode = 'Standard'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Bridge.Common.ps1')
$workspacePath = Resolve-BridgeWorkspace $Workspace
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'skills\codex-desktop-bridge'
$target = Join-Path $workspacePath '.agents\skills\codex-desktop-bridge'
$stateDir = Join-Path $workspacePath '.bridge'
$statePath = Join-Path $stateDir 'settings.json'
Assert-BridgePlainPath $target
Assert-BridgePlainPath $statePath

# Preflight before any write. Never overwrite a locally edited or unrelated skill.
$sourceFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File)
if (Test-Path -LiteralPath $target) {
    $targetFiles = @(Get-ChildItem -LiteralPath $target -Recurse -File)
    if ($sourceFiles.Count -ne $targetFiles.Count) { throw 'Existing skill differs. Review it before updating.' }
    foreach ($file in $sourceFiles) {
        $relative = $file.FullName.Substring($source.Length).TrimStart([char[]]'\/')
        $existing = Join-Path $target $relative
        if (-not (Test-Path -LiteralPath $existing -PathType Leaf) -or
            (Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $existing).Hash) {
            throw 'Existing skill differs. Review it before updating.'
        }
    }
}
if (Test-Path -LiteralPath $statePath) {
    $old = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($old.schemaVersion -ne 1 -or $old.workspace -ne $workspacePath) { throw 'Unrecognized bridge settings; review before replacing.' }
}
if ($PSCmdlet.ShouldProcess($workspacePath, 'Install project skill and bridge settings')) {
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Get-ChildItem -LiteralPath $source | Copy-Item -Destination $target -Recurse
    }
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    $settings = [ordered]@{ schemaVersion = 1; workspace = $workspacePath; mode = $Mode }
    $settings | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    [pscustomobject]@{ Workspace = $workspacePath; Mode = $Mode; SkillPath = $target; SettingsPath = $statePath }
}
