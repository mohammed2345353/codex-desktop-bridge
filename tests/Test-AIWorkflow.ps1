#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'scripts/AI.Common.ps1')
$count = 0
function Assert { param($Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Case { param([string]$Name,[scriptblock]$Body); & $Body; $script:count++; Write-Output "PASS $Name" }
function Confirmation {
    param([string]$Id, [string[]]$Capabilities, [string]$Processing = 'local', [decimal]$Cost = 0, [int]$Slots = 10)
    [pscustomobject]@{id=$Id;available=$true;access=$(if($Processing -eq 'local'){'local-free'}else{'subscription'});processing=$Processing;capabilities=$Capabilities;confirmedAt=[DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o');validUntil=[DateTimeOffset]::UtcNow.AddHours(1).ToString('o');incrementalCostUsd=$Cost;remainingTasks=$Slots}
}
function Provider {
    param([string]$Id,[string[]]$Capabilities,[string]$Processing='local',[decimal]$Cost=0,[int]$Slots=10)
    [pscustomobject]@{id=$Id;name=$Id;advertisedCapabilities=$Capabilities;confirmation=(Confirmation $Id $Capabilities $Processing $Cost $Slots);detected=$false;source='https://example.org';note='fixture'}
}
function Task {
    param([string]$Id,[string]$Capability='writing',[string]$Privacy='public',[string[]]$Dependencies=@())
    [pscustomobject]@{id=$Id;title=$Id;capability=$Capability;privacy=$Privacy;dependsOn=$Dependencies;instruction='Return a draft for manual review.'}
}
function Plan {
    param([object[]]$Providers,[object[]]$Tasks,[decimal]$Budget=0)
    New-AIPlan -Map ([pscustomobject]@{providers=$Providers}) -Request ([pscustomobject]@{schemaVersion=1;title='Fixture';tasks=$Tasks}) -BudgetUsd $Budget
}
function Reject { param([scriptblock]$Body); $failed=$false; try { & $Body | Out-Null } catch { $failed=$true }; Assert $failed 'Invalid request accepted.' }

Case 'Unconfirmed accounts never route' {
    $p=Provider 'unknown' @('writing');$p.confirmation=$null
    $plan=Plan @($p) @((Task 'a'))
    Assert ($plan.steps[0].status -eq 'blocked') 'Unconfirmed account selected.'
}
Case 'Confirmed web tool can route without local installation' {
    $plan=Plan @((Provider 'web' @('writing') 'external')) @((Task 'a'))
    Assert ($plan.steps[0].providerId -eq 'web') 'Manual web confirmation ignored.'
}
Case 'Private task cannot fall back to external provider' {
    $plan=Plan @((Provider 'web' @('writing') 'external')) @((Task 'a' 'writing' 'private'))
    Assert ($plan.steps[0].status -eq 'blocked') 'Private task routed externally.'
}
Case 'Local wins equal cost; budget covers the entire plan' {
    $plan=Plan @((Provider 'cloud' @('writing') 'external'),(Provider 'local' @('writing'))) @((Task 'a'))
    Assert ($plan.steps[0].providerId -eq 'local') 'Local preference lost.'
    $plan=Plan @((Provider 'paid' @('writing') 'external' 0.7)) @((Task 'a'),(Task 'b')) 1
    Assert ($plan.steps[0].status -eq 'planned' -and $plan.steps[1].status -eq 'blocked' -and $plan.estimatedCostUsd -eq 0.7) 'Total budget exceeded.'
}
Case 'Task allowance is reserved within a plan' {
    $plan=Plan @((Provider 'one' @('writing') 'local' 0 1)) @((Task 'a'),(Task 'b'))
    Assert ($plan.steps[1].status -eq 'blocked') 'Task allowance exceeded.'
}
Case 'Equal providers share work without forcing unsuitable tools' {
    $plan=Plan @((Provider 'a' @('writing')),(Provider 'b' @('writing'))) @((Task 'one'),(Task 'two'))
    Assert ($plan.steps[0].providerId -ne $plan.steps[1].providerId) 'Tie balancing failed.'
}
Case 'Capability mismatch and blocked prerequisites remain blocked' {
    $plan=Plan @((Provider 'writer' @('writing'))) @((Task 'image' 'image'),(Task 'write' 'writing' 'public' @('image')))
    Assert (@($plan.steps | Where-Object status -eq 'blocked').Count -eq 2) 'Blocked prerequisite ignored.'
}
Case 'Expired, future, long, unknown and malformed confirmations are rejected' {
    foreach($change in @('expired','future','long','access','cost','slots','capability','missing','boolean-cost','local-cloud')) {
        $p=Provider 'p' @('writing')
        switch($change) {
            'expired' {$p.confirmation.validUntil=[DateTimeOffset]::UtcNow.AddMinutes(-2).ToString('o')}
            'future' {$p.confirmation.confirmedAt=[DateTimeOffset]::UtcNow.AddHours(1).ToString('o')}
            'long' {$p.confirmation.validUntil=[DateTimeOffset]::UtcNow.AddDays(3).ToString('o')}
            'access' {$p.confirmation.access='unknown'}
            'cost' {$p.confirmation.incrementalCostUsd=-1}
            'slots' {$p.confirmation.remainingTasks=1.5}
            'capability' {$p.confirmation.capabilities=@('video')}
            'missing' {$p.confirmation=[pscustomobject]@{available=$true}}
            'boolean-cost' {$p.confirmation.incrementalCostUsd=$true}
            'local-cloud' {$p.confirmation.processing='external'}
        }
        Assert ((Plan @($p) @((Task 'a'))).steps[0].status -eq 'blocked') "Invalid $change confirmation selected."
    }
}
Case 'Reject duplicate IDs, cycles, unknown dependencies and privacy' {
    Reject { Plan @() @((Task 'a'),(Task 'a')) }
    Reject { Plan @() @((Task 'a' 'writing' 'public' @('b')),(Task 'b')) }
    Reject { Plan @() @((Task 'a' 'writing' 'public' @('a'))) }
    Reject { Plan @() @((Task 'a' 'writing' 'secret')) }
}
Case 'Literal instructions are never interpreted; HTML safely encodes them' {
    $task=Task 'hostile';$task.instruction='</script><img src=x onerror=alert(1)> $(Get-Content secret) العربية'
    $plan=Plan @((Provider 'p' @('writing'))) @($task)
    $html=ConvertTo-AIWorkflowHtml $plan
    Assert (-not $html.Contains($task.instruction)) 'Task text interpolated into markup.'
    Assert ($html.Contains('connect-src ''none''') -and -not $html.Contains('__PLAN_BASE64__')) 'Offline policy or packaging missing.'
    $payload=[regex]::Match($html,"JSON.parse\(decode\('([A-Za-z0-9+/=]+)'\)\)").Groups[1].Value
    $roundtrip=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
    Assert ($roundtrip.steps[0].instruction -ceq $task.instruction) 'UTF-8 task data changed.'
}
Case 'Discovery detects a command shim without executing it or leaking paths' {
    $temp=Join-Path ([IO.Path]::GetTempPath()) ('ai-discovery-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp | Out-Null
    $sentinel=Join-Path $temp 'executed.txt'
    Set-Content -LiteralPath (Join-Path $temp 'codex.cmd') -Value ('@echo executed > "'+$sentinel+'"')
    $saved=$env:PATH
    try {
        $env:PATH=$temp
        $map=Get-AIToolMap
        Assert (($map.providers | Where-Object id -eq 'codex').detected) 'Command filename not detected.'
        Assert (-not (Test-Path -LiteralPath $sentinel)) 'Discovery executed an application.'
        Assert (-not (($map | ConvertTo-Json -Depth 15).Contains($temp))) 'Local PATH disclosed.'
    } finally { $env:PATH=$saved }
}
Case 'Example confirmations are disabled by default' {
    $map=Get-AIToolMap -ConfirmationsPath (Join-Path $repo 'examples/confirmations.example.json')
    $request=Read-AIJson (Join-Path $repo 'examples/tasks.json')
    $plan=New-AIPlan $map $request
    Assert (@($plan.steps | Where-Object status -ne 'blocked').Count -eq 0) 'Example silently enabled an account.'
}
Case 'Vendored files match reviewed SHA256 fingerprints' {
    $manifest=Read-AIJson (Join-Path $repo 'vendor/manifest.json')
    foreach($entry in $manifest.files){
        Assert ((Get-FileHash -LiteralPath (Join-Path $repo $entry.path) -Algorithm SHA256).Hash -eq $entry.sha256) ('Vendor file changed: '+$entry.path)
    }
}
Write-Output "Passed $count workflow tests on PowerShell $($PSVersionTable.PSVersion)."
