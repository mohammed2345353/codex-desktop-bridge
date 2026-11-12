#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$ServerExecutable,
    [string[]]$ServerArgument = @(),
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Name = 'desktop-commander'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Bridge.Common.ps1')
$codexPath = Get-BridgeCodex
$server = Get-Command $ServerExecutable -CommandType Application,ExternalScript -ErrorAction Stop | Select-Object -First 1
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$lookupOutput = (& $codexPath mcp get $Name 2>&1 | Out-String)
$lookupExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
if ($lookupExitCode -eq 0) { throw 'A server with this name is already registered. Review it in Codex before changing it.' }
if ($lookupOutput -notmatch ('No MCP server named ' + [regex]::Escape("'$Name'") + ' found')) {
    throw 'Could not confirm that the server name is unused. Check Codex configuration before registration.'
}
if ($PSCmdlet.ShouldProcess($Name, 'Register the selected MCP executable in Codex user settings')) {
    & $codexPath mcp add $Name -- $server.Source @ServerArgument
    if ($LASTEXITCODE -ne 0) { throw 'MCP registration failed. Check Codex output.' }
    Write-Output 'Registered. Verify a harmless read through this server before relying on it.'
}
