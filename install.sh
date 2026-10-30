#!/bin/bash
# Instala ou atualiza o AudioPrime a partir da última release no GitHub.
#   curl -fsSL https://raw.githubusercontent.com/murilocicuti/audioprime/main/install.sh | bash
# Para desinstalar:
#   curl -fsSL https://raw.githubusercontent.com/murilocicuti/audioprime/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="murilocicuti/audioprime"
APP_NAME="AudioPrime.app"
ZIP_URL="${AUDIOPRIME_ZIP_URL:-https://github.com/$REPO/releases/latest/download/AudioPrime.zip}"

say() { printf '\033[1m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[31mErro:\033[0m %s\n' "$1" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "o AudioPrime só funciona no macOS."
# Captura de áudio por app (process taps) com pedido de permissão confiável: macOS 14.4+.
OS_VERSION="$(sw_vers -productVersion)"
IFS=. read -r MAJOR MINOR _ <<< "$OS_VERSION"
if (( MAJOR < 14 || (MAJOR == 14 && ${MINOR:-0} < 4) )); then
    fail "o AudioPrime precisa do macOS 14.4 (Sonoma) ou mais recente. Seu Mac está no $OS_VERSION.
       Atualize em Ajustes do Sistema › Geral › Atualização de Software e tente de novo."
fi

# /Applications quando o usuário pode escrever lá (administradores); senão ~/Applications.
if [[ -w /Applications ]]; then DEST_DIR="/Applications"; else DEST_DIR="$HOME/Applications"; fi
DEST="$DEST_DIR/$APP_NAME"

quit_running() {
    if pgrep -x AudioPrime >/dev/null; then
        say "Fechando o AudioPrime em execução..."
        osascript -e 'tell application id "com.murilo.audioprime" to quit' >/dev/null 2>&1 || pkill -x AudioPrime || true
        sleep 1
    fi
}

if [[ "${1:-}" == "--uninstall" ]]; then
    quit_running
    rm -rf "/Applications/$APP_NAME" "$HOME/Applications/$APP_NAME"
    defaults delete com.murilo.audioprime >/dev/null 2>&1 || true
    say "AudioPrime removido."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Baixando o AudioPrime..."
curl -fL --progress-bar "$ZIP_URL" -o "$TMP/AudioPrime.zip" || fail "não foi possível baixar $ZIP_URL"
ditto -x -k "$TMP/AudioPrime.zip" "$TMP" || fail "o arquivo baixado está corrompido."
[[ -d "$TMP/$APP_NAME" ]] || fail "o pacote baixado não contém $APP_NAME."

quit_running
say "Instalando em $DEST_DIR..."
mkdir -p "$DEST_DIR"
# Remove cópias antigas em outro local para não ficar com dois AudioPrime no Mac.
for OLD in "/Applications/$APP_NAME" "$HOME/Applications/$APP_NAME" "$HOME/Downloads/$APP_NAME"; do
    if [[ "$OLD" != "$DEST" && -d "$OLD" && -w "$(dirname "$OLD")" ]]; then rm -rf "$OLD"; fi
done
rm -rf "$DEST"
ditto "$TMP/$APP_NAME" "$DEST"
# O app não é assinado pela Apple; sem a marca de quarentena o macOS o abre sem bloquear.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo '?')"
say "AudioPrime $VERSION instalado. Abrindo..."
open "$DEST"
echo
echo "Procure o ícone de alto-falante na barra de menus. Ao ajustar o primeiro app,"
echo "o macOS vai pedir permissão para acessar o áudio do sistema: clique em Permitir."
