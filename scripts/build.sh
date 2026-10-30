#!/bin/zsh
# Compila um app universal (arm64 + x86_64) em build/AudioPrime.app e gera build/AudioPrime.zip.
# VERSION=1.2.3 ./scripts/build.sh define a versão exibida no app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/AudioPrime.app
rm -rf "$APP" build/AudioPrime.zip build/arch
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/arch

# Algumas instalações das Command Line Tools trazem um usr/include/swift/module.modulemap antigo
# que redefine SwiftBridging e quebra a importação do Foundation. O overlay o substitui por um vazio.
OVERLAY_ARGS=()
if [[ -f /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap ]]; then
    sed "s#@EMPTY@#$PWD/scripts/toolchain-fix/empty.modulemap#" scripts/toolchain-fix/overlay.yaml.in > build/overlay.yaml
    OVERLAY_ARGS=(-vfsoverlay build/overlay.yaml -Xcc -ivfsoverlay -Xcc build/overlay.yaml)
fi

for ARCH in arm64 x86_64; do
    swiftc -O -swift-version 5 \
        -target "$ARCH-apple-macosx14.4" \
        -sdk "$(xcrun --show-sdk-path)" \
        "${OVERLAY_ARGS[@]}" \
        -module-name AudioPrime -parse-as-library \
        Sources/AudioPrime/*.swift \
        -o "build/arch/AudioPrime-$ARCH"
done
lipo -create build/arch/AudioPrime-* -output "$APP/Contents/MacOS/AudioPrime"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP"

ditto -c -k --keepParent "$APP" build/AudioPrime.zip
echo "OK: $APP ($(lipo -archs "$APP/Contents/MacOS/AudioPrime"))"
