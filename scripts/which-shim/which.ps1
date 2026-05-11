$ErrorActionPreference = 'Stop'
$candidates = $args[0] -split ';'
$userArgs = @()
if ($args.Count -gt 1) { $userArgs = $args[1..($args.Count - 1)] }
foreach ($cmd in $candidates) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        & $found.Path @userArgs
        exit $LASTEXITCODE
    }
}
Write-Error "which-shim: none of ($($args[0])) found in PATH"
exit 1
