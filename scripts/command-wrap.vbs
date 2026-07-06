Option Explicit

' command-wrap.vbs -- no-console-window equivalent of command-wrap.ps1 / .cmd
'   arg(0) = comma-separated candidate executables, tried in order (first in PATH wins)
'   arg(1+)= forwarded to the resolved command
' Why a .vbs: a .lnk whose TargetPath is a .cmd/.bat flashes a console on launch (cmd.exe
' always allocates one). Launched via wscript.exe, a .vbs has NO console, so the GUI
' shortcut starts silently. WSH splits args on whitespace only -- commas are NOT delimiters,
' so multi-candidate lists need NO quoting here (unlike the .cmd port).

Dim sh, fso, args, candidates, cand, rest, i, resolved
Set sh   = CreateObject("WScript.Shell")
Set fso  = CreateObject("Scripting.FileSystemObject")
Set args = WScript.Arguments

If args.Count = 0 Then Fail "no candidates provided"

candidates = Split(args(0), ",")
rest = ""
For i = 1 To args.Count - 1
    If rest = "" Then rest = args(i) Else rest = rest & " " & args(i)
Next

For Each cand In candidates
    cand = Trim(cand)
    If cand <> "" Then
        resolved = ResolveCommand(cand)
        If resolved <> "" Then
            ' Window style 0 = hidden: the wrapped process starts with no console either.
            ' bWaitOnReturn=True so the .lnk inherits the wrapped command's exit code.
            WScript.Quit sh.Run(Chr(34) & resolved & Chr(34) & " " & rest, 0, True)
        End If
    End If
Next

Fail "none of (" & args(0) & ") found in PATH"

' ---------------- helpers ----------------

Function ResolveCommand(name)
    Dim pathExt, extList, pathEnv, dirs, base, e, full
    ' Explicit path given: use as-is if it exists.
    If InStr(name, "\") > 0 Or InStr(name, "/") > 0 Or InStr(name, ":") > 0 Then
        If fso.FileExists(name) Then ResolveCommand = name : Exit Function
    End If
    pathExt = sh.Environment("Process")("PATHEXT")
    If pathExt = "" Then pathExt = ".COM;.EXE;.BAT;.CMD;.VBS;.JS;.WSF;.MSC"
    extList = Split(pathExt, ";")
    pathEnv = sh.Environment("Process")("PATH")
    dirs = Split(pathEnv, ";")
    For Each base In dirs
        If base <> "" Then
            If Right(base, 1) <> "\" Then base = base & "\"
            ' name already carries an extension -> try exact
            If fso.FileExists(base & name) Then ResolveCommand = base & name : Exit Function
            ' else try each PATHEXT extension
            For Each e In extList
                full = base & name & e
                If fso.FileExists(full) Then ResolveCommand = full : Exit Function
            Next
        End If
    Next
    ResolveCommand = ""
End Function

Sub Fail(msg)
    ' WScript.Echo -> stdout under cscript, message box under wscript (error feedback either way).
    WScript.Echo "command-wrap: " & msg
    WScript.Quit 1
End Sub
