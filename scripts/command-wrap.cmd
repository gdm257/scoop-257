@echo off
setlocal EnableDelayedExpansion
rem Snapshot %~dp0 before any SHIFT: inside a called script's parenthesized block,
rem %~dp0 resolves against the shifted arg list and returns a wrong directory.
set "scriptdir=%~dp0"

rem command-wrap.cmd -- .cmd equivalent of scripts/command-wrap.ps1
rem   %1   = comma-separated candidate executables, tried in order (first in PATH wins)
rem   %2+  = forwarded to the resolved command
rem   A "--workdir <path>" pair anywhere in %2+ is intercepted (not forwarded) and
rem   sets the wrapped command's working dir; relative paths resolve against THIS
rem   script's dir, not the caller's cwd.
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
set "workdir="
:argloop
if "%~1"=="" goto argdone
if /i "%~1"=="--workdir" (
    if "%~2"=="" (
        echo command-wrap: --workdir requires a value 1>&2
        exit /b 1
    )
    set "workdir=%~2"
    shift
    shift
    goto argloop
)
if defined rest (set "rest=!rest! %~1") else (set "rest=%~1")
shift
goto argloop
:argdone

if defined workdir (
    rem Absolute = "X:\..." or leading "\"/UNC; else resolve against this script's dir.
    set "wd=!scriptdir!!workdir!"
    if "!workdir:~1,1!"==":" set "wd=%workdir%"
    if "!workdir:~0,1!"=="\" set "wd=%workdir%"
    if not exist "!wd!\" (
        echo command-wrap: workdir not found: !wd! 1>&2
        exit /b 1
    )
    cd /d "!wd!"
)

for %%C in (%candidates%) do (
    where %%C >nul 2>nul
    if not errorlevel 1 (
        %%C !rest!
        exit /b !errorlevel!
    )
)

echo command-wrap: none of (%candidates%) found in PATH 1>&2
exit /b 1
