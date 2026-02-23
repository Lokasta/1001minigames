# TokTok Games – Conceito: feed de minigames (estilo WarioWare)

## Ideia em uma frase

**TikTok, mas de jogos:** tela cheia em portrait; você dá **slide up** e cai direto num minigame. Joga até perder → aparece seu score → **slide up** de novo → outro minigame. Sem menus, sem escolher jogo: o gesto é sempre “próximo”.

Referência forte: **WarioWare** – vários microgames curtos, instrução rápida, “joga isso em 5 segundos”, fail = próximo.

---

## Loop do jogador

1. **Tela atual** (minigame **ou** tela de score)
2. Jogador faz **swipe up** (gesto principal)
3. **Se estava num minigame:** pode ser que o jogo interprete como ação no jogo OU só avance quando perdeu (a gente define por minigame).
4. **Quando perde:** aparece **tela de score** (pontos daquele minigame, opcional: melhor da sessão).
5. **Swipe up na tela de score** → carrega **próximo minigame** (aleatório ou sequência).
6. Volta ao passo 1.

Ou seja: **navegação = swipe up = “próximo”**. Sem botões “jogar” ou “menu” – o feed é a interface.

---

## Pilares do conceito

| Pilar | Descrição |
|-------|-----------|
| **Portrait, tela cheia** | Uma “card” por vez, como stories/TikTok. |
| **Swipe up = próximo** | Único gesto de navegação entre jogos e telas de score. |
| **Minigames curtos** | 10–30 s de gameplay; “perdeu = acabou”, score mostrado. |
| **Sem menu clássico** | Não escolhe jogo; o sistema escolhe o próximo (aleatório ou rotação). |
| **Estilo WarioWare** | Muitos microgames simples, regras óbvias em 1 frase, reação rápida. |

---

## Fluxo técnico (visão geral)

```
[ Tela inicial / "Swipe up to play" ]
            ↓ swipe up
[ Minigame A ]  →  joga até perder
            ↓ (automático ou swipe após score)
[ Score: 42 pts ]
            ↓ swipe up
[ Minigame B ]  →  joga até perder
            ↓
[ Score: 18 pts ]
            ↓ swipe up
[ Minigame C ]
   ...
```

- **Uma “slide” = uma tela** (um minigame OU uma tela de score).
- Podemos ter uma **lista/array de minigames** e, ao swipe up na tela de score, sortear o próximo (ou rodar em ordem).

---

## Minigames: o que a gente precisa

- Cada minigame é **um módulo/cena** com:
  - **Instrução rápida** (texto ou ícone: “Tap!”, “Don’t touch red!”, “Catch the green”).
  - **Gameplay** em poucos segundos.
  - **Condição de derrota** clara (ex.: errou 1x, caiu no buraco, tempo acabou).
  - **Score** (opcional por jogo: pontos, tempo sobrevivido, etc.).

Ideias de microgames para começar (todos PvE, local, simples em mobile/browser):

1. **Tap no momento certo** – barra ou círculo; tap quando estiver na zona verde.
2. **Não toque no vermelho** – aparecem formas; tap só nas verdes, evitar vermelhas.
3. **Segura o botão** – “Segure por 3s” – soltou antes = perdeu.
4. **Um toque só** – um obstáculo vem; um único tap para desviar no timing certo.
5. **Catch** – coisas caem; pegar X verdes, não pegar vermelhas.
6. **Fuja** – personagem corre; tap = pulo; sobreviver o máximo de tempo (score = tempo ou distância).

Dá para lançar com **2–3 minigames** e ir acrescentando; a estrutura do “feed + swipe up” já serve para N jogos.

---

## O que implementar primeiro (MVP)

1. **Feed de “slides”**
   - Uma tela por vez (minigame ou score).
   - Detectar **swipe up** e trocar para a próxima “slide” (próximo minigame ou tela de score).

2. **Tela de score**
   - Após perder: mostrar pontos (e opcional “melhor da sessão”).
   - Texto ou ícone: “Swipe up for next game”.

3. **2 ou 3 minigames**
   - Cada um com: instrução, gameplay curto, condição de perda, score.
   - Ao perder → mostrar score → swipe up → próximo jogo (aleatório ou sequência).

4. **Tela inicial**
   - “Swipe up to play” (primeira “slide” do feed).

Com isso a gente já tem o **TokTok de games** no espírito WarioWare: swipe up = próximo, sem menu, portrait, PvE e local. Depois é só encher de minigames novos.

Se quiser, no próximo passo a gente quebra isso em **telas e cenas no Heaps** (uma cena = feed/slider, uma cena = minigame, uma cena = score) e já pensa no primeiro minigame em código.
