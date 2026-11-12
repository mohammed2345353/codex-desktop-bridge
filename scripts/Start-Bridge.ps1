#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Workspace,
    [ValidateSet('Standard','Review','Quiet')][string]$Mode,
    [string[]]$AdditionalDirectory = @(),
    [string]$Prompt,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Bridge.Common.ps1')
$workspacePath = Resolve-BridgeWorkspace $Workspace
if (-not $Mode) {
    $settingsPath = Join-Path $workspacePath '.bridge\settings.json'
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        if ($settings.schemaVersion -ne 1 -or $settings.workspace -ne $workspacePath) { throw 'Bridge settings do not match this workspace.' }
        $Mode = $settings.mode
    } else { $Mode = 'Standard' }
}
$arguments = @(Get-BridgeArguments -Workspace $workspacePath -Mode $Mode -AdditionalDirectory $AdditionalDirectory -Prompt $Prompt)
if ($DryRun) {
    [pscustomobject]@{ Command = 'codex'; Arguments = $arguments; Workspace = $workspacePath; Mode = $Mode }
    return
}
$codexPath = Get-BridgeCodex
$helpText = (& $codexPath --help 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $helpText -notmatch '--ask-for-approval' -or $helpText -notmatch '--sandbox') {
    throw 'Installed Codex does not advertise the required CLI options.'
}
if ($Mode -eq 'Review' -and $helpText -notmatch '--approve-for-me') {
    throw 'Automatic review support was not detected. Use Standard or check your Codex version.'
}
& $codexPath @arguments
exit $LASTEXITCODE
