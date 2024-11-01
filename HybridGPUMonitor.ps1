<#
.SYNOPSIS
    Monitors the sunshine.log file for Sunshine.exe and ensures GPU priority matches expected values upon specific events.

.DESCRIPTION
    This script continuously monitors the sunshine.log file located in the config folder of the Sunshine directory.
    When a "Set GPU preference" entry is detected in the log, it verifies if the GPU priority matches the expected configuration obtained via ddprobe.
    If the GPU preference has changed from the last known value, it sends a message to a named pipe and restarts the SunshineService.
    After restarting, the script waits for 10 seconds to prevent immediate consecutive restarts.

.PARAMETER scriptName
    The name of the script for logging and configuration purposes.

.EXAMPLE
    .\MonitorSunshine.ps1
#>



# Determine the path of the currently running script and set the working directory to that path
$path = Split-Path $MyInvocation.MyCommand.Path -Parent
Set-Location $path

# Load helper functions or configurations if any (assuming Helpers.ps1 exists)
. .\Helpers.ps1 -n HybridGPUFix

# Load settings from a JSON file located in the same directory as the script
$settings = Get-Settings

# Initialize a variable to track the last known GPU preference to prevent redundant restarts
$global:LastKnownGpuPreference = $null
# Function to send messages to a named pipe
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

# Function to restart the SunshineService
function Restart-SunshineService {
    Write-Host "Restarting SunshineService..."
    try {
        Restart-Service -Name "SunshineService" -Force -ErrorAction Stop
        Write-Host "SunshineService restarted successfully."
    }
    catch {
        Write-Host "Failed to restart SunshineService: $_"
    }

    # Wait for 10 seconds to prevent immediate consecutive restarts
    Start-Sleep -Seconds 10
}

# Function to get the number of physical GPUs (unchanged, kept for potential future use)
function Get-GPUCount {
    $physicalGPUs = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_VideoController |
    Where-Object { $_.VideoProcessor -notlike "*Microsoft*" -and $_.PNPDeviceID -notlike "*VEN_8086*" }

    return $physicalGPUs.Count
}

# Function to retrieve GpuPreference from the registry
function Get-GpuPreference {

    $exePath = Join-Path $settings.sunshineDirectory "Sunshine.exe"
    Write-Host "Searching for GPU preference of: $exePath"

    $registryPath = "Registry::HKEY_USERS\S-1-5-18\Software\Microsoft\DirectX\UserGpuPreferences"

    try {
        $properties = Get-ItemProperty -Path $registryPath -ErrorAction Stop

        # Find the property that matches the exePath (case-insensitive)
        $matchedProperty = $properties.PSObject.Properties | Where-Object {
            $_.Name -ieq $exePath
        }

        if ($matchedProperty) {
            $gpuPreferenceValue = $matchedProperty.Value

            if ($gpuPreferenceValue -match "GpuPreference=(\d+)") {
                $gpuPreferenceInt = [int]$matches[1]
                Write-Host "Configured GpuPreference: $gpuPreferenceInt"
                return $gpuPreferenceInt
            }
            else {
                Write-Warning "GpuPreference format is unexpected: $gpuPreferenceValue"
                return $null
            }
        }
        else {
            Write-Warning "Property '$exePath' does not exist in registry path."
            return $null
        }
    }
    catch {
        Write-Warning "Failed to retrieve GpuPreference from registry: $_"
        return $null
    }
}


# New Function: Retrieves the current GPU preference by running ddprobe.exe
function Get-CurrentGpuPreference {
    # Define necessary paths
    $ddprobePath = Join-Path $settings.sunshineDirectory "tools\ddprobe.exe" 
    $sunshineExePath = Join-Path $settings.sunshineDirectory "Sunshine.exe"
    
    # Validate paths
    if (-Not (Test-Path -Path $ddprobePath)) {
        Write-Error "ddprobe.exe not found at path: $ddprobePath"
        return $null
    }

    if (-Not (Test-Path -Path $sunshineExePath)) {
        Write-Error "Sunshine.exe not found at path: $sunshineExePath"
        return $null
    }
    
    $gpuCount = Get-GPUCount
    for ($i = 1; $i -le $gpuCount; $i++) {
        Write-Host "Running ddprobe.exe with index $i..."
    
        # Capture the output and errors from ddprobe.exe
        $ddprobeOutput = & "$ddprobePath" $i --verify-frame-capture 2>&1
        $exitCode = $LASTEXITCODE
    
        # Log the output for debugging
        Write-Host "ddprobe.exe output for index $i`:`n$ddprobeOutput"
    
        if ($exitCode -eq 0) {
            # No output indicates success
            return $i
        }
        else {
            # Any output indicates failure
            Write-Warning "ddprobe.exe encountered an issue with index $i -- Exit Code: $exitCode. Output: $ddprobeOutput. Trying the next adapter..."
        }
    }

    Write-Warning "Failed to determine GPU preference using ddprobe.exe."
    return $null
}



# Refactored Function: Handles GPU preference changes
function Verify-GPUPreference {
    $sunshineGPUPreference = Get-GpuPreference 
    $currentGpuPreference = Get-CurrentGpuPreference

    if ($null -ne $sunshineGPUPreference -and $null -ne $currentGpuPreference) {
        if ($currentGpuPreference -ne $sunshineGPUPreference) {
            Write-Host "GpuPreference has changed from $sunshineGPUPreference to $currentGpuPreference."

            # Send message to MonitorSwapper
            Send-PipeMessage -pipeName "MonitorSwapper" -message "GPUAdapterChange"

            # Restart SunshineService
            Restart-SunshineService
            return $true
        }
        else {
        
            Write-Host "GpuPreference ($currentGpuPreference) matches the last known value. No action needed."
            return $true
        }

    }
    else {
        Write-Warning "Could not determine the current GPU preference. Skipping action."
    }

    return $false
}

# Function to handle specific error detection and service restart
function Handle-DuplicateOutputError {
    Write-Host "Detected 'Error: DuplicateOutput() test failed' in log, user is probably at the lock screen."
}

function Monitor-LogFile {
    param (
        [string]$logFilePath
    )

    Write-Host "Starting to monitor log file: $logFilePath"

    while ($true) {
        if (Test-Path $logFilePath) {
            try {
                # Open the log file for reading with shared read/write access
                $fileStream = [System.IO.File]::Open($logFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $streamReader = New-Object System.IO.StreamReader($fileStream)

                # Seek to the end of the file to start monitoring new entries
                $streamReader.BaseStream.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null

                while ($true) {
                    if (-not (Test-Path $logFilePath)) {
                        Write-Host "Log file has been deleted. Waiting for recreation..."
                        break
                    }

                    $line = $streamReader.ReadLine()
                    if ($line) {
                        Process-LogLine -line $line
                    }
                    else {
                        Start-Sleep -Milliseconds 500 # Adjust the sleep interval as needed
                        if ($fileStream.Length -lt $streamReader.BaseStream.Position) {
                            # Log file has been truncated or recreated
                            Write-Host "Log file truncated or recreated. Reopening..."
                            break
                        }
                    }
                }
            }
            catch {
                Write-Warning "An error occurred while monitoring the log file: $_"
            }
            finally {
                if ($streamReader) {
                    $streamReader.Close()
                    $streamReader.Dispose()
                }
                if ($fileStream) {
                    $fileStream.Close()
                    $fileStream.Dispose()
                }
            }
        }
        else {
            Write-Warning "Log file not found at path: $logFilePath. Retrying in 5 seconds..."
        }

        Start-Sleep -Seconds 5 # Wait before retrying to open the log file
    }
}

# Function to process each log line
function Process-LogLine {
    param (
        [string]$line
    )

    # Define patterns to detect relevant log entries
    $duplicateOutputErrorPattern = "Error: DuplicateOutput\(\) test failed"
    $clientConnectedPattern = "Client Connected"

    # Check for "Set GPU preference"
    if ($line -match $clientConnectedPattern) {
        for ($i = 0; $i -lt 180; $i++) {
            $applied = Verify-GPUPreference

            if ($applied) {
                break;
            }

            Start-Sleep -Seconds 1
        }
    }
    

    # Check for duplicate output error
    if ($line -match $duplicateOutputErrorPattern) {
        Handle-DuplicateOutputError
    }
}

# Main Execution Flow
function Start-Monitoring {
    # Determine the log file path
    $sunshineDirectory = $settings.sunshineDirectory
    if (-not $sunshineDirectory) {
        Write-Error "sunshineDirectory is not defined in settings.json."
        return
    }

    $logFilePath = Join-Path -Path $sunshineDirectory -ChildPath "config\sunshine.log"


    # Start monitoring the log file in a loop to ensure continuous monitoring
    while ($true) {
        try {
            Monitor-LogFile -logFilePath $logFilePath
        }
        catch {
            Write-Warning "An error occurred while monitoring the log file: $_"
            Start-Sleep -Seconds 5  # Wait before retrying
        }
    }
}
Start-Logging

# Start the monitoring process
Start-Monitoring

Stop-Logging

Remove-OldLogs
