#!/bin/bash
# Setup iOS build dependencies for TokTok Games
# Downloads SDL2 and copies HashLink source for native iOS compilation
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/ios"
DEPS_DIR="$IOS_DIR/deps"

SDL2_VERSION="2.30.11"
SDL2_URL="https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz"

echo "=== TokTok Games iOS Setup ==="

# Check prerequisites
command -v haxe >/dev/null 2>&1 || { echo "Error: haxe not found. Install with: brew install haxe"; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "Error: cmake not found. Install with: brew install cmake"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "Error: Xcode not found. Install from App Store."; exit 1; }

# Check hashlink is installed (needed for source files)
HL_PREFIX="$(brew --prefix hashlink 2>/dev/null || true)"
if [ -z "$HL_PREFIX" ] || [ ! -d "$HL_PREFIX" ]; then
    echo "Installing HashLink..."
    brew install hashlink
    HL_PREFIX="$(brew --prefix hashlink)"
fi

mkdir -p "$DEPS_DIR"

# 1. Download SDL2
if [ ! -d "$DEPS_DIR/sdl2/CMakeLists.txt" ]; then
    echo "Downloading SDL2 ${SDL2_VERSION}..."
    curl -L "$SDL2_URL" -o /tmp/sdl2.tar.gz
    rm -rf "$DEPS_DIR/sdl2"
    mkdir -p "$DEPS_DIR/sdl2"
    tar xzf /tmp/sdl2.tar.gz -C "$DEPS_DIR/sdl2" --strip-components=1
    rm /tmp/sdl2.tar.gz
    echo "SDL2 ${SDL2_VERSION} downloaded."
else
    echo "SDL2 already present, skipping download."
fi

# 2. Copy HashLink source from brew installation
if [ ! -d "$DEPS_DIR/hashlink/src" ]; then
    echo "Copying HashLink source..."
    HL_SRC="$HL_PREFIX/share/hashlink/src"
    if [ ! -d "$HL_SRC" ]; then
        # Fallback: find in Cellar
        HL_SRC="$(find "$(brew --cellar hashlink)" -name "src" -path "*/share/hashlink/*" -type d | head -1)"
    fi
    if [ -z "$HL_SRC" ] || [ ! -d "$HL_SRC" ]; then
        echo "Error: HashLink source not found. Trying to copy from Cellar..."
        HL_CELLAR="$(brew --cellar hashlink)"
        HL_VER="$(ls "$HL_CELLAR" | head -1)"
        cp -R "$HL_CELLAR/$HL_VER/" "$DEPS_DIR/hashlink/"
    else
        cp -R "$(dirname "$HL_SRC")" "$DEPS_DIR/hashlink"
    fi
    echo "HashLink source copied."
else
    echo "HashLink source already present, skipping."
fi

# 3. Copy newer hlsdl source (matches haxelib hlsdl 1.15.0)
HLSDL_PATH="$(haxelib libpath hlsdl 2>/dev/null || true)"
if [ -n "$HLSDL_PATH" ] && [ -f "$HLSDL_PATH/sdl.c" ]; then
    echo "Copying hlsdl 1.15.0 source files..."
    cp "$HLSDL_PATH/sdl.c" "$DEPS_DIR/hashlink/libs/sdl/sdl.c"
    cp "$HLSDL_PATH/gl.c" "$DEPS_DIR/hashlink/libs/sdl/gl.c"
    [ -f "$HLSDL_PATH/GLImports.h" ] && cp "$HLSDL_PATH/GLImports.h" "$DEPS_DIR/hashlink/libs/sdl/GLImports.h"
    echo "hlsdl source updated."
fi

# 4. Patch hlc_main.c for iOS SDL_main support
HLC_MAIN="$DEPS_DIR/hashlink/src/hlc_main.c"
if [ -f "$HLC_MAIN" ] && ! grep -q "HL_IOS" "$HLC_MAIN"; then
    echo "Patching hlc_main.c for iOS..."
    sed -i '' 's/#if defined(HL_MOBILE) && defined(sdl__Sdl__val)/#if defined(HL_IOS)\
\/\/ On iOS, SDL2 provides the real main() in SDL_uikitappdelegate.m\
\/\/ which calls SDL_main(). We must rename our main() to SDL_main().\
#   define main SDL_main\
#elif defined(HL_MOBILE) \&\& defined(sdl__Sdl__val)/' "$HLC_MAIN"
    echo "hlc_main.c patched."
fi

# 5. Patch pngpriv.h (remove Classic Mac OS fp.h include)
PNGPRIV="$DEPS_DIR/hashlink/include/png/pngpriv.h"
if [ -f "$PNGPRIV" ] && grep -q "fp.h" "$PNGPRIV"; then
    echo "Patching pngpriv.h (removing fp.h for iOS)..."
    sed -i '' '/#.*include.*<fp.h>/d' "$PNGPRIV"
    # Ensure math.h is included
    if ! grep -q '#include <math.h>' "$PNGPRIV"; then
        sed -i '' 's/#include "pngconf.h"/#include "pngconf.h"\n#include <math.h>/' "$PNGPRIV"
    fi
    echo "pngpriv.h patched."
fi

# 6. Add glColorMaski stub for iOS GLES
GL_C="$DEPS_DIR/hashlink/libs/sdl/gl.c"
if [ -f "$GL_C" ] && ! grep -q "glColorMaski" "$GL_C" 2>/dev/null | grep -q "define"; then
    echo "Patching gl.c (glColorMaski stub for GLES)..."
    sed -i '' 's/#	define HL_GLES/#	define HL_GLES\
#	ifndef glColorMaski\
#		define glColorMaski(i, r, g, b, a) glColorMask(r, g, b, a)\
#	endif/' "$GL_C"
    echo "gl.c patched."
fi

# 7. Generate HL/C code
echo "Generating HL/C code..."
cd "$PROJECT_ROOT"
haxe compile_ios.hxml
echo "HL/C code generated in ios/hlc_out/"

# 8. Generate Xcode project
echo "Generating Xcode project..."
rm -rf "$IOS_DIR/build"
mkdir -p "$IOS_DIR/build"
cd "$IOS_DIR/build"
cmake .. -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DSDL_HAPTIC=OFF

echo ""
echo "=== iOS Setup Complete ==="
echo "Open Xcode project: open ios/build/TokTokGames.xcodeproj"
echo "Select scheme 'TokTokGames', pick your iPhone, and hit Cmd+R"
