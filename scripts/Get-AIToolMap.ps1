#Requires -Version 5.1
[CmdletBinding()]
param([string]$ConfirmationsPath, [switch]$AsJson)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AI.Common.ps1')
$map = Get-AIToolMap -ConfirmationsPath $ConfirmationsPath
if ($AsJson) { $map | ConvertTo-Json -Depth 15 } else { $map }
