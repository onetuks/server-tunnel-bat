# PowerShell script to automate SSH tunneling with password inputs
# This script automatically inputs the password after launching SSH.

# JSON 설정 파일 로드
$ConfigFile = Join-Path $PSScriptRoot "tunnel_config.json"
if (-not (Test-Path $ConfigFile)) {
    Write-Error "설정 파일을 찾을 수 없습니다: $ConfigFile"
    Exit
}

# UTF-8 파일 읽기 및 JSON 변환
$Configs = Get-Content -Raw -Path $ConfigFile -Encoding utf8 | ConvertFrom-Json
$EnabledConfigs = $Configs | Where-Object { $_.Enabled -eq $true }

if ($null -eq $EnabledConfigs -or $EnabledConfigs.Count -eq 0) {
    Write-Host "[SSH Tunneling] 활성화(Enabled: true)된 터널링 설정이 없습니다. 설정 파일을 확인하세요." -ForegroundColor Yellow
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

    # 1. 포트 옵션 동적 생성
    $PortArguments = ""
    if ($Target.Ports) {
        foreach ($Port in $Target.Ports) {
            $PortArguments += " -L ${Port}:localhost:${Port}"
        }
    }

    # 2. Jump Host 경유 여부에 따른 SSH 명령어 생성 분기
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
        # [점프 호스트가 존재하는 경우 - 2단계 패스워드 입력]
        # Focus the window and enter the 1st password (Jump Host)
        Write-Host "  -> Entering 1st password (Jump Host)..." -ForegroundColor Yellow
        $null = $WScriptShell.AppActivate($SshPid)
        $null = $WScriptShell.AppActivate("SSH Tunnel Window ($EnvName)")
        Start-Sleep -Milliseconds 500
        $WScriptShell.SendKeys($JumpPassword)
        $WScriptShell.SendKeys("{ENTER}")

        # Wait for the target server password prompt to appear
        Start-Sleep -Milliseconds 3000

        # Focus the window and enter the 2nd password (Target Host)
        Write-Host "  -> Entering 2nd password (Target Host)..." -ForegroundColor Yellow
        $null = $WScriptShell.AppActivate($SshPid)
        $null = $WScriptShell.AppActivate("SSH Tunnel Window ($EnvName)")
        Start-Sleep -Milliseconds 500
        $WScriptShell.SendKeys($RemotePassword)
        $WScriptShell.SendKeys("{ENTER}")
    } else {
        # [점프 호스트가 없는 경우 - 직접 연결, 1단계 패스워드 입력]
        # Focus the window and enter the password (Target Host)
        Write-Host "  -> Entering password (Target Host)..." -ForegroundColor Yellow
        $null = $WScriptShell.AppActivate($SshPid)
        $null = $WScriptShell.AppActivate("SSH Tunnel Window ($EnvName)")
        Start-Sleep -Milliseconds 500
        $WScriptShell.SendKeys($RemotePassword)
        $WScriptShell.SendKeys("{ENTER}")
    }

    Write-Host "[SSH Tunneling] Auto-input complete for [$EnvName]!" -ForegroundColor Green
    Write-Host "--------------------------------------------------" -ForegroundColor Gray

    # 여러 환경을 동시에 띄울 때 키 입력 포커스 충돌을 방지하기 위한 대기시간
    Start-Sleep -Seconds 2
}
