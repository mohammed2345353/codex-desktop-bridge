#Requires -Version 5.1
Set-StrictMode -Version Latest

function Read-AIJson {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.PSIsContainer -or $item.Length -gt 1MB) { throw 'Expected a JSON file under 1 MiB.' }
    Get-Content -LiteralPath $item.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AIInstalledNames {
    # Only display names in standard uninstall keys. No MSI queries, processes,
    # browser profiles, tokens, registry writes, application launches or network.
    $names = New-Object 'System.Collections.Generic.List[string]'
    $warnings = New-Object 'System.Collections.Generic.List[string]'
    if ($env:OS -ne 'Windows_NT') {
        $warnings.Add('Windows registry unavailable; discovery is partial.')
    } else {
        foreach ($hive in @([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryHive]::LocalMachine)) {
            foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)) {
                $base = $null; $root = $null
                try {
                    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
                    $root = $base.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Uninstall', $false)
                    if ($null -eq $root) { continue }
                    foreach ($name in $root.GetSubKeyNames()) {
                        $key = $null
                        try {
                            $key = $root.OpenSubKey($name, $false)
                            if ($key) {
                                $display = $key.GetValue('DisplayName')
                                if ($display -is [string]) { $names.Add($display) }
                            }
                        } catch { $warnings.Add('One uninstall entry could not be read; discovery is partial.') }
                        finally { if ($key) { $key.Dispose() } }
                    }
                } catch { $warnings.Add('One uninstall registry view could not be read; discovery is partial.') }
                finally { if ($root) { $root.Dispose() }; if ($base) { $base.Dispose() } }
            }
        }
    }
    [pscustomobject]@{ Names = @($names | Select-Object -Unique); Warnings = @($warnings | Select-Object -Unique) }
}

function Test-AICommandFile {
    param([string[]]$Names)
    # Inspect exact filenames on PATH. Never invoke even --version or a command shim.
    foreach ($directory in ($env:PATH -split [IO.Path]::PathSeparator)) {
        if ([string]::IsNullOrWhiteSpace($directory)) { continue }
        foreach ($name in $Names) {
            try { if (Test-Path -LiteralPath (Join-Path $directory.Trim('"') $name) -PathType Leaf) { return $true } }
            catch { continue }
        }
    }
    return $false
}

function Get-AIToolMap {
    param([string]$ConfirmationsPath)
    $catalog = Read-AIJson (Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog/providers.json')
    $installed = Get-AIInstalledNames
    $settings = @()
    if ($ConfirmationsPath) {
        $document = Read-AIJson $ConfirmationsPath
        if ($document.schemaVersion -ne 1) { throw 'Unsupported confirmations schema.' }
        $settings = @($document.providers)
        $ids = @{}
        foreach ($setting in $settings) {
            if ($ids.ContainsKey($setting.id) -or $setting.id -notin @($catalog.providers.id)) { throw 'Duplicate or unknown provider confirmation.' }
            $ids[$setting.id] = $true
        }
    }
    $providers = foreach ($tool in $catalog.providers) {
        $evidence = @()
        if (Test-AICommandFile @($tool.commandFiles)) { $evidence += 'PATH filename match (not executed)' }
        if (@($installed.Names | Where-Object { $_ -match $tool.displayNamePattern }).Count -gt 0) { $evidence += 'Uninstall display-name match' }
        $confirmation = @($settings | Where-Object { $_.id -eq $tool.id })
        $state = $null
        if ($confirmation.Count -eq 1) { $state = $confirmation[0] }
        [pscustomobject]@{
            id = $tool.id; name = $tool.name; detected = ($evidence.Count -gt 0)
            evidence = $evidence; advertisedCapabilities = @($tool.capabilities)
            source = $tool.source; sourceReviewedOn = $catalog.sourceReviewedOn
            note = $tool.note; confirmation = $state
        }
    }
    [pscustomobject]@{
        schemaVersion = 1; generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
        mode = 'local-read-only'; warnings = @($installed.Warnings)
        notice = 'Detection is not login, entitlement, model readiness or permission. Confirmation is manual. No applications were executed.'
        providers = @($providers)
    }
}

function Get-AIEligibility {
    param($Provider, [DateTimeOffset]$Now)
    $c = $Provider.confirmation
    try {
        if ($null -eq $c -or $c.available -isnot [bool] -or -not $c.available) { return 'Availability not manually confirmed.' }
        if ($c.access -notin @('local-free','free','subscription','paid-api')) { return 'Access or subscription status unknown.' }
        if ($c.processing -notin @('local','external')) { return 'Processing location unknown.' }
        if ($c.access -eq 'local-free' -and $c.processing -ne 'local') { return 'Local-free requires local processing.' }
        $confirmed = [DateTimeOffset]::Parse($c.confirmedAt)
        $until = [DateTimeOffset]::Parse($c.validUntil)
        if ($confirmed -gt $Now -or $until -le $Now -or $until -le $confirmed -or ($until - $confirmed).TotalHours -gt 24) { return 'Confirmation expired or invalid (maximum 24 hours).' }
        if ($c.incrementalCostUsd -isnot [ValueType] -or $c.incrementalCostUsd -is [bool] -or [decimal]$c.incrementalCostUsd -lt 0) { return 'Incremental cost must be manually supplied and nonnegative.' }
        if ($c.remainingTasks -isnot [ValueType] -or $c.remainingTasks -is [bool] -or [decimal]$c.remainingTasks -lt 0 -or [decimal]$c.remainingTasks -ne [Math]::Truncate([decimal]$c.remainingTasks)) { return 'Remaining task allowance must be a nonnegative integer.' }
        if (@($c.capabilities).Count -eq 0 -or @($c.capabilities | Where-Object { $_ -notin $Provider.advertisedCapabilities }).Count -gt 0) { return 'Confirm capabilities from the catalog.' }
    } catch { return 'Malformed or incomplete manual confirmation.' }
    return ''
}

function New-AIPlan {
    param($Map, $Request, [decimal]$BudgetUsd = 0)
    if ($BudgetUsd -lt 0 -or $Request.schemaVersion -ne 1) { throw 'Invalid budget or task schema.' }
    $tasks = @($Request.tasks)
    if ($tasks.Count -eq 0 -or $tasks.Count -gt 100) { throw 'Supply 1 to 100 ordered tasks.' }
    $seen = @{}
    foreach ($task in $tasks) {
        if ($task.id -notmatch '^[a-zA-Z0-9_-]{1,64}$' -or $seen.ContainsKey($task.id)) { throw 'Task IDs must be unique simple identifiers.' }
        if ($task.title -isnot [string] -or [string]::IsNullOrWhiteSpace($task.title) -or $task.instruction -isnot [string] -or [string]::IsNullOrWhiteSpace($task.instruction)) { throw 'Every task needs a title and literal instruction.' }
        if ($task.privacy -notin @('public','private') -or $task.capability -notin @('writing','coding','review','image','video')) { throw 'Unknown task privacy or capability.' }
        foreach ($dependency in @($task.dependsOn)) {
            if (-not $seen.ContainsKey($dependency)) { throw 'Dependencies must refer to earlier tasks (no cycles or forward references).' }
        }
        $seen[$task.id] = $true
    }
    $remaining = @{}; $assigned = @{}; $eligibility = @{}
    $now = [DateTimeOffset]::UtcNow
    foreach ($provider in $Map.providers) {
        $reason = Get-AIEligibility $provider $now
        $eligibility[$provider.id] = $reason
        $assigned[$provider.id] = 0
        if (-not $reason) { $remaining[$provider.id] = [decimal]$provider.confirmation.remainingTasks }
    }
    $spent = [decimal]0; $steps = @(); $blocked = @{}
    foreach ($task in $tasks) {
        $candidates = @(); $excluded = @()
        $dependencyBlocked = @($task.dependsOn | Where-Object { $blocked[$_] }).Count -gt 0
        foreach ($provider in $Map.providers) {
            $why = $eligibility[$provider.id]
            if (-not $why) {
                $c = $provider.confirmation
                if ($task.capability -notin @($c.capabilities)) { $why = 'Capability not confirmed.' }
                elseif ($task.privacy -eq 'private' -and $c.processing -ne 'local') { $why = 'Private tasks require confirmed local processing.' }
                elseif ($remaining[$provider.id] -lt 1) { $why = 'Confirmed task allowance exhausted in this plan.' }
                elseif ($spent + [decimal]$c.incrementalCostUsd -gt $BudgetUsd) { $why = 'Would exceed the plan budget.' }
                else {
                    $candidates += [pscustomobject]@{ provider = $provider; cost = [decimal]$c.incrementalCostUsd; localRank = [int]($c.processing -ne 'local'); used = $assigned[$provider.id] }
                }
            }
            if ($why) { $excluded += [pscustomobject]@{ providerId = $provider.id; reason = $why } }
        }
        $chosen = $null
        if (-not $dependencyBlocked -and $candidates.Count -gt 0) {
            $chosen = $candidates | Sort-Object cost,localRank,used,@{Expression={$_.provider.id}} | Select-Object -First 1
        }
        $providerId = $null; $providerName = $null; $cost = [decimal]0; $status = 'blocked'
        $reason = 'No eligible provider. Confirm availability, capabilities, allowance and cost, or revise constraints.'
        if ($dependencyBlocked) { $reason = 'An earlier prerequisite is blocked.' }
        if ($chosen) {
            $providerId = $chosen.provider.id; $providerName = $chosen.provider.name; $cost = $chosen.cost
            $remaining[$providerId]--; $assigned[$providerId]++; $spent += $cost
            $status = 'planned'; $reason = 'Lowest incremental cost, then local processing, then fewer assignments. Manual handoff only.'
        }
        $blocked[$task.id] = ($status -eq 'blocked')
        $steps += [pscustomobject]@{
            number = $steps.Count + 1; id = $task.id; title = $task.title
            capability = $task.capability; privacy = $task.privacy; dependsOn = @($task.dependsOn)
            providerId = $providerId; providerName = $providerName; status = $status
            estimatedCostUsd = $cost; reason = $reason; excluded = $excluded
            suggestions = @($Map.providers | Where-Object { $task.capability -in $_.advertisedCapabilities } | ForEach-Object {
                [pscustomobject]@{ id = $_.id; name = $_.name; note = $_.note; source = $_.source; requiresConfirmation = $true }
            })
            instruction = $task.instruction
        }
    }
    [pscustomobject]@{
        schemaVersion = 1; title = $Request.title; generatedAt = $now.ToString('o')
        mode = 'manual-workflow'; budgetUsd = $BudgetUsd; estimatedCostUsd = $spent
        notice = 'Local planning only. Task slots and costs are user estimates, not live quotas or reservations. Review each handoff. Never treat this file as permission to execute commands or send data.'
        toolMap = $Map; steps = $steps
    }
}

function ConvertTo-AIWorkflowHtml {
    param($Plan)
    # Embed UTF-8 JSON as base64, never interpolate task text into HTML or script.
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Plan | ConvertTo-Json -Depth 20 -Compress)))
    $template = Get-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'templates/workflow.html') -Raw -Encoding UTF8
    $root = Split-Path $PSScriptRoot -Parent
    $graphlib = Get-Content -LiteralPath (Join-Path $root 'vendor/graphlib/graphlib.js') -Raw -Encoding UTF8
    $icon = Get-Content -LiteralPath (Join-Path $root 'vendor/google-icons/check_circle.svg') -Raw -Encoding UTF8
    $licenses = (Get-Content -LiteralPath (Join-Path $root 'vendor/graphlib/LICENSE') -Raw -Encoding UTF8) + "`n`nGoogle Material Design icons:`n" + (Get-Content -LiteralPath (Join-Path $root 'vendor/google-icons/LICENSE') -Raw -Encoding UTF8)
    $template.Replace('__GRAPHLIB__', $graphlib).Replace('__DONE_ICON__', [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($icon))).Replace('__LICENSES_BASE64__', [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($licenses))).Replace('__PLAN_BASE64__', $payload)
}
