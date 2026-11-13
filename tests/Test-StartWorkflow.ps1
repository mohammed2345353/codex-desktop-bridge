#Requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=Split-Path $PSScriptRoot -Parent
$start=Join-Path $repo 'scripts/Start-Workflow.ps1'
$state=Join-Path ([IO.Path]::GetTempPath()) ('ai-workflow-start-'+[guid]::NewGuid().ToString('N'))
function Assert {param($Condition,[string]$Message);if(-not $Condition){throw $Message}}
& $start -Action Demo -StateDirectory $state
$demo=@(Get-ChildItem -LiteralPath $state -Filter '*.html')
Assert ($demo.Count -eq 1) 'Demo must produce an actual .html file.'
$before=(Get-FileHash -LiteralPath $demo[0].FullName).Hash
& $start -Action Demo -StateDirectory $state
Assert (@(Get-ChildItem -LiteralPath $state -Filter '*.html').Count -eq 2) 'Repeat overwrote an existing workflow.'
Assert ((Get-FileHash -LiteralPath $demo[0].FullName).Hash -eq $before) 'Existing demo changed.'
$goal='هدف عربي </script> & $(Get-Content secret)'
& $start -Action Prepare -StateDirectory $state -Goal $goal
$brief=Get-ChildItem -LiteralPath $state -Filter 'ai-brief*.txt' | Select-Object -First 1
Assert ((Get-Content -LiteralPath $brief.FullName -Raw -Encoding UTF8).Contains($goal)) 'Goal was interpreted or lost.'
$template=Get-ChildItem -LiteralPath $state -Filter 'tasks-template*.json' | Select-Object -First 1
$request=Get-Content -LiteralPath $template.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($request.title -ceq $goal -and $request.tasks[0].privacy -eq 'private') 'Safe private task template missing.'
& $start -Action Plan -StateDirectory $state -TasksPath $template.FullName
$planFile=Get-ChildItem -LiteralPath $state -Filter 'workflow-plan*.json' | Select-Object -First 1
$plan=Get-Content -LiteralPath $planFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($plan.steps[0].status -eq 'blocked') 'Unconfigured app silently routed a task.'
Assert (-not (Test-Path -LiteralPath (Join-Path $state 'accounts.json'))) 'Account confirmation was invented.'
Set-Content -LiteralPath (Join-Path $state 'accounts.json') -Value '{invalid'
$failed=$false
try{& $start -Action Plan -StateDirectory $state -TasksPath $template.FullName}catch{$failed=$true}
Assert $failed 'Corrupt local accounts were ignored.'
Assert ((Get-Content -LiteralPath (Join-Path $state 'accounts.json') -Raw).Trim() -eq '{invalid') 'Corrupt account file overwritten.'
$configuredState=Join-Path $state 'confirmed'
$answerQueue=New-Object 'System.Collections.Generic.Queue[string]'
foreach($answer in @('1','yes','subscription','external','coding,review','My confirmed model','0','3','yes')){$answerQueue.Enqueue($answer)}
Set-Item Function:Read-Host -Value {param([string]$Prompt);if($answerQueue.Count -eq 0){throw 'Unexpected prompt.'};$answerQueue.Dequeue()}.GetNewClosure()
& $start -Action Configure -StateDirectory $configuredState
$savedAccounts=Get-Content -LiteralPath (Join-Path $configuredState 'accounts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($savedAccounts.providers[0].id -eq 'codex' -and $savedAccounts.providers[0].modelLabel -eq 'My confirmed model') 'Manual confirmation was not saved.'
foreach($answer in @('1','no','no')){$answerQueue.Enqueue($answer)}
& $start -Action Configure -StateDirectory $configuredState
$unchangedAccounts=Get-Content -LiteralPath (Join-Path $configuredState 'accounts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($unchangedAccounts.providers[0].available) 'Declining save changed an account.'
foreach($answer in @('1','no','yes')){$answerQueue.Enqueue($answer)}
& $start -Action Configure -StateDirectory $configuredState
$disabledAccounts=Get-Content -LiteralPath (Join-Path $configuredState 'accounts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert (-not $disabledAccounts.providers[0].available) 'Manual account disable failed.'
Assert (@(Get-ChildItem -LiteralPath $configuredState -Filter 'accounts-backup*.json').Count -eq 1) 'Previous account configuration not backed up.'
Remove-Item Function:Read-Host
Write-Output 'PASS Start workflow: offline demo, unique outputs, literal UTF-8 goal, private template, unconfirmed-account blocking, corrupt-state preservation and manual configuration/decline/disable/backup.'
