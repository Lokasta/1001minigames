# TokTok Games

Projeto de jogo com [Heaps.io](https://heaps.io) (engine 2D/3D em Haxe).

## Pré-requisitos

- **Haxe 4+** (instalado via Homebrew: `brew install haxe`)
- **Heaps** (instalado via haxelib, ver abaixo)

## Configuração do ambiente

No macOS, adicione ao seu `~/.zshrc` (ou `~/.bashrc`):

```bash
export HAXE_STD_PATH="/opt/homebrew/lib/haxe/std"
```

Se for a primeira vez usando haxelib, configure o repositório de libs (já feito com `~/haxelib`):

```bash
haxelib setup
# e informe: /Users/leonidasmaciel/haxelib
```

## Instalação do Heaps (já feita)

```bash
haxelib git heaps https://github.com/HeapsIO/heaps.git
```

## Compilar e rodar

- **Compilar (HTML5):**  
  `haxe compile.hxml`  
  Gera `hello.js` e `hello.js.map`.

- **Rodar no navegador:**  
  Abra `index.html` no Chrome (ou use F5 no VS Code com a extensão Haxe e launch "Launch Chrome (Heaps HTML5)").

- **Build rápido:**  
  No terminal: `haxe compile.hxml` e depois abra `index.html`.

## Estrutura

```
.
├── .vscode/launch.json   # Debug no Chrome
├── res/                  # Assets (fontes, imagens, etc.)
├── src/
│   └── Main.hx           # Entry point do jogo
├── compile.hxml          # Configuração de compilação
├── index.html            # Página para rodar o build JS
└── README.md
```

## Documentação

- [Heaps – Installation](https://heaps.io/documentation/installation.html)
- [Heaps – Hello World](https://heaps.io/documentation/hello-world.html)
