# Juice – filosofia de design

**Objetivo:** máximo de feedback visual e sensação boa. Animações, efeitos, partículas, easing – tudo a serviço do “feel” do jogo.

## O que já temos

### Transição entre slides (feed)
- **Slide up:** ao dar swipe up, a cena atual sobe e sai pelo topo, a próxima sobe de baixo (estilo TikTok).
- **Easing:** `easeOutCubic` na transição (~0,38 s).
- **Scale no slide que entra:** começa em 0,97 e vai a 1 durante a entrada (leve “zoom in”).
- Swipe é ignorado enquanto a transição está rodando.

### Shared: `shared/Easing.hx`
- `easeOutCubic(t)` – suave no fim (sai de cena).
- `easeInCubic(t)` – acelera no início.
- `easeInOutCubic(t)` – suave nos dois lados.
- `easeOutBack(t)` – overshoot (bom para “pop”).
- `easeOutElastic(t)` – elástico no fim.

Use nos minigames para qualquer animação (UI, personagens, partículas).

## Ideias para mais juice (futuro)

- **Partículas:** ao passar obstáculo (Flappy/Dino), ao perder, ao ganhar ponto.
- **Shake de câmera:** leve quando colide ou perde.
- **Feedback de tap:** pequeno scale ou flash no botão/área tocada.
- **Som e haptic:** sons curtos + vibração no celular em eventos importantes.
- **Transição de game over:** breve “freeze” + fade ou shake antes da tela de score.
- **Sombra/blur** atrás dos slides durante a transição (opcional).

Sempre que adicionar um minigame ou uma tela, perguntar: “onde dá para colocar mais juice?” (animação, easing, partícula, som).
