# Language: PowerShell
# Description: Reusable script to provision a new developer workstation on Windows.

# Ensure script runs as administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    Exit 1
}

# Function to install a package using winget if not already installed
function Install-PackageIfMissing {
    param(
        [string]$PackageId,
        [string]$PackageName
    )
    $packageInstalled = winget list --id $PackageId | Select-String $PackageId
    if (-not $packageInstalled) {
        Write-Host "Installing $PackageName..." -ForegroundColor Green
        winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements
    } else {
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

# Loop through tools and install each one
foreach ($tool in $tools) {
    Install-PackageIfMissing -PackageId $tool.Id -PackageName $tool.Name
}

# Optional: Download VS Code installer if winget is not used
$vsCodeInstallerUrl = "https://aka.ms/win32-x64-user-stable"
$localInstallerPath = "$env:TEMP\VSCodeSetup.exe"

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "Downloading VS Code installer..." -ForegroundColor Green
    Invoke-WebRequest -Uri $vsCodeInstallerUrl -OutFile $localInstallerPath
    Start-Process -FilePath $localInstallerPath -ArgumentList "/verysilent /mergetasks=!runcode" -Wait
    Remove-Item $localInstallerPath
} else {
    Write-Host "VS Code already installed." -ForegroundColor Yellow
}

# Finish message
Write-Host "Developer workstation setup complete!" -ForegroundColor Cyan