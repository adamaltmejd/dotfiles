#!/usr/bin/env zsh
# Git configuration

# Diff files not in git repo using git's colored diff
gdiff() {
    git diff --no-index --color-words "$@"
}
