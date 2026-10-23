@echo off
rem Stub candidate command for test-uv-env.cmd: dumps received UV_* vars and
rem forwarded args to %STUB_OUT%, exits 7 so the exit-code path is observable.
> "%STUB_OUT%" (
    echo UV_PYTHON_INSTALL_DIR=%UV_PYTHON_INSTALL_DIR%
    echo UV_PYTHON_BIN_DIR=%UV_PYTHON_BIN_DIR%
    echo UV_CACHE_DIR=%UV_CACHE_DIR%
    echo UV_PYTHON_PREFERENCE=%UV_PYTHON_PREFERENCE%
    echo ARGS=%*
)
exit /b 7
