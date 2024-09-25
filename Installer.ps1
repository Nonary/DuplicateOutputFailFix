# Installer.ps1
# This script creates a scheduled task to run HybridGPUMonitor.ps1 in the background as the current user with elevated privileges.

# Define the task name
$taskName = "HybridGPUMonitorTask"

# Get the directory where the installer.ps1 is located
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Define the path to HybridGPUMonitor.ps1
$monitorScript = Join-Path $scriptDirectory "HybridGPUMonitor.ps1"

# Check if HybridGPUMonitor.ps1 exists
if (-Not (Test-Path -Path $monitorScript)) {
    Write-Error "HybridGPUMonitor.ps1 not found in $scriptDirectory"
    exit 1
}

# Get the current user
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Define the action: Run PowerShell with the monitor script, hidden window
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitorScript`""

# Define the trigger: At logon of any user
$trigger = New-ScheduledTaskTrigger -AtLogOn

# Define the principal: Run as the current user with highest privileges
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest

# Define the settings:
# - Allow the task to restart on failure
# - Set restart count and interval
# - Hidden window
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1)`
    -Hidden `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false

# Remove existing task if it exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Register the scheduled task
try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
    Write-Output "Scheduled task '$taskName' has been successfully created."
}
catch {
    Write-Error "Failed to create scheduled task '$taskName'. Error: $_"
    exit 1
}

# Optional: Start the task immediately
try {
    Start-ScheduledTask -TaskName $taskName
    Write-Output "Scheduled task '$taskName' has been started."
}
catch {
    Write-Error "Failed to start scheduled task '$taskName'. Error: $_"
}
