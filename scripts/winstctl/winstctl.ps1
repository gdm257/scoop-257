#!/usr/bin/env powershell
# winstctl - Windows Task Scheduler management wrapper
# Calls task with the bundled Taskfile.yml
$ErrorActionPreference = 'Stop'
$taskfile = Join-Path $PSScriptRoot 'Taskfile.yml'
task -t $taskfile @args
