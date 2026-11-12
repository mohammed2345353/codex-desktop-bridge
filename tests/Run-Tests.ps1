#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$scripts = Join-Path $repo 'scripts'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-bridge-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$passed = 0
$skipped = 0
function Assert-True { param([bool]$Value, [string]$Message); if (-not $Value) { throw $Message } }
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try { & $Body } catch [NotSupportedException] {
        $script:skipped++
        Write-Output "SKIP $Name : $($_.Exception.Message)"
        return
    }
    $script:passed++
    Write-Output "PASS $Name"
}
$originalPath = $env:PATH
try {
    $workspace = Join-Path $tempRoot 'Project [one] with spaces'
    New-Item -ItemType Directory -Path $workspace | Out-Null
    Test-Case 'WhatIf makes no changes' {
        & (Join-Path $scripts 'Initialize-Bridge.ps1') -Workspace $workspace -WhatIf
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $workspace '.agents'))) 'WhatIf wrote files.'
    }
    Test-Case 'Setup and repeat preserve project files' {
        Set-Content -LiteralPath (Join-Path $workspace 'keep.txt') -Value 'keep'
        & (Join-Path $scripts 'Initialize-Bridge.ps1') -Workspace $workspace -Mode Quiet | Out-Null
        & (Join-Path $scripts 'Initialize-Bridge.ps1') -Workspace $workspace -Mode Quiet | Out-Null
        Assert-True ((Get-Content -LiteralPath (Join-Path $workspace 'keep.txt')) -eq 'keep') 'Project content changed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $workspace '.agents\skills\codex-desktop-bridge\SKILL.md')) 'Skill missing.'
    }
    Test-Case 'Quiet mode uses saved settings' {
        $run = & (Join-Path $scripts 'Start-Bridge.ps1') -Workspace $workspace -DryRun
        Assert-True ($run.Mode -eq 'Quiet' -and $run.Arguments -contains 'never') 'Quiet settings ignored.'
        Assert-True ($run.Arguments -contains 'workspace-write') 'Sandbox missing.'
    }
    Test-Case 'Prompt remains one literal argument' {
        $prompt = 'show $(Get-Content secret); `"quoted`" & --sandbox danger-full-access'
        $run = & (Join-Path $scripts 'Start-Bridge.ps1') -Workspace $workspace -Mode Standard -Prompt $prompt -DryRun
        Assert-True ($run.Arguments[-1] -ceq $prompt -and $run.Arguments[-2] -eq '--') 'Prompt boundary changed.'
        Assert-True (@($run.Arguments | Where-Object { $_ -eq '--sandbox' }).Count -eq 1) 'Prompt became an option.'
    }
    Test-Case 'Review uses reviewer and explicit extra directory' {
        $extra = Join-Path $tempRoot 'assets [selected]'
        New-Item -ItemType Directory -Path $extra | Out-Null
        $run = & (Join-Path $scripts 'Start-Bridge.ps1') -Workspace $workspace -Mode Review -AdditionalDirectory $extra -DryRun
        Assert-True ($run.Arguments -contains 'approvals_reviewer=auto_review') 'Reviewer missing.'
        Assert-True ($run.Arguments[-1] -eq $extra) 'Extra directory not literal.'
    }
    Test-Case 'Missing workspace is rejected' {
        $failed = $false
        try { & (Join-Path $scripts 'Start-Bridge.ps1') -Workspace (Join-Path $tempRoot 'absent') -DryRun | Out-Null } catch { $failed = $true }
        Assert-True $failed 'Missing workspace accepted.'
    }
    Test-Case 'Changed skill is never overwritten' {
        $installed = Join-Path $workspace '.agents\skills\codex-desktop-bridge\SKILL.md'
        Add-Content -LiteralPath $installed -Value 'local edit'
        $before = (Get-FileHash -LiteralPath $installed).Hash
        $failed = $false
        try { & (Join-Path $scripts 'Initialize-Bridge.ps1') -Workspace $workspace | Out-Null } catch { $failed = $true }
        Assert-True ($failed -and (Get-FileHash -LiteralPath $installed).Hash -eq $before) 'Local changes were overwritten.'
    }
    Test-Case 'Invalid saved mode is rejected' {
        $state = Join-Path $workspace '.bridge\settings.json'
        @{ schemaVersion = 1; workspace = $workspace; mode = 'full-access' } | ConvertTo-Json | Set-Content -LiteralPath $state
        $failed = $false
        try { & (Join-Path $scripts 'Start-Bridge.ps1') -Workspace $workspace -DryRun | Out-Null } catch { $failed = $true }
        Assert-True $failed 'Invalid saved mode accepted.'
    }
    # Use a subprocess so Start-Bridge's exit cannot terminate the test runner.
    $mockBin = Join-Path $tempRoot 'mock-bin'
    New-Item -ItemType Directory -Path $mockBin | Out-Null
    $mockPath = Join-Path $mockBin 'codex.ps1'
    @'
if ($args[0] -eq '--help') { Write-Output '--ask-for-approval --sandbox --approve-for-me'; exit 0 }
if ($args[0] -eq '--version') { Write-Output 'codex-cli mock'; exit 0 }
if ($args[0] -eq 'mcp' -and $args[1] -eq 'get') {
    if ($args[2] -eq 'existing') { exit 0 }
    if ($args[2] -eq 'broken') { Write-Output 'Configuration failed'; exit 2 }
    Write-Output "No MCP server named '$($args[2])' found."
    exit 1
}
ConvertTo-Json -InputObject @($args) -Compress | Set-Content -LiteralPath $env:BRIDGE_TEST_CAPTURE
exit 0
'@ | Set-Content -LiteralPath $mockPath -Encoding UTF8
    $env:PATH = $mockBin + [IO.Path]::PathSeparator + $originalPath
    $env:BRIDGE_TEST_CAPTURE = Join-Path $tempRoot 'arguments.json'
    $hostExe = (Get-Process -Id $PID).Path
    Test-Case 'Launcher invokes CLI with literal arguments' {
        & $hostExe -NoProfile -File (Join-Path $scripts 'Start-Bridge.ps1') -Workspace $workspace -Mode Review -Prompt 'one & two'
        Assert-True ($LASTEXITCODE -eq 0) 'Launcher failed.'
        $captured = @(Get-Content -LiteralPath $env:BRIDGE_TEST_CAPTURE -Raw | ConvertFrom-Json)
        Assert-True ($captured[-1] -eq 'one & two' -and $captured -contains 'approvals_reviewer=auto_review') 'CLI arguments changed.'
    }
    Test-Case 'Environment report distinguishes untested tools' {
        $report = & (Join-Path $scripts 'Test-BridgeEnvironment.ps1') -Workspace $workspace -AsJson | ConvertFrom-Json
        Assert-True ($report.codexRunnable -and $report.desktopCommander -like 'Not probed*') 'Report claims an untested connection.'
    }
    Test-Case 'MCP registration uses caller arguments' {
        & (Join-Path $scripts 'Connect-DesktopCommander.ps1') -ServerExecutable $hostExe -ServerArgument @('-NoProfile','-File','C:\Tools\server [one].ps1') | Out-Null
        $captured = @(Get-Content -LiteralPath $env:BRIDGE_TEST_CAPTURE -Raw | ConvertFrom-Json)
        Assert-True ($captured[0] -eq 'mcp' -and $captured[1] -eq 'add' -and $captured[-1] -eq 'C:\Tools\server [one].ps1') 'MCP arguments changed.'
    }
    Test-Case 'MCP WhatIf does not register' {
        $before = (Get-FileHash -LiteralPath $env:BRIDGE_TEST_CAPTURE).Hash
        & (Join-Path $scripts 'Connect-DesktopCommander.ps1') -ServerExecutable $hostExe -WhatIf
        Assert-True ((Get-FileHash -LiteralPath $env:BRIDGE_TEST_CAPTURE).Hash -eq $before) 'WhatIf registered a server.'
    }
    Test-Case 'Existing or unreadable MCP configuration is preserved' {
        $before = (Get-FileHash -LiteralPath $env:BRIDGE_TEST_CAPTURE).Hash
        foreach ($serverName in @('existing', 'broken')) {
            $failed = $false
            try { & (Join-Path $scripts 'Connect-DesktopCommander.ps1') -ServerExecutable $hostExe -Name $serverName | Out-Null } catch { $failed = $true }
            Assert-True $failed 'Registration continued without a confirmed unused name.'
        }
        Assert-True ((Get-FileHash -LiteralPath $env:BRIDGE_TEST_CAPTURE).Hash -eq $before) 'MCP configuration was changed.'
    }
    Test-Case 'Missing CLI produces a clear failure' {
        . (Join-Path $scripts 'Bridge.Common.ps1')
        $savedPath = $env:PATH
        try {
            $env:PATH = $mockBin + '\absent'
            $failed = $false
            try { Get-BridgeCodex | Out-Null } catch { $failed = $_.Exception.Message -like '*not found*' }
            Assert-True $failed 'Missing CLI not diagnosed.'
        } finally { $env:PATH = $savedPath }
    }
    Test-Case 'Setup refuses writes through a junction' {
        $linkedWorkspace = Join-Path $tempRoot 'linked-project'
        $outside = Join-Path $tempRoot 'outside-state'
        New-Item -ItemType Directory -Path $linkedWorkspace, $outside | Out-Null
        Set-Content -LiteralPath (Join-Path $outside 'sentinel.txt') -Value 'untouched'
        try {
            New-Item -ItemType Junction -Path (Join-Path $linkedWorkspace '.bridge') -Target $outside | Out-Null
        } catch {
            if ($_.Exception.Message -match 'Access.*denied|privilege' -or $_.CategoryInfo.Category -eq 'PermissionDenied') {
                throw [NotSupportedException]::new('The execution environment does not permit creating a junction.')
            }
            throw
        }
        $failed = $false
        try { & (Join-Path $scripts 'Initialize-Bridge.ps1') -Workspace $linkedWorkspace | Out-Null } catch { $failed = $true }
        Assert-True ($failed -and -not (Test-Path -LiteralPath (Join-Path $outside 'settings.json'))) 'Junction boundary not preserved.'
    }
    # Parse every shipped PowerShell file, including this runner.
    Test-Case 'All PowerShell scripts parse' {
        foreach ($file in Get-ChildItem -LiteralPath $repo -Filter '*.ps1' -Recurse -File) {
            $tokens = $null; $parseErrors = $null
            [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
            Assert-True ($parseErrors.Count -eq 0) "Parse error in $($file.Name)"
        }
    }
    Write-Output "Passed $passed tests; skipped $skipped on PowerShell $($PSVersionTable.PSVersion)."
} finally {
    $env:PATH = $originalPath
    Remove-Item Env:BRIDGE_TEST_CAPTURE -ErrorAction SilentlyContinue
    # Leave disposable test artifacts for inspection; do not recursively delete paths.
}
exit 0
