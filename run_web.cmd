@echo off
REM CyberPulse - run in Chrome (interactive: r = hot reload, R = hot restart)
cd /d "%~dp0"

REM Keep temp off the (full) C: drive
if not exist ".tmp" mkdir ".tmp"
set "TMP=%CD%\.tmp"
set "TEMP=%CD%\.tmp"

echo [%date% %time%] run_web.cmd started >> run_web.log 2>&1
where flutter >> run_web.log 2>&1
if errorlevel 1 (
    echo [%date% %time%] FLUTTER NOT ON PATH >> run_web.log 2>&1
    echo Flutter not found on PATH
    pause
    exit /b 1
)
echo [%date% %time%] launching flutter run... >> run_web.log 2>&1
flutter run -d chrome --web-port 8080 >> run_web.log 2>&1
echo [%date% %time%] flutter exited with code %errorlevel% >> run_web.log 2>&1
echo All done.
pause