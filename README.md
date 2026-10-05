# dev-workstation
Scripts and tools for provisioning and deploying a developer workstation.

## dev-tools-install.ps1

`dev-tools-install.ps1` is a reusable PowerShell script for setting up a new Windows developer workstation.

### Execute on a new developer workstation

1. **Open PowerShell as Administrator**
   - Press `Win + X` and select "Windows PowerShell (Admin)" or "Terminal (Admin)"
   - Alternatively, search for "PowerShell" in the Start menu, right-click it, and select "Run as administrator"

2. **Copy and paste the following command:**

```powershell
iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/tauCete/dev-workstation/main/dev-tools-install.ps1')
```

3. **Press Enter** and wait for the installation to complete. The script will log all actions to `C:\t\logs\`.

### What it does
- Verifies the script is running with Administrator privileges.
- Creates a timestamped log file under `C:\t\logs`.
- Uses `winget` to detect and install missing developer tools.
- Installs the following tools when they are not already present:
  - Visual Studio Code
  - Git
  - Python 3
  - Node.js
- Logs each action, success, and error to the console and the log file.

### Current scope
The script intentionally does not install Docker Desktop or Postman right now. The repository notes indicate that Docker/Postman were temporarily removed, with Insomnia preferred instead as a lightweight API client.

### Requirements
- Windows 10 or 11
- `winget` available on the system
- PowerShell run as an Administrator

### Example usage
From an elevated PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\dev-tools-install.ps1
```

### Notes
- The script is designed to be idempotent: it checks whether each package is already installed before attempting installation.
- Log files are created with names like `install-YYYY-MM-DD_HH-mm-ss.log`.
- The script is intentionally simple and easy to extend with additional software or alternative package managers in the future.
