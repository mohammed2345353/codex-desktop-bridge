Set-StrictMode -Version Latest

function Resolve-BridgeWorkspace {
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if (-not $item.PSIsContainer -or $item.PSProvider.Name -ne 'FileSystem') {
        throw 'Workspace must be an existing filesystem directory.'
    }
    $resolved = $item.FullName.TrimEnd([char[]]'\/')
    if ($resolved -eq [IO.Path]::GetPathRoot($item.FullName).TrimEnd([char[]]'\/')) {
        throw 'Select a project folder rather than a drive root.'
    }
    return $resolved
}

function Get-BridgeCodex {
    $command = Get-Command codex -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw 'Codex CLI was not found. Install it and sign in before launching.' }
    return $command.Source
}

function Assert-BridgePlainPath {
    param([Parameter(Mandatory)][string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Setup will not write through a symbolic link or junction.'
            }
        }
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Get-BridgeArguments {
    param([string]$Workspace, [ValidateSet('Standard','Review','Quiet')][string]$Mode,
          [string[]]$AdditionalDirectory = @(), [string]$Prompt)
    $result = @('--cd', $Workspace, '--sandbox', 'workspace-write', '--ask-for-approval')
    if ($Mode -eq 'Quiet') { $result += 'never' } else { $result += 'on-request' }
    if ($Mode -eq 'Review') { $result += @('-c', 'approvals_reviewer=auto_review') }
    foreach ($directory in $AdditionalDirectory) { $result += @('--add-dir', (Resolve-BridgeWorkspace $directory)) }
    if ($Prompt) { $result += @('--', $Prompt) }
    return $result
}
