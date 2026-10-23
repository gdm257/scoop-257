@echo off
rem test-uv-env.cmd -- unit test for the per-app uv-env.cmd / uv-env.vbs wrappers.
rem Sandbox: temp dir with the wrappers, a stub candidate (uvstub.cmd) that dumps
rem the received UV_* vars and forwarded args, and the py/uv-cache dir skeleton.
rem Asserts env expansion relative to the script's own dir (incl. after the dir
rem is moved), arg + exit-code forwarding, and the no-candidate error.
rem Zero deps: plain cmd + cscript. Run: scripts\tests\test-uv-env.cmd
setlocal EnableDelayedExpansion

set "here=%~dp0"
set "box=%TEMP%\uv-env-test.%RANDOM%%RANDOM%"
set "fail=0"

mkdir "%box%\py\bin" "%box%\uv-cache" "%box%\stub" 2>nul
copy /y "%here%fixtures\uvstub.cmd" "%box%\stub\uvstub.cmd" >nul
for %%F in ("%here%..\uv-env\uv-env.cmd" "%here%..\uv-env\uv-env.vbs" "%here%..\command-wrapper\command-wrapper.cmd") do copy /y "%%F" "%box%" >nul

set "PATH=%box%\stub;%PATH%"
set "STUB_OUT=%box%\dump.txt"
set "EXPECT=%box%\expect.txt"

rem --- uv-env.cmd: env expanded relative to its own dir, args + exit code forwarded
cd /d "%TEMP%"
call "%box%\uv-env.cmd" uvstub alpha beta
set "rc=!errorlevel!"
call :is "%rc%" 7 "uv-env.cmd forwards exit code"
call :expectdump "%box%" "alpha beta" "uv-env.cmd env/args relative to script dir"

rem --- portability: after the whole dir moves, paths follow the new location
set "box2=%TEMP%\uv-env-test-moved.%RANDOM%"
move "%box%" "%box2%" >nul
set "PATH=%box2%\stub;%PATH%"
set "STUB_OUT=%box2%\dump.txt"
set "EXPECT=%box2%\expect.txt"
call "%box2%\uv-env.cmd" uvstub moved
set "rc=!errorlevel!"
call :is "%rc%" 7 "uv-env.cmd forwards exit code after move"
call :expectdump "%box2%" "moved" "uv-env.cmd env follows moved dir"

rem --- uv-env.cmd: no candidate found -> error
call "%box2%\uv-env.cmd" definitely-missing-cmd-xyz >nul 2>&1
set "rc=!errorlevel!"
call :is "%rc%" 1 "uv-env.cmd errors when no candidate found"

rem --- uv-env.vbs: same env injection, arg + exit code forwarding
cscript //nologo "%box2%\uv-env.vbs" uvstub gamma >nul
set "rc=!errorlevel!"
call :is "%rc%" 7 "uv-env.vbs forwards exit code"
call :expectdump "%box2%" "gamma" "uv-env.vbs env/args relative to script dir"

rem --- uv-env.vbs: no candidate found -> error
cscript //nologo "%box2%\uv-env.vbs" definitely-missing-cmd-xyz >nul 2>&1
set "rc=!errorlevel!"
call :is "%rc%" 1 "uv-env.vbs errors when no candidate found"

rmdir /s /q "%box2" 2>nul
if "%fail%"=="0" (echo ALL PASSED) else (echo FAILED)
exit /b %fail%

:is
if "%~1"=="%~2" (echo ok: %~3) else (echo FAIL: %~3 & set "fail=1")
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
