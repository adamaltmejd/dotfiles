#!/usr/bin/env zsh
# macOS-specific configuration

#
# Network
#
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"

#
# System Maintenance
#
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

#
# Finder
#

# cd to frontmost Finder window
cdf() {
    cd "$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')"
}

#
# Dropbox
#
dropbox_ignore() {
    if [[ -z "$1" ]]; then
        echo "Usage: dropbox_ignore <path>"
        return 1
    fi
    xattr -w 'com.apple.fileprovider.ignore#P' 1 "$1"
    echo "Ignored in Dropbox: $1"
}

dropbox_ignore_all() {
    # Ignore .venv, node_modules, .git in Dropbox
    find "$HOME/Library/CloudStorage/Dropbox" -type d \( -name ".venv" -o -name "node_modules" -o -name ".git" \) \
        -exec xattr -w 'com.apple.fileprovider.ignore#P' 1 {} \; -print -prune
}

#
# Utilities
#
alias urlencode='python3 -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))"'
