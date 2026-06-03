param(
    [string]$WikiPath = "docs/wiki",
    [switch]$SkipGitDiffCheck
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $repoRoot "Tools/ValidateWiki.ps1"

$validatorArgs = @{
    WikiPath = $WikiPath
}
if ($SkipGitDiffCheck) {
    $validatorArgs.SkipGitDiffCheck = $true
}

& $validator @validatorArgs
