@echo off
setlocal EnableDelayedExpansion
rem Snapshot %~dp0 before any SHIFT: inside a called script's parenthesized block,
rem %~dp0 resolves against the shifted arg list and returns a wrong directory.
set "scriptdir=%~dp0"
rem Cleared up front: the leading --workdir block below sets it before the arg loop.
set "workdir="

rem command-wrapper.cmd -- .cmd equivalent of scripts/command-wrapper.ps1
rem   %1   = '+'-separated candidate executables, tried in order (first in PATH wins)
rem   %2+  = forwarded to the resolved command
rem   An optional "--workdir <path>" may lead %1 or appear anywhere in %2+; the pair
rem   is intercepted (not forwarded) and sets the wrapped command's working dir;
rem   relative paths resolve against THIS script's dir, not the caller's cwd.
rem NOTE: '+' is the separator precisely because cmd.exe splits a BARE comma into
rem   separate args, so  command-wrapper.cmd ugrep+egrep.exe ...  needs no quoting
rem   (a quoted "ugrep,egrep.exe" also works -- comma stays accepted).
rem Why a .cmd: a Windows .lnk whose TargetPath is a .ps1 opens in Notepad on double-click
rem   (the default Open verb for .ps1 is edit), so it never executes. A .cmd IS executed.
rem Error exits goto labels below instead of exiting inline: an "exit /b 1" with sibling
rem   commands after its block inside the parens silently loses its code (cmd quirk).

rem Leading "--workdir <path>" before the candidate list. %~1/%~2 inside the parens
rem expand before the shifts execute, so they see the original arg positions.
if /i "%~1"=="--workdir" (
    if "%~2"=="" goto workdir_no_value
    set "workdir=%~2"
    shift
    shift
)

if "%~1"=="" goto no_candidates

set "candidates=%~1"
shift

rem Rebuild everything after %1 to forward as one tail (simple space-join).
rem ponytail: args with embedded spaces/special chars are not re-quoted; every caller here passes plain tokens.
set "rest="
:argloop
if "%~1"=="" goto argdone
if /i "%~1"=="--workdir" (
    if "%~2"=="" goto workdir_no_value
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
    if not exist "!wd!\" goto workdir_not_found
    cd /d "!wd!"
)

rem '+' -> ',': the for-set splits on commas natively, so quoted comma lists keep working.
rem MUST be percent (not delayed) expansion: delayed results are not re-parsed as syntax,
rem so the commas would never split the set.
for %%C in (%candidates:+=,%) do (
    where %%C >nul 2>nul
    if not errorlevel 1 (
        %%C !rest!
        exit /b !errorlevel!
    )
)

echo command-wrapper: none of (%candidates%) found in PATH 1>&2
exit /b 1

:no_candidates
echo command-wrapper: no candidates provided 1>&2
exit /b 1

:workdir_no_value
echo command-wrapper: --workdir requires a value 1>&2
exit /b 1

:workdir_not_found
echo command-wrapper: workdir not found: !wd! 1>&2
exit /b 1
