#!/usr/bin/env zsh
# Secrets loaded from 1Password CLI (lazy loading)
# Requires: `op` CLI installed and signed in

# Functions to fetch secrets on demand
github_pat() {
    op read 'op://Work/github.com/s2eucbehbmtqyrycdbml3c7wxe'
}

# Load all secrets into environment (call manually when needed)
load_secrets() {
    export GITHUB_PAT="$(github_pat)"
    # Add more as needed:
    # export OPENAI_API_KEY="$(op read 'op://VAULT/ITEM/FIELD')"
}
