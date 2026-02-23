#ifndef FLUTTER_BICUBIC_RESIZE_H
#define FLUTTER_BICUBIC_RESIZE_H

#include <stdint.h>

#if defined(_WIN32)
#define FFI_EXPORT __declspec(dllexport)
#else
#define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Error codes
// ============================================================================

#define BICUBIC_SUCCESS              0
#define BICUBIC_ERROR_NULL_INPUT    -1
#define BICUBIC_ERROR_INVALID_DIMS  -2
#define BICUBIC_ERROR_DECODE_FAILED -3
#define BICUBIC_ERROR_ALLOC_FAILED  -4
#define BICUBIC_ERROR_ENCODE_FAILED -5

// ============================================================================
// Filter types (matching stb_image_resize2 filters)
// ============================================================================

#define FILTER_CATMULL_ROM   0  // OpenCV INTER_CUBIC, PIL BICUBIC (default)
#define FILTER_CUBIC_BSPLINE 1  // Smoother, more blurry
#define FILTER_MITCHELL      2  // Mitchell-Netravali (balanced)

// ============================================================================
// Edge modes (how to handle pixels outside image bounds)
// ============================================================================

#define EDGE_CLAMP   0  // Repeat edge pixels (default)
#define EDGE_WRAP    1  // Wrap around (tile)
#define EDGE_REFLECT 2  // Mirror reflection
#define EDGE_ZERO    3  // Black/transparent pixels

// ============================================================================
// Crop anchor positions
// ============================================================================

#define CROP_CENTER        0  // Center crop (default)
#define CROP_TOP_LEFT      1
#define CROP_TOP_CENTER    2
#define CROP_TOP_RIGHT     3
#define CROP_CENTER_LEFT   4
#define CROP_CENTER_RIGHT  5
#define CROP_BOTTOM_LEFT   6
#define CROP_BOTTOM_CENTER 7
#define CROP_BOTTOM_RIGHT  8

// ============================================================================
// Crop aspect ratio modes
// ============================================================================

#define ASPECT_SQUARE   0  // 1:1 square crop (default)
#define ASPECT_ORIGINAL 1  // Keep original aspect ratio
#define ASPECT_CUSTOM   2  // Custom aspect ratio (use aspect_w/aspect_h)

// ============================================================================
// Raw pixel data resize functions
// ============================================================================

// Resize RGB image using specified filter
// filter: 0=Catmull-Rom (default), 1=Cubic B-Spline, 2=Mitchell
// edge_mode: 0=clamp (default), 1=wrap, 2=reflect, 3=zero
// crop: crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
// crop_anchor: 0=center (default), 1-8 = other positions
// aspect_mode: 0=square (default), 1=original, 2=custom
// aspect_w, aspect_h: custom aspect ratio (only used if aspect_mode=2)
// Returns BICUBIC_SUCCESS (0) on success, or a negative BICUBIC_ERROR_* code
FFI_EXPORT int bicubic_resize_rgb(
    const uint8_t* input,
    int input_width,
    int input_height,
    uint8_t* output,
    int output_width,
    int output_height,
    int filter,
    int edge_mode,
    float crop,
    int crop_anchor,
    int aspect_mode,
    float aspect_w,
    float aspect_h
);

// Resize RGBA image using specified filter
// filter: 0=Catmull-Rom (default), 1=Cubic B-Spline, 2=Mitchell
// edge_mode: 0=clamp (default), 1=wrap, 2=reflect, 3=zero
// crop: crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
// crop_anchor: 0=center (default), 1-8 = other positions
// aspect_mode: 0=square (default), 1=original, 2=custom
// aspect_w, aspect_h: custom aspect ratio (only used if aspect_mode=2)
// Returns BICUBIC_SUCCESS (0) on success, or a negative BICUBIC_ERROR_* code
FFI_EXPORT int bicubic_resize_rgba(
    const uint8_t* input,
    int input_width,
    int input_height,
    uint8_t* output,
    int output_width,
    int output_height,
    int filter,
    int edge_mode,
    float crop,
    int crop_anchor,
    int aspect_mode,
    float aspect_w,
    float aspect_h
);

// ============================================================================
// JPEG resize functions (decode -> resize -> encode)
// ============================================================================

// Resize JPEG image
// filter: 0=Catmull-Rom (default), 1=Cubic B-Spline, 2=Mitchell
// edge_mode: 0=clamp (default), 1=wrap, 2=reflect, 3=zero
// quality: JPEG quality 1-100
// crop: crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
// crop_anchor: 0=center (default), 1-8 = other positions
// aspect_mode: 0=square (default), 1=original, 2=custom
// aspect_w, aspect_h: custom aspect ratio (only used if aspect_mode=2)
// apply_exif: 1=apply EXIF orientation (default), 0=ignore EXIF
// Returns BICUBIC_SUCCESS (0) on success, or a negative BICUBIC_ERROR_* code
FFI_EXPORT int bicubic_resize_jpeg(
    const uint8_t* input_data,
    int input_size,
    int output_width,
    int output_height,
    int quality,
    int filter,
    int edge_mode,
    float crop,
    int crop_anchor,
    int aspect_mode,
    float aspect_w,
    float aspect_h,
    int apply_exif,
    uint8_t** output_data,
    int* output_size
);

// ============================================================================
// PNG resize functions (decode -> resize -> encode)
// ============================================================================

// Resize PNG image
// filter: 0=Catmull-Rom (default), 1=Cubic B-Spline, 2=Mitchell
// edge_mode: 0=clamp (default), 1=wrap, 2=reflect, 3=zero
// crop: crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
// crop_anchor: 0=center (default), 1-8 = other positions
// aspect_mode: 0=square (default), 1=original, 2=custom
// aspect_w, aspect_h: custom aspect ratio (only used if aspect_mode=2)
// compression_level: PNG compression 0-9 (0=none, 9=max, default=6)
// Returns BICUBIC_SUCCESS (0) on success, or a negative BICUBIC_ERROR_* code
FFI_EXPORT int bicubic_resize_png(
    const uint8_t* input_data,
    int input_size,
    int output_width,
    int output_height,
    int filter,
    int edge_mode,
    float crop,
    int crop_anchor,
    int aspect_mode,
    float aspect_w,
    float aspect_h,
    int compression_level,
    uint8_t** output_data,
    int* output_size
);

// ============================================================================
// Raw RGB output (for ML preprocessing)
// ============================================================================

// Decode and resize image to raw RGB bytes (no re-encoding)
// This is optimized for ML preprocessing where you need raw pixels
// filter: 0=Catmull-Rom (default), 1=Cubic B-Spline, 2=Mitchell
// edge_mode: 0=clamp (default), 1=wrap, 2=reflect, 3=zero
// crop: crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
// crop_anchor: 0=center (default), 1-8 = other positions
// aspect_mode: 0=square (default), 1=original, 2=custom
// aspect_w, aspect_h: custom aspect ratio (only used if aspect_mode=2)
// apply_exif: 1=apply EXIF orientation (JPEG only), 0=ignore EXIF
// is_jpeg: 1=input is JPEG, 0=input is PNG
// Returns BICUBIC_SUCCESS (0) on success, or a negative BICUBIC_ERROR_* code
FFI_EXPORT int bicubic_resize_to_rgb(
    const uint8_t* input_data,
    int input_size,
    int output_width,
    int output_height,
    int filter,
    int edge_mode,
    float crop,
    int crop_anchor,
    int aspect_mode,
    float aspect_w,
    float aspect_h,
    int apply_exif,
    int is_jpeg,
    uint8_t** output_data,
    int* output_size
);

// ============================================================================
// Memory management
// ============================================================================

// Free buffer allocated by resize functions
FFI_EXPORT void free_buffer(uint8_t* buffer);

#ifdef __cplusplus
}
#endif

#endif
