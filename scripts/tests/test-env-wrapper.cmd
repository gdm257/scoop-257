@echo off
rem test-env-wrapper.cmd -- unit test for the generic env-wrapper.cmd / .vbs wrappers.
rem Sandbox: temp dir with the wrappers, a generated app-env.cmd (set "KEY=%~dp0..."
rem lines), a stub candidate (uvstub.cmd) that dumps the received UV_* vars and
rem forwarded args, and the py/uv-cache dir skeleton.
rem Asserts %~dp0 expansion relative to the wrapper's own dir (incl. after the dir
rem is moved), arg + exit-code forwarding, the missing-app-env.cmd error, and the
rem no-candidate error. Zero deps: plain cmd + cscript.
rem Run: scripts\tests\test-env-wrapper.cmd
setlocal EnableDelayedExpansion

set "here=%~dp0"
set "box=%TEMP%\env-wrapper-test.%RANDOM%%RANDOM%"
set "fail=0"

mkdir "%box%\py\bin" "%box%\uv-cache" "%box%\stub" 2>nul
copy /y "%here%fixtures\uvstub.cmd" "%box%\stub\uvstub.cmd" >nul
for %%F in ("%here%..\env-wrapper\env-wrapper.cmd" "%here%..\env-wrapper\env-wrapper.vbs" "%here%..\command-wrapper\command-wrapper.cmd") do copy /y "%%F" "%box%" >nul

call :mkappenv "%box%"

set "PATH=%box%\stub;%PATH%"
set "STUB_OUT=%box%\dump.txt"
set "EXPECT=%box%\expect.txt"

rem --- env-wrapper.cmd: env expanded relative to its own dir, args + exit code forwarded
cd /d "%TEMP%"
call "%box%\env-wrapper.cmd" uvstub alpha beta
set "rc=!errorlevel!"
call :is "%rc%" 7 "env-wrapper.cmd forwards exit code"
call :expectdump "%box%" "alpha beta" "env-wrapper.cmd env/args relative to script dir"

rem --- portability: after the whole dir moves, paths follow the new location
set "box2=%TEMP%\env-wrapper-test-moved.%RANDOM%"
move "%box%" "%box2%" >nul
set "PATH=%box2%\stub;%PATH%"
set "STUB_OUT=%box2%\dump.txt"
set "EXPECT=%box2%\expect.txt"
call "%box2%\env-wrapper.cmd" uvstub moved
set "rc=!errorlevel!"
call :is "%rc%" 7 "env-wrapper.cmd forwards exit code after move"
call :expectdump "%box2%" "moved" "env-wrapper.cmd env follows moved dir"

rem --- env-wrapper.cmd: app-env.cmd missing -> error
ren "%box2%\app-env.cmd" app-env.cmd.bak
call "%box2%\env-wrapper.cmd" uvstub >nul 2>&1
set "rc=!errorlevel!"
call :is "%rc%" 1 "env-wrapper.cmd errors when app-env.cmd missing"
ren "%box2%\app-env.cmd.bak" app-env.cmd

rem --- env-wrapper.cmd: no candidate found -> error
call "%box2%\env-wrapper.cmd" definitely-missing-cmd-xyz >nul 2>&1
set "rc=!errorlevel!"
call :is "%rc%" 1 "env-wrapper.cmd errors when no candidate found"

rem --- env-wrapper.vbs: same env injection, arg + exit code forwarding
cscript //nologo "%box2%\env-wrapper.vbs" uvstub gamma >nul
set "rc=!errorlevel!"
call :is "%rc%" 7 "env-wrapper.vbs forwards exit code"
call :expectdump "%box2%" "gamma" "env-wrapper.vbs env/args relative to script dir"

rem --- env-wrapper.vbs: app-env.cmd missing -> error
ren "%box2%\app-env.cmd" app-env.cmd.bak
cscript //nologo "%box2%\env-wrapper.vbs" uvstub >nul 2>&1
set "rc=!errorlevel!"
call :is "%rc%" 1 "env-wrapper.vbs errors when app-env.cmd missing"
ren "%box2%\app-env.cmd.bak" app-env.cmd

rem --- env-wrapper.vbs: no candidate found -> error
cscript //nologo "%box2%\env-wrapper.vbs" definitely-missing-cmd-xyz >nul 2>&1
set "rc=!errorlevel!"
call :is "%rc%" 1 "env-wrapper.vbs errors when no candidate found"

rmdir /s /q "%box2" 2>nul
if "%fail%"=="0" (echo ALL PASSED) else (echo FAILED)
exit /b %fail%

:is
if "%~1"=="%~2" (echo ok: %~3) else (echo FAIL: %~3 & set "fail=1")
goto :eof

:mkappenv
> "%~1\app-env.cmd" (
    echo set "UV_PYTHON_INSTALL_DIR=%%~dp0py"
    echo set "UV_PYTHON_BIN_DIR=%%~dp0py\bin"
    echo set "UV_CACHE_DIR=%%~dp0uv-cache"
    echo set "UV_PYTHON_PREFERENCE=only-managed"
)
goto :eof

:expectdump
> "%EXPECT%" (
    echo UV_PYTHON_INSTALL_DIR=%~1\py
    echo UV_PYTHON_BIN_DIR=%~1\py\bin
    echo UV_CACHE_DIR=%~1\uv-cache
    echo UV_PYTHON_PREFERENCE=only-managed
    echo ARGS=%~2
)
fc "%EXPECT%" "%STUB_OUT%" >nul 2>&1
if errorlevel 1 (echo FAIL: %~3 & set "fail=1") else echo ok: %~3
goto :eof
