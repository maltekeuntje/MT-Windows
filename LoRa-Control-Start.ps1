# LoRa-Control start routine
# 1. checks that a Meshstick is plugged in
# 2. (re)starts the meshtasticd service if the node is not reachable
#    (stop service, end leftover meshtasticd processes, start service)
# 3. waits until the node listens on TCP port 4403
# 4. starts the LoRa-Control client (without administrator rights)
param([switch]$Repair)

$svc    = 'meshtasticd'
$client = Join-Path $PSScriptRoot 'MeshhessenClient\bin\Debug\net8.0-windows10.0.22621.0\win-x64\MeshhessenClient.exe'

function Test-NodePort {
    [bool](Get-NetTCPConnection -LocalPort 4403 -State Listen -ErrorAction SilentlyContinue)
}

function Test-Stick {
    [bool](Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -like '*VID_1A86&PID_5512*' -and $_.Status -eq 'OK' })
}

function Stop-WithError([string]$text) {
    Write-Host ''
    Write-Host "FEHLER: $text" -ForegroundColor Red
    Write-Host ''
    Read-Host 'Enter druecken zum Schliessen' | Out-Null
    exit 1
}

# ---- elevated part: only the service handling needs administrator rights ----
if ($Repair) {
    try {
        # start 2 minutes after boot, when the USB stick is ready
        sc.exe config $svc start= delayed-auto | Out-Null
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        # a manual meshtasticd run would keep the stick busy
        Get-Process meshtasticd -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
        Start-Service $svc -ErrorAction Stop
        exit 0
    } catch {
        exit 1
    }
}

$Host.UI.RawUI.WindowTitle = 'LoRa-Control Start'

Write-Host '[1/4] Pruefe Meshstick ...'
if (-not (Get-Service $svc -ErrorAction SilentlyContinue)) {
    Stop-WithError 'Der Dienst "meshtasticd" ist nicht installiert.'
}
if (-not (Test-Stick)) {
    Stop-WithError 'Kein Meshstick gefunden. Stick mit Antenne einstecken und diese Datei erneut starten.'
}
Write-Host '      Meshstick erkannt.'

Write-Host '[2/4] Pruefe Node ...'
if ((Get-Service $svc).Status -eq 'Running' -and (Test-NodePort)) {
    Write-Host '      Node laeuft bereits.'
} else {
    Write-Host '      Node laeuft nicht - starte den Dienst neu.'
    Write-Host '      Bitte die Windows-Abfrage mit "Ja" bestaetigen.'
    try {
        $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Repair')
        $p = Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList $psArgs
    } catch {
        Stop-WithError 'Die Windows-Abfrage wurde abgelehnt. Der Dienst wurde nicht gestartet.'
    }
    if ($p.ExitCode -ne 0) {
        Stop-WithError 'Der Dienst konnte nicht gestartet werden.'
    }
}

Write-Host '[3/4] Warte auf die Node (Port 4403) ...'
$ready = $false
for ($i = 0; $i -lt 45; $i++) {
    if (Test-NodePort) { $ready = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $ready) {
    $state = (Get-Service $svc).Status
    Stop-WithError "Die Node meldet sich nicht (Dienst: $state). Stick kurz abziehen, wieder einstecken und diese Datei erneut starten."
}
Write-Host '      Node bereit.'

Write-Host '[4/4] Starte LoRa-Control ...'
if (-not (Test-Path $client)) {
    Stop-WithError "Client nicht gefunden: $client - bitte zuerst bauen: dotnet build MeshhessenClient\MeshhessenClient.csproj -c Debug"
}
Start-Process -FilePath $client -WorkingDirectory (Split-Path $client)
