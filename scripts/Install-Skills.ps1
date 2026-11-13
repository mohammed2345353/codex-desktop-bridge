#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$Workspace,[switch]$Replace)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Bridge.Common.ps1')
$workspacePath=Resolve-BridgeWorkspace $Workspace
$repo=Split-Path $PSScriptRoot -Parent
$plans=@(foreach($name in @('codex-desktop-bridge','plugin-skill-advisor')){
    $source=Join-Path $repo ('skills/'+$name)
    $target=Join-Path $workspacePath ('.agents/skills/'+$name)
    Assert-BridgePlainPath $source
    Assert-BridgePlainPath $target
    $different=$false
    if(Test-Path -LiteralPath $target){
        $left=@(Get-ChildItem -LiteralPath $source -Recurse -File)
        $right=@(Get-ChildItem -LiteralPath $target -Recurse -File)
        foreach($item in Get-ChildItem -LiteralPath $target -Recurse -Force){Assert-BridgePlainPath $item.FullName}
        if($left.Count -ne $right.Count){$different=$true}
        foreach($file in $left){
            $relative=$file.FullName.Substring($source.Length).TrimStart([char[]]'\/')
            $existing=Join-Path $target $relative
            if(-not (Test-Path -LiteralPath $existing -PathType Leaf)){$different=$true;continue}
            if((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $existing).Hash){$different=$true}
        }
    }
    if($different -and -not $Replace){throw 'Existing skill differs. Review changes and use -Replace to preserve a backup and update.'}
    [pscustomobject]@{name=$name;source=$source;target=$target;different=$different}
})
foreach($plan in $plans){
    if($PSCmdlet.ShouldProcess($plan.target,'Install project skill; preserve previous files in .bridge/skill-backups')){
        if($plan.different){
            $backup=Join-Path $workspacePath ('.bridge/skill-backups/'+$plan.name+'-'+[guid]::NewGuid().ToString('N'))
            Assert-BridgePlainPath $backup
            New-Item -ItemType Directory -Path $backup -Force | Out-Null
            Get-ChildItem -LiteralPath $plan.target -Force | Copy-Item -Destination $backup -Recurse
            Write-Host ('Backup: '+$backup)
        }
        New-Item -ItemType Directory -Path $plan.target -Force | Out-Null
        Get-ChildItem -LiteralPath $plan.source -Force | Copy-Item -Destination $plan.target -Recurse -Force
        foreach($file in Get-ChildItem -LiteralPath $plan.source -Recurse -File){
            $relative=$file.FullName.Substring($plan.source.Length).TrimStart([char[]]'\/')
            if((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $plan.target $relative)).Hash){throw 'Installed skill hash mismatch.'}
        }
        [pscustomobject]@{skill=$plan.name;path=$plan.target;status='files-installed; refresh Codex discovery in a new chat'}
    }
}
