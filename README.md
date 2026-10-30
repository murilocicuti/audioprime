# AudioPrime

Mixer de áudio por app na barra de menus do macOS (inspirado no Apoo): volume, mudo e saída de áudio
individuais para cada app, além de volume e saída do sistema.

Requer macOS 26 e a permissão de captura de áudio do sistema (pedida no primeiro ajuste de um app).

## Compilar e rodar

```bash
./scripts/run.sh
```

Não precisa de Xcode: o script usa `swiftc` das Command Line Tools e assina ad-hoc. Cada recompilação muda
a assinatura, então o macOS pode pedir a permissão de áudio novamente.

## Como funciona

- `AudioProcesses` lista os objetos de processo do Core Audio e agrupa helpers (WebContent, renderers)
  no app que os abriu.
- `AppTap` cria, para cada app ajustado, um *process tap* (`CATapDescription`, `mutedWhenTapped`) e um
  dispositivo agregado privado com a saída escolhida; um IOProc copia o áudio aplicando o ganho.
- `MixerStore` guarda os ajustes por bundle ID (UserDefaults) e só mantém taps para apps que fogem do
  padrão (volume < 100%, mudo ou saída diferente da do sistema).
- `MixerView` é o painel SwiftUI do `MenuBarExtra`.

Só áudio estéreo; mídia protegida e apps com acesso exclusivo ao dispositivo podem não ser interceptados.
