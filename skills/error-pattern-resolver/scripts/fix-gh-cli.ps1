# fix-gh-cli.ps1 — Install GitHub CLI on Windows
# Usage: powershell -ExecutionPolicy Bypass -File fix-gh-cli.ps1
#
# Detects existing installation, downloads and installs GitHub CLI
# if not present, and verifies the installation.

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

# Configuration
$GH_CLI_URL = "https://github.com/cli/cli/releases/latest/download/gh_2.65.0_windows_amd64.msi"
$GH_CLI_MIN_VERSION = [version]"2.0.0"
$INSTALL_DIR = "${env:ProgramFiles}\GitHub CLI"
$LOG_FILE = "$env:TEMP\gh-cli-install.log"

# Write-Log function for consistent logging
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warn", "Error", "Success")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "Info"    { Write-Host $logEntry -ForegroundColor Cyan }
        "Warn"    { Write-Host $logEntry -ForegroundColor Yellow }
        "Error"   { Write-Host $logEntry -ForegroundColor Red }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
    }

    Add-Content -Path $LOG_FILE -Value $logEntry -ErrorAction SilentlyContinue
}

# Check if GitHub CLI is already installed
function Test-GhInstalled {
    try {
        $ghPath = Get-Command gh -ErrorAction Stop
        $version = & gh --version 2>$null | Select-Object -First 1

        if ($version -match "gh version (\d+\.\d+\.\d+)") {
            $installedVersion = [version]$Matches[1]
            Write-Log "GitHub CLI found: v$installedVersion at $($ghPath.Source)" -Level Info

            if ($installedVersion -ge $GH_CLI_MIN_VERSION) {
                Write-Log "Installed version meets minimum requirement ($GH_CLI_MIN_VERSION)" -Level Success
                return $true
            } else {
                Write-Log "Installed version is below minimum ($GH_CLI_MIN_VERSION)" -Level Warn
                return $false
            }
        }

        Write-Log "GitHub CLI found but version could not be determined" -Level Warn
        return $false
    } catch {
        Write-Log "GitHub CLI is not installed" -Level Info
        return $false
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Download file with progress
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    Write-Log "Downloading from: $Url" -Level Info

    try {
        # Use TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)

        $fileInfo = Get-Item $OutputPath
        Write-Log "Download complete: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -Level Success
        return $true
    } catch {
        Write-Log "Download failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Install GitHub CLI from MSI
function Install-GhCli {
    param(
        [string]$MsiPath
    )

    Write-Log "Installing GitHub CLI..." -Level Info

    try {
        # Silent install with msiexec
        $arguments = @(
            "/i"
            "`"$MsiPath`""
            "/quiet"
            "/norestart"
            "/l*v"
            "`"$LOG_FILE`""
        )

        $process = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList $arguments `
            -Wait `
            -PassThru `
            -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Log "Installation completed successfully" -Level Success
            return $true
        } elseif ($process.ExitCode -eq 3010) {
            Write-Log "Installation completed (restart required)" -Level Warn
            return $true
        } else {
            Write-Log "Installation failed with exit code: $($process.ExitCode)" -Level Error
            return $false
        }
    } catch {
        Write-Log "Installation error: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Add GitHub CLI to PATH if not already present
function Update-Path {
    $ghPath = "$INSTALL_DIR\gh.exe"

    if (-not (Test-Path $ghPath)) {
        Write-Log "gh.exe not found at expected location: $ghPath" -Level Warn
        return
    }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

    if ($currentPath -notlike "*$INSTALL_DIR*") {
        Write-Log "Adding GitHub CLI to system PATH..." -Level Info

        if (Test-Administrator) {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$INSTALL_DIR", "Machine")
            $env:Path = "$env:Path;$INSTALL_DIR"
            Write-Log "GitHub CLI added to system PATH" -Level Success
        } else {
            Write-Log "Administrator privileges required to modify system PATH" -Level Warn
            Write-Log "Please manually add to PATH: $INSTALL_DIR" -Level Warn
        }
    } else {
        Write-Log "GitHub CLI is already in system PATH" -Level Info
    }
}

# Verify installation
function Verify-Installation {
    Write-Log "Verifying GitHub CLI installation..." -Level Info

    # Refresh PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    try {
        $version = & gh --version 2>$null | Select-Object -First 1
        if ($version) {
            Write-Log "Verification successful: $version" -Level Success

            # Test auth status
            $authStatus = & gh auth status 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "GitHub authentication is configured" -Level Success
            } else {
                Write-Log "GitHub CLI installed but not authenticated. Run: gh auth login" -Level Warn
            }

            return $true
        }
    } catch {
        Write-Log "Verification failed: gh command not found" -Level Error
    }

    return $false
}

# Main execution
function Main {
    Write-Log "GitHub CLI Installer for Windows" -Level Info
    Write-Log "================================" -Level Info

    # Check if running as administrator (required for install)
    $isAdmin = Test-Administrator
    if (-not $isAdmin) {
        Write-Log "Warning: Not running as administrator. Installation may require elevation." -Level Warn
    }

    # Check if already installed
    if (Test-GhInstalled) {
        if ($Force) {
            Write-Log "Force flag set. Proceeding with reinstallation..." -Level Warn
        } elseif ($VerifyOnly) {
            Write-Log "Verify-only mode. Skipping installation." -Level Info
            return
        } else {
            Write-Log "GitHub CLI is already installed. Use -Force to reinstall." -Level Info
            return
        }
    }

    # Download MSI
    $msiPath = "$env:TEMP\gh-cli-install.msi"

    Write-Log "Downloading GitHub CLI..." -Level Info
    if (-not (Download-File -Url $GH_CLI_URL -OutputPath $msiPath)) {
        Write-Log "Failed to download GitHub CLI installer" -Level Error
        Write-Log "Please download manually from: https://cli.github.com/" -Level Error
        exit 1
    }

    # Install
    if (-not (Install-GhCli -MsiPath $msiPath)) {
        Write-Log "Failed to install GitHub CLI" -Level Error
        exit 1
    }

    # Update PATH
    Update-Path

    # Clean up
    if (Test-Path $msiPath) {
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up installer file" -Level Info
    }

    # Verify
    if (Verify-Installation) {
        Write-Log "" -Level Info
        Write-Log "========================================" -Level Success
        Write-Log "  GitHub CLI installed successfully!" -Level Success
        Write-Log "  Run 'gh auth login' to authenticate" -Level Success
        Write-Log "========================================" -Level Success
    } else {
        Write-Log "Installation completed but verification failed." -Level Warn
        Write-Log "You may need to restart your terminal or computer." -Level Warn
    }
}

# Run main function
Main
