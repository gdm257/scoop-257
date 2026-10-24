@echo off
setlocal
rem env-wrapper.cmd -- generic per-app environment for CLI use: apply the sibling
rem generated app-env.cmd (set "KEY=%~dp0..." lines), then delegate to the sibling
rem command-wrapper.cmd. The app's env lives in a data file, so new app templates
rem need no new wrapper.
if not exist "%~dp0app-env.cmd" (
    echo env-wrapper: app-env.cmd not found next to "%~dp0" 1>&2
    exit /b 1
)
call "%~dp0app-env.cmd"
call "%~dp0command-wrapper.cmd" %*
exit /b %errorlevel%
