#!/usr/bin/env bash
# R configuration
feat r || return 0

# R with sensible defaults
alias R="R --silent --no-save --no-restore-data"

# Radian - modern R console
alias r="radian --quiet"
