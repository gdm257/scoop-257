<#
.SYNOPSIS
    Run the first available command from a candidate list, forwarding extra arguments.
    An optional "--workdir <path>" may lead the candidates or appear among the
    forwarded args; the last occurrence wins.

.PARAMETER Candidates
    Candidate executables to try in order, '+'-separated (comma also accepted).
    Deliberately not Mandatory: a leading "--workdir" must not be consumed as the
    candidate list (both binder shapes are normalized below), and a truly empty list
    is diagnosed by hand instead of prompting.
.PARAMETER UserArgs
    Optional arguments to append to the resolved command.
    A "--workdir <path>" pair anywhere in these is intercepted (not forwarded) and
    sets the wrapped command's working dir; relative paths resolve against this
    script's directory, not the caller's cwd.
#>
param(
    [Parameter(Position = 0)]
    [string[]]$Candidates,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$UserArgs
)

$ErrorActionPreference = 'Stop'

# Under -File, a leading "--workdir <path>" parses as a failed named-parameter match:
# the binder drops the pair into $UserArgs and binds the candidate token after it to
# $Candidates, so the interception loop below covers the leading form for free. A
# console "& $path --workdir w cand" (how the scoop .ps1 shim calls us) instead binds
# the flag token to $Candidates positionally with its value in $UserArgs[0]; reunite
# the pair in $UserArgs so one parse below covers both binder shapes.
if ($Candidates -and $Candidates[0] -eq '--workdir') {
    $u = if ($UserArgs) { @($UserArgs) } else { @() }
    $UserArgs = @('--workdir') + $u
    $Candidates = if ($u.Count -gt 1) { @($u[1]) } else { @() }
}
# Only the degenerate shapes leave $Candidates empty; tell "--workdir" missing its
# value apart from a missing candidate list by hand (Mandatory would prompt instead).
if (-not $Candidates) {
    if ($UserArgs -and $UserArgs.Count -lt 2 -and $UserArgs[0] -eq '--workdir') {
        Write-Error 'command-wrapper: --workdir requires a value'
    }
    Write-Error 'command-wrapper: no candidates provided'
}

$candidateList = ($Candidates -join ',') -split '[+,]'

$workDir = $null
if ($UserArgs) {
    # Strip every "--workdir <path>" pair so the forwarded args never see them; the
    # loop leaves $workDir at the last pair's value (last one wins).
    $argList = [System.Collections.Generic.List[string]]$UserArgs
    for ($i = 0; $i -lt $argList.Count; ) {
        if ($argList[$i] -eq '--workdir') {
            if ($i + 1 -ge $argList.Count) { Write-Error 'command-wrapper: --workdir requires a value' }
            $workDir = $argList[$i + 1]
            $argList.RemoveRange($i, 2)
        } else {
            $i++
        }
    }
    $UserArgs = $argList.ToArray()
}

if ($workDir) {
    if (-not [IO.Path]::IsPathRooted($workDir)) { $workDir = Join-Path $PSScriptRoot $workDir }
    # try/catch instead of a pre-check: Win32 normalization strips trailing dots ("...." -> "."),
    # so existence probes lie about degenerate paths that Push-Location then rejects.
    try { Push-Location -LiteralPath $workDir } catch { Write-Error "command-wrapper: workdir not found: $workDir" }
}

foreach ($cmd in $candidateList) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        & $found.Path @UserArgs
        exit $LASTEXITCODE
    }
}

Write-Error "command-wrapper: none of ($Candidates) found in PATH"
exit 1
