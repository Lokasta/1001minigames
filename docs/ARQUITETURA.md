# Arquitetura – TokTok Games (feed de minigames)

## Visão geral

- **Feed de slides:** uma “tela” por vez (Start → Minigame → Score → swipe → próximo Minigame).
- **Minigames** são cenas **totalmente separadas**; podem compartilhar componentes em `shared/` quando fizer sentido.
- **Navegação:** só **swipe up** para avançar (na Start e na Score).

## Estrutura de pastas

```
src/
├── Main.hx                    # Entry point: scaleMode, cria GameFlow, registra minigames
├── core/                      # Núcleo do feed (não é um minigame)
│   ├── GameFlow.hx            # Controla estado (Start / Playing / Score), swipe, transições
│   ├── SwipeDetector.hx       # Detecta swipe up/down numa área
│   ├── IMinigameScene.hx      # Contrato: content, start(), dispose(), getMinigameId(), getTitle()
│   ├── MinigameContext.hx     # Contexto para reportar "perdeu" + score
│   ├── IMinigameSceneWithLose.hx  # setOnLose(ctx) para minigames que terminam com score
│   └── IMinigameUpdatable.hx  # update(dt) para minigames com timer/física
├── scenes/                    # Cenas do feed (UI) e minigames
│   ├── StartScreen.hx         # "Swipe up to play"
│   ├── ScoreScreen.hx        # Score + "Swipe up for next game"
│   └── minigames/             # Um arquivo/cena por minigame
│       └── ExampleMinigame.hx # Exemplo: "Don't tap for 2 sec"
└── shared/                     # Componentes e helpers reutilizáveis (juice, etc.)
    └── Easing.hx               # Funções de easing para animações
```

## Contratos

### IMinigameScene (todo minigame)

- `content: Object` – raiz 2D da cena (GameFlow adiciona ao feed).
- `start()` – chamado quando o minigame entra; inicializa e começa o gameplay.
- `dispose()` – chamado ao sair; remove conteúdo e libera recursos.
- `getMinigameId(): String` – ID único (ex.: para score screen / analytics).
- `getTitle(): String` – nome curto (ex.: "Don't tap!").

### IMinigameSceneWithLose (minigame que termina com “perdeu” + score)

- `setOnLose(ctx: MinigameContext)` – GameFlow chama antes de `start()`; o minigame chama `ctx.lose(score, id)` quando o jogador perde.

### IMinigameUpdatable (minigame com update por frame)

- `update(dt: Float)` – GameFlow chama a cada frame enquanto o minigame está ativo.

## Fluxo (GameFlow)

1. **Start** – mostra `StartScreen`; ao **swipe up** → escolhe um minigame (fábrica aleatória), cria cena, chama `setOnLose`, adiciona `content` ao root, chama `start()` → estado **Playing**.
2. **Playing** – minigame roda; se implementar `IMinigameUpdatable`, recebe `update(dt)`. Quando chama `ctx.lose(score, id)` → GameFlow faz `dispose()`, remove conteúdo, mostra `ScoreScreen` com score e id → estado **Score**.
3. **Score** – ao **swipe up** → volta ao passo 1 (próximo minigame).

## Como adicionar um minigame novo

1. Criar classe em `scenes/minigames/NomeDoMinigame.hx` que implemente pelo menos `IMinigameScene` e, se for terminar com score, `IMinigameSceneWithLose` (e opcionalmente `IMinigameUpdatable`).
2. No construtor: criar `content = new Object()` e montar toda a UI/gameplay em cima de `content`.
3. Em `Main.init()`, registrar:  
   `gameFlow.registerMinigame(() -> new scenes.minigames.NomeDoMinigame());`

Cada minigame é uma cena **separada**; pode usar coisas em `shared/` (botões, textos, etc.) sem acoplar um minigame ao outro.
