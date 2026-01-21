#!/bin/bash

# Copied from https://gist.github.com/BertanT/9d222da115ca2d1274ef34735c4260cf
# Compiles and installs Security Key Provider library (SSH_SK_PROVIDER) from libfido for use with MacOS builtin openssh

################################################################################################
# macskeyinstaller.sh
# Last Updated: January 13, 2025
#
# macOS OpenSSH Client Patcher for Hardware Security Key Support (ED25519-SK With YubiKey Etc.)
# Check out https://gist.github.com/BertanT/9d222da115ca2d1274ef34735c4260cf for details!
#
# Copyright 2025 Mehmet Bertan Tarakcioglu (github.com/BertanT), under the MIT License.
################################################################################################

# Exit early if there is an error
set -e

printf "\n* Hello! This script compiles and installs the security key provider for the built-in macOS Open SSH client to enable support for hardware security keys (such as a YubiKey)."

# Check if the script is running as root
if [ "$(id -u)" -eq 0 ]; then
  printf "\n!!! Error: For safety reasons, this script cannot be run as root. If using sudo, please try again without it.\n" >&2
  exit 1
fi

# Function to compare macOS version strings
version_ge() {
  [[ "$(echo -e "$1\n$2" | sort -V | head -n1)" == "$2" ]]
}

# function to get the current macOS Version
macos_version=$(sw_vers -productVersion | cut -d '.' -f1,2)

# Check if running at least macOS Sonoma
if ! version_ge "$macos_version" "14.0"; then
  printf "\n!!! Error: macOS version is $macos_version. This script requires at least macOS Sonoma (14.0).\n" >&2
  exit 1
fi
printf "\n* macOS version is supported!"

# Check if Homebrew is installed
if ! which brew &>/dev/null; then
  printf "\n!!! Error: This script requires Homebrew to install dependencies! Please install Homebrew and try again\n" >&2
  exit 1
fi
printf "\n* Homebrew is installed!"

printf "\n* Cloning the latest main branch of openssh-portable from GitHub. This may take a while..."
git clone --quiet https://github.com/openssh/openssh-portable.git
cd openssh-portable

printf "\n* Installing dependencies from Homebrew: libfido2, openssl, autoconf, automake, libtool\n"
brew install libfido2 openssl autoconf automake libtool pkgconf

printf "\n* Generating configuration script."
autoreconf -i

printf "\n* Exporting flags."

# Determine the CPU architecture and set the appropriate Homebrew base path
if [[ "$(uname -m)" == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
elif [[ "$(uname -m)" == "x86_64" ]]; then
  BREW_PREFIX="/usr/local"
else
  echo "!!! Error: Unknown CPU architecture $(uname -m).\n" >&2
  exit 1
fi

# Get the appropriate paths for the Homebrew dependecies as they differ through version
BREW_OPENSSL_PATH=$(ls -d $BREW_PREFIX/Cellar/openssl@3/*)
BREW_LIBFIDO2_PATH=$(ls -d $BREW_PREFIX/Cellar/libfido2/*)
export CFLAGS="-L$BREW_OPENSSL_PATH/lib -I$BREW_OPENSSL_PATH/include -L$BREW_LIBFIDO2_PATH/lib -I$BREW_LIBFIDO2_PATH/include -Wno-error=implicit-function-declaration"
export LDFLAGS="-L$BREW_OPENSSL_PATH/lib -L$BREW_LIBFIDO2_PATH/lib"

printf "\n* Configuring build. This may take a while..."
./configure --quiet --with-security-key-standalone

printf "\n* Cleaning previous build for good measure."
make --quiet clean

printf "\n* Building OpenSSH Portable."
make --quiet

printf "\n* Copying the Security Key Provider library to /usr/local/lib."
printf "\n  We need root privileges to modify system files.\n"
sudo mkdir -p /usr/local/lib
sudo mv sk-libfido2.dylib /usr/local/lib/

# Check if the script is running in ZSH. If not, give the user instructions.
# Otherwise, modify .zshenv to set the environment variable if not already present.
if [[ "$SHELL" == *zsh* ]]; then
	printf "\n* Configuring the ~/.zshenv for the System SSH use the Security Key Provider we just built"
    if ! grep -q "export SSH_SK_PROVIDER=/usr/local/lib/sk-libfido2.dylib" "$HOME/.zshenv" &>/dev/null; then
        echo "export SSH_SK_PROVIDER=/usr/local/lib/sk-libfido2.dylib" >> "$HOME/.zshenv"
        printf "\n* Added SSH_SK_PROVIDER to ~/.zshenv."
    else
        printf "\n* SSH_SK_PROVIDER is already configured in ~/.zshenv."
    fi
else
	printf "*\n Since you are not on ZSH, you will need to manually configure your shell profile to tell the System SSH client to use the Security Key Provider we just built."
	printf "\n  The shell profile should export the environment variable as follows:"
	printf "\n  export SSH_SK_PROVIDER=/usr/local/lib/sk-libfido2.dylib"
fi

printf "\n* Exiting the directory and deleting the repository we cloned. We don't need it anymore"
cd ..
rm -rf openssh-portable

printf "\n\n* That's it! After restarting your terminal session, you can plug in your hardware security key and test the installation using:"
printf "\n  ssh-keygen -t ed25519-sk -O resident -O verify-required -C \"Your Comment\""
printf "\n\nHave a nice day! :)\n\n"