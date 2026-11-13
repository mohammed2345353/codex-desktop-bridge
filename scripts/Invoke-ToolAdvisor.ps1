#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Catalog','Inventory','Search','Recommend','Confirm','Profile','Open','Export')][string]$Action='Inventory',
    [string]$Task,[string]$Query,[string]$ToolId,
    [string[]]$Roots,[string]$ConfigPath,[string]$StateDirectory,
    [ValidateRange(0,1000000)][decimal]$BudgetUsd=0,
    [ValidateSet('any','local-only')][string]$Privacy='any',
    [ValidateSet('unknown','local','free-tier','subscription','api')][string]$Access='unknown',
    [ValidateSet('unknown','local','external')][string]$Processing='unknown',
    [Nullable[decimal]]$FeatureCostUsd=$null,[string]$PlanLabel='',
    [switch]$Ready,[ValidateRange(1,24)][int]$ValidHours=12
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Advisor.Common.ps1')
$repo=Split-Path $PSScriptRoot -Parent
if(-not $StateDirectory){$StateDirectory=Join-Path $repo '.bridge/advisor'}
if(-not $Roots){
    $codexRoot=$env:CODEX_HOME;if(-not $codexRoot){$codexRoot=Join-Path $env:USERPROFILE '.codex'}
    $Roots=@((Join-Path $codexRoot 'skills'),(Join-Path $env:USERPROFILE '.agents/skills'),(Join-Path $codexRoot 'plugins/cache'))
    if(-not $ConfigPath){$ConfigPath=Join-Path $codexRoot 'config.toml'}
}
$catalog=Get-AdvisorCatalog
switch($Action){
    'Catalog' {$catalog.tools | Select-Object id,name,requirements,costNote}
    'Inventory' {Get-AdvisorInventory -Roots $Roots -ConfigPath $ConfigPath}
    'Search' {if(-not $Query){throw 'Supply -Query.'};Find-AdvisorSkills -Inventory (Get-AdvisorInventory -Roots $Roots -ConfigPath $ConfigPath) -Query $Query}
    'Recommend' {New-AdvisorRecommendation -Task $Task -Catalog $catalog -Confirmations @(Get-AdvisorConfirmations $StateDirectory) -BudgetUsd $BudgetUsd -Privacy $Privacy}
    'Profile' {Get-AdvisorConfirmations $StateDirectory}
    'Confirm' {
        if($ToolId -notin @($catalog.tools.id)){throw 'Choose a tool ID from catalog/advisor.json.'}
        if($null -ne $FeatureCostUsd -and ($FeatureCostUsd -lt 0 -or $FeatureCostUsd -gt 1000000)){throw 'Invalid feature cost.'}
        if($PlanLabel.Length -gt 160 -or $PlanLabel -match '[\r\n]'){throw 'Use a short product/tier label, not account details.'}
        $now=[DateTimeOffset]::UtcNow
        $record=[pscustomobject]@{schemaVersion=1;toolId=$ToolId;ready=[bool]$Ready;access=$Access;processing=$Processing;featureCostUsd=$FeatureCostUsd;planLabel=$PlanLabel;evidence='user-confirmed-feature-estimate';confirmedAt=$now.ToString('o');validUntil=$now.AddHours($ValidHours).ToString('o')}
        if($PSCmdlet.ShouldProcess($StateDirectory,'Save local feature confirmation (no credentials)')){Save-AdvisorReport -Directory $StateDirectory -Prefix 'confirmation' -Extension json -Content ($record|ConvertTo-Json -Depth 10)}
    }
    'Open' {
        $tool=@($catalog.tools | Where-Object id -eq $ToolId)
        if($tool.Count -ne 1){throw 'Choose an exact catalog tool ID.'}
        $destination=Resolve-AdvisorLaunch $tool[0]
        if($PSCmdlet.ShouldProcess($destination,'Open catalog application or website; no prompt or private files sent')){
            Start-Process -FilePath $destination | Out-Null
            [pscustomobject]@{toolId=$ToolId;launchRequested=$true;readiness='unverified';notice='Opening does not confirm login, entitlement or readiness.'}
        }
    }
    'Export' {
        $inventory=Get-AdvisorInventory -Roots $Roots -ConfigPath $ConfigPath
        if($PSCmdlet.ShouldProcess($StateDirectory,'Export local inventory with private local paths')){
            $json=Save-AdvisorReport -Directory $StateDirectory -Prefix inventory -Extension json -Content ($inventory|ConvertTo-Json -Depth 15)
            $lines=@('# Local skill inventory','',$inventory.scope,'','| Name | Description | Readiness / cost | Path |','|---|---|---|---|')
            foreach($row in $inventory.skills){
                $cells=@($row.name,$row.description,'unverified / unknown',$row.path) | ForEach-Object {([string]$_).Replace('|','\|').Replace("`r",' ').Replace("`n",' ')}
                $lines+='| '+($cells -join ' | ')+' |'
            }
            $lines+=@('','Coverage and warnings are in the companion JSON. Private local paths: do not publish this report.')
            $markdown=Save-AdvisorReport -Directory $StateDirectory -Prefix inventory -Extension md -Content ($lines -join "`r`n")
            [pscustomobject]@{json=$json;markdown=$markdown;skillFiles=$inventory.skillFiles;duplicateGroups=@($inventory.exactDuplicateGroups).Count}
        }
    }
}
