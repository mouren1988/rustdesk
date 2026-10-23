/* encoder/decoder 须在 vp8.h 之前，否则 bindgen 可能把 vpx_codec_*_cfg 生成为 opaque { _address } */
#include <vpx/vpx_encoder.h>
#include <vpx/vpx_decoder.h>
#include <vpx/vp8.h>
#include <vpx/vp8cx.h>
#include <vpx/vp8dx.h>
#include <vpx/vpx_frame_buffer.h>
#include <vpx/vpx_image.h>
#include <vpx/vpx_integer.h>
