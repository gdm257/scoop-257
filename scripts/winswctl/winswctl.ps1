#!/usr/bin/env powershell
# winswctl - Windows Services management wrapper
# Calls task with the bundled Taskfile.yml
$ErrorActionPreference = 'Stop'
$taskfile = Join-Path $PSScriptRoot 'Taskfile.yml'
task -t $taskfile @args
