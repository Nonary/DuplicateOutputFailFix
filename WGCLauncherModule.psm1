function Load-Settings {
    param (
        [string]$Path
    )
    if (-Not (Test-Path $Path)) {
        Throw "Settings file not found at path: $Path"
    }
    Get-Content $Path | ConvertFrom-Json
}

function UpdateSunshineConfig {
    param (
        [string]$ConfigPath
    )

    $content = Get-Content $ConfigPath
    $found = $false

    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i].StartsWith("capture")) {
            $content[$i] = "capture = wgc"
            $found = $true
            break
        }
    }

    if (-not $found) {
        $content += "capture = wgc"
    }

    return $content
}

function Ensure-DirectoryExists {
    param (
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Write-ConfigFile {
    param (
        [string]$Path,
        [string[]]$Content
    )
    $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Content, $utf8NoBOM)
    Write-Host "Configuration written to $Path"
}

function UpdateAppsJson {
    param (
        [string]$AppsJsonPath,
        [string]$DestinationPath,
        [string]$ScriptRoot
    )

    $appsContent = Get-Content $AppsJsonPath -Raw | ConvertFrom-Json

    # Remove apps related to WGC
    $appsContent.apps = $appsContent.apps | Where-Object { $_.name -notlike "*WGC*" }

    # Check if "WGC Kill Session" app exists
    $wgcAppExists = $appsContent.apps | Where-Object { $_.name -eq "WGC Kill Session" }

    if (-not $wgcAppExists) {
        # Define the new app configuration
        $newApp = @{
            "name"                    = "WGC Kill Session"
            "cmd"                     = "powershell.exe -ExecutionPolicy Bypass -File `"$ScriptRoot\WGCLauncher.ps1`" KillSession"
            "image-path"              = ""
            "auto-detach"             = "true"
            "wait-all"                = "true"
            "elevated"                = "true"
            "exclude-global-prep-cmd" = "true"
        }

        # Add the new app to the apps array
        $appsContent.apps += $newApp

        # Convert back to JSON
        $newAppsJson = $appsContent | ConvertTo-Json -Depth 10

        # Write the updated JSON content to the destination apps.json
        $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($DestinationPath, $newAppsJson, $utf8NoBOM)
        Write-Host "'WGC Kill Session' app added to apps.json."
    }
    else {
        Write-Host "The 'WGC Kill Session' app already exists in apps.json."
    }
}

function Copy-Configuration {
    param (
        [object]$Settings
    )

    $sunshinePath = $Settings.sunshineDirectory

    $sunshineConfig = Join-Path $sunshinePath "config\sunshine.conf"
    $appsJson = Join-Path $sunshinePath "config\apps.json"

    # Update sunshine.conf
    $updatedConfig = UpdateSunshineConfig -ConfigPath $sunshineConfig

    # Ensure the output directory exists
    $outputDir = ".\SunshinePortable\config"
    Ensure-DirectoryExists -Path $outputDir

    # Copy Sunshine directory
    Copy-Item -Recurse -Force -Path "$sunshinePath\*" -Destination ".\SunshinePortable"

    # Write the updated sunshine.conf to the new location
    $adjustedConfig = Join-Path $PSScriptRoot "SunshinePortable\config\sunshine.conf"
    Write-ConfigFile -Path $adjustedConfig -Content $updatedConfig

    # Update apps.json
    UpdateAppsJson -AppsJsonPath $appsJson -DestinationPath "$PSScriptRoot\SunshinePortable\config\apps.json" -ScriptRoot $PSScriptRoot
}
function Execute-ScriptBlockWMI {
    param (
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    try {
        Write-Host "Debug: Starting Execute-ScriptBlockWMI"
        
        # Create WMI process startup configuration
        $startupInfo = ([WMICLASS]"Win32_ProcessStartup").CreateInstance()
        $startupInfo.ShowWindow = 0

        # Create the command string with arguments
        $argString = if ($Arguments) {
            "'" + ($Arguments -join "','") + "'"
        } else { "" }
        
        # Create the full PowerShell command
        $psCommand = "& {" + $ScriptBlock.ToString() + "} $argString"
        
        # Convert to Base64
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($psCommand)
        $encodedCommand = [Convert]::ToBase64String($bytes)

        Write-Host "Debug: Creating WMI process..."
        $process = ([WMICLASS]"Win32_Process").Create(
            "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand",
            $Arguments[0],  # Working directory
            $startupInfo
        )

        if ($process.ReturnValue -eq 0) {
            Write-Host "Successfully launched script in new process. PID: $($process.ProcessId)"
            return $process.ProcessId
        }
        else {
            throw "Failed to create process. Return value: $($process.ReturnValue)"
        }
    }
    catch {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $logFile = Join-Path $desktopPath "WMIExecutionError.log"
        @"
----------------------------------------
Error Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Error Message: $($_.Exception.Message)
Command: $psCommand
----------------------------------------
"@ | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        throw "WMI execution failed: $_"
    }
}

function Launch-PortableSunshine {
    $scriptBlock = {
        param($Path)
        Set-Location $Path
        
        if (Get-Service SunshineService -ErrorAction SilentlyContinue) {
            Write-Log "Stopping Sunshine service..."
            Stop-Service SunshineService -Force
        }
    
        $sunshinePath = Join-Path $Path "SunshinePortable\sunshine.exe"
        Write-Log "Launching Sunshine from: $sunshinePath"
        Start-Process -FilePath $sunshinePath -WorkingDirectory "$Path\SunshinePortable" -WindowStyle Normal
    }
    
    Execute-ScriptBlockWMI -ScriptBlock $scriptBlock -Arguments $PSScriptRoot
}
function RestartSunshineService {
    param (
        [string]$Path
    )

    $service = Get-Service SunshineService

    # Stop the service
    Stop-Service -InputObject $service -Force

    # Start the SunshinePortable executable
    Set-Location "$Path\SunshinePortable"
    Start-Process "sunshine.exe" -WindowStyle Hidden

    # Start the service again
    Start-Service -InputObject $service

    Write-Host "Forcefully terminating this session with an error to get Moonlight to return back."
    exit -1
}

function HandleSunshineProcess {
    $path = $PSScriptRoot
    Set-Location $path

    $process = Get-Process sunshine -ErrorAction SilentlyContinue

    if ($null -ne $process -and $process.Path -notlike '*SunshinePortable*') {
        $service = Get-Service SunshineService -ErrorAction SilentlyContinue

        if ($null -eq $service) {
            Write-Error "SunshineService not found."
            return
        }

        if ($service.StartType -ne 'Automatic') {
            Write-Warning "The Sunshine service is not configured as automatic. On the next reboot, you will not be able to connect again."
        }

        Launch-PortableSunshine
    }

}

function KillSunshineSession {
    <#
    .SYNOPSIS
        Kills the Sunshine process and ensures the Sunshine service is running.
    #>
    $scriptBlock = {
        param($Path)
        Write-Host "Script Root Path: $Path"
        $service = Get-Service SunshineService -ErrorAction SilentlyContinue

        if ($null -ne $service) {
            $sunshineProcess = Get-Process sunshine -ErrorAction SilentlyContinue

            if ($null -ne $sunshineProcess) {
                Write-Host "Killing the Sunshine process..."
                Stop-Process -Id $sunshineProcess.Id -Force
            }

            if ($service.Status -ne 'Running') {
                Write-Host "Starting the Sunshine service..."
                Start-Service -InputObject $service
            }
        }
    }

    Execute-ScriptBlockWMI -ScriptBlock $scriptBlock -Arguments $PSScriptRoot
    exit -1
}


function Send-PipeMessage {
    param (
        [string]$pipeName,
        [string]$message
    )
    Write-Debug "Attempting to send message to pipe: $pipeName"

    try {
        # Check if the named pipe exists
        $pipeExists = Get-ChildItem -Path "\\.\pipe\" | Where-Object { $_.Name -eq $pipeName }
        Write-Debug "Pipe exists check: $($pipeExists.Length -gt 0)"
        
        if ($pipeExists.Length -gt 0) {
            $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName, [System.IO.Pipes.PipeDirection]::Out)
            Write-Debug "Connecting to pipe: $pipeName"
            
            try {
                $pipe.Connect(3000) # Timeout in milliseconds
                $streamWriter = New-Object System.IO.StreamWriter($pipe)
                Write-Debug "Sending message: $message"
                
                $streamWriter.WriteLine($message)
                $streamWriter.Flush()
            }
            catch {
                Write-Warning "Failed to send message to pipe: $_"
            }
            finally {
                try {
                    $streamWriter.Dispose()
                    $pipe.Dispose()
                    Write-Debug "Resources disposed successfully."
                }
                catch {
                    Write-Debug "Error during disposal: $_"
                }
            }
        }
        else {
            Write-Debug "Pipe not found: $pipeName"
        }
    }
    catch {
        Write-Warning "An error occurred while sending pipe message: $_"
    }
}


# Module Exports
Export-ModuleMember -Function Load-Settings, UpdateSunshineConfig, Ensure-DirectoryExists, Write-ConfigFile, UpdateAppsJson, Copy-Configuration, Execute-EncodedScript, Launch-PortableSunshine, RestartSunshineService, HandleSunshineProcess, KillSunshineSession, Send-PipeMessage
