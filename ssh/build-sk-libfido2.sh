#!/usr/bin/env zsh
# Build sk-libfido2.dylib for macOS built-in SSH FIDO2 support
# Required because Apple's OpenSSH doesn't include security key support
set -e

if [[ -f /usr/local/lib/sk-libfido2.dylib ]]; then
    echo "sk-libfido2.dylib already installed, skipping..."
    exit 0
fi

echo "Building sk-libfido2.dylib for SSH security key support..."

# Track which build tools need to be installed (and later removed)
BUILD_DEPS=(autoconf automake libtool)
INSTALLED_DEPS=()
for dep in $BUILD_DEPS; do
    if ! brew list "$dep" &>/dev/null; then
        INSTALLED_DEPS+=("$dep")
    fi
done

if [[ ${#INSTALLED_DEPS[@]} -gt 0 ]]; then
    echo "Installing temporary build dependencies: ${INSTALLED_DEPS[*]}"
    brew install --quiet "${INSTALLED_DEPS[@]}"
fi

cleanup() {
    [[ -n "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    if [[ ${#INSTALLED_DEPS[@]} -gt 0 ]]; then
        echo "Removing temporary build dependencies..."
        brew uninstall --quiet "${INSTALLED_DEPS[@]}"
    fi
}
trap cleanup EXIT

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git clone --quiet --depth 1 https://github.com/openssh/openssh-portable.git
cd openssh-portable

autoreconf -i &>/dev/null

OPENSSL_PREFIX=$(brew --prefix openssl@3)
LIBFIDO2_PREFIX=$(brew --prefix libfido2)
export CFLAGS="-L$OPENSSL_PREFIX/lib -I$OPENSSL_PREFIX/include -L$LIBFIDO2_PREFIX/lib -I$LIBFIDO2_PREFIX/include -Wno-error=implicit-function-declaration"
export LDFLAGS="-L$OPENSSL_PREFIX/lib -L$LIBFIDO2_PREFIX/lib"

./configure --quiet --with-security-key-standalone
make --quiet

sudo mkdir -p /usr/local/lib
sudo cp sk-libfido2.dylib /usr/local/lib/

echo "sk-libfido2.dylib installed to /usr/local/lib"
