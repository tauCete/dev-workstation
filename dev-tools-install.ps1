# Version: 20261005.003
# Language: PowerShell
# Description: Hardened script to provision a new developer workstation on Windows.

$ErrorActionPreference = "Stop"

# Use a more reliable log path and fallback if the default path is unavailable
$preferredLogDir = "C:\t\logs"
$logDir = $preferredLogDir

try {
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    if (-not (Test-Path $logDir)) {
        throw "Unable to create log directory: $logDir"
    }
    $testFile = Join-Path $logDir "write-test-$PID.txt"
    Set-Content -Path $testFile -Value "log test" -Force
    Remove-Item $testFile -Force
} catch {
    $fallbackLogDir = Join-Path $env:TEMP "dev-workstation-logs"
    if (-not (Test-Path $fallbackLogDir)) {
        New-Item -ItemType Directory -Path $fallbackLogDir -Force | Out-Null
    }
    $logDir = $fallbackLogDir
}

$logFile = Join-Path $logDir ("install-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    try {
        Add-Content -Path $logFile -Value $logMessage
    } catch {
        # Best effort fallback if logging fails for any reason
        Write-Host $logMessage
    }

    Write-Host $logMessage
}

function Ensure-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "This script must be run as Administrator." -ForegroundColor Red
        exit 1
    }
}

function Ensure-Winget {
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
        Write-Log "winget was not found on PATH. Please install App Installer/Winget and try again." -Level "ERROR"
        exit 1
    }
}

function Test-PackageInstalled {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId
    )

    $output = & winget list --id $PackageId --exact --accept-source-agreements 2>&1

    # winget often returns exit code 0 even when no package is found; parse the output instead
    $match = ($output | Out-String) -match "(?im)^\s*$([regex]::Escape($PackageId))\s+"

    return $match
}

function Install-PackageWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$PackageName,
        [int]$MaxAttempts = 3
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Write-Log "Checking installation status for $PackageName (ID: $PackageId)..." -Level "DEBUG"

        if (Test-PackageInstalled -PackageId $PackageId) {
            Write-Log "$PackageName is already installed (skipped)." -Level "INFO"
            return $true
        }

        Write-Log "Installing $PackageName (attempt $attempt/$MaxAttempts)..." -Level "INFO"
        Write-Host "Installing $PackageName..." -ForegroundColor Green

        $installStart = Get-Date

        try {
            & winget install `
                --id $PackageId `
                --exact `
                --silent `
                --accept-package-agreements `
                --accept-source-agreements `
                --disable-interactivity `
                --source winget 2>&1 | Tee-Object -Variable installOutput

            $exitCode = $LASTEXITCODE

            $duration = ((Get-Date) - $installStart).TotalSeconds

            if ($exitCode -eq 0) {
                if (Test-PackageInstalled -PackageId $PackageId) {
                    Write-Log "Successfully installed $PackageName in $([math]::Round($duration, 2))s" -Level "INFO"
                    return $true
                }

                Write-Log "winget reported success for $PackageName, but package was not detected afterward." -Level "WARNING"
            } else {
                Write-Log "Install attempt failed for $PackageName with exit code $exitCode" -Level "ERROR"
                if ($installOutput) {
                    Write-Log ($installOutput | Out-String) -Level "ERROR"
                }
            }
        } catch {
            $exceptionMsg = $PSItem.Exception.Message
            Write-Log "Exception during install of $PackageName - $exceptionMsg" -Level "ERROR"
        }

        if ($attempt -lt $MaxAttempts) {
            $sleepSeconds = 5 * $attempt
            Write-Log "Retrying $PackageName in ${sleepSeconds}s..." -Level "WARNING"
            Start-Sleep -Seconds $sleepSeconds
        } else {
            Write-Log "Failed to install $PackageName after $MaxAttempts attempts." -Level "ERROR"
            return $false
        }
    }

    return $false
}

function Show-Summary {
    param(
        [System.Collections.Generic.List[object]]$Results
    )

    $successful = ($Results | Where-Object { $_.Succeeded -eq $true }).Count
    $failed = ($Results | Where-Object { $_.Succeeded -eq $false }).Count

    Write-Log "Installation summary: $successful succeeded, $failed failed." -Level "INFO"
    Write-Host ""
    Write-Host "Installation summary: $successful succeeded, $failed failed." -ForegroundColor Cyan
}

# Main flow
Ensure-Admin
Ensure-Winget

Write-Log "Starting developer workstation provisioning..." -Level "INFO"
Write-Log "Log file: $logFile" -Level "INFO"

# List of tools to install via winget
# Keep these explicitly version-stable and well-known IDs.
$tools = @(
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
    @{ Id = "Git.Git"; Name = "Git" },
    @{ Id = "Python.Python.3"; Name = "Python 3" },
    @{ Id = "NodeJS.NodeJS"; Name = "Node.js" },
    @{ Id = "Obsidian.Obsidian"; Name = "Obsidian" }
)

# Future consideration: consider using Chocolatey for enterprise environments.
# For now, staying with winget for personal single-person use.
Write-Log "Processing $($tools.Count) tools for installation..." -Level "INFO"

$results = New-Object System.Collections.Generic.List[object]

foreach ($tool in $tools) {
    $installCount = $results.Count + 1
    Write-Log "[$installCount/$($tools.Count)] Processing $($tool.Name)..." -Level "INFO"

    $succeeded = Install-PackageWithRetry -PackageId $tool.Id -PackageName $tool.Name -MaxAttempts 3
    $results.Add([pscustomobject]@{
        Name      = $tool.Name
        PackageId = $tool.Id
        Succeeded = $succeeded
    })
}

Show-Summary -Results $results

Write-Log "Developer workstation setup complete!" -Level "INFO"
Write-Host "Developer workstation setup complete!" -ForegroundColor Cyan
Write-Host "Log file saved to: $logFile" -ForegroundColor Cyan
