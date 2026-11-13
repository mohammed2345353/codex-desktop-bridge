#Requires -Version 5.1
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Bridge.Common.ps1')

function Get-AdvisorCatalog {
    $path=Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog/advisor.json'
    Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}
function Read-AdvisorJson {
    param([string]$Path)
    Assert-BridgePlainPath $Path
    $item=Get-Item -LiteralPath $Path -ErrorAction Stop
    if($item.PSIsContainer -or $item.Length -gt 10MB){throw 'Expected JSON under 10 MiB.'}
    $text=Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')){ConvertFrom-Json -InputObject $text -DateKind String}else{ConvertFrom-Json -InputObject $text}
}
function Save-AdvisorReport {
    param([string]$Directory,[string]$Prefix,[string]$Extension,[string]$Content)
    Assert-BridgePlainPath $Directory
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $path=Join-Path $Directory ($Prefix+'-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.'+$Extension)
    Assert-BridgePlainPath $path
    $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$bytes=[Text.UTF8Encoding]::new($true).GetPreamble()+[Text.Encoding]::UTF8.GetBytes($Content);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
    $path
}
function Get-AdvisorInventory {
    param([string[]]$Roots,[string]$ConfigPath)
    $rows=New-Object 'System.Collections.Generic.List[object]'
    $issues=New-Object 'System.Collections.Generic.List[object]'
    $coverage=New-Object 'System.Collections.Generic.List[object]'
    $seen=@{}
    foreach($root in $Roots){
        $count=0
        try{
            Assert-BridgePlainPath $root
            if(-not (Test-Path -LiteralPath $root -PathType Container)){throw 'Missing root.'}
            $pending=New-Object 'System.Collections.Generic.Stack[string]';$pending.Push([IO.Path]::GetFullPath($root))
            while($pending.Count -gt 0){
                $dir=$pending.Pop()
                try{
                    foreach($item in Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop){
                        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){continue}
                        if($item.PSIsContainer){$pending.Push($item.FullName);continue}
                        if($item.Name -cne 'SKILL.md' -or $seen.ContainsKey($item.FullName)){continue}
                        $seen[$item.FullName]=$true
                        if($item.Length -gt 1MB){$issues.Add([pscustomobject]@{path=$item.FullName;reason='Skill over 1 MiB; skipped.'});continue}
                        try{
                            $text=Get-Content -LiteralPath $item.FullName -Raw -Encoding UTF8
                            $name='';$description=''
                            $front=[regex]::Match($text,'(?s)\A---\s*\r?\n(.*?)\r?\n---(?:\r?\n|$)')
                            if($front.Success){
                                foreach($key in @('name','description')){
                                    $match=[regex]::Match($front.Groups[1].Value,'(?m)^'+$key+':\s*([^\r\n]*)')
                                    $value=$match.Groups[1].Value.Trim().Trim([char[]]@([char]34,[char]39))
                                    if($value -in @('|','>','|-','>-')){$value=''}
                                    if($key -eq 'name'){$name=$value}else{$description=$value}
                                }
                            }
                            $rows.Add([pscustomobject]@{name=$name;description=$description;path=$item.FullName;root=$root;sha256=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash;presence='local-file';readiness='unverified';requirements='uninspected';cost='unknown'})
                            $count++
                        }catch{$issues.Add([pscustomobject]@{path=$item.FullName;reason='Cannot inspect skill metadata.'})}
                    }
                }catch{$issues.Add([pscustomobject]@{path=$dir;reason='Cannot list directory.'})}
            }
        }catch{$issues.Add([pscustomobject]@{path=$root;reason='Root missing, inaccessible, or linked.'})}
        $coverage.Add([pscustomobject]@{root=$root;skillFiles=$count})
    }
    $servers=@()
    if($ConfigPath){
        try{
            Assert-BridgePlainPath $ConfigPath
            if((Get-Item -LiteralPath $ConfigPath -ErrorAction Stop).Length -gt 1MB){throw 'Config too large.'}
            # Headers only. Never emit URLs, commands, arguments, env values or auth data.
            $servers=@(Get-Content -LiteralPath $ConfigPath -Encoding UTF8 | ForEach-Object {
                if($_ -match '^\[mcp_servers\.(?:([A-Za-z0-9_-]+)|"([^"\r\n]+)")\]\s*$'){
                    $serverName=$Matches[1];if(-not $serverName){$serverName=$Matches[2]}
                    [pscustomobject]@{name=$serverName;connection='unverified';evidence='configuration-header-only'}
                }
            })
        }catch{$issues.Add([pscustomobject]@{path=$ConfigPath;reason='Config headers not inspected.'})}
    }
    $duplicates=@($rows | Group-Object sha256 | Where-Object Count -gt 1 | ForEach-Object {[pscustomobject]@{sha256=$_.Name;paths=@($_.Group.path)}})
    [pscustomobject]@{schemaVersion=1;generatedAt=[DateTimeOffset]::UtcNow.ToString('o');scope='Local files and MCP header names only; not account installation, session availability, connection, cost or readiness.';skillFiles=$rows.Count;skills=@($rows.ToArray());exactDuplicateGroups=$duplicates;configuredMcp=$servers;coverage=@($coverage.ToArray());warnings=@($issues.ToArray())}
}
function Find-AdvisorSkills {
    param($Inventory,[string]$Query)
    $terms=@([regex]::Split($Query.Trim(),'\s+') | Where-Object {$_.Length -gt 1})
    if($terms.Count -eq 0){return @()}
    @($Inventory.skills | Where-Object {
        $haystack=$_.name+' '+$_.description
        $hit=$false
        foreach($term in $terms){if($haystack.IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -ge 0){$hit=$true;break}}
        $hit
    })
}
function Get-AdvisorConfirmations {
    param([string]$Directory)
    if(-not (Test-Path -LiteralPath $Directory)){return @()}
    Assert-BridgePlainPath $Directory
    $latest=@{}
    foreach($file in Get-ChildItem -LiteralPath $Directory -Filter 'confirmation-*.json' -File){
        $record=Read-AdvisorJson $file.FullName
        if($record.schemaVersion -ne 1 -or $record.toolId -notmatch '^[a-z0-9-]+$'){throw 'Invalid confirmation record.'}
        $id=$record.toolId
        if(-not $latest.ContainsKey($id) -or [DateTimeOffset]::Parse($record.confirmedAt) -gt [DateTimeOffset]::Parse($latest[$id].confirmedAt)){$latest[$id]=$record}
    }
    @($latest.Values)
}
function New-AdvisorRecommendation {
    param([string]$Task,$Catalog,[object[]]$Confirmations=@(),[decimal]$BudgetUsd=0,[string]$Privacy='any')
    if([string]::IsNullOrWhiteSpace($Task)){throw 'Supply a task.'}
    $now=[DateTimeOffset]::UtcNow
    $candidates=@(foreach($tool in $Catalog.tools){
        $matched=@($tool.keywords | Where-Object {$Task.IndexOf([string]$_,[StringComparison]::OrdinalIgnoreCase) -ge 0})
        if($matched.Count -eq 0){continue}
        $state='unverified';$reason='Confirm exact feature access, cost and processing; plan name alone is insufficient.'
        $cost=$null;$processing='unknown';$confirmedPlan='';$c=@($Confirmations | Where-Object toolId -eq $tool.id)
        if($c.Count -gt 1){throw 'Duplicate confirmations.'}
        if($c.Count -eq 1){
            $x=$c[0]
            try{
                $when=[DateTimeOffset]::Parse($x.confirmedAt);$until=[DateTimeOffset]::Parse($x.validUntil)
                if($until -le $now -or $when -gt $now -or $until -le $when -or ($until-$when).TotalHours -gt 24){$reason='Confirmation expired or invalid; reconfirm.'}
                elseif($x.ready -isnot [bool] -or -not $x.ready){$state='needs-setup';$reason='User reports feature not ready.'}
                elseif($x.access -notin @('local','free-tier','subscription','api') -or $x.processing -notin @('local','external')){$reason='Access or processing unknown.'}
                elseif($null -eq $x.featureCostUsd -or $x.featureCostUsd -isnot [ValueType] -or $x.featureCostUsd -is [bool] -or [decimal]$x.featureCostUsd -lt 0){$reason='Feature cost unknown or invalid.'}
                else{
                    $cost=[decimal]$x.featureCostUsd;$processing=$x.processing;$confirmedPlan=$x.planLabel
                    if($cost -gt $BudgetUsd){$state='over-budget';$reason='Extra cost exceeds the task budget.'}
                    elseif($Privacy -eq 'local-only' -and $processing -ne 'local'){$state='privacy-blocked';$reason='Task requires local processing.'}
                    else{$state='user-confirmed';$reason='User-confirmed feature estimate; not a live quota or operational test.'}
                }
            }catch{$reason='Malformed confirmation; reconfirm.'}
        }
        [pscustomobject]@{id=$tool.id;name=$tool.name;matchedTerms=$matched;status=$state;reason=$reason;requirements=$tool.requirements;costNote=$tool.costNote;estimatedExtraCostUsd=$cost;processing=$processing;planLabel=$confirmedPlan;source=$tool.source;sourceReviewedOn=$Catalog.sourceReviewedOn}
    })
    $eligible=@($candidates | Where-Object status -eq 'user-confirmed' | Sort-Object estimatedExtraCostUsd,id)
    [pscustomobject]@{schemaVersion=1;task=$Task;budgetUsd=$BudgetUsd;privacy=$Privacy;primary=@($eligible | Select-Object -First 1);alternatives=@($eligible | Select-Object -Skip 1 -First 2);candidates=$candidates;notice='Offline keyword matching, not AI reasoning or automatic execution. Unknown costs are never treated as free. No model calls or quota savings guarantee.'}
}
function Resolve-AdvisorLaunch {
    param($Tool)
    if($Tool.launch.kind -eq 'web'){
        $uri=[uri]$Tool.launch.url
        if($uri.Scheme -ne 'https' -or $uri.UserInfo){throw 'Only catalog HTTPS destinations are supported.'}
        return $uri.AbsoluteUri
    }
    if($Tool.launch.kind -ne 'app'){throw 'No launcher for this item.'}
    foreach($relative in $Tool.launch.localAppPaths){
        $root=$env:LOCALAPPDATA;if(-not $root){continue}
        $path=Join-Path $root $relative
        if(Test-Path -LiteralPath $path -PathType Leaf){Assert-BridgePlainPath $path;return [IO.Path]::GetFullPath($path)}
    }
    if($env:ProgramFiles){
        foreach($relative in $Tool.launch.programFilesPaths){
            $path=Join-Path $env:ProgramFiles $relative
            if(Test-Path -LiteralPath $path -PathType Leaf){Assert-BridgePlainPath $path;return [IO.Path]::GetFullPath($path)}
        }
    }
    throw 'Catalog application executable not found; no install or guessed command was run.'
}
