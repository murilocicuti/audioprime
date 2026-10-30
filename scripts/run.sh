#!/bin/zsh
# Recompila, fecha a instância em execução (o `open` só reativaria a antiga) e abre a nova.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh
pkill -x AudioPrime && sleep 1 || true
open build/AudioPrime.app
