<#
.SYNOPSIS
    Run scoop core's bin\checkver.ps1 against the local buckets, forwarding extra arguments.
.PARAMETER App
    Manifest name or filepath, per core checkver.ps1. Default '*' (all buckets).
.PARAMETER Rest
    Remaining arguments forwarded as-is (-Update, -Skip, -Dir, ...).
#>
param(
    [Parameter(Position = 0)]
    [string]$App = '*',

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

# Resolve scoop root: env override first, then the shims-dir heuristic
# (shims live in <scooproot>\shims), else ask scoop (which returns the app dir).
$scoopRoot = $env:SCOOP
if (-not $scoopRoot -and (Split-Path -Leaf $PSScriptRoot) -eq 'shims') {
    $scoopRoot = Split-Path -Parent $PSScriptRoot
}
if (-not $scoopRoot) { $scoopRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (scoop prefix scoop).Trim())) }
$checkver = Join-Path $scoopRoot 'apps\scoop\current\bin\checkver.ps1'

# Core checkver.ps1 requires -Dir; default to the local buckets dir unless given.
if ($Rest -contains '-Dir') {
    & $checkver -App $App @Rest
} else {
    & $checkver -App $App -Dir (Join-Path $scoopRoot 'buckets') @Rest
}
if ($?) { exit 0 } else { exit 1 }
