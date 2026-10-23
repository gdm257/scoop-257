@echo off
setlocal
rem uv-env.cmd -- per-app uv environment for CLI use, then delegate to the
rem sibling command-wrapper.cmd. All paths derive from this script's dir, so
rem the app dir stays fully portable (no absolute paths, nothing global).
set "UV_PYTHON_INSTALL_DIR=%~dp0py"
set "UV_PYTHON_BIN_DIR=%~dp0py\bin"
set "UV_CACHE_DIR=%~dp0uv-cache"
set "UV_PYTHON_PREFERENCE=only-managed"
call "%~dp0command-wrapper.cmd" %*
exit /b %errorlevel%
