<#
.SYNOPSIS
    Run the first available command from a candidate list, forwarding extra arguments.

.PARAMETER Candidates
    Comma-separated list of executable names to try in order.
.PARAMETER UserArgs
    Optional arguments to append to the resolved command.
#>
param(
    [Parameter(Position = 0, Mandatory)]
    [string[]]$Candidates,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$UserArgs
)

$ErrorActionPreference = 'Stop'

$candidateList = ($Candidates -join ',') -split ','

foreach ($cmd in $candidateList) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        & $found.Path @UserArgs
        exit $LASTEXITCODE
    }
}

Write-Error "command-wrap: none of ($Candidates) found in PATH"
exit 1
