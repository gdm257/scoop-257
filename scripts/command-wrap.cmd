@echo off
setlocal EnableDelayedExpansion

rem command-wrap.cmd -- .cmd equivalent of scripts/command-wrap.ps1
rem   %1   = comma-separated candidate executables, tried in order (first in PATH wins)
rem   %2+  = forwarded to the resolved command
rem NOTE: cmd.exe splits a BARE comma into separate args, so a multi-candidate list MUST be
rem passed quoted, e.g.  command-wrap.cmd "ugrep,egrep.exe" ...  (single candidates need no quotes).
rem Why a .cmd: a Windows .lnk whose TargetPath is a .ps1 opens in Notepad on double-click
rem (the default Open verb for .ps1 is edit), so it never executes. A .cmd IS executed.

if "%~1"=="" (
    echo command-wrap: no candidates provided 1>&2
    exit /b 1
)

set "candidates=%~1"
shift

rem Rebuild everything after %1 to forward as one tail (simple space-join).
rem ponytail: args with embedded spaces/special chars are not re-quoted; every caller here passes plain tokens.
set "rest="
:argloop
if "%~1"=="" goto argdone
if defined rest (set "rest=!rest! %~1") else (set "rest=%~1")
shift
goto argloop
:argdone

for %%C in (%candidates%) do (
    where %%C >nul 2>nul
    if not errorlevel 1 (
        %%C !rest!
        exit /b !errorlevel!
    )
)

echo command-wrap: none of (%candidates%) found in PATH 1>&2
exit /b 1
