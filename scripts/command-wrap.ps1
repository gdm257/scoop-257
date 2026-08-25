<#
.SYNOPSIS
    Run the first available command from a candidate list, forwarding extra arguments.

.PARAMETER Candidates
    Comma-separated list of executable names to try in order.
.PARAMETER UserArgs
    Optional arguments to append to the resolved command.
    A "--workdir <path>" pair anywhere in these is intercepted (not forwarded) and
    sets the wrapped command's working dir; relative paths resolve against this
    script's directory, not the caller's cwd.
#>
param(
    [Parameter(Position = 0, Mandatory)]
    [string[]]$Candidates,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$UserArgs
)

$ErrorActionPreference = 'Stop'

$candidateList = ($Candidates -join ',') -split ','

$workDir = $null
if ($UserArgs) {
    $argList = [System.Collections.Generic.List[string]]$UserArgs
    $i = $argList.IndexOf('--workdir')
    if ($i -ge 0) {
        if ($i + 1 -ge $argList.Count) { Write-Error 'command-wrap: --workdir requires a value' }
        $workDir = $argList[$i + 1]
        $argList.RemoveRange($i, 2)
        $UserArgs = $argList.ToArray()
    }
}

if ($workDir) {
    if (-not [IO.Path]::IsPathRooted($workDir)) { $workDir = Join-Path $PSScriptRoot $workDir }
    # try/catch instead of a pre-check: Win32 normalization strips trailing dots ("...." -> "."),
    # so existence probes lie about degenerate paths that Push-Location then rejects.
    try { Push-Location -LiteralPath $workDir } catch { Write-Error "command-wrap: workdir not found: $workDir" }
}

foreach ($cmd in $candidateList) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        & $found.Path @UserArgs
        exit $LASTEXITCODE
    }
}

Write-Error "command-wrap: none of ($Candidates) found in PATH"
exit 1
