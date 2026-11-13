#Requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'scripts/Advisor.Common.ps1')
$entry=Join-Path $repo 'scripts/Invoke-ToolAdvisor.ps1'
$script:checks=0
function Assert($Value,[string]$Message){if(-not $Value){throw $Message};$script:checks++}
$testRoot=Join-Path $repo ('test-results/advisor-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$skills=Join-Path $testRoot 'skills'
foreach($folder in @('one','two','three')){New-Item -ItemType Directory -Path (Join-Path $skills $folder) -Force | Out-Null}
$skillText="---`nname: sample`ndescription: Motion graphics sample`n---`nBody"
foreach($folder in @('one','two')){Set-Content -LiteralPath (Join-Path $skills ($folder+'/SKILL.md')) -Value $skillText -Encoding UTF8}
Set-Content -LiteralPath (Join-Path $skills 'three/SKILL.md') -Value ($skillText+' changed') -Encoding UTF8
$config=Join-Path $testRoot 'config.toml'
Set-Content -LiteralPath $config -Value @('[mcp_servers.demo]','command = "DO_NOT_RETURN"','[mcp_servers.demo.env]','TOKEN = "SECRET_SENTINEL"') -Encoding UTF8
$missing=Join-Path $testRoot 'missing'
$inventory=Get-AdvisorInventory -Roots @($skills,(Join-Path $skills 'one'),$missing) -ConfigPath $config
Assert ($inventory.skillFiles -eq 3) 'Overlapping roots inflated inventory.'
Assert (@($inventory.exactDuplicateGroups).Count -eq 1) 'Duplicate grouping failed.'
Assert (@($inventory.exactDuplicateGroups[0].paths).Count -eq 2) 'Same name with changed contents was merged.'
Assert (@($inventory.warnings).Count -eq 1) 'Missing root was not reported.'
$json=$inventory|ConvertTo-Json -Depth 15
Assert (-not $json.Contains('SECRET_SENTINEL') -and -not $json.Contains('DO_NOT_RETURN')) 'Config values leaked.'
Assert ($inventory.configuredMcp[0].name -eq 'demo' -and $inventory.configuredMcp[0].connection -eq 'unverified') 'Configuration promoted to connection.'
Assert (@(Find-AdvisorSkills $inventory 'motion').Count -eq 3) 'Literal search failed.'
Assert (@(Find-AdvisorSkills $inventory '.*').Count -eq 0) 'Query was interpreted as regex.'
$state=Join-Path $testRoot 'state'
$catalog=Get-AdvisorCatalog
$result=New-AdvisorRecommendation -Task 'create skill' -Catalog $catalog
Assert (@($result.primary).Count -eq 0 -and $result.candidates[0].status -eq 'unverified') 'Unknown access treated as free.'
& $entry -Action Confirm -ToolId codex -Ready -Access subscription -Processing external -FeatureCostUsd 0 -StateDirectory $state -WhatIf
Assert (-not (Test-Path -LiteralPath $state)) 'WhatIf wrote confirmation.'
$null=& $entry -Action Confirm -ToolId codex -Ready -Access subscription -Processing external -FeatureCostUsd 0 -PlanLabel 'fixture tier' -StateDirectory $state
$records=@(Get-AdvisorConfirmations $state)
Assert ($records.Count -eq 1) 'Confirmation not saved.'
$result=New-AdvisorRecommendation -Task 'create skill' -Catalog $catalog -Confirmations $records
Assert ($result.primary[0].id -eq 'codex' -and $result.primary[0].status -eq 'user-confirmed') 'Confirmed route excluded.'
$result=New-AdvisorRecommendation -Task 'create skill' -Catalog $catalog -Confirmations $records -Privacy local-only
Assert (@($result.primary).Count -eq 0 -and $result.candidates[0].status -eq 'privacy-blocked') 'Private task routed externally.'
$records[0].featureCostUsd=1
Assert ((New-AdvisorRecommendation -Task 'skill' -Catalog $catalog -Confirmations $records).candidates[0].status -eq 'over-budget') 'Budget not enforced.'
$records[0].featureCostUsd=$null
Assert ((New-AdvisorRecommendation -Task 'skill' -Catalog $catalog -Confirmations $records).candidates[0].status -eq 'unverified') 'Unknown cost accepted.'
$records[0].featureCostUsd=0;$records[0].validUntil=[DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
Assert ((New-AdvisorRecommendation -Task 'skill' -Catalog $catalog -Confirmations $records).candidates[0].status -eq 'unverified') 'Expired confirmation accepted.'
$records[0].validUntil=[DateTimeOffset]::UtcNow.AddHours(48).ToString('o')
Assert ((New-AdvisorRecommendation -Task 'skill' -Catalog $catalog -Confirmations $records).candidates[0].status -eq 'unverified') 'Unbounded confirmation accepted.'
$bad=$false;try{& $entry -Action Confirm -ToolId unknown -StateDirectory $state}catch{$bad=$true};Assert $bad 'Unknown tool saved.'
$launches=New-Object 'System.Collections.Generic.List[string]'
function Start-Process {param([string]$FilePath);$launches.Add($FilePath)}
& $entry -Action Open -ToolId codex -WhatIf
Assert ($launches.Count -eq 0) 'WhatIf opened a website.'
$null=& $entry -Action Open -ToolId codex
Assert ($launches.Count -eq 1 -and $launches[0] -eq 'https://chatgpt.com/codex') 'Launcher sent an unintended destination.'
$bad=$false;try{& $entry -Action Open -ToolId 'codex; calc.exe'}catch{$bad=$true};Assert $bad 'Arbitrary tool command accepted.'
Remove-Item Function:Start-Process
$export=Join-Path $testRoot 'export'
& $entry -Action Export -Roots @($skills) -StateDirectory $export -WhatIf
Assert (-not (Test-Path -LiteralPath $export)) 'WhatIf exported files.'
$out=& $entry -Action Export -Roots @($skills) -StateDirectory $export
$out2=& $entry -Action Export -Roots @($skills) -StateDirectory $export
Assert ($out.json -ne $out2.json -and (Test-Path -LiteralPath $out.markdown)) 'Report overwritten or incomplete.'
$workspace=Join-Path $testRoot 'workspace';New-Item -ItemType Directory -Path $workspace -Force | Out-Null
$installer=Join-Path $repo 'scripts/Install-Skills.ps1'
& $installer -Workspace $workspace -WhatIf
Assert (-not (Test-Path -LiteralPath (Join-Path $workspace '.agents'))) 'Installer WhatIf wrote files.'
$null=& $installer -Workspace $workspace
$null=& $installer -Workspace $workspace
$installed=Join-Path $workspace '.agents/skills/plugin-skill-advisor/SKILL.md'
Assert (Test-Path -LiteralPath $installed) 'Advisor skill not installed.'
Add-Content -LiteralPath $installed -Value 'Local edit' -Encoding UTF8
$bad=$false;try{& $installer -Workspace $workspace}catch{$bad=$true};Assert $bad 'Local edit overwritten silently.'
$null=& $installer -Workspace $workspace -Replace
$backups=@(Get-ChildItem -LiteralPath (Join-Path $workspace '.bridge/skill-backups') -Filter SKILL.md -Recurse -File | Where-Object {(Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8).Contains('Local edit')})
Assert ($backups.Count -eq 1) 'Previous edit was not backed up.'
Write-Output "Passed $script:checks advisor checks on PowerShell $($PSVersionTable.PSVersion). No live applications or model services were invoked."
