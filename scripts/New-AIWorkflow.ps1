#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TasksPath,
    [string]$ConfirmationsPath,
    [ValidateRange(0,1000000)][decimal]$BudgetUsd = 0,
    [ValidateSet('Json','Html')][string]$Format = 'Json'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AI.Common.ps1')
$map = Get-AIToolMap -ConfirmationsPath $ConfirmationsPath
$tasks = Read-AIJson $TasksPath
$plan = New-AIPlan -Map $map -Request $tasks -BudgetUsd $BudgetUsd
if ($Format -eq 'Html') { ConvertTo-AIWorkflowHtml $plan } else { $plan | ConvertTo-Json -Depth 20 }
