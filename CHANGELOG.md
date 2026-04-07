# Changelog

## [1.5.2] - 2026-04-07

### Changed
- Updated installation docs to ^1.5.2

## [1.5.1] - 2026-04-07

### Changed
- Dart SDK constraint: `>=3.2.0 <4.0.0`
- Flutter constraint: `>=3.16.0`
- Android `compileSdk`: 33 → 35
- Android Gradle Plugin: 7.4.2 → 8.7.3
- iOS deployment target: 11.0 → 13.0
- Modernized Gradle DSL (`compileSdkVersion` → `compileSdk`)

## [1.5.0] - 2026-03-27

### Added
- **`getImageInfo()`** — read image dimensions, format, channels, and EXIF orientation without decoding pixels
  - `BicubicImageInfo` class with `width`, `height`, `channels`, `format`, `exifOrientation`
  - Computed `orientedWidth`/`orientedHeight` for EXIF-corrected dimensions
  - Async variant: `getImageInfoAsync()`
- **`resizeFile()` / `resizeFileToFile()`** — File I/O convenience methods
  - Read from file path, resize, and return bytes or save to output path
  - Async variants: `resizeFileAsync()`, `resizeFileToFileAsync()`
- **Format conversion** — JPEG↔PNG conversion without resizing
  - `jpegToPng()` / `pngToJpeg()` — direct format conversion
  - `convertFormat()` — auto-detect input and convert to target format
  - Async variants: `jpegToPngAsync()`, `pngToJpegAsync()`, `convertFormatAsync()`
- **`formatUnknown` error code** (-6) in `BicubicNativeError` for unknown/unsupported image formats

### Changed
- **Parameter validation in C layer** — out-of-range filter, edge mode, crop anchor, and aspect mode values are now clamped to safe defaults instead of causing undefined behavior
- Updated `flutter_lints` from ^3.0.0 to ^4.0.0

## [1.4.0] - 2026-02-23

### Added
- **Async wrappers** for all public resize methods using `Isolate.run()` to avoid blocking the UI thread
  - `resizeJpegAsync()`, `resizePngAsync()`, `resizeRgbAsync()`, `resizeRgbaAsync()`
  - `resizeAsync()` (auto-detect format), `resizeForModelAsync()` (ML preprocessing)
- **Specific native error codes** replacing generic `-1` for better debugging
  - `BicubicNativeError` enum: `nullInput` (-1), `invalidDims` (-2), `decodeFailed` (-3), `allocFailed` (-4), `encodeFailed` (-5)
  - `BicubicResizeException` class with `nativeCode`, `error`, and human-readable `message`
- **Custom normalization validation** - `resizeForModel()` now throws `ArgumentError` if any `std` value is zero

### Changed
- Native C functions now return specific `BICUBIC_ERROR_*` codes instead of `-1` for all errors
- Dart error handling uses `BicubicResizeException` (implements `Exception` for backward compatibility)

## [1.3.1] - 2026-01-13

### Fixed
- **Android 15 compatibility** - Added 16KB page alignment for native library
  - Fixed `libflutter_bicubic_resize.so` alignment from 4KB to 16KB
  - Required for Android 15 (API 35+) which enforces 16KB page size
  - Added `-Wl,-z,max-page-size=16384` linker flag in CMakeLists.txt

## [1.3.0] - 2026-01-13

### Added
- **ML preprocessing with normalization** - new `resizeForModel()` method returning `Float32List`
  - `NormalizationType` enum: `none` (default), `simple` [0,1], `centered` [-1,1], `imageNet`, `custom`
  - `ChannelOrder` enum: `rgb` (default), `bgr`
  - `TensorLayout` enum: `hwc` (default, TensorFlow), `chw` (PyTorch)
  - Custom mean/std normalization parameters
  - Native C pipeline for raw RGB output (no re-encoding overhead)

### Optimized
- Pre-computed scale/offset factors for normalization (multiply+add instead of divide+subtract+divide)
- Branch conditions moved outside hot loops for better performance

### Changed
- Added `machine-learning` topic to pubspec.yaml
- Updated API documentation with ML preprocessing section
- Updated README with normalization examples

## [1.2.3] - 2025-12-18

### Added
- **Format detection and validation** - library now handles unsupported formats
  - `ImageFormat` enum (`jpeg`, `png`) for supported formats
  - `UnsupportedImageFormatException` - thrown for unsupported formats (HEIC, WebP, GIF, etc.)
  - `BicubicResizer.detectFormat(bytes)` - detect image format from bytes
  - `BicubicResizer.resize(bytes: ...)` - generic resize with auto-detection, throws exception for unsupported formats

## [1.2.2] - 2025-12-18

### Added
- **Crop anchor positions** (`CropAnchor`) - crop from any position, not just center
  - `center` (default), `topLeft`, `topCenter`, `topRight`, `centerLeft`, `centerRight`, `bottomLeft`, `bottomCenter`, `bottomRight`
- **Crop aspect ratio modes** (`CropAspectRatio`) - control crop shape
  - `square` (default) - 1:1 aspect ratio
  - `original` - keep original image proportions
  - `custom` - use custom aspect ratio with `aspectRatioWidth`/`aspectRatioHeight`
- **Edge handling modes** (`EdgeMode`) - control how pixels outside bounds are handled
  - `clamp` (default) - repeat edge pixels
  - `wrap` - tile/repeat image
  - `reflect` - mirror reflection at edges
  - `zero` - black/transparent pixels outside
- **JPEG EXIF control** (`applyExifOrientation`) - option to disable EXIF orientation correction
- **PNG compression control** (`compressionLevel`) - adjust compression 0-9 (default: 6)

### Changed
- All new parameters are optional with backward-compatible defaults
- Updated API documentation with comprehensive examples
- Expanded README with new features and usage examples

## [1.2.1] - 2025-12-14

### Fixed
- **iOS release build crash** - Fixed FFI symbol stripping issue that caused "symbol not found" errors in release/archive builds
- Added proper Xcode build settings to prevent symbol stripping (`STRIP_STYLE=non-global`)
- Added symbol retention mechanism in Swift plugin to ensure C functions are linked

## [1.2.0] - 2025-12-14

### Added
- **EXIF orientation support** for JPEG images - photos from mobile cameras now display correctly
- Automatic rotation/flip based on EXIF metadata (supports all 8 orientation values)

### Changed
- **Breaking:** Crop now produces 1:1 aspect ratio (square) instead of proportional crop
  - `crop: 1.0` on 1920x1080 image now crops to 1080x1080 (not 1920x1080)
  - This prevents stretching when resizing to square output (e.g., 224x224)
- Updated README with new features documentation

## [1.1.0] - 2025-12-12

### Added
- Optional center crop parameter (`crop`) for all resize methods
- Crop value range: 0.0-1.0 (1.0 = no crop, 0.5 = center 50%)
- Crop is applied before resize for efficient single-pass processing
- Example app now includes crop slider for testing

### Changed
- Updated API documentation with crop parameter
- Updated README with crop usage examples

## [1.0.1] - 2025-12-12

### Fixed
- Fixed GitHub repository links in pubspec.yaml

### Added
- Added API documentation (doc/api.md)
- Added topics for better discoverability on pub.dev
- Added funding link
- Added library documentation comments

## [1.0.0] - 2025-12-12

### Added
- Initial release
- Bicubic resize using native C code (stb_image_resize2)
- RGB and RGBA support
- JPEG and PNG encoding/decoding
- Isolate support for non-blocking operations
- iOS and Android support
