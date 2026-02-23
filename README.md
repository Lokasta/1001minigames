# TokTok Games

Projeto de jogo com [Heaps.io](https://heaps.io) (engine 2D/3D em Haxe).

## Pré-requisitos

- **Haxe 4+** (instalado via Homebrew: `brew install haxe`)
- **Heaps** (instalado via haxelib, ver abaixo)
- **Node.js** (só para hot reload: `npm run dev`)

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

### Hot reload (desenvolvimento)

Para desenvolver e ver as mudanças no jogo sem recarregar manualmente:

1. Instale as dependências de dev (uma vez):  
   `npm install`

2. Deixe o ambiente Haxe disponível no terminal (ex.: no `~/.zshrc`):  
   `export HAXE_STD_PATH="/opt/homebrew/lib/haxe/std"`

3. Rode em modo desenvolvimento:  
   `npm run dev`

Isso sobe um servidor em **http://localhost:8080** e fica observando `src/*.hx` e `compile.hxml`. Ao salvar qualquer arquivo, o projeto recompila e o navegador recarrega sozinho.

## Estrutura

```
.
├── .vscode/launch.json
├── docs/
│   ├── ARQUITETURA.md         # Feed, slides, minigames, contratos
│   ├── CONCEITO_TIKTOK_GAMES.md
│   └── GAME_DESIGN_BRAINSTORM.md
├── res/
├── src/
│   ├── Main.hx                # Entry point, registra minigames no GameFlow
│   ├── core/                  # Feed: GameFlow, swipe, contratos (IMinigameScene, etc.)
│   └── scenes/                # StartScreen, ScoreScreen, minigames/*
├── compile.hxml
├── index.html
└── README.md
```

Detalhes: [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## Build Android (app nativo)

A engine Heaps suporta **Android nativo** via HashLink (C) + SDL2. Para gerar um APK:

1. Configura o projeto Android (uma vez): ver [docs/ANDROID.md](docs/ANDROID.md) — clonar `altef/heaps-android` para a pasta `android/`.
2. Na raiz do projeto: `haxe compile_android.hxml` (gera o C em `android/app/src/main/cpp/out/`).
3. `cd android && ./gradlew assembleDebug` — APK em `android/app/build/outputs/apk/debug/`.

Requisitos: Android Studio, NDK, CMake e NDK r18b (detalhes no [docs/ANDROID.md](docs/ANDROID.md)).

## Documentação

- [Heaps – Installation](https://heaps.io/documentation/installation.html)
- [Heaps – Hello World](https://heaps.io/documentation/hello-world.html)

### H3D (3D) – referência para o game

Documentação principal: **[H3D – Heaps 3D API](https://heaps.io/documentation/h3d.html)**

Tópicos úteis para o jogo:

| Tópico | Uso |
|--------|-----|
| [Events and interaction](https://heaps.io/documentation/h3d.html#events-and-interaction) | Objetos 3D clicáveis / interação |
| [Lights](https://heaps.io/documentation/h3d.html#lights) | Luz direcional, point lights |
| [Material Basics](https://heaps.io/documentation/h3d.html#material-basics) | Materiais, cores, texturas |
| [PBR Materials](https://heaps.io/documentation/h3d.html#pbr-materials) | Materiais realistas (opcional) |
| [Shadows](https://heaps.io/documentation/h3d.html#shadows) | Sombras em tempo real |
| [FBX Models](https://heaps.io/documentation/h3d.html#fbx-models) | Modelos 3D exportados |
| [GPU Particles](https://heaps.io/documentation/h3d.html#gpu-particles) | Partículas em GPU |
| [World Batching](https://heaps.io/documentation/h3d.html#world-batching) | Otimização de draw calls |
| [Render Target](https://heaps.io/documentation/h3d.html#render-target) | Render para textura |
