# --- Disable Sleep Mode ---
function Disable-SleepMode {
    try {
        powercfg -change -standby-timeout-ac 0
        powercfg -change -standby-timeout-dc 0
        powercfg -change -monitor-timeout-ac 0
        powercfg -change -monitor-timeout-dc 0
        Write-Host "Sleep mode and monitor timeout disabled."
    } catch {
        Write-Host "Error disabling sleep mode: $_" -ForegroundColor Red
    }
}

# --- Set Desktop Background ---
function Set-DesktopBackground {
    param (
        [string]$ImagePath
    )
    try {
        if (-not (Test-Path $ImagePath)) {
            Write-Host "Background image file not found: $ImagePath" -ForegroundColor Red
            return
        }
        Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
        $SPI_SETDESKWALLPAPER = 0x0014
        $SPIF_UPDATEINIFILE = 0x01
        $SPIF_SENDWININICHANGE = 0x02
        [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE) | Out-Null
        Write-Host "Desktop background set to $ImagePath."
    } catch {
        Write-Host "Error setting desktop background: $_" -ForegroundColor Red
    }
}
Clear-Host
Write-Host ""
Write-Host "========================================================"
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host '      ____   _   _   ___  ' -ForegroundColor Red
Write-Host '     | ___ \_   _/  ___|  ' -ForegroundColor Red
Write-Host '     | |_/ / | | \ `--.   ' -ForegroundColor Red
Write-Host '     |    /  | |  `--. \  ' -ForegroundColor Red
Write-Host '     | |\ \  | | /\__/ /  ' -ForegroundColor Red
Write-Host '     \_| \_| \_/ \____/    ' -ForegroundColor Red
Write-Host ""
Write-Host '     RTS Package Installer Script V1.0' -ForegroundColor Red
Write-Host '     Created by Brecht Bondue ' -ForegroundColor Red
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host 'NOTES:' -ForegroundColor blue
Write-Host ""
Write-Host "========================================================"
Write-Host ""
Write-Host "NOTES:" -ForegroundColor blue
function Install-Chocolatey {
    try {
        $choco = Get-Command choco.exe -ErrorAction SilentlyContinue
        if ($choco) {
            Write-Log "Chocolatey is already installed."
        } else {
            Write-Log "Installing Chocolatey using winget..."
            winget install --id "Chocolatey.Chocolatey" --exact --source winget --accept-source-agreements --accept-package-agreements --silent
            if (Get-Command choco.exe -ErrorAction SilentlyContinue) {
                Write-Log "Chocolatey installed successfully."
            } else {
                Write-Log "Chocolatey installation failed." "ERROR"
            }
        }
    } catch {
        Write-Log "Error installing Chocolatey: $_" "ERROR"
    }
}
<#
.SYNOPSIS
    Configures a Windows machine with SNMP, RDP, firewall rules, and hostname.

.DESCRIPTION
    - Installs SNMP if not installed
    - Renames computer (requires reboot)
    - Enables RDP
    - Configures firewall rules (RDP + ICMP)
    - Logs actions to file

.PARAMETER Hostname
    New hostname for the computer.

.PARAMETER LogPath
    Path to log file. Default: C:\Temp\config-server.log
#>



# Set default values if not provided
if (-not $Hostname) {
    $Hostname = Read-Host "Enter the new hostname for this computer"
    if (-not $Hostname) { $Hostname = "MyServer" }
}
if (-not $LogPath) { $LogPath = "C:\Temp\config-server.log" }

# Ensure log directory exists
$logDir = Split-Path $LogPath
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line
}
# Installing SNMP
function Install-SNMP {
    Write-Host "SNMP feature installeren..."
    if (Add-WindowsCapability -Online -Name "SNMP.Client~~~~0.0.1.0") {
        # For Windows Server
        Install-WindowsFeature -Name "SNMP" -IncludeManagementTools
    } else {
        # For Windows 10/11
        Add-WindowsCapability -Online -Name "SNMP.Client~~~~0.0.1.0"
    }
    Write-Host "SNMP feature is geïnstalleerd."
}


# --- Change Hostname ---
function Set-Hostname {
    param ([string]$NewName)
    if ($env:COMPUTERNAME -ne $NewName) {
        try {
            Rename-Computer -NewName $NewName -Force -ErrorAction Stop
            Write-Log "Hostname changed to $NewName. Reboot required."
        } catch {
            Write-Log "Error changing hostname: $_" "ERROR"
        }
    } else {
        Write-Log "Hostname already set to $NewName."
    }
}

# --- Enable RDP ---
function Enable-RDP {
    try {
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        Write-Log "RDP enabled."

        # Enable RDP firewall rule
            $rdpRule = Get-NetFirewallRule -DisplayName "Remote Desktop" -ErrorAction SilentlyContinue
            if (-not $rdpRule) {
                New-NetFirewallRule -DisplayName "Remote Desktop" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 3389
                Write-Log "RDP firewall rule added."
            } elseif ($rdpRule.Enabled -ne "True") {
                Set-NetFirewallRule -DisplayName "Remote Desktop" -Enabled True
                Write-Log "RDP firewall rule enabled."
            } else {
                Write-Log "RDP firewall rule already exists and is enabled."
        }
    } catch {
        Write-Log "Error enabling RDP: $_" "ERROR"
    }
}

# --- Configure Firewall (ICMP + RDP) ---
function Configure-Firewall {
    try {
            $icmpv4Rule = Get-NetFirewallRule -DisplayName "Allow Inbound ICMPv4 Echo Request" -ErrorAction SilentlyContinue
            if (-not $icmpv4Rule) {
                New-NetFirewallRule -DisplayName "Allow Inbound ICMPv4 Echo Request" -Protocol ICMPv4 -IcmpType 8 -Enabled True -Profile Any -Action Allow
                Write-Log "ICMPv4 firewall rule added."
            } elseif ($icmpv4Rule.Enabled -ne "True") {
                Set-NetFirewallRule -DisplayName "Allow Inbound ICMPv4 Echo Request" -Enabled True
                Write-Log "ICMPv4 firewall rule enabled."
            }

            $icmpv6Rule = Get-NetFirewallRule -DisplayName "Allow Inbound ICMPv6 Echo Request" -ErrorAction SilentlyContinue
            if (-not $icmpv6Rule) {
                New-NetFirewallRule -DisplayName "Allow Inbound ICMPv6 Echo Request" -Protocol ICMPv6 -IcmpType 128 -Enabled True -Profile Any -Action Allow
                Write-Log "ICMPv6 firewall rule added."
          
            } elseif ($icmpv6Rule.Enabled -ne "True") {
                Set-NetFirewallRule -DisplayName "Allow Inbound ICMPv6 Echo Request" -Enabled True
                Write-Log "ICMPv6 firewall rule enabled."
        }
    } catch {
        Write-Log "Error configuring firewall: $_" "ERROR"
    }
}

# --- Main Execution ---
Write-Log "===== Starting system configuration ====="
Install-Chocolatey
Install-SNMP
Get-WindowsProductKey
Set-Hostname -NewName $Hostname
Enable-RDP
Configure-Firewall
Disable-SleepMode
# Set desktop background (update the path as needed)
# Example: $backgroundPath = "C:\Path\To\Your\Image.jpg"
# Set-DesktopBackground -ImagePath $backgroundPath
Write-Log "===== Configuration complete. Reboot recommended. ====="

# --- Run app-install-script.ps1 ---
$appInstallScript = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ".\APPS\app-install-script.ps1"
if (Test-Path $appInstallScript) {
    Write-Log "Starting application package installations from app-install-script.ps1..."
    try {
        & $appInstallScript
        Write-Log "Application package installations completed."
    } catch {
        Write-Log "Error running app-install-script.ps1: $_" "ERROR"
    }
} else {
    Write-Log "app-install-script.ps1 not found. Skipping application package installations." "WARN"
}
# --- Run and install .exe files in APPS\EXE_FILES ---
$exeFolder = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ".\APPS\EXE_FILES"
if (Test-Path $exeFolder) {
    $exeFiles = Get-ChildItem -Path $exeFolder -Filter *.exe
    foreach ($exe in $exeFiles) {
        Write-Log "Found installer: $($exe.Name). Attempting to run silently..."
        try {
            # Try common silent install switches
            Start-Process -FilePath $exe.FullName -ArgumentList "/S", "/silent", "/qn", "/quiet" -Wait
            Write-Log "$($exe.Name) installation attempted."
        } catch {
            Write-Log "ERROR: Failed to run $($exe.Name): $_"
        }
    }
} else {
    Write-Log "INFO: No EXE installers folder found. Skipping .exe installations."
}
# ...existing code...
