# Build Android nativo (Heaps + HashLink)

O jogo usa **Heaps** com target **HashLink/C** e **SDL2** para Android. O projeto nativo vem do repositório [altef/heaps-android](https://github.com/altef/heaps-android), que já inclui HashLink, SDL2, OpenAL e CMake/NDK.

## Pré-requisitos

- **Haxe 4+** e **Heaps** (como no README principal). Para o target Android usa-se **Heaps 2.1.0** (compatível com hlsdl); para HTML5 podes continuar a usar `haxelib git heaps`.
- **hlsdl**, **format** e **hashlink** para HashLink/SDL:
  ```bash
  haxelib install hlsdl
  haxelib install format
  haxelib install hashlink
  ```
- **JDK 17** para o Gradle (se tiveres só Java 25, instala com `brew install openjdk@17` e usa `export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` antes de `./gradlew`).
- **Android Studio** e **Android SDK** (SDK Manager → SDK Tools: NDK, CMake). Define `ANDROID_SDK_ROOT` ou cria `android/local.properties` com `sdk.dir=/caminho/para/Android/sdk`. (com **NDK** e **CMake** instalados via SDK Manager → SDK Tools)
- **NDK r18b** – o projeto só compila com esta versão. Descarrega de [Unsupported Downloads](https://github.com/android/ndk/wiki/Unsupported-Downloads), descompacta e coloca na pasta `ndk` do teu Android SDK. Renomeia a pasta para `18.1.1` (ou ajusta `ndkVersion` em `app/build.gradle`).

## Configuração (uma vez)

Na **raiz do repositório** (toktokgames), clona o projeto Android com os submodules:

```bash
git clone --recursive https://github.com/altef/heaps-android android
```

Isto cria a pasta `android/` com o projeto Gradle, HashLink, SDL2, OpenAL, etc.

## Build do APK

1. **Gera o código C** a partir do Haxe (na raiz do toktokgames):

   ```bash
   haxe compile_android.hxml
   ```
   ou `npm run build:android`

   Isto gera os ficheiros em `android/app/src/main/cpp/out/` (incluindo `main.c`).

2. **Compila o APK**:

   ```bash
   cd android
   ./gradlew assembleDebug
   ```

   O APK fica em `android/app/build/outputs/apk/debug/app-debug.apk`.

3. **Instalar no dispositivo/emulador**:

   ```bash
   ./gradlew installDebug
   ```

Ou abre a pasta `android` no Android Studio e usa **Build → Build Bundle(s) / APK(s) → Build APK(s)**.

## Estrutura relevante

- `compile_android.hxml` (na raiz) – compila o jogo para HashLink/C com **hlsdl**, output em `android/app/src/main/cpp/out/`.
- `android/app/src/main/cpp/` – código nativo: HashLink, SDL2, OpenAL e o `out/main.c` gerado pelo Haxe.
- `android/app/src/main/java/` – activity Android que inicia o runtime nativo.

## Notas

- O repositório oficial [HeapsIO/heaps-android](https://github.com/HeapsIO/heaps-android) está desatualizado; o fork **altef/heaps-android** é o que funciona com Android Studio + NDK atual.
- Se mudares o `applicationId` ou a estrutura de pastas do projeto Android, ajusta o caminho em `compile_android.hxml` (`-hl android/.../out/main.c`) para bater com o teu layout.
