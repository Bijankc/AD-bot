@echo off
rem Packs the log, settings and screenshots into AD-Bot-report-<version>.zip next to the bot. Send that file to the author.
cd /d "%~dp0"
set VER=unknown
for /f tokens^=2^ delims^=^" %%v in ('findstr /b "APP_VERSION" ui.ahk') do set VER=%%v
set ZIP=AD-Bot-report-v%VER%.zip
if exist "%ZIP%" del "%ZIP%"
if exist _report rmdir /s /q _report
mkdir _report
if exist raid.log copy /y raid.log _report >nul
if exist raid.ini copy /y raid.ini _report >nul
if exist shots xcopy /e /i /q shots _report\shots >nul
echo version %VER%> _report\version.txt
powershell -NoProfile -Command "Compress-Archive -Path '_report\*' -DestinationPath '%ZIP%'"
rmdir /s /q _report
echo.
echo Done: %ZIP% - send this file to the author.
pause