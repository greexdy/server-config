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
    - Retrieves Windows product key
    - Renames computer (requires reboot)
    - Enables RDP
    - Configures firewall rules (RDP + ICMP)
    - Logs actions to file

.PARAMETER Hostname
    New hostname for the computer.

.PARAMETER LogPath
    Path to log file. Default: C:\Temp\config-supermicro.log
#>

param (
    [string]$Hostname,
    [string]$LogPath
)

# Set default values if not provided
if (-not $Hostname) { $Hostname = "MyServer" }
if (-not $LogPath) { $LogPath = "C:\Temp\config-supermicro.log" }

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

# --- Install SNMP ---
function Install-SNMP {
    Write-Log "Checking SNMP installation..."
    try {
        $snmpInstalled = Get-WindowsCapability -Online | Where-Object Name -like "SNMP.Client*" | Where-Object State -eq "Installed"
    } catch {
        Write-Log "Get-WindowsCapability failed: $_" "ERROR"
        if ($_.Exception.Message -like '*0x800f0800*') {
            Write-Log "Windows component store may be corrupted. Please run the following commands in an elevated PowerShell window:" "ERROR"
            Write-Log "DISM /Online /Cleanup-Image /RestoreHealth" "ERROR"
            Write-Log "sfc /scannow" "ERROR"
        }
        return
    }
    if ($snmpInstalled) {
        Write-Log "SNMP is already installed."
    } else {
        try {
            Add-WindowsCapability -Online -Name "SNMP.Client~~~~0.0.1.0" -ErrorAction Stop
            Write-Log "SNMP installed successfully."
        } catch {
            try {
                Install-WindowsFeature -Name "SNMP" -IncludeManagementTools -ErrorAction Stop
                Write-Log "SNMP installed successfully (Server method)."
            } catch {
                Write-Log "SNMP installation failed: $_" "ERROR"
            }
        }
    }
}

# --- Get Windows Product Key ---
function Get-WindowsProductKey {
    try {
        $key = (Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey
        if ($key) {
            Write-Log "Windows Product Key: $key"
        } else {
            Write-Log "Windows Product Key not found." "WARN"
        }
    } catch {
        Write-Log "Error retrieving product key: $_" "ERROR"
    }
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
