#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Returns 0 for unsupported formats or invalid lengths. Pixels are RGBA, top-left origin.
int sekai_decode_texture(const uint8_t *source, size_t source_size, int width, int height,
                         int unity_format, uint8_t *rgba, size_t rgba_size);
#ifdef __cplusplus
}
#endif
