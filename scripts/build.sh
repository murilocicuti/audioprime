#!/bin/zsh
# Compila as fontes com swiftc e monta build/AudioPrime.app (assinatura ad-hoc).
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/AudioPrime.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Algumas instalações das Command Line Tools trazem um usr/include/swift/module.modulemap antigo
# que redefine SwiftBridging e quebra a importação do Foundation. O overlay o substitui por um vazio.
OVERLAY_ARGS=()
if [[ -f /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap ]]; then
    sed "s#@EMPTY@#$PWD/scripts/toolchain-fix/empty.modulemap#" scripts/toolchain-fix/overlay.yaml.in > build/overlay.yaml
    OVERLAY_ARGS=(-vfsoverlay build/overlay.yaml -Xcc -ivfsoverlay -Xcc build/overlay.yaml)
fi

swiftc -O -swift-version 5 \
    -target "$(uname -m)-apple-macosx26.0" \
    -sdk "$(xcrun --show-sdk-path)" \
    "${OVERLAY_ARGS[@]}" \
    -module-name AudioPrime -parse-as-library \
    Sources/AudioPrime/*.swift \
    -o "$APP/Contents/MacOS/AudioPrime"

cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "OK: $APP"
