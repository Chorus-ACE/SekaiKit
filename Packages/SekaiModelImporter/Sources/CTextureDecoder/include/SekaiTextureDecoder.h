#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// IEEE binary16 vertex attributes, including Intel Mac targets without Swift.Float16.
float sekai_decode_float16(uint16_t bits);
// Returns 0 for unsupported formats or invalid lengths. RGBA rows retain Unity's
// decode order, matching Haruki's unflipped PNGs and texture.flipY=false.
int sekai_decode_texture(const uint8_t *source, size_t source_size, int width, int height,
                         int unity_format, uint8_t *rgba, size_t rgba_size);
#ifdef __cplusplus
}
#endif
