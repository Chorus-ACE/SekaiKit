#include "SekaiTextureDecoder.h"
#include "vendor/astc.h"
#include "vendor/etc.h"
#include "vendor/bcn.h"
#include <algorithm>
#include <vector>
#include <cstring>

int sekai_decode_texture(const uint8_t *src, size_t size, int w, int h, int format, uint8_t *rgba, size_t out_size) {
    if (!src || !rgba || w <= 0 || h <= 0 || w > 4096 || h > 4096 || out_size != size_t(w) * h * 4) return 0;
    int bx = 4, by = 4, bytes = 0, kind = 0;
    if (format == 34) { bytes = 8; kind = 1; }
    else if (format == 45) { bytes = 8; kind = 2; }
    else if (format == 46) { bytes = 8; kind = 3; }
    else if (format == 47) { bytes = 16; kind = 4; }
    else if (format == 10) { bytes = 8; kind = 5; }
    else if (format == 12) { bytes = 16; kind = 6; }
    else if (format == 25) { bytes = 16; kind = 7; }
    else if (format >= 48 && format <= 59) {
        const int blocks[] = {4, 5, 6, 8, 10, 12}; bx = by = blocks[(format - 48) % 6]; bytes = 16; kind = 8;
    } else if (format == 4) { bytes = 4; bx = by = 1; kind = 9; }
    else if (format == 3) { bytes = 3; bx = by = 1; kind = 10; }
    else if (format == 1) { bytes = 1; bx = by = 1; kind = 11; }
    else return 0;
    const size_t required = size_t((w + bx - 1) / bx) * ((h + by - 1) / by) * bytes;
    if (size < required) return 0;
    std::vector<uint32_t> pixels(size_t(w) * h);
    int ok = 1;
    switch (kind) {
        case 1: ok = decode_etc1(src,w,h,pixels.data()); break;
        case 2: ok = decode_etc2(src,w,h,pixels.data()); break;
        case 3: ok = decode_etc2a1(src,w,h,pixels.data()); break;
        case 4: ok = decode_etc2a8(src,w,h,pixels.data()); break;
        case 5: ok = decode_bc1(src,w,h,pixels.data()); break;
        case 6: ok = decode_bc3(src,w,h,pixels.data()); break;
        case 7: ok = decode_bc7(src,w,h,pixels.data()); break;
        case 8: ok = decode_astc(src,w,h,bx,by,pixels.data()); break;
    }
    if (!ok) return 0;
    const auto *bgra = reinterpret_cast<const uint8_t *>(pixels.data());
    for (int y=0; y<h; ++y) for (int x=0; x<w; ++x) {
        const size_t input=(size_t(y)*w+x), output=(size_t(h-1-y)*w+x)*4;
        if (kind == 9) std::memcpy(rgba+output,src+input*4,4);
        else if (kind == 10) { std::memcpy(rgba+output,src+input*3,3); rgba[output+3]=255; }
        else if (kind == 11) { rgba[output]=rgba[output+1]=rgba[output+2]=255; rgba[output+3]=src[input]; }
        else { rgba[output]=bgra[input*4+2];rgba[output+1]=bgra[input*4+1];rgba[output+2]=bgra[input*4];rgba[output+3]=bgra[input*4+3]; }
    }
    return 1;
}
