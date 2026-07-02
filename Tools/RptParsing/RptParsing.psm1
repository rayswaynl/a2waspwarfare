Set-StrictMode -Version 2.0

function Get-WaspRptCsvDelimiter {
	param(
		[ValidateSet("Semicolon", "Comma", "Tab")]
		[string]$Name = "Semicolon"
	)

	switch ($Name) {
		"Comma" { return "," }
		"Tab" { return "`t" }
		default { return ";" }
	}
}

function Get-WaspRptItemCount {
	param($Items)

	if ($null -eq $Items) { return 0 }
	$array = @($Items)
	return $array.Length
}

function ConvertTo-WaspRptHtmlText {
	param($Value)

	if ($null -eq $Value) { return "" }
	return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-WaspRptDefaultRoleFromPath {
	param([string]$Path)

	$name = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
	if ($name -match 'headless|(^|[_\-.])hc([_\-.]|$)') { return "HC" }
	if ($name -match 'server') { return "SERVER" }
	return "UNKNOWN"
}

function Resolve-WaspRptInputFiles {
	param(
		[string[]]$Path,
		[switch]$Recurse,
		[string]$ExplicitRole = "",
		[scriptblock]$RoleResolver = $null
	)

	$files = New-Object System.Collections.Generic.List[object]
	$searchOption = if ($Recurse) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }

	foreach ($inputPath in $Path) {
		if ([string]::IsNullOrWhiteSpace($inputPath)) { continue }

		$matchedItems = New-Object System.Collections.Generic.List[object]
		if (Test-Path -LiteralPath $inputPath -PathType Leaf) {
			$matchedItems.Add((Get-Item -LiteralPath $inputPath))
		} elseif (Test-Path -LiteralPath $inputPath -PathType Container) {
			[System.IO.Directory]::EnumerateFiles((Get-Item -LiteralPath $inputPath).FullName, "*.*", $searchOption) |
				Where-Object { $_ -match '\.(rpt|log|txt)$' } |
				ForEach-Object { $matchedItems.Add((Get-Item -LiteralPath $_)) }
		} else {
			$resolvedPaths = @(Resolve-Path -Path $inputPath -ErrorAction SilentlyContinue)
			foreach ($resolvedPath in $resolvedPaths) {
				$item = Get-Item -LiteralPath $resolvedPath.Path
				if (!$item.PSIsContainer) { $matchedItems.Add($item) }
			}
		}

		if ($matchedItems.Count -eq 0 -and !(Test-Path -LiteralPath $inputPath -PathType Container)) {
			throw "InputPath not found: $inputPath"
		}

		foreach ($item in $matchedItems) {
			$role = $ExplicitRole
			if ([string]::IsNullOrWhiteSpace($role)) {
				$role = if ($null -ne $RoleResolver) { & $RoleResolver $item.FullName } else { Get-WaspRptDefaultRoleFromPath $item.FullName }
			}

			$files.Add([pscustomobject]@{
				Path = $item.FullName
				FullName = $item.FullName
				FileInfo = $item
				Role = $role
			})
		}
	}

	return @($files.ToArray())
}

function Export-WaspRptRows {
	param(
		[object[]]$Rows,
		[string]$Path,
		[string]$Delimiter
	)

	if ((Get-WaspRptItemCount $Rows) -eq 0) {
		"no_rows" | Set-Content -LiteralPath $Path -Encoding UTF8
		return
	}

	$Rows | Export-Csv -LiteralPath $Path -Delimiter $Delimiter -NoTypeInformation -Encoding UTF8
}

function Export-WaspRptCsv {
	param(
		[object[]]$Rows,
		[string]$Path,
		[string]$Delimiter
	)

	$Rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 -Delimiter $Delimiter
}

Set-Alias -Name Get-CsvDelimiter -Value Get-WaspRptCsvDelimiter
Set-Alias -Name Get-ItemCount -Value Get-WaspRptItemCount
Set-Alias -Name ConvertTo-HtmlText -Value ConvertTo-WaspRptHtmlText
Set-Alias -Name Export-Rows -Value Export-WaspRptRows
Set-Alias -Name Export-AuditCsv -Value Export-WaspRptCsv

Export-ModuleMember -Function Get-WaspRptCsvDelimiter, Get-WaspRptItemCount, ConvertTo-WaspRptHtmlText, Get-WaspRptDefaultRoleFromPath, Resolve-WaspRptInputFiles, Export-WaspRptRows, Export-WaspRptCsv -Alias Get-CsvDelimiter, Get-ItemCount, ConvertTo-HtmlText, Export-Rows, Export-AuditCsv
