# AudioPrime

Mixer de áudio por app na barra de menus do macOS. Gratuito e de código aberto.

- Volume e mudo separados para cada app
- Saída de áudio diferente por app (ex.: música no fone, chamada na caixa de som)
- Volume e saída do sistema no mesmo painel
- Abrir ao iniciar sessão (opcional)

O áudio é processado ao vivo no seu Mac. Nada é gravado nem enviado.

**Requisitos:** macOS 26 ou mais recente, Mac com Apple Silicon ou Intel.

## Instalar

Abra o **Terminal** (Aplicativos › Utilitários › Terminal), cole a linha abaixo e tecle Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/murilocicuti/audioprime/main/install.sh | bash
```

O AudioPrime é instalado em Aplicativos e aberto. Procure o ícone de alto-falante na barra de menus.
Ao ajustar o primeiro app, o macOS pede permissão para acessar o áudio do sistema: clique em **Permitir**.

Para **atualizar**, rode o mesmo comando de novo.

### Sem o Terminal

1. Baixe o `AudioPrime.zip` na [página de versões](https://github.com/murilocicuti/audioprime/releases/latest).
2. Abra o zip e arraste o **AudioPrime** para a pasta **Aplicativos**.
3. Abra o app. O macOS vai avisar que não pode verificar o desenvolvedor, porque o app não é assinado
   pela Apple (isso custa US$ 99 por ano). Clique em **OK**.
4. Vá em **Ajustes do Sistema › Privacidade e Segurança**, role até o aviso sobre o AudioPrime e clique em
   **Abrir mesmo assim**. Isso só é necessário na primeira vez.

### Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/murilocicuti/audioprime/main/install.sh | bash -s -- --uninstall
```

## Limitações

- Só áudio estéreo.
- Mídia protegida e apps com acesso exclusivo ao dispositivo de áudio podem não ser interceptados.
- Se um app ficar mudo, desligue o AudioPrime no botão do painel, confira a permissão de áudio em
  Ajustes do Sistema › Privacidade e Segurança e abra o app de novo.
- Como o app não é assinado pela Apple, cada atualização pode pedir a permissão de áudio novamente.

## Desenvolvimento

```bash
./scripts/run.sh
```

Compila um app universal com `swiftc` (não precisa de Xcode), fecha a instância em execução e abre a nova.
Para publicar uma versão, envie uma tag: `git tag v0.2.0 && git push origin v0.2.0`. O GitHub Actions
compila e cria a release com o `AudioPrime.zip`, que é o que o instalador baixa.

### Como funciona

- `AudioProcesses` lista os objetos de processo do Core Audio e agrupa helpers (WebContent, renderers)
  no app que os abriu.
- `AppTap` cria, para cada app ajustado, um *process tap* (`CATapDescription`, `mutedWhenTapped`) e um
  dispositivo agregado privado com a saída escolhida; um IOProc copia o áudio aplicando o ganho.
- `MixerStore` guarda os ajustes por bundle ID (UserDefaults) e só mantém taps para apps que fogem do
  padrão (volume < 100%, mudo ou saída diferente da do sistema).
- `MixerView` é o painel SwiftUI do `MenuBarExtra`.

## Licença

[MIT](LICENSE)
