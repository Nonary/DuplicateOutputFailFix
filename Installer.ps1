[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Specify whether to Install or Uninstall.")]
    [ValidateSet("Install", "Uninstall", IgnoreCase = $true)]
    [string]$Action
)
Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)
$filePath = $($MyInvocation.MyCommand.Path)
$scriptRoot = Split-Path $filePath -Parent


function Get-Settings {
    # Read the file content
    $jsonContent = Get-Content -Path ".\settings.json" -Raw

    # Remove single line comments
    $jsonContent = $jsonContent -replace '//.*', ''

    # Remove multi-line comments
    $jsonContent = $jsonContent -replace '/\*[\s\S]*?\*/', ''

    # Remove trailing commas from arrays and objects
    $jsonContent = $jsonContent -replace ',\s*([\]}])', '$1'

    try {
        # Convert JSON content to PowerShell object
        $jsonObject = $jsonContent | ConvertFrom-Json
        return $jsonObject
    }
    catch {
        Write-Error "Failed to parse JSON: $_"
    }
}

$script:settings = Get-Settings

# This script modifies the global_prep_cmd setting in the Sunshine configuration file

function Test-UACEnabled {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $uacEnabled = Get-ItemProperty -Path $key -Name 'EnableLUA'
    return [bool]$uacEnabled.EnableLUA
}


$isAdmin = [bool]([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')

# If the user is not an administrator and UAC is enabled, re-launch the script with elevated privileges
if (-not $isAdmin -and (Test-UACEnabled)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$filePath`" -Action $Action"
    exit
}



Import-Module .\WGCLauncherModule.psm1


# Function to install the scheduled task
function Install-ScheduledTask {
    # Get the current user
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $monitorScript = Resolve-Path -Path .\HybridGPUMonitor.ps1
    $taskName = "HybridGPUFix"

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
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -Hidden `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false

    # Remove existing task if it exists
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Output "Existing scheduled task '$taskName' has been removed."
        }
        catch {
            Write-Error "Failed to remove existing scheduled task '$taskName'. Error: $_"
            exit 1
        }
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
        Write-Warning "Scheduled task '$taskName' was created but could not be started immediately. You can start it manually."
    }
}

# Function to uninstall the scheduled task
function Uninstall-ScheduledTask {
    $taskName = "HybridGPUFix"
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        try {
            Get-ScheduledTask  -TaskName $taskName | Stop-ScheduledTask -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Output "Scheduled task '$taskName' has been successfully removed."
        }
        catch {
            Write-Error "Failed to remove scheduled task '$taskName'. Error: $_"
        }
    }
    else {
        Write-Output "Scheduled task '$taskName' does not exist. No action taken."
    }
}

function Add-ExecutableFirewallRule {
    param (
        [Parameter(Mandatory)]
        [string]$ProgramPath,
        [Parameter(Mandatory)]
        [string]$RuleName
    )

    try {
        # Verify program exists and get full path
        $fullPath = (Resolve-Path $ProgramPath -ErrorAction Stop).Path
        if (-not (Test-Path $fullPath)) {
            throw "Program not found at path: $fullPath"
        }

        # Clean the rule name to avoid invalid characters
        $cleanRuleName = $RuleName -replace '[^\w\-\s]', '_'

        # Create inbound rule
        New-NetFirewallRule -DisplayName $cleanRuleName `
            -Direction Inbound `
            -Program $fullPath `
            -Action Allow `
            -Protocol Any `
            -Profile Any `
            -Group "Custom Rules" `
            -ErrorAction Stop | Out-Null

        # Create outbound rule
        New-NetFirewallRule -DisplayName $cleanRuleName `
            -Direction Outbound `
            -Program $fullPath `
            -Action Allow `
            -Protocol Any `
            -Profile Any `
            -Group "Custom Rules" `
            -ErrorAction Stop | Out-Null

        Write-Host "Firewall rules created successfully for '$cleanRuleName'"
    }
    catch {
        Write-Error "Failed to create firewall rules: $_"
        Write-Host "Program Path: $fullPath"
        Write-Host "Rule Name: $cleanRuleName"
    }
}

function Remove-ExecutableFirewallRule {
    param (
        [Parameter(Mandatory)]
        [string]$RuleName
    )

    try {
        # Clean the rule name to match creation
        $cleanRuleName = $RuleName -replace '[^\w\-\s]', '_'

        # Get and remove rules
        $rules = Get-NetFirewallRule -DisplayName $cleanRuleName -ErrorAction SilentlyContinue
        if ($rules) {
            $rules | Remove-NetFirewallRule -ErrorAction Stop
            Write-Host "Firewall rules removed successfully for '$cleanRuleName'"
        }
        else {
            Write-Warning "No firewall rules found with name: '$cleanRuleName'"
        }
    }
    catch {
        Write-Error "Failed to remove firewall rules: $_"
    }
}

function Remove-ExecutableFirewallRule {
    param (
        [Parameter(Mandatory)]
        [string]$RuleName
    )

    try {
        # Remove both inbound and outbound rules
        Get-NetFirewallRule -DisplayName $RuleName -ErrorAction Stop | Remove-NetFirewallRule
        Write-Host "Firewall rules removed successfully for $RuleName"
    }
    catch {
        Write-Error "Failed to remove firewall rules: $_"
    }
}

# Function to add WGC Launcher to apps.json
function Add-WGCLauncher {
    $wgcLauncherScript = Resolve-Path .\WGCLauncher.ps1
    $sunshinePath = $settings.sunshineDirectory
    # Paths to configuration files
    $sunshineConfig = Join-Path $sunshinePath "config\sunshine.conf"
    $appsJsonPath = Join-Path $sunshinePath "config\apps.json"

    # Check if sunshine.conf exists
    if (-Not (Test-Path -Path $sunshineConfig)) {
        Write-Error "sunshine.conf not found at $sunshineConfig"
        return
    }

    # Check if apps.json exists
    if (-Not (Test-Path -Path $appsJsonPath)) {
        Write-Error "apps.json not found at $appsJsonPath"
        return
    }

    # Read apps.json
    try {
        $appsContent = Get-Content -Path $appsJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to read apps.json: $_"
        return
    }

    # Remove existing WGC apps to avoid duplicates
    $appsContent.apps = $appsContent.apps | Where-Object { $_.name -notlike "*WGC*" }

    # Check if "WGC Launcher" app already exists
    $wgcAppExists = $appsContent.apps | Where-Object { $_.name -eq "WGC Launcher" }

    if (-not $wgcAppExists) {
        # Define the new app configuration
        $newApp = @{
            "name" = "WGC Launcher"
            "cmd" = "powershell.exe -ExecutionPolicy Bypass -File `"$wgcLauncherScript`""
            "image-path" = ""
            "auto-detach" = "true"
            "wait-all" = "true"
            "elevated" = "true"
            "exclude-global-prep-cmd" = "false"
        }

        # Add the new app to the apps array
        $appsContent.apps += $newApp

        # Convert back to JSON with proper formatting
        $newAppsJson = $appsContent | ConvertTo-Json -Depth 10 -Compress:$false

        # Write the updated JSON content back to apps.json
        try {
            # Define UTF8 encoding without BOM
            $utf8NoBOM = New-Object System.Text.UTF8Encoding($False)
            [System.IO.File]::WriteAllText($appsJsonPath, $newAppsJson, $utf8NoBOM)
            Write-Output "'WGC Launcher' has been added to apps.json."
        }
        catch {
            Write-Error "Failed to write to apps.json: $_"
        }
    }
    else {
        Write-Output "'WGC Launcher' already exists in apps.json. No action taken."
    }
}

# Function to remove WGC Launcher from apps.json
function Remove-WGCLauncher {
    $sunshinePath = $settings.sunshineDirectory
    # Paths to configuration files
    $sunshineConfig = Join-Path $sunshinePath "config\sunshine.conf"
    $appsJsonPath = Join-Path $sunshinePath "config\apps.json"

    # Check if sunshine.conf exists
    if (-Not (Test-Path -Path $sunshineConfig)) {
        Write-Error "sunshine.conf not found at $sunshineConfig"
        return
    }

    # Check if apps.json exists
    if (-Not (Test-Path -Path $appsJsonPath)) {
        Write-Error "apps.json not found at $appsJsonPath"
        return
    }

    # Read apps.json
    try {
        $appsContent = Get-Content -Path $appsJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to read apps.json: $_"
        return
    }

    # Check if "WGC Launcher" app exists
    $wgcApp = $appsContent.apps | Where-Object { $_.name -eq "WGC Launcher" }

    if ($wgcApp) {
        # Remove the WGC Launcher app
        $appsContent.apps = $appsContent.apps | Where-Object { $_.name -ne "WGC Launcher" }

        # Convert back to JSON with proper formatting
        $newAppsJson = $appsContent | ConvertTo-Json -Depth 10 -Compress:$false

        # Write the updated JSON content back to apps.json
        try {
            # Define UTF8 encoding without BOM
            $utf8NoBOM = New-Object System.Text.UTF8Encoding($False)
            [System.IO.File]::WriteAllText($appsJsonPath, $newAppsJson, $utf8NoBOM)
            Write-Output "'WGC Launcher' has been removed from apps.json."
        }
        catch {
            Write-Error "Failed to write to apps.json: $_"
        }
    }
    else {
        Write-Output "'WGC Launcher' does not exist in apps.json. No action taken."
    }
}

# Function to install WGC Launcher
function Install-WGCLauncher {
    $PSScriptRoot
    Write-Output "Starting Installation Process..."
    Add-WGCLauncher
    Copy-Configuration -Settings $script:settings
    Add-ExecutableFirewallRule -ProgramPath "$PSScriptRoot/SunshinePortable/sunshine.exe" -RuleName "WGC Sunshine Portable Exclusion"
}

# Function to uninstall WGC Launcher
function Uninstall-WGCLauncher {
    Remove-WGCLauncher
    Remove-ExecutableFirewallRule -RuleName "WGC Sunshine Portable Exclusion" -ErrorAction SilentlyContinue
}


# Main Execution Block
switch ($Action) {
    "install" {
        Install-WGCLauncher
        Write-Output "Installation completed successfully."
    }
    "uninstall" {
        Uninstall-WGCLauncher
        Write-Output "Uninstallation completed successfully."
    }
    default {
        Write-Error "Invalid action specified. Use -Action Install or -Action Uninstall."
    }
}

$sunshineService = Get-Service -ErrorAction Ignore | Where-Object { $_.Name -eq 'sunshinesvc' -or $_.Name -eq 'SunshineService' }
# In order for the commands to apply we have to restart the service
$sunshineService | Restart-Service  -WarningAction SilentlyContinue
Write-Host "If you didn't see any errors, that means the script installed without issues! You can close this window."

