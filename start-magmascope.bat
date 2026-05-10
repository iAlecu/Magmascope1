@echo off
echo Fixing directory and launching Magmascope...

REM Navigate to the correct inner folder where the React app lives
cd /d "%~dp0Magmascope\magmascope"

echo Cleaning up corrupted dependencies...
if exist node_modules rmdir /s /q node_modules
if exist package-lock.json del /q package-lock.json

echo Installing dependencies cleanly...
call npm install

echo Starting the development server (keep this window open!)...
call npm run dev

pause