@echo off
rem Launch the game for manual play-testing. Double-click it, or run:  run.cmd [seed]
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0.tools\appdata"
set "EXE=%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%EXE%" (
  echo Engine not found: %EXE%
  pause
  exit /b 1
)
set "ARGS=--path . --resolution 1280x720 --"
if not "%~1"=="" set "ARGS=%ARGS% seed=%~1"
start "" "%EXE%" %ARGS%
echo started. seed=%~1
endlocal
