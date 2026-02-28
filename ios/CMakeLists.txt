cmake_minimum_required(VERSION 3.14)

project(TokTokGames LANGUAGES C)
enable_language(OBJC)

set(CMAKE_C_STANDARD 11)

# iOS settings
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "Minimum iOS deployment target")

include_directories(deps/hashlink/src)

# ============ HashLink Runtime (libhl) ============

file(GLOB HL_STD deps/hashlink/src/std/*.c)
file(GLOB HL_CORE
    deps/hashlink/src/alloc.c
    deps/hashlink/src/gc.c
)
# Remove debug.c (not needed for HL/C)
list(FILTER HL_STD EXCLUDE REGEX "debug\\.c$")

file(GLOB PCRE deps/hashlink/include/pcre/pcre*.c)

add_library(hl STATIC
    ${PCRE}
    ${HL_STD}
    ${HL_CORE}
    deps/hl_stubs.c
)
target_include_directories(hl PRIVATE deps/hashlink/include/pcre)
target_compile_definitions(hl PRIVATE LIBHL_STATIC)

# ============ FMT (image/audio formats) ============

file(GLOB FMT deps/hashlink/libs/fmt/*.c)
file(GLOB PNG deps/hashlink/include/png/*.c)
file(GLOB ZLIB deps/hashlink/include/zlib/*.c)
file(GLOB VORBIS deps/hashlink/include/vorbis/*.c)
file(GLOB MIKKT deps/hashlink/include/mikktspace/*.c)
file(GLOB MINIMP3 deps/hashlink/include/minimp3/*.c)

add_library(fmt.hdll STATIC
    ${FMT}
    ${PNG}
    ${ZLIB}
    ${VORBIS}
    ${MIKKT}
    ${MINIMP3}
)
target_include_directories(fmt.hdll PRIVATE
    deps/hashlink/include/png
    deps/hashlink/include/mikktspace
    deps/hashlink/include/minimp3
    deps/hashlink/include/vorbis
    deps/hashlink/include/zlib
    deps/hashlink/src
)
target_compile_definitions(fmt.hdll PRIVATE
    LIBHL_STATIC
    PNG_ARM_NEON_OPT=0
)
target_include_directories(fmt.hdll PRIVATE deps/turbojpeg_stub)

# ============ SDL2 ============

# Build SDL2 as a static library for iOS
set(IOS ON CACHE BOOL "" FORCE)
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL2_DISABLE_SDL2MAIN OFF CACHE BOOL "" FORCE)
set(SDL2_DISABLE_INSTALL ON CACHE BOOL "" FORCE)
set(CMAKE_SKIP_INSTALL_RULES ON CACHE BOOL "" FORCE)
# Suppress -Werror for SDL2 (old code has declaration-after-statement warnings)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-error=declaration-after-statement")
add_subdirectory(deps/sdl2)

# Override generated SDL_config.h with the iOS-specific one
file(COPY deps/sdl2/include/SDL_config_iphoneos.h
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/deps/sdl2/include)
file(RENAME ${CMAKE_CURRENT_BINARY_DIR}/deps/sdl2/include/SDL_config_iphoneos.h
            ${CMAKE_CURRENT_BINARY_DIR}/deps/sdl2/include/SDL_config.h)


file(GLOB SDL_HL deps/hashlink/libs/sdl/*.c)
add_library(sdl.hdll STATIC ${SDL_HL})
target_include_directories(sdl.hdll PUBLIC deps/sdl2/include deps/hashlink/src)
target_compile_definitions(sdl.hdll PRIVATE LIBHL_STATIC)
target_link_libraries(sdl.hdll SDL2-static SDL2main)

# ============ OpenAL (stub for now — no audio libs bundled) ============

# Use a stub ui.hdll
file(GLOB UI_STUB deps/hashlink/libs/ui/ui_stub.c)
add_library(ui.hdll STATIC ${UI_STUB})
target_include_directories(ui.hdll PRIVATE deps/hashlink/src)
target_compile_definitions(ui.hdll PRIVATE LIBHL_STATIC)

# ============ TokTok Games App ============

add_executable(TokTokGames
    hlc_out/main.c
)

target_include_directories(TokTokGames PRIVATE
    hlc_out
    deps/hashlink/src
    deps/sdl2/include
)

target_compile_definitions(TokTokGames PRIVATE LIBHL_STATIC HL_MOBILE HL_IOS sdl__Sdl__val=1)

target_link_libraries(TokTokGames
    hl
    sdl.hdll
    fmt.hdll
    ui.hdll
)

# iOS frameworks needed by SDL2
target_link_libraries(TokTokGames
    "-framework Foundation"
    "-framework UIKit"
    "-framework OpenGLES"
    "-framework QuartzCore"
    "-framework CoreAudio"
    "-framework AudioToolbox"
    "-framework CoreGraphics"
    "-framework CoreMotion"
    "-framework GameController"
    "-framework Metal"
    "-framework AVFoundation"
)

# App bundle settings
set_target_properties(TokTokGames PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.lokasta.toktokgames"
    MACOSX_BUNDLE_BUNDLE_NAME "TokTok Games"
    MACOSX_BUNDLE_BUNDLE_VERSION "1.0"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.lokasta.toktokgames"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "14.0"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "N45547YJ4V"
)
