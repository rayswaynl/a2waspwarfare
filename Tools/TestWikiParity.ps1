param(
    [string]$DocsWikiPath = "docs/wiki",
    [string]$WikiPath = "C:\Users\Steff\_wasp_wiki_tmp"
)

$ErrorActionPreference = "Stop"

function Resolve-CheckedPath {
    param(
        [string]$PathValue,
        [string]$BasePath,
        [string]$Label
    )

    $candidate = if ([IO.Path]::IsPathRooted($PathValue)) {
        $PathValue
    } else {
        Join-Path $BasePath $PathValue
    }

    if (-not (Test-Path -LiteralPath $candidate)) {
        Write-Error "$Label path not found: $candidate"
        exit 1
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$docsRoot = Resolve-CheckedPath -PathValue $DocsWikiPath -BasePath $repoRoot -Label "docs/wiki"
$wikiRoot = Resolve-CheckedPath -PathValue $WikiPath -BasePath $repoRoot -Label "wiki mirror"

$docsFiles = @(Get-ChildItem -LiteralPath $docsRoot -File)
$wikiFiles = @(Get-ChildItem -LiteralPath $wikiRoot -File)

$docsByName = @{}
foreach ($file in $docsFiles) {
    $docsByName[$file.Name] = $file.FullName
}

$wikiByName = @{}
foreach ($file in $wikiFiles) {
    $wikiByName[$file.Name] = $file.FullName
}

$problems = New-Object System.Collections.Generic.List[string]

foreach ($name in ($docsByName.Keys | Sort-Object)) {
    if (-not $wikiByName.ContainsKey($name)) {
        $problems.Add("missing-in-wiki: $name")
        continue
    }

    $docsHash = (Get-FileHash -LiteralPath $docsByName[$name] -Algorithm SHA256).Hash
    $wikiHash = (Get-FileHash -LiteralPath $wikiByName[$name] -Algorithm SHA256).Hash
    if ($docsHash -ne $wikiHash) {
        $problems.Add("hash-mismatch: $name")
    }
}

foreach ($name in ($wikiByName.Keys | Sort-Object)) {
    if (-not $docsByName.ContainsKey($name)) {
        $problems.Add("extra-in-wiki: $name")
    }
}

if ($problems.Count -gt 0) {
    $problems | Sort-Object | ForEach-Object { Write-Host $_ }
    Write-Error "Wiki parity check failed"
    exit 1
}

Write-Host "Parity OK: $($docsFiles.Count) files"
