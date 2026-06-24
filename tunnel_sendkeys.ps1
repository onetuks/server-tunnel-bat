# PowerShell script to automate SSH tunneling with password inputs
# This script automatically inputs the password after launching SSH.

# Load JSON configuration file
$ConfigFile = Join-Path $PSScriptRoot "tunnel_config.json"
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    Exit
}

# Read file and convert JSON
$RawContent = Get-Content -Raw -Path $ConfigFile
$Configs = $RawContent | ConvertFrom-Json
$EnabledConfigs = $Configs | Where-Object { $_.Enabled -eq $true }

if ($null -eq $EnabledConfigs -or $EnabledConfigs.Count -eq 0) {
    Write-Host "[SSH Tunneling] No enabled (Enabled: true) configurations found. Please check tunnel_config.json." -ForegroundColor Yellow
    Exit
}

# Create a wscript.shell object to simulate keyboard input.
$WScriptShell = New-Object -ComObject wscript.shell

foreach ($Target in $EnabledConfigs) {
    $RemoteHost = $Target.RemoteHost
    $RemotePassword = $Target.RemotePassword
    $JumpHost = $Target.JumpHost
    $JumpPassword = $Target.JumpPassword
    $EnvName = $Target.EnvName

    # 1. Dynamic port arguments generation
    $PortArguments = ""
    if ($Target.Ports) {
        foreach ($Port in $Target.Ports) {
            $PortArguments += " -L ${Port}:localhost:${Port}"
        }
    }

    # 2. Command branch based on Jump Host availability
    $HasJumpHost = -not [string]::IsNullOrEmpty($JumpHost)
    if ($HasJumpHost) {
        $SshCommand = "ssh -J $JumpHost$PortArguments $RemoteHost"
    } else {
        $SshCommand = "ssh$PortArguments $RemoteHost"
    }

    Write-Host "[SSH Tunneling] Starting tunneling process for [$EnvName]..." -ForegroundColor Cyan
    Write-Host "Command: $SshCommand" -ForegroundColor Gray

    # Run the SSH process in a classic console window (conhost)
    $SshProcess = Start-Process conhost.exe -ArgumentList "powershell -NoExit -Command `"[System.Console]::Title = 'SSH Tunnel Window ($EnvName)'; Write-Host '[SSH] Connecting to tunnel ($EnvName). This window will remain open...' -ForegroundColor Green; $SshCommand`"" -PassThru
    $SshPid = $SshProcess.Id

    # Wait for the window to initialize
    Write-Host "  -> Launching SSH window..." -ForegroundColor Cyan
    Start-Sleep -Milliseconds 3000

    if ($HasJumpHost) {
        # [Jump Host exists - 2-step password input]
        Write-Host "  -> Entering 1st password (Jump Host)..." -ForegroundColor Yellow
        $null = $WScriptShell.AppActivate($SshPid)
        $null = $WScriptShell.AppActivate("SSH Tunnel Window ($EnvName)")
        Start-Sleep -Milliseconds 500
        $WScriptShell.SendKeys($JumpPassword)
        $WScriptShell.SendKeys("{ENTER}")

        # Wait for the target server password prompt
        Start-Sleep -Milliseconds 3000

        # Focus and enter the 2nd password (Target Host)
        Write-Host "  -> Entering 2nd password (Target Host)..." -ForegroundColor Yellow
        $null = $WScriptShell.AppActivate($SshPid)
        $null = $WScriptShell.AppActivate("SSH Tunnel Window ($EnvName)")
        Start-Sleep -Milliseconds 500
        $WScriptShell.SendKeys($RemotePassword)
        $WScriptShell.SendKeys("{ENTER}")
    } else {
        # [Direct connection - 1-step password input]
        Write-Host "  -> Entering password (Target Host)..." -ForegroundColor Yellow
        $null = $WScriptShell.AppActivate($SshPid)
        $null = $WScriptShell.AppActivate("SSH Tunnel Window ($EnvName)")
        Start-Sleep -Milliseconds 500
        $WScriptShell.SendKeys($RemotePassword)
        $WScriptShell.SendKeys("{ENTER}")
    }

    Write-Host "[SSH Tunneling] Auto-input complete for [$EnvName]!" -ForegroundColor Green
    Write-Host "--------------------------------------------------" -ForegroundColor Gray

    # Wait before starting the next tunnel to avoid focus conflicts
    Start-Sleep -Seconds 2
}
