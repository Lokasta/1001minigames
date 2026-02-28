// Stub turbojpeg.h for iOS builds (no JPEG support needed - all graphics are procedural)
#ifndef _TURBOJPEG_H
#define _TURBOJPEG_H

#include <stdlib.h>

#define TJSAMP_444 0
#define TJSAMP_422 1
#define TJSAMP_420 2
#define TJSAMP_GRAY 3
#define TJPF_BGRA 1
#define TJPF_RGBA 2
#define TJFLAG_FASTDCT 256
#define TJFLAG_BOTTOMUP 2

typedef void* tjhandle;

static inline tjhandle tjInitDecompress(void) { return NULL; }
static inline int tjDecompressHeader3(tjhandle handle, unsigned char *buf, unsigned long size, int *width, int *height, int *subsamp, int *colorspace) { return -1; }
static inline int tjDecompress2(tjhandle handle, unsigned char *buf, unsigned long size, unsigned char *dst, int width, int pitch, int height, int pf, int flags) { return -1; }
static inline int tjDestroy(tjhandle handle) { return 0; }
static inline tjhandle tjInitCompress(void) { return NULL; }
static inline int tjCompress2(tjhandle handle, const unsigned char *src, int width, int pitch, int height, int pf, unsigned char **dst, unsigned long *sz, int subsamp, int quality, int flags) { return -1; }
static inline void tjFree(unsigned char *buf) { free(buf); }

#endif
