# Language: PowerShell
# Description: Reusable script to provision a new developer workstation on Windows.

# Set up logging
$logDir = "C:\t\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = "$logDir\install-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# Ensure script runs as administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    Exit 1
}

# Validate logging capability before proceeding
Write-Host "Validating logging capability..." -ForegroundColor Cyan
try {
    $testLogFile = "$logDir\test-$(Get-Random).log"
    "Test log entry" | Out-File -FilePath $testLogFile -Encoding UTF8
    Remove-Item -Path $testLogFile -Force
    Write-Host "✓ Logging validation successful." -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to validate logging capability." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Log directory: $logDir" -ForegroundColor Red
    Write-Host "Please ensure the directory exists and you have write permissions." -ForegroundColor Red
    Exit 1
}

Write-Log "Starting developer workstation provisioning..." -Level "INFO"
Write-Log "Log file: $logFile" -Level "INFO"

# Function to install a package using winget if not already installed
function Install-PackageIfMissing {
    param(
        [string]$PackageId,
        [string]$PackageName
    )
    
    Write-Log "Checking installation status for $PackageName (ID: $PackageId)..." -Level "DEBUG"
    
    $packageInstalled = winget list --id $PackageId 2>&1 | Select-String $PackageId
    if (-not $packageInstalled) {
        Write-Log "Installing $PackageName..." -Level "INFO"
        Write-Host "Installing $PackageName..." -ForegroundColor Green
        
        $installStart = Get-Date
        try {
            winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            $installEnd = Get-Date
            $duration = ($installEnd - $installStart).TotalSeconds
            Write-Log "Successfully installed $PackageName in $($duration)s" -Level "INFO"
        } catch {
            Write-Log "Failed to install $PackageName`: $_" -Level "ERROR"
            Write-Host "Error installing $PackageName`: $_" -ForegroundColor Red
        }
    } else {
        Write-Log "$PackageName is already installed (skipped)." -Level "INFO"
        Write-Host "$PackageName is already installed." -ForegroundColor Yellow
    }
}

# List of tools to install via winget
$tools = @(
    @{Id="Microsoft.VisualStudioCode"; Name="Visual Studio Code"},
    @{Id="Git.Git"; Name="Git"},
    @{Id="Python.Python.3"; Name="Python 3"},
    @{Id="NodeJS.NodeJS"; Name="Node.js"}
# manually removed postman and docker for now. use insomnia instead of Postman, always
#    @{Id="Postman.Postman"; Name="Postman"},
#    @{Id="Docker.DockerDesktop"; Name="Docker Desktop"}
)

# Future consideration.  Consider using Chocolatey instead of winget for better enterprise features.
# for now as this is a personal single person audience staying with winget.

Write-Log "Processing $($tools.Count) tools for installation..." -Level "INFO"

# Loop through tools and install each one
$installCount = 0
foreach ($tool in $tools) {
    $installCount++
    Write-Log "[$installCount/$($tools.Count)] Processing $($tool.Name)..." -Level "INFO"
    Install-PackageIfMissing -PackageId $tool.Id -PackageName $tool.Name
}

# Optional: Download VS Code installer if winget is not used
# $vsCodeInstallerUrl = "https://aka.ms/win32-x64-user-stable"
# $localInstallerPath = "$env:TEMP\VSCodeSetup.exe"
#
# if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
#     Write-Host "Downloading VS Code installer..." -ForegroundColor Green
#     Invoke-WebRequest -Uri $vsCodeInstallerUrl -OutFile $localInstallerPath
#     Start-Process -FilePath $localInstallerPath -ArgumentList "/verysilent /mergetasks=!runcode" -Wait
#     Remove-Item $localInstallerPath
# } else {
#     Write-Host "VS Code already installed." -ForegroundColor Yellow
# }

# Finish message
Write-Log "Developer workstation setup complete!" -Level "INFO"
Write-Host "Developer workstation setup complete!" -ForegroundColor Cyan
Write-Host "Log file saved to: $logFile" -ForegroundColor Cyan
