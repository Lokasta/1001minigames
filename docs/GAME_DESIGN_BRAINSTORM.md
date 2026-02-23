# Game Design – Brainstorm TokTok Games

**Restrições:** simples | roda bem no celular | também no navegador | PvE | local (single player)

---

## Ideia 1: **Tower Defense minimalista**
- Uma pista (path) e ondas de inimigos que vêm de um lado.
- Torres fixas (ou slots) que o jogador coloca: atiram sozinhos.
- Recursos por onda ou por kill para desbloquear/evoluir torres.
- **Por que encaixa:** 2D/2.5D, poucos objetos na tela, lógica por “onda”, fácil de balancear. Toque = colocar torre / selecionar.

---

## Ideia 2: **Endless runner / dodge**
- Personagem corre (ou a câmera avança); obstáculos e buracos.
- Tap = pulo ou deslizar; às vezes duas pistas (esquerda/direita).
- Pontos por distância; talvez power-ups (imortalidade 3s, magnet de moedas).
- **Por que encaixa:** loop super simples, um gesto (tap), performance leve. Pode ser 2D ou 3D simples.

---

## Ideia 3: **Merge / 2 em 1 (tipo 2048 com tema)**
- Grid; peças iguais se juntam quando uma é empurrada contra a outra (ou no merge clássico).
- Objetivo: chegar num “número” ou num tipo de peça (ex.: dragão nível 5).
- **Por que encaixa:** turn-based, sem tempo real pesado, só input discreto. Muito amigável pra mobile e browser.

---

## Ideia 4: **Top-down survivor (mini Vampire Survivors)**
- Um personagem no centro; inimigos surgem e se aproximam.
- Arma atira sozinha (ou ataque em área a cada X segundos).
- Coletar XP/gems para subir de nível e escolher 1 de 3 upgrades (dano, área, velocidade).
- Sessões curtas (5–10 min); objetivo = sobreviver o máximo de tempo.
- **Por que encaixa:** PvE puro, um stick virtual + eventualmente um botão. Heaps aguenta muitos sprites 2D ou 3D simples.

---

## Ideia 5: **Puzzle de blocos / match-3 light**
- Grid de blocos; objetivo: limpar X linhas ou fazer Y combos.
- Mecânica única: ex. “arrastar um bloco e soltar para trocar de lugar” ou “clicar em grupos de 2+ da mesma cor”.
- **Por que encaixa:** PvE, local, input por toque/clique. Dá pra fazer em 2D com tiles e poucos efeitos.

---

## Ideia 6: **Shooter on-rails (1 lane)**
- Nave (ou personagem) fixo no eixo X ou Y; inimigos e obstáculos vêm na direção do jogador.
- Toque/clique = atirar; às vezes “segurar” = tiro contínuo ou poder.
- Fases curtas (1–2 min) com boss no final.
- **Por que encaixa:** câmera e movimento simples, foco em timing e padrões. Roda leve em mobile e browser.

---

## Ideia 7: **Coleta + evolução (idle light)**
- Personagem anda por um mapa pequeno (ou só uma tela); recursos aparecem (frutas, cristais).
- Coletar gera moeda; gastar em upgrades (velocidade, capacidade, nova área).
- Objetivo: “desbloquear o fim do mapa” ou “atingir nível 10”.
- **Por que encaixa:** PvE, local, ritmo lento. Poucos sistemas: movimento, colisão, UI de upgrade.

---

## Resumo rápido

| Ideia              | Complexidade | Mobile | Browser | PvE | Local |
|--------------------|-------------|--------|---------|-----|-------|
| Tower Defense      | Média       | ✅     | ✅      | ✅  | ✅    |
| Endless runner     | Baixa       | ✅     | ✅      | ✅  | ✅    |
| Merge / 2 em 1     | Baixa       | ✅     | ✅      | ✅  | ✅    |
| Top-down survivor  | Média       | ✅     | ✅      | ✅  | ✅    |
| Puzzle blocos      | Baixa       | ✅     | ✅      | ✅  | ✅    |
| Shooter on-rails   | Baixa–média | ✅     | ✅      | ✅  | ✅    |
| Coleta + evolução  | Baixa       | ✅     | ✅      | ✅  | ✅    |

---

## Recomendações para “fazer hoje”

- **Mais rápido de prototipar:** Endless runner, Puzzle blocos, Shooter on-rails ou Merge.
- **Mais “game feel” com pouco código:** Endless runner (pulo, velocidade, obstáculos) ou Shooter on-rails (tiro, inimigos em linha).
- **Se curtir mais estratégia:** Tower Defense ou Top-down survivor (começar com 1 inimigo, 1 arma, 1 upgrade).

Escolhe uma direção (ou mistura duas, ex: “runner com power-ups de merge”) e no próximo passo a gente quebra em **MVP**: mecânicas mínimas, uma tela, um objetivo claro e depois iteramos.
