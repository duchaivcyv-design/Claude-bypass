#!/bin/bash
# language: bash, file: build-deb.sh
# Build 3 deb ClaudeGuard bằng Theos local
set -e

cd "$(dirname "$0")/../ClaudeGuard"

if [ -z "$THEOS" ]; then
    export THEOS="$HOME/theos"
fi

echo "[*] THEOS = $THEOS"
echo "[*] Build 3 scheme..."

build() {
    local scheme="$1"
    echo ""
    echo "===== $scheme ====="
    make clean >/dev/null 2>&1 || true
    if [ "$scheme" = "rootful" ]; then
        make package FINALPACKAGE=1
    else
        make package THEOS_PACKAGE_SCHEME="$scheme" FINALPACKAGE=1
    fi
    local deb
    deb=$(ls -t packages/*.deb | head -1)
    mv "$deb" "packages/ClaudeGuard-$scheme.deb"
}

build rootful
build rootless
build roothide

echo ""
echo "[+] Done:"
ls -lh packages/*.deb
