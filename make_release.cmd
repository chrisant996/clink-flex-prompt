@echo off
if "%1" == "" goto :usage

set SEVENZ="c:\Program Files\7-Zip\7z.exe"

%SEVENZ% a clink-flex-prompt-%1.zip flexprompt.lua flexprompt_bubbles.lua flexprompt_modules.lua flexprompt_wizard.lua
goto :eof

:usage
echo Usage:  make_release ^<version_number^>
echo.
echo   Creates a clink-flex-prompt-^<version_number^>.zip release file.
goto :eof
