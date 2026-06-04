#!/bin/sh
exec "$(scoop prefix openssh)/ssh-keygen.exe" -U "$@"
