<#
	Author: Marty
	Description:
		Small Windows picker for the Town Defense RPT Analyzer.
		Lets users choose server and headless client RPT files through Explorer dialogs.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$analyzerPath = Join-Path $scriptDirectory "Analyze-TownDefenseRpt.ps1"

function Select-RptFile {
	param([string]$Title)

	$dialog = New-Object System.Windows.Forms.OpenFileDialog
	$dialog.Title = $Title
	$dialog.Filter = "Arma logs (*.rpt;*.log;*.txt)|*.rpt;*.log;*.txt|All files (*.*)|*.*"
	$dialog.Multiselect = $false

	if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		return $dialog.FileName
	}

	return $null
}

function Select-OutputFolder {
	param([string]$Description)

	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
	$dialog.Description = $Description
	$dialog.ShowNewFolderButton = $true

	if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		return $dialog.SelectedPath
	}

	return $null
}

function Get-DefaultOutputPath {
	param(
		[string]$ServerRpt,
		[string]$HcRpt
	)

	$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
	$basePath = $scriptDirectory

	if (![string]::IsNullOrWhiteSpace($ServerRpt)) {
		$basePath = Split-Path -Parent $ServerRpt
	} elseif (![string]::IsNullOrWhiteSpace($HcRpt)) {
		$basePath = Split-Path -Parent $HcRpt
	}

	return Join-Path $basePath ("TownDefenseRptResults_{0}" -f $timestamp)
}

function Resolve-OutputPath {
	param([string]$OutputPath)

	if ([System.IO.Path]::IsPathRooted($OutputPath)) {
		return [System.IO.Path]::GetFullPath($OutputPath)
	}

	return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputPath))
}

function Show-AnalyzerWindow {
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Town Defense RPT Analyzer"
	$form.StartPosition = "CenterScreen"
	$form.FormBorderStyle = "FixedDialog"
	$form.MaximizeBox = $false
	$form.MinimizeBox = $false
	$form.ClientSize = New-Object System.Drawing.Size(660, 235)

	$title = New-Object System.Windows.Forms.Label
	$title.Text = "Choose the server and headless client RPT files to analyze."
	$title.AutoSize = $true
	$title.Location = New-Object System.Drawing.Point(16, 16)
	$form.Controls.Add($title)

	$serverLabel = New-Object System.Windows.Forms.Label
	$serverLabel.Text = "Server RPT"
	$serverLabel.AutoSize = $true
	$serverLabel.Location = New-Object System.Drawing.Point(16, 52)
	$form.Controls.Add($serverLabel)

	$serverBox = New-Object System.Windows.Forms.TextBox
	$serverBox.Location = New-Object System.Drawing.Point(110, 49)
	$serverBox.Size = New-Object System.Drawing.Size(430, 23)
	$form.Controls.Add($serverBox)

	$serverButton = New-Object System.Windows.Forms.Button
	$serverButton.Text = "Browse..."
	$serverButton.Location = New-Object System.Drawing.Point(552, 47)
	$serverButton.Size = New-Object System.Drawing.Size(88, 27)
	$serverButton.Add_Click({
		$selected = Select-RptFile "Select the server RPT/log file"
		if (![string]::IsNullOrWhiteSpace($selected)) { $serverBox.Text = $selected }
	})
	$form.Controls.Add($serverButton)

	$hcLabel = New-Object System.Windows.Forms.Label
	$hcLabel.Text = "HC RPT"
	$hcLabel.AutoSize = $true
	$hcLabel.Location = New-Object System.Drawing.Point(16, 88)
	$form.Controls.Add($hcLabel)

	$hcBox = New-Object System.Windows.Forms.TextBox
	$hcBox.Location = New-Object System.Drawing.Point(110, 85)
	$hcBox.Size = New-Object System.Drawing.Size(430, 23)
	$form.Controls.Add($hcBox)

	$hcButton = New-Object System.Windows.Forms.Button
	$hcButton.Text = "Browse..."
	$hcButton.Location = New-Object System.Drawing.Point(552, 83)
	$hcButton.Size = New-Object System.Drawing.Size(88, 27)
	$hcButton.Add_Click({
		$selected = Select-RptFile "Select the headless client RPT/log file"
		if (![string]::IsNullOrWhiteSpace($selected)) { $hcBox.Text = $selected }
	})
	$form.Controls.Add($hcButton)

	$outputLabel = New-Object System.Windows.Forms.Label
	$outputLabel.Text = "Output"
	$outputLabel.AutoSize = $true
	$outputLabel.Location = New-Object System.Drawing.Point(16, 124)
	$form.Controls.Add($outputLabel)

	$outputBox = New-Object System.Windows.Forms.TextBox
	$outputBox.Location = New-Object System.Drawing.Point(110, 121)
	$outputBox.Size = New-Object System.Drawing.Size(430, 23)
	$form.Controls.Add($outputBox)

	$outputButton = New-Object System.Windows.Forms.Button
	$outputButton.Text = "Browse..."
	$outputButton.Location = New-Object System.Drawing.Point(552, 119)
	$outputButton.Size = New-Object System.Drawing.Size(88, 27)
	$outputButton.Add_Click({
		$selected = Select-OutputFolder "Select the output folder."
		if (![string]::IsNullOrWhiteSpace($selected)) { $outputBox.Text = $selected }
	})
	$form.Controls.Add($outputButton)

	$hint = New-Object System.Windows.Forms.Label
	$hint.Text = "Server and HC files are optional individually, but at least one RPT must be selected."
	$hint.AutoSize = $true
	$hint.Location = New-Object System.Drawing.Point(110, 153)
	$form.Controls.Add($hint)

	$analyzeButton = New-Object System.Windows.Forms.Button
	$analyzeButton.Text = "Analyze"
	$analyzeButton.Location = New-Object System.Drawing.Point(400, 188)
	$analyzeButton.Size = New-Object System.Drawing.Size(110, 32)
	$analyzeButton.Add_Click({
		$serverRpt = $serverBox.Text.Trim()
		$hcRpt = $hcBox.Text.Trim()

		if ([string]::IsNullOrWhiteSpace($serverRpt) -and [string]::IsNullOrWhiteSpace($hcRpt)) {
			[System.Windows.Forms.MessageBox]::Show("Select at least one RPT file.", "Town Defense RPT Analyzer", "OK", "Warning") | Out-Null
			return
		}

		if (![string]::IsNullOrWhiteSpace($serverRpt) -and !(Test-Path -LiteralPath $serverRpt -PathType Leaf)) {
			[System.Windows.Forms.MessageBox]::Show("Server RPT not found:`n$serverRpt", "Town Defense RPT Analyzer", "OK", "Error") | Out-Null
			return
		}

		if (![string]::IsNullOrWhiteSpace($hcRpt) -and !(Test-Path -LiteralPath $hcRpt -PathType Leaf)) {
			[System.Windows.Forms.MessageBox]::Show("HC RPT not found:`n$hcRpt", "Town Defense RPT Analyzer", "OK", "Error") | Out-Null
			return
		}

		$outputPath = $outputBox.Text.Trim()
		if ([string]::IsNullOrWhiteSpace($outputPath)) {
			$outputPath = Get-DefaultOutputPath -ServerRpt $serverRpt -HcRpt $hcRpt
			$outputBox.Text = $outputPath
		}

		$form.Tag = [pscustomobject]@{
			ServerRpt = $serverRpt
			HcRpt = $hcRpt
			OutputPath = $outputPath
		}
		$form.Close()
	})
	$form.Controls.Add($analyzeButton)

	$cancelButton = New-Object System.Windows.Forms.Button
	$cancelButton.Text = "Cancel"
	$cancelButton.Location = New-Object System.Drawing.Point(530, 188)
	$cancelButton.Size = New-Object System.Drawing.Size(110, 32)
	$cancelButton.Add_Click({
		$form.Tag = $null
		$form.Close()
	})
	$form.Controls.Add($cancelButton)

	$form.AcceptButton = $analyzeButton
	$form.CancelButton = $cancelButton

	[void]$form.ShowDialog()
	return $form.Tag
}

if (!(Test-Path -LiteralPath $analyzerPath -PathType Leaf)) {
	[System.Windows.Forms.MessageBox]::Show("Analyzer script not found:`n$analyzerPath", "Town Defense RPT Analyzer", "OK", "Error") | Out-Null
	exit 1
}

$selection = Show-AnalyzerWindow
if ($null -eq $selection) { exit 0 }

try {
	$outputPath = Resolve-OutputPath $selection.OutputPath
	[System.IO.Directory]::CreateDirectory($outputPath) | Out-Null

	$hasServerRpt = ![string]::IsNullOrWhiteSpace($selection.ServerRpt)
	$hasHcRpt = ![string]::IsNullOrWhiteSpace($selection.HcRpt)

	if ($hasServerRpt -and $hasHcRpt) {
		& $analyzerPath -ServerRpt $selection.ServerRpt -HcRpt $selection.HcRpt -OutputPath $outputPath
	} elseif ($hasServerRpt) {
		& $analyzerPath -ServerRpt $selection.ServerRpt -OutputPath $outputPath
	} elseif ($hasHcRpt) {
		& $analyzerPath -HcRpt $selection.HcRpt -OutputPath $outputPath
	} else {
		throw "No RPT file was selected."
	}

	if (!(Test-Path -LiteralPath $outputPath -PathType Container)) {
		throw "Output folder was not created:`n$outputPath"
	}

	$htmlReportPath = Join-Path $outputPath "town_defense_report.html"
	[System.Windows.Forms.MessageBox]::Show("Analysis complete.`n`nOutput folder:`n$outputPath", "Town Defense RPT Analyzer", "OK", "Information") | Out-Null
	if (Test-Path -LiteralPath $htmlReportPath -PathType Leaf) {
		Start-Process -FilePath $htmlReportPath
	} else {
		Start-Process explorer.exe -ArgumentList "`"$outputPath`""
	}
} catch {
	[System.Windows.Forms.MessageBox]::Show("Analysis failed:`n$($_.Exception.Message)", "Town Defense RPT Analyzer", "OK", "Error") | Out-Null
	throw
}
