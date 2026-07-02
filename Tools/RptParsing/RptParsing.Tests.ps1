Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "RptParsing.psm1") -Force

function Assert-Equal {
	param(
		$Actual,
		$Expected,
		[string]$Message
	)

	if ($Actual -ne $Expected) {
		throw "$Message Expected [$Expected], got [$Actual]."
	}
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-rpt-parsing-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
	Assert-Equal (Get-WaspRptCsvDelimiter "Semicolon") ";" "Semicolon delimiter mismatch."
	Assert-Equal (Get-WaspRptCsvDelimiter "Comma") "," "Comma delimiter mismatch."
	Assert-Equal (Get-WaspRptCsvDelimiter "Tab") "`t" "Tab delimiter mismatch."
	Assert-Equal (ConvertTo-WaspRptHtmlText '<tag attr="x">&') '&lt;tag attr=&quot;x&quot;&gt;&amp;' "HTML escaping mismatch."
	Assert-Equal (Get-WaspRptItemCount $null) 0 "Null count mismatch."
	Assert-Equal (Get-WaspRptItemCount @("a", "b")) 2 "Array count mismatch."

	$serverRpt = Join-Path $tempRoot "server.rpt"
	$hcLog = Join-Path $tempRoot "hc.log"
	$ignored = Join-Path $tempRoot "notes.md"
	"server" | Set-Content -LiteralPath $serverRpt -Encoding UTF8
	"hc" | Set-Content -LiteralPath $hcLog -Encoding UTF8
	"ignored" | Set-Content -LiteralPath $ignored -Encoding UTF8

	$folderFiles = @(Resolve-WaspRptInputFiles -Path @($tempRoot))
	Assert-Equal $folderFiles.Count 2 "Folder RPT/log resolution mismatch."
	Assert-Equal (@($folderFiles | Where-Object { $_.Role -eq "SERVER" }).Count) 1 "Server role inference mismatch."
	Assert-Equal (@($folderFiles | Where-Object { $_.Role -eq "HC" }).Count) 1 "HC role inference mismatch."

	$explicitFiles = @(Resolve-WaspRptInputFiles -Path @($serverRpt) -ExplicitRole "SERVER")
	Assert-Equal $explicitFiles[0].Role "SERVER" "Explicit role mismatch."

	$csvPath = Join-Path $tempRoot "rows.csv"
	Export-WaspRptRows @([pscustomobject]@{ name = "alpha"; value = 1 }) $csvPath ";"
	if (!(Test-Path -LiteralPath $csvPath)) { throw "CSV export did not create a file." }

	$plainCsvPath = Join-Path $tempRoot "plain.csv"
	Export-WaspRptCsv @([pscustomobject]@{ name = "bravo"; value = 2 }) $plainCsvPath ";"
	if (!(Select-String -LiteralPath $plainCsvPath -Pattern '"bravo"' -Quiet)) { throw "Plain CSV export did not write row data." }

	$emptyPath = Join-Path $tempRoot "empty.csv"
	Export-WaspRptRows @() $emptyPath ";"
	Assert-Equal (Get-Content -LiteralPath $emptyPath -Raw).Trim() "no_rows" "Empty export sentinel mismatch."
} finally {
	Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

Write-Host "RptParsing self-test passed."
