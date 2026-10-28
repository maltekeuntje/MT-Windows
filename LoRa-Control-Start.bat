@echo off
setlocal
title LoRa-Control Start

rem Startet LoRa-Control: prueft den Meshtastic-Dienst, wartet auf die Node
rem (TCP-Port 4403) und oeffnet danach den Client.

set "CLIENT=%~dp0MeshhessenClient\bin\Debug\net8.0-windows10.0.22621.0\win-x64\MeshhessenClient.exe"

echo.
echo [1/3] Pruefe Meshtastic-Dienst ...
sc query meshtasticd >nul 2>&1
if errorlevel 1 (
    echo     FEHLER: Der Dienst "meshtasticd" ist nicht installiert.
    goto :fail
)
sc query meshtasticd | find "RUNNING" >nul
if errorlevel 1 (
    echo     Dienst laeuft nicht - starte ihn. Bitte die Windows-Abfrage bestaetigen.
    powershell -NoProfile -Command "Start-Process sc.exe -ArgumentList 'start meshtasticd' -Verb RunAs -WindowStyle Hidden -Wait"
) else (
    echo     Dienst laeuft.
)

echo [2/3] Warte auf die Node (Port 4403) ...
powershell -NoProfile -Command "for ($i = 0; $i -lt 30; $i++) { if (Get-NetTCPConnection -LocalPort 4403 -State Listen -ErrorAction SilentlyContinue) { exit 0 }; Start-Sleep 1 }; exit 1"
if errorlevel 1 (
    echo     FEHLER: Die Node meldet sich nicht.
    echo     Steckt der Meshstick mit Antenne? Danach diese Datei erneut starten.
    goto :fail
)
echo     Node bereit.

echo [3/3] Starte LoRa-Control ...
if not exist "%CLIENT%" (
    echo     FEHLER: Client nicht gefunden:
    echo     %CLIENT%
    echo     Bitte zuerst bauen: dotnet build MeshhessenClient\MeshhessenClient.csproj -c Debug
    goto :fail
)
start "" "%CLIENT%"
exit /b 0

:fail
echo.
pause
exit /b 1
