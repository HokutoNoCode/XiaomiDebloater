@echo off
title XiaomiDebloater - non chiudere questa finestra
cd /d "%~dp0"
if not exist "%~dp0platform-tools\adb.exe" (
  echo Scarico gli strumenti ADB ufficiali di Google...
  curl.exe -L -o "%TEMP%\platform-tools.zip" https://dl.google.com/android/repository/platform-tools-latest-windows.zip
  powershell -NoProfile -Command "Expand-Archive -Force '%TEMP%\platform-tools.zip' '%~dp0'"
)
echo Apro XiaomiDebloater...
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0gestione_app.ps1"
if errorlevel 1 pause
