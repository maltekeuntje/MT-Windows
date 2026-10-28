@echo off
rem Startet LoRa-Control. Die eigentliche Startroutine steht in LoRa-Control-Start.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0LoRa-Control-Start.ps1"
