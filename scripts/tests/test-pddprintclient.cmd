@echo off
rem test-pddprintclient.cmd -- unit test for scripts\shortcut-pddprintclient\pddprintclient.cmd.
rem Sandbox: %ProgramFiles(x86)% is pointed at a temp dir with a paren in its path, like the
rem real one, holding fake PddPrint version dirs; each candidate gets a copy of cmd.exe as
rem PDDPrintClient.exe that dumps its cwd, proving both the version picked and the working
rem dir the launcher sets.
rem Asserts zero-padded ordering across digit rollovers, skipping non-numeric and exe-less
rem dirs, and exit 1 when nothing matches. Zero deps: plain cmd.
rem Run: scripts\tests\test-pddprintclient.cmd
setlocal EnableDelayedExpansion

set "here=%~dp0"
set "box=%TEMP%\pddprintclient-test (x86).%RANDOM%%RANDOM%"
set "pf=%box%\PddPrint"
set "fail=0"

mkdir "%pf%\1.8.9.1080907" "%pf%\1.8.10.2" "%pf%\backup" "%pf%\1.9.0.5" 2>nul
copy /y "%here%..\shortcut-pddprintclient\pddprintclient.cmd" "%box%\pddprintclient.cmd" >nul
for %%V in (1.8.9.1080907 1.8.10.2 backup) do copy /y "%ComSpec%" "%pf%\%%V\PDDPrintClient.exe" >nul
set "ProgramFiles(x86)=%box%"

rem --- 1.8.10.2 beats 1.8.9.1080907 (name order would pick 1.8.9); backup and exe-less 1.9.0.5 skipped
call :launch 1.8.10.2 "zero-padded compare picks 1.8.10 over 1.8.9, skips non-numeric and exe-less dirs"

rem --- 1.10.0.1 beats 1.9.0.5 and 1.8.10.2 once they all hold the exe
mkdir "%pf%\1.10.0.1"
copy /y "%ComSpec%" "%pf%\1.10.0.1\PDDPrintClient.exe" >nul
copy /y "%ComSpec%" "%pf%\1.9.0.5\PDDPrintClient.exe" >nul
call :launch 1.10.0.1 "zero-padded compare picks 1.10 over 1.9 and 1.8"

rem --- only non-numeric or exe-less dirs left -> exit 1, nothing launched
del /q "%pf%\1.9.0.5\PDDPrintClient.exe"
for /d %%D in ("%pf%\*") do if not "%%~nxD"=="backup" if not "%%~nxD"=="1.9.0.5" rmdir /s /q "%%~fD"
call "%box%\pddprintclient.cmd" >nul 2>&1
set "rc=!errorlevel!"
call :is "%rc%" 1 "exit 1 when no numeric dir holds PDDPrintClient.exe"

rmdir /s /q "%box%" 2>nul
if "%fail%"=="0" (echo ALL PASSED) else (echo FAILED)
exit /b %fail%

:launch
rem %1 = expected version dir, %2 = label
for /d %%D in ("%pf%\*") do del /q "%%~fD\ran.txt" 2>nul
call "%box%\pddprintclient.cmd" /c "cd > ran.txt"
set /a n=0
:launch_wait
if exist "%pf%\%~1\ran.txt" goto :launch_got
ping -n 1 127.0.0.1 >nul
set /a n+=1
if %n% LSS 50 goto :launch_wait
call :fail "%~2 (nothing launched into %~1)"
goto :eof
:launch_got
ping -n 2 127.0.0.1 >nul
set "got="
set /p got=<"%pf%\%~1\ran.txt"
call :is "%got%" "%pf%\%~1" "%~2"
for /d %%D in ("%pf%\*") do if not "%%~nxD"=="%~1" if exist "%%~fD\ran.txt" call :fail "%~2 (also launched into %%~nxD)"
goto :eof

:is
if "%~1"=="%~2" (echo ok: %~3) else call :fail "%~3"
goto :eof

:fail
echo FAIL: %~1
set "fail=1"
goto :eof
