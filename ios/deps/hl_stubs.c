// Stubs for functions not available on iOS
#include <hl.h>
#include <stddef.h>

// hl_mem_compact - newer HashLink function not in our bundled source
HL_API vdynamic* hl_mem_compact(vdynamic* d, varray* a, int flags, int* out) {
    if (out) *out = 0;
    return NULL;
}

// SDL Haptic stubs - no haptic feedback on iOS via SDL
typedef void SDL_Haptic;
void SDL_HapticClose(SDL_Haptic *h) {}
SDL_Haptic* SDL_HapticOpenFromJoystick(void *j) { return NULL; }
int SDL_HapticRumbleInit(SDL_Haptic *h) { return -1; }
int SDL_HapticRumblePlay(SDL_Haptic *h, float strength, unsigned int length) { return -1; }

// libuv stubs - game doesn't use async I/O
typedef void uv_loop_t;
#define HL_NAME(n) uv_##n

HL_PRIM void HL_NAME(close_handle)(void *h, void *c) {}
HL_PRIM void* HL_NAME(default_loop)(void) { return NULL; }
HL_PRIM void* HL_NAME(fs_start_wrap)(void) { return NULL; }
HL_PRIM bool HL_NAME(run)(void *loop, int mode) { return false; }
