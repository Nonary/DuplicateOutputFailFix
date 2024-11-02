param($kill)
Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)
Import-Module .\WGCLauncherModule.psm1
try {
    # Load configuration settings
    $settings = Get-Content .\settings.json | ConvertFrom-Json

    if (-not $kill) {
        Copy-Configuration -Settings $settings
        Send-PipeMessage -pipeName "MonitorSwapper" -message "GPUAdapterChange"
        Launch-PortableSunshine
    }
    else {
        KillSunshineSession
        Read-Host "Enter to End"
    }
}
catch {
    # Display error message and the specific line number where the error occurred
    Write-Host "Error Message: $($_.Exception.Message)" | Out-File "error.txt"
    Write-Host "Error Occurred at Line: $($_.InvocationInfo.ScriptLineNumber)" | Out-File "line.txt"
    Write-Host "Error Line Position: $($_.InvocationInfo.OffsetInLine)" | Out-File "invocation.txt"
    Write-Host "Script Name: $($_.InvocationInfo.ScriptName)"
    Write-Host "Full Stack Trace: $($_.Exception.StackTrace)" | Out-File "stack.txt"
    exit 1
}


