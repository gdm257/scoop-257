@echo off
setlocal EnableDelayedExpansion
rem pddprintclient.cmd -- Start Menu launcher for PDDPrintClient, whose exe sits in a
rem version-named dir under %ProgramFiles(x86)%\PddPrint that every self-update replaces,
rem so the .lnk targets this script and the exe is resolved at launch time.
rem Newest = greatest dotted version among dirs holding PDDPrintClient.exe; each segment
rem is zero-padded so cmd's string GTR orders numbers, not names (1.8.10 beats 1.8.9).
rem Non-numeric dir names are skipped. Exits 1 when nothing matches.

set "root=%ProgramFiles(x86)%\PddPrint"
set "dir="
set "key="
for /d %%D in ("%root%\*") do (
    if exist "%%~fD\PDDPrintClient.exe" (
        set "junk="
        for /f "tokens=1* delims=0123456789." %%x in ("%%~nxD") do set "junk=%%x"
        if not defined junk (
            set "k="
            for /f "tokens=1-4 delims=." %%a in ("%%~nxD") do (
                for %%s in (%%a %%b %%c %%d) do (
                    set "p=0000000000%%s"
                    set "k=!k!.!p:~-10!"
                )
            )
            if not defined key (
                set "key=!k!"
                set "dir=%%~fD"
            ) else if "!k!" GTR "!key!" (
                set "key=!k!"
                set "dir=%%~fD"
            )
        )
    )
)

if not defined dir (
    echo pddprintclient: no PDDPrintClient.exe under "%root%" 1>&2
    exit /b 1
)
start "" /d "%dir%" "%dir%\PDDPrintClient.exe" %*
