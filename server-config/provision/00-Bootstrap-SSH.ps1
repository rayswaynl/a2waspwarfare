# 00-Bootstrap-SSH.ps1 - FIRST-CONTACT script: paste into an elevated PowerShell in the
# box's RDP session right after activation. Installs OpenSSH Server and authorizes the
# operator pubkey so every later step can run remotely.
# Usage:  .\00-Bootstrap-SSH.ps1 -PubKey 'ssh-ed25519 AAAA... comment'
# (Get the pubkey on the operator PC with:  type %USERPROFILE%\.ssh\id_ed25519.pub)
# PowerShell 5.1 compatible. Run elevated. Idempotent.
Param([Parameter(Mandatory = $true)][String]$PubKey)
$ErrorActionPreference = 'Stop'

if ($PubKey -notmatch '^(ssh-(rsa|ed25519)|ecdsa-sha2-\S+)\s+\S+') { throw 'PubKey does not look like an OpenSSH public key line.' }

Write-Host '== Installing OpenSSH Server capability =='
$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
if ($null -eq $cap) { throw 'OpenSSH.Server capability not found on this image.' }
if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name | Out-Null; Write-Host 'Installed.' }
else { Write-Host 'Already installed.' }

Write-Host '== Enabling sshd service =='
Set-Service sshd -StartupType Automatic
Start-Service sshd

Write-Host '== Firewall =='
$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if ($null -eq $rule) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Host 'Rule created.'
} else { Write-Host 'Rule present.' }

Write-Host '== Authorizing key (administrators_authorized_keys) =='
# Admin-group users read keys from this file, NOT ~\.ssh\authorized_keys.
$keys = 'C:\ProgramData\ssh\administrators_authorized_keys'
$have = @()
if (Test-Path $keys) { $have = @(Get-Content -LiteralPath $keys) }
if ($have -notcontains $PubKey) {
    Add-Content -LiteralPath $keys -Value $PubKey -Encoding Ascii
    Write-Host 'Key appended.'
} else { Write-Host 'Key already present.' }
# sshd requires this exact ACL (Administrators + SYSTEM only) or it ignores the file.
icacls $keys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null

Write-Host '== Done =='
Write-Host 'Verify from the operator PC:  ssh <user>@<this-box-ip> hostname'
Write-Host 'Then continue with 01-Base-OS.ps1 remotely.'
