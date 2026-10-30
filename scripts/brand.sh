#!/bin/zsh
# Regenera brand/ e Resources/AppIcon.icns a partir de Sources/AudioPrime/WaveMark.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

OVERLAY_ARGS=()
if [[ -f /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap ]]; then
    sed "s#@EMPTY@#$PWD/scripts/toolchain-fix/empty.modulemap#" scripts/toolchain-fix/overlay.yaml.in > build/overlay.yaml
    OVERLAY_ARGS=(-vfsoverlay build/overlay.yaml -Xcc -ivfsoverlay -Xcc build/overlay.yaml)
fi

swiftc -O -swift-version 5 -sdk "$(xcrun --show-sdk-path)" "${OVERLAY_ARGS[@]}" \
    Sources/AudioPrime/WaveMark.swift scripts/brand/main.swift -o build/brand-tool

rm -rf build/AppIcon.iconset
build/brand-tool brand build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
echo "OK: Resources/AppIcon.icns"
