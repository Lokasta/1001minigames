# Publicar build no itch.io

O jogo pode ser publicado na web (HTML5) no itch.io com um único comando, usando o **butler** (CLI oficial).

## 1. Instalar o butler

- **macOS:** `brew install butler` ou descarregar em [itch.io/docs/butler](https://itch.io/docs/butler/)
- Ou: [https://itch.io/docs/butler/install.html](https://itch.io/docs/butler/install.html)

## 2. Autenticação (uma vez)

No terminal:

```bash
butler login
```

Abre o browser para autorizar o butler na tua conta itch.io.

## 3. Criar o projeto no itch.io

Se ainda não criaste a página do jogo:

1. Entra em [itch.io](https://itch.io) e faz login.
2. **Create new project** → preenche nome, URL (ex.: `toktokgames`).
3. Na edição do projeto, em **Kind of project** escolhe **HTML** (para “Play in browser”).
4. Guarda. O projeto fica em `https://TEU_USER.itch.io/NOME_DO_JOGO`.

## 4. Publicar a build

Na raiz do repositório, define o teu projeto (user/jogo, tudo em minúsculas) e corre o script:

```bash
ITCH_PROJECT=teuuser/nome-do-jogo ./scripts/push-itch.sh
```

Exemplo:

```bash
ITCH_PROJECT=leonidasmaciel/toktokgames ./scripts/push-itch.sh
```

O script:

1. Faz o build web (`haxe compile.hxml` → `hello.js`).
2. Copia `index.html` e `hello.js` (e `hello.js.map` se existir) para `dist/`.
3. Envia `dist/` para o itch.io no canal **html5** (ou no canal que definires em `ITCH_CHANNEL`).
4. Se existir um APK no caminho indicado (ver abaixo), envia também para o canal **android**.

### Enviar também a build Android (APK)

O script envia APK para o canal **android** se o ficheiro existir:

- **Caminho por defeito:** `android/app/build/outputs/apk/debug/app-debug.apk` (quando o APK é construído neste repo).
- **Caminho à medida:** define `ITCH_APK_PATH` com o caminho completo para o `.apk`.

Exemplo quando o APK é construído na worktree (e queres enviá-lo a partir do repo principal):

```bash
ITCH_PROJECT=teuuser/toktokgames ITCH_APK_PATH=../toktokgames-android-build/android/app/build/outputs/apk/debug/app-debug.apk ./scripts/push-itch.sh
```

Ou só web (sem APK):

```bash
ITCH_PROJECT=teuuser/toktokgames ./scripts/push-itch.sh
```

No itch.io, o canal **android** fica automaticamente marcado como Android; na página do jogo os jogadores podem fazer download do APK.

Canal web diferente (opcional):

```bash
ITCH_PROJECT=teuuser/toktokgames ITCH_CHANNEL=web ./scripts/push-itch.sh
```

## 5. Depois do primeiro push

Na página de edição do jogo no itch.io:

- Em **Kind of project** confirma que está **HTML**.
- Marca a opção **HTML5 / Playable in browser** no canal onde fizeste push (ex.: html5).

Assim o jogo fica “Play in browser” e quem entrar na página pode jogar direto.

## Automatizar (CI)

Para fazer push a partir de um pipeline (ex.: GitHub Actions):

1. Gera uma API key: no itch.io, **Account** → **API keys** → criar chave.
2. No CI, define a variável `BUTLER_API_KEY` com essa chave (como secret).
3. Define `ITCH_PROJECT` (e, se quiseres, `ITCH_CHANNEL`) no workflow e corre o mesmo script (ou os mesmos comandos: build → `butler push dist/ ...`).

Exemplo mínimo no workflow:

```yaml
env:
  ITCH_PROJECT: teuuser/toktokgames
  BUTLER_API_KEY: ${{ secrets.BUTLER_API_KEY }}
run: ./scripts/push-itch.sh
```

(Com butler instalado no runner; em GitHub Actions podes usar uma action que instale o butler.)

## Resumo

| O quê              | Comando / valor                          |
|--------------------|------------------------------------------|
| Publicar manual   | `ITCH_PROJECT=user/jogo ./scripts/push-itch.sh` |
| Canal web         | `html5` (alterável com `ITCH_CHANNEL`)   |
| Canal Android     | `android` (usado se existir APK no caminho) |
| Caminho do APK    | Por defeito `android/.../app-debug.apk`; ou `ITCH_APK_PATH=/caminho/para/app.apk` |
| Autenticação      | `butler login` (uma vez) ou `BUTLER_API_KEY` em CI |
