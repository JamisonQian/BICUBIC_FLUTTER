import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_bindings.dart';

// ============================================================================
// ML Preprocessing Enums
// ============================================================================

/// Normalization type for ML model preprocessing.
///
/// Different ML models expect different input normalization schemes.
/// Use [none] to get raw pixel values (0-255) as the default behavior.
enum NormalizationType {
  /// No normalization - returns raw pixel values (0-255).
  /// This is the default behavior for backward compatibility.
  none,

  /// Simple normalization: pixel / 255.0 -> [0.0, 1.0]
  /// Common for TensorFlow Lite models.
  simple,

  /// Centered normalization: (pixel / 127.5) - 1.0 -> [-1.0, 1.0]
  /// Common for MobileNet and similar models.
  centered,

  /// ImageNet normalization with standard mean and std.
  /// mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225]
  /// Common for ResNet, VGG, EfficientNet, etc.
  imageNet,

  /// Custom normalization with user-provided mean and std values.
  /// Use [meanR], [meanG], [meanB], [stdR], [stdG], [stdB] parameters.
  custom,
}

/// Channel ordering for ML model input.
enum ChannelOrder {
  /// RGB order (default) - Red, Green, Blue
  rgb,

  /// BGR order - Blue, Green, Red (used by some OpenCV-based models)
  bgr,
}

/// Tensor layout for ML model input.
enum TensorLayout {
  /// Height, Width, Channels (default) - TensorFlow/TFLite format
  /// Shape: [height, width, channels]
  hwc,

  /// Channels, Height, Width - PyTorch format
  /// Shape: [channels, height, width]
  chw,
}

// ============================================================================
// Image Format Enum
// ============================================================================

/// Supported image formats for resize operations
enum ImageFormat {
  /// JPEG format
  jpeg,

  /// PNG format
  png,
}

/// Image metadata obtained without full pixel decoding.
///
/// Contains dimensions, channel count, format, and EXIF orientation.
/// Use [orientedWidth] and [orientedHeight] to get dimensions after
/// EXIF orientation is applied.
///
/// ```dart
/// final info = BicubicResizer.getImageInfo(bytes);
/// print('${info.width}x${info.height} ${info.format}');
/// print('Oriented: ${info.orientedWidth}x${info.orientedHeight}');
/// ```
class BicubicImageInfo {
  /// Image width in pixels (before EXIF orientation).
  final int width;

  /// Image height in pixels (before EXIF orientation).
  final int height;

  /// Number of color channels (1=gray, 3=RGB, 4=RGBA).
  final int channels;

  /// Detected image format.
  final ImageFormat format;

  /// EXIF orientation value (1-8). Only meaningful for JPEG.
  /// 1 = normal (no transformation needed).
  final int exifOrientation;

  const BicubicImageInfo({
    required this.width,
    required this.height,
    required this.channels,
    required this.format,
    required this.exifOrientation,
  });

  /// Width after applying EXIF orientation.
  /// For orientations 5-8 (90/270 degree rotations), width and height are swapped.
  int get orientedWidth => exifOrientation >= 5 ? height : width;

  /// Height after applying EXIF orientation.
  /// For orientations 5-8 (90/270 degree rotations), width and height are swapped.
  int get orientedHeight => exifOrientation >= 5 ? width : height;

  @override
  String toString() => 'BicubicImageInfo(${width}x$height, channels=$channels, '
      'format=$format, exifOrientation=$exifOrientation)';
}

/// Exception thrown when an unsupported image format is detected.
///
/// This library only supports JPEG and PNG formats.
/// Other formats like HEIC, WebP, GIF, BMP, etc. are not supported.
class UnsupportedImageFormatException implements Exception {
  /// The raw bytes that were passed to the resize method
  final Uint8List bytes;

  /// Human-readable message describing the error
  final String message;

  UnsupportedImageFormatException({
    required this.bytes,
    this.message = 'Unsupported image format. Only JPEG and PNG are supported.',
  });

  @override
  String toString() => 'UnsupportedImageFormatException: $message';
}

// ============================================================================
// Native Error Codes
// ============================================================================

/// Native error codes returned by the C layer.
///
/// These correspond to the `BICUBIC_*` defines in `resize.h`.
enum BicubicNativeError {
  /// Null pointer passed as input, output, or size parameter.
  nullInput(-1, 'Null pointer passed to native function'),

  /// Invalid dimensions (width or height <= 0, or input_size <= 0).
  invalidDims(-2, 'Invalid dimensions (width, height, or size <= 0)'),

  /// Image decoding failed (corrupt or unsupported data).
  decodeFailed(-3, 'Image decoding failed (corrupt or unsupported data)'),

  /// Memory allocation failed in native code.
  allocFailed(-4, 'Memory allocation failed in native code'),

  /// Image encoding failed (JPEG/PNG write error).
  encodeFailed(-5, 'Image encoding failed'),

  /// Unknown or unsupported image format.
  formatUnknown(-6, 'Unknown or unsupported image format');

  /// The native error code value.
  final int code;

  /// Human-readable description of the error.
  final String description;

  const BicubicNativeError(this.code, this.description);

  /// Look up a [BicubicNativeError] by its native [code].
  ///
  /// Returns `null` if the code does not match any known error.
  static BicubicNativeError? fromCode(int code) {
    for (final error in values) {
      if (error.code == code) return error;
    }
    return null;
  }
}

/// Exception thrown when a native bicubic resize operation fails.
///
/// Contains the native error code and a human-readable description
/// to aid debugging.
class BicubicResizeException implements Exception {
  /// The raw native error code returned by the C function.
  final int nativeCode;

  /// The mapped error enum, or `null` if the code is unrecognized.
  final BicubicNativeError? error;

  /// Human-readable message describing the failure.
  final String message;

  BicubicResizeException(this.nativeCode)
      : error = BicubicNativeError.fromCode(nativeCode),
        message = BicubicNativeError.fromCode(nativeCode)?.description ??
            'Unknown native error (code: $nativeCode)';

  @override
  String toString() => 'BicubicResizeException: $message (code: $nativeCode)';
}

/// Available bicubic filter types
enum BicubicFilter {
  /// Catmull-Rom spline (same as OpenCV INTER_CUBIC, PIL BICUBIC)
  /// Best for ML preprocessing. Default.
  catmullRom(0),

  /// Cubic B-Spline (smoother, more blurry)
  cubicBSpline(1),

  /// Mitchell-Netravali (balanced between sharp and smooth)
  mitchell(2);

  final int value;
  const BicubicFilter(this.value);
}

/// Edge handling modes for resize operations
enum EdgeMode {
  /// Repeat edge pixels (default)
  clamp(0),

  /// Wrap around (tile/repeat image)
  wrap(1),

  /// Mirror reflection at edges
  reflect(2),

  /// Black/transparent pixels outside bounds
  zero(3);

  final int value;
  const EdgeMode(this.value);
}

/// Crop anchor positions
enum CropAnchor {
  /// Center of the image (default)
  center(0),

  /// Top-left corner
  topLeft(1),

  /// Top center
  topCenter(2),

  /// Top-right corner
  topRight(3),

  /// Center left
  centerLeft(4),

  /// Center right
  centerRight(5),

  /// Bottom-left corner
  bottomLeft(6),

  /// Bottom center
  bottomCenter(7),

  /// Bottom-right corner
  bottomRight(8);

  final int value;
  const CropAnchor(this.value);
}

/// Crop aspect ratio modes
enum CropAspectRatio {
  /// 1:1 square crop (default) - crops to the largest square that fits
  square(0),

  /// Keep original aspect ratio - scales proportionally
  original(1),

  /// Custom aspect ratio - use [aspectRatioWidth] and [aspectRatioHeight]
  custom(2);

  final int value;
  const CropAspectRatio(this.value);
}

// ============================================================================
// Helper: throw if native result indicates error
// ============================================================================

/// Maps a native return code to a [BicubicResizeException] and throws it.
///
/// Does nothing if [result] is 0 (success).
void _throwIfError(int result) {
  if (result != 0) {
    throw BicubicResizeException(result);
  }
}

class BicubicResizer {
  // ============================================================================
  // Raw pixel resize (sync)
  // ============================================================================

  /// Resize raw RGB bytes using bicubic interpolation
  ///
  /// [input] - Raw RGB pixel data (3 bytes per pixel)
  /// [inputWidth] - Width of input image in pixels
  /// [inputHeight] - Height of input image in pixels
  /// [outputWidth] - Desired output width
  /// [outputHeight] - Desired output height
  /// [filter] - Bicubic filter type (default: Catmull-Rom)
  /// [edgeMode] - How to handle pixels outside image bounds (default: clamp)
  /// [crop] - Crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
  /// [cropAnchor] - Position to anchor the crop (default: center)
  /// [cropAspectRatio] - Aspect ratio mode for crop (default: square)
  /// [aspectRatioWidth] - Custom aspect ratio width (only used with CropAspectRatio.custom)
  /// [aspectRatioHeight] - Custom aspect ratio height (only used with CropAspectRatio.custom)
  ///
  /// Returns resized RGB pixel data
  static Uint8List resizeRgb({
    required Uint8List input,
    required int inputWidth,
    required int inputHeight,
    required int outputWidth,
    required int outputHeight,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
  }) {
    final expectedInputSize = inputWidth * inputHeight * 3;
    if (input.length != expectedInputSize) {
      throw ArgumentError(
        'Input size mismatch: expected $expectedInputSize bytes, got ${input.length}',
      );
    }

    final outputSize = outputWidth * outputHeight * 3;
    final inputPtr = calloc<Uint8>(input.length);
    final outputPtr = calloc<Uint8>(outputSize);

    try {
      inputPtr.asTypedList(input.length).setAll(0, input);

      final result = NativeBindings.instance.bicubicResizeRgb(
        inputPtr,
        inputWidth,
        inputHeight,
        outputPtr,
        outputWidth,
        outputHeight,
        filter.value,
        edgeMode.value,
        crop,
        cropAnchor.value,
        cropAspectRatio.value,
        aspectRatioWidth,
        aspectRatioHeight,
      );

      _throwIfError(result);

      return Uint8List.fromList(outputPtr.asTypedList(outputSize));
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
    }
  }

  /// Resize raw RGBA bytes using bicubic interpolation
  ///
  /// [input] - Raw RGBA pixel data (4 bytes per pixel)
  /// [inputWidth] - Width of input image in pixels
  /// [inputHeight] - Height of input image in pixels
  /// [outputWidth] - Desired output width
  /// [outputHeight] - Desired output height
  /// [filter] - Bicubic filter type (default: Catmull-Rom)
  /// [edgeMode] - How to handle pixels outside image bounds (default: clamp)
  /// [crop] - Crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
  /// [cropAnchor] - Position to anchor the crop (default: center)
  /// [cropAspectRatio] - Aspect ratio mode for crop (default: square)
  /// [aspectRatioWidth] - Custom aspect ratio width (only used with CropAspectRatio.custom)
  /// [aspectRatioHeight] - Custom aspect ratio height (only used with CropAspectRatio.custom)
  ///
  /// Returns resized RGBA pixel data
  static Uint8List resizeRgba({
    required Uint8List input,
    required int inputWidth,
    required int inputHeight,
    required int outputWidth,
    required int outputHeight,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
  }) {
    final expectedInputSize = inputWidth * inputHeight * 4;
    if (input.length != expectedInputSize) {
      throw ArgumentError(
        'Input size mismatch: expected $expectedInputSize bytes, got ${input.length}',
      );
    }

    final outputSize = outputWidth * outputHeight * 4;
    final inputPtr = calloc<Uint8>(input.length);
    final outputPtr = calloc<Uint8>(outputSize);

    try {
      inputPtr.asTypedList(input.length).setAll(0, input);

      final result = NativeBindings.instance.bicubicResizeRgba(
        inputPtr,
        inputWidth,
        inputHeight,
        outputPtr,
        outputWidth,
        outputHeight,
        filter.value,
        edgeMode.value,
        crop,
        cropAnchor.value,
        cropAspectRatio.value,
        aspectRatioWidth,
        aspectRatioHeight,
      );

      _throwIfError(result);

      return Uint8List.fromList(outputPtr.asTypedList(outputSize));
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
    }
  }

  // ============================================================================
  // JPEG resize (full native pipeline)
  // ============================================================================

  /// Resize JPEG image bytes using bicubic interpolation
  ///
  /// Entire pipeline (decode -> resize -> encode) runs in native C code.
  /// This is synchronous but very fast due to native performance.
  ///
  /// [jpegBytes] - JPEG encoded image data
  /// [outputWidth] - Desired output width
  /// [outputHeight] - Desired output height
  /// [quality] - JPEG output quality (1-100, default 95)
  /// [filter] - Bicubic filter type (default: Catmull-Rom)
  /// [edgeMode] - How to handle pixels outside image bounds (default: clamp)
  /// [crop] - Crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
  /// [cropAnchor] - Position to anchor the crop (default: center)
  /// [cropAspectRatio] - Aspect ratio mode for crop (default: square)
  /// [aspectRatioWidth] - Custom aspect ratio width (only used with CropAspectRatio.custom)
  /// [aspectRatioHeight] - Custom aspect ratio height (only used with CropAspectRatio.custom)
  /// [applyExifOrientation] - Whether to apply EXIF orientation (default: true)
  ///
  /// Returns resized JPEG encoded data
  static Uint8List resizeJpeg({
    required Uint8List jpegBytes,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    final inputPtr = calloc<Uint8>(jpegBytes.length);
    final outputDataPtr = calloc<Pointer<Uint8>>();
    final outputSizePtr = calloc<Int32>();

    try {
      inputPtr.asTypedList(jpegBytes.length).setAll(0, jpegBytes);

      final result = NativeBindings.instance.bicubicResizeJpeg(
        inputPtr,
        jpegBytes.length,
        outputWidth,
        outputHeight,
        quality,
        filter.value,
        edgeMode.value,
        crop,
        cropAnchor.value,
        cropAspectRatio.value,
        aspectRatioWidth,
        aspectRatioHeight,
        applyExifOrientation ? 1 : 0,
        outputDataPtr,
        outputSizePtr,
      );

      _throwIfError(result);

      final outputData = outputDataPtr.value;
      final outputSize = outputSizePtr.value;

      // Copy data before freeing native buffer
      final resultBytes = Uint8List.fromList(
        outputData.asTypedList(outputSize),
      );

      // Free the native-allocated buffer
      NativeBindings.instance.freeBuffer(outputData);

      return resultBytes;
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputDataPtr);
      calloc.free(outputSizePtr);
    }
  }

  // ============================================================================
  // PNG resize (full native pipeline)
  // ============================================================================

  /// Resize PNG image bytes using bicubic interpolation
  ///
  /// Entire pipeline (decode -> resize -> encode) runs in native C code.
  /// Preserves alpha channel if present.
  /// This is synchronous but very fast due to native performance.
  ///
  /// [pngBytes] - PNG encoded image data
  /// [outputWidth] - Desired output width
  /// [outputHeight] - Desired output height
  /// [filter] - Bicubic filter type (default: Catmull-Rom)
  /// [edgeMode] - How to handle pixels outside image bounds (default: clamp)
  /// [crop] - Crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
  /// [cropAnchor] - Position to anchor the crop (default: center)
  /// [cropAspectRatio] - Aspect ratio mode for crop (default: square)
  /// [aspectRatioWidth] - Custom aspect ratio width (only used with CropAspectRatio.custom)
  /// [aspectRatioHeight] - Custom aspect ratio height (only used with CropAspectRatio.custom)
  /// [compressionLevel] - PNG compression level (0-9, default 6, 0=none, 9=max)
  ///
  /// Returns resized PNG encoded data
  static Uint8List resizePng({
    required Uint8List pngBytes,
    required int outputWidth,
    required int outputHeight,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    int compressionLevel = 6,
  }) {
    final inputPtr = calloc<Uint8>(pngBytes.length);
    final outputDataPtr = calloc<Pointer<Uint8>>();
    final outputSizePtr = calloc<Int32>();

    try {
      inputPtr.asTypedList(pngBytes.length).setAll(0, pngBytes);

      final result = NativeBindings.instance.bicubicResizePng(
        inputPtr,
        pngBytes.length,
        outputWidth,
        outputHeight,
        filter.value,
        edgeMode.value,
        crop,
        cropAnchor.value,
        cropAspectRatio.value,
        aspectRatioWidth,
        aspectRatioHeight,
        compressionLevel,
        outputDataPtr,
        outputSizePtr,
      );

      _throwIfError(result);

      final outputData = outputDataPtr.value;
      final outputSize = outputSizePtr.value;

      // Copy data before freeing native buffer
      final resultBytes = Uint8List.fromList(
        outputData.asTypedList(outputSize),
      );

      // Free the native-allocated buffer
      NativeBindings.instance.freeBuffer(outputData);

      return resultBytes;
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputDataPtr);
      calloc.free(outputSizePtr);
    }
  }

  // ============================================================================
  // Format detection
  // ============================================================================

  /// Detect the image format from raw bytes.
  ///
  /// Returns the detected [ImageFormat] or `null` if the format is not supported.
  ///
  /// Supported formats: JPEG, PNG
  /// Unsupported formats: HEIC, WebP, GIF, BMP, TIFF, etc.
  ///
  /// [bytes] - Raw image data
  static ImageFormat? detectFormat(Uint8List bytes) {
    if (bytes.length < 4) return null;

    // JPEG: starts with FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return ImageFormat.jpeg;
    }

    // PNG: starts with 89 50 4E 47 (PNG magic number)
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return ImageFormat.png;
    }

    return null;
  }

  // ============================================================================
  // Generic resize (auto-detect format)
  // ============================================================================

  /// Resize image bytes with automatic format detection.
  ///
  /// This method automatically detects whether the input is JPEG or PNG
  /// and calls the appropriate resize method.
  ///
  /// Throws [UnsupportedImageFormatException] if the format is not supported.
  ///
  /// [bytes] - Image data (JPEG or PNG)
  /// [outputWidth] - Desired output width
  /// [outputHeight] - Desired output height
  /// [quality] - JPEG output quality (1-100, default 95). Ignored for PNG.
  /// [compressionLevel] - PNG compression level (0-9, default 6). Ignored for JPEG.
  /// [filter] - Bicubic filter type (default: Catmull-Rom)
  /// [edgeMode] - How to handle pixels outside image bounds (default: clamp)
  /// [crop] - Crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
  /// [cropAnchor] - Position to anchor the crop (default: center)
  /// [cropAspectRatio] - Aspect ratio mode for crop (default: square)
  /// [aspectRatioWidth] - Custom aspect ratio width (only used with CropAspectRatio.custom)
  /// [aspectRatioHeight] - Custom aspect ratio height (only used with CropAspectRatio.custom)
  /// [applyExifOrientation] - Whether to apply EXIF orientation for JPEG (default: true)
  ///
  /// Returns resized image data in the same format as input
  static Uint8List resize({
    required Uint8List bytes,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    int compressionLevel = 6,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    final format = detectFormat(bytes);

    if (format == null) {
      throw UnsupportedImageFormatException(bytes: bytes);
    }

    switch (format) {
      case ImageFormat.jpeg:
        return resizeJpeg(
          jpegBytes: bytes,
          outputWidth: outputWidth,
          outputHeight: outputHeight,
          quality: quality,
          filter: filter,
          edgeMode: edgeMode,
          crop: crop,
          cropAnchor: cropAnchor,
          cropAspectRatio: cropAspectRatio,
          aspectRatioWidth: aspectRatioWidth,
          aspectRatioHeight: aspectRatioHeight,
          applyExifOrientation: applyExifOrientation,
        );
      case ImageFormat.png:
        return resizePng(
          pngBytes: bytes,
          outputWidth: outputWidth,
          outputHeight: outputHeight,
          filter: filter,
          edgeMode: edgeMode,
          crop: crop,
          cropAnchor: cropAnchor,
          cropAspectRatio: cropAspectRatio,
          aspectRatioWidth: aspectRatioWidth,
          aspectRatioHeight: aspectRatioHeight,
          compressionLevel: compressionLevel,
        );
    }
  }

  // ============================================================================
  // ML Model Preprocessing
  // ============================================================================

  /// Resize and normalize image for ML model inference.
  ///
  /// This method combines resize with normalization to produce a tensor-ready
  /// Float32List that can be directly fed to ML models.
  ///
  /// [bytes] - Image data (JPEG or PNG)
  /// [outputWidth] - Desired output width (e.g., 224 for many models)
  /// [outputHeight] - Desired output height (e.g., 224 for many models)
  /// [normalization] - Type of normalization to apply (default: none)
  /// [channelOrder] - RGB or BGR channel ordering (default: rgb)
  /// [layout] - Tensor layout HWC or CHW (default: hwc)
  /// [filter] - Bicubic filter type (default: Catmull-Rom)
  /// [edgeMode] - How to handle pixels outside image bounds (default: clamp)
  /// [crop] - Crop factor (0.0-1.0), 1.0 = no crop, 0.5 = 50%
  /// [cropAnchor] - Position to anchor the crop (default: center)
  /// [cropAspectRatio] - Aspect ratio mode for crop (default: square)
  /// [aspectRatioWidth] - Custom aspect ratio width (only used with CropAspectRatio.custom)
  /// [aspectRatioHeight] - Custom aspect ratio height (only used with CropAspectRatio.custom)
  /// [applyExifOrientation] - Whether to apply EXIF orientation for JPEG (default: true)
  /// [meanR], [meanG], [meanB] - Custom mean values per channel (only used with NormalizationType.custom)
  /// [stdR], [stdG], [stdB] - Custom std values per channel (only used with NormalizationType.custom)
  ///
  /// Returns a Float32List ready for ML model input.
  /// - For [NormalizationType.none]: values are 0.0-255.0 (raw pixel values as floats)
  /// - For [NormalizationType.simple]: values are 0.0-1.0
  /// - For [NormalizationType.centered]: values are -1.0-1.0
  /// - For [NormalizationType.imageNet]: normalized using ImageNet mean/std
  /// - For [NormalizationType.custom]: normalized using provided mean/std
  ///
  /// Throws [ArgumentError] if [normalization] is [NormalizationType.custom]
  /// and any of [stdR], [stdG], [stdB] is zero (division by zero).
  static Float32List resizeForModel({
    required Uint8List bytes,
    required int outputWidth,
    required int outputHeight,
    NormalizationType normalization = NormalizationType.none,
    ChannelOrder channelOrder = ChannelOrder.rgb,
    TensorLayout layout = TensorLayout.hwc,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
    // Custom normalization parameters
    double meanR = 0.0,
    double meanG = 0.0,
    double meanB = 0.0,
    double stdR = 1.0,
    double stdG = 1.0,
    double stdB = 1.0,
  }) {
    // Validate custom normalization std values
    if (normalization == NormalizationType.custom) {
      if (stdR == 0.0) {
        throw ArgumentError.value(stdR, 'stdR', 'must not be zero');
      }
      if (stdG == 0.0) {
        throw ArgumentError.value(stdG, 'stdG', 'must not be zero');
      }
      if (stdB == 0.0) {
        throw ArgumentError.value(stdB, 'stdB', 'must not be zero');
      }
    }

    // First, get the raw RGB pixels using existing resize pipeline
    final Uint8List rgbBytes = _resizeToRgb(
      bytes: bytes,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      filter: filter,
      edgeMode: edgeMode,
      crop: crop,
      cropAnchor: cropAnchor,
      cropAspectRatio: cropAspectRatio,
      aspectRatioWidth: aspectRatioWidth,
      aspectRatioHeight: aspectRatioHeight,
      applyExifOrientation: applyExifOrientation,
    );

    // Pre-compute scale and offset for optimized normalization
    // Formula: output = pixel * scale + offset
    // This avoids divisions in the hot loop
    double scaleR, scaleG, scaleB;
    double offsetR, offsetG, offsetB;

    switch (normalization) {
      case NormalizationType.none:
        // No normalization - raw pixel values as float
        scaleR = scaleG = scaleB = 1.0;
        offsetR = offsetG = offsetB = 0.0;
        break;
      case NormalizationType.simple:
        // pixel / 255.0 -> [0, 1]
        scaleR = scaleG = scaleB = 1.0 / 255.0;
        offsetR = offsetG = offsetB = 0.0;
        break;
      case NormalizationType.centered:
        // (pixel / 127.5) - 1.0 -> [-1, 1]
        scaleR = scaleG = scaleB = 1.0 / 127.5;
        offsetR = offsetG = offsetB = -1.0;
        break;
      case NormalizationType.imageNet:
        // ImageNet: (pixel/255 - mean) / std = pixel * (1/(255*std)) - mean/std
        const double imgMeanR = 0.485, imgMeanG = 0.456, imgMeanB = 0.406;
        const double imgStdR = 0.229, imgStdG = 0.224, imgStdB = 0.225;
        scaleR = 1.0 / (255.0 * imgStdR);
        scaleG = 1.0 / (255.0 * imgStdG);
        scaleB = 1.0 / (255.0 * imgStdB);
        offsetR = -imgMeanR / imgStdR;
        offsetG = -imgMeanG / imgStdG;
        offsetB = -imgMeanB / imgStdB;
        break;
      case NormalizationType.custom:
        // Custom: (pixel/255 - mean) / std = pixel * (1/(255*std)) - mean/std
        scaleR = 1.0 / (255.0 * stdR);
        scaleG = 1.0 / (255.0 * stdG);
        scaleB = 1.0 / (255.0 * stdB);
        offsetR = -meanR / stdR;
        offsetG = -meanG / stdG;
        offsetB = -meanB / stdB;
        break;
    }

    // Allocate output buffer
    final int pixelCount = outputWidth * outputHeight;
    final Float32List output = Float32List(pixelCount * 3);
    final bool isBgr = channelOrder == ChannelOrder.bgr;

    // Process pixels - branch outside loop for performance
    if (layout == TensorLayout.hwc) {
      // HWC layout: [height, width, channels] - interleaved
      if (isBgr) {
        for (int i = 0; i < pixelCount; i++) {
          final int srcIdx = i * 3;
          final int dstIdx = i * 3;
          output[dstIdx] = rgbBytes[srcIdx + 2] * scaleB + offsetB;
          output[dstIdx + 1] = rgbBytes[srcIdx + 1] * scaleG + offsetG;
          output[dstIdx + 2] = rgbBytes[srcIdx] * scaleR + offsetR;
        }
      } else {
        for (int i = 0; i < pixelCount; i++) {
          final int srcIdx = i * 3;
          final int dstIdx = i * 3;
          output[dstIdx] = rgbBytes[srcIdx] * scaleR + offsetR;
          output[dstIdx + 1] = rgbBytes[srcIdx + 1] * scaleG + offsetG;
          output[dstIdx + 2] = rgbBytes[srcIdx + 2] * scaleB + offsetB;
        }
      }
    } else {
      // CHW layout: [channels, height, width] - planar
      final int plane1 = pixelCount;
      final int plane2 = pixelCount * 2;

      if (isBgr) {
        for (int i = 0; i < pixelCount; i++) {
          final int srcIdx = i * 3;
          output[i] = rgbBytes[srcIdx + 2] * scaleB + offsetB;
          output[plane1 + i] = rgbBytes[srcIdx + 1] * scaleG + offsetG;
          output[plane2 + i] = rgbBytes[srcIdx] * scaleR + offsetR;
        }
      } else {
        for (int i = 0; i < pixelCount; i++) {
          final int srcIdx = i * 3;
          output[i] = rgbBytes[srcIdx] * scaleR + offsetR;
          output[plane1 + i] = rgbBytes[srcIdx + 1] * scaleG + offsetG;
          output[plane2 + i] = rgbBytes[srcIdx + 2] * scaleB + offsetB;
        }
      }
    }

    return output;
  }

  /// Internal method to decode and resize image to raw RGB bytes.
  static Uint8List _resizeToRgb({
    required Uint8List bytes,
    required int outputWidth,
    required int outputHeight,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    final format = detectFormat(bytes);

    if (format == null) {
      throw UnsupportedImageFormatException(bytes: bytes);
    }

    final inputPtr = calloc<Uint8>(bytes.length);
    final outputDataPtr = calloc<Pointer<Uint8>>();
    final outputSizePtr = calloc<Int32>();

    try {
      inputPtr.asTypedList(bytes.length).setAll(0, bytes);

      // Use native pipeline to decode, apply EXIF, crop, and resize
      // Output raw RGB instead of re-encoding
      final result = NativeBindings.instance.bicubicResizeToRgb(
        inputPtr,
        bytes.length,
        outputWidth,
        outputHeight,
        filter.value,
        edgeMode.value,
        crop,
        cropAnchor.value,
        cropAspectRatio.value,
        aspectRatioWidth,
        aspectRatioHeight,
        format == ImageFormat.jpeg && applyExifOrientation ? 1 : 0,
        format == ImageFormat.jpeg ? 1 : 0, // isJpeg flag
        outputDataPtr,
        outputSizePtr,
      );

      _throwIfError(result);

      final outputData = outputDataPtr.value;
      final outputSize = outputSizePtr.value;

      // Copy data before freeing native buffer
      final resultBytes = Uint8List.fromList(
        outputData.asTypedList(outputSize),
      );

      // Free the native-allocated buffer
      NativeBindings.instance.freeBuffer(outputData);

      return resultBytes;
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputDataPtr);
      calloc.free(outputSizePtr);
    }
  }

  // ============================================================================
  // Image info (lightweight - no full pixel decode)
  // ============================================================================

  /// Get image dimensions, format and EXIF orientation without decoding pixels.
  ///
  /// This is a lightweight operation that only reads image headers,
  /// making it much faster than a full decode when you only need metadata.
  ///
  /// [bytes] - Image data (JPEG or PNG)
  ///
  /// Returns [BicubicImageInfo] with dimensions, channels, format and EXIF orientation.
  ///
  /// Throws [UnsupportedImageFormatException] if the format is not JPEG or PNG.
  /// Throws [BicubicResizeException] if headers cannot be parsed.
  static BicubicImageInfo getImageInfo(Uint8List bytes) {
    final inputPtr = calloc<Uint8>(bytes.length);
    final widthPtr = calloc<Int32>();
    final heightPtr = calloc<Int32>();
    final channelsPtr = calloc<Int32>();
    final formatPtr = calloc<Int32>();
    final orientationPtr = calloc<Int32>();

    try {
      inputPtr.asTypedList(bytes.length).setAll(0, bytes);

      final result = NativeBindings.instance.bicubicGetImageInfo(
        inputPtr,
        bytes.length,
        widthPtr,
        heightPtr,
        channelsPtr,
        formatPtr,
        orientationPtr,
      );

      if (result == -6) {
        throw UnsupportedImageFormatException(bytes: bytes);
      }
      _throwIfError(result);

      final formatValue = formatPtr.value;
      final ImageFormat format;
      switch (formatValue) {
        case 1:
          format = ImageFormat.jpeg;
          break;
        case 2:
          format = ImageFormat.png;
          break;
        default:
          throw UnsupportedImageFormatException(bytes: bytes);
      }

      return BicubicImageInfo(
        width: widthPtr.value,
        height: heightPtr.value,
        channels: channelsPtr.value,
        format: format,
        exifOrientation: orientationPtr.value,
      );
    } finally {
      calloc.free(inputPtr);
      calloc.free(widthPtr);
      calloc.free(heightPtr);
      calloc.free(channelsPtr);
      calloc.free(formatPtr);
      calloc.free(orientationPtr);
    }
  }

  /// Async version of [getImageInfo]. Runs in a separate isolate.
  static Future<BicubicImageInfo> getImageInfoAsync(Uint8List bytes) {
    return Isolate.run(() => getImageInfo(bytes));
  }

  // ============================================================================
  // File I/O convenience methods
  // ============================================================================

  /// Resize image file and return bytes.
  ///
  /// Reads the file at [inputPath], resizes it, and returns the result.
  /// All resize parameters are the same as [resize].
  ///
  /// [inputPath] - Path to the input image file (JPEG or PNG)
  ///
  /// Returns resized image data in the same format as input.
  static Uint8List resizeFile({
    required String inputPath,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    int compressionLevel = 6,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    final bytes = File(inputPath).readAsBytesSync();
    return resize(
      bytes: bytes,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      quality: quality,
      compressionLevel: compressionLevel,
      filter: filter,
      edgeMode: edgeMode,
      crop: crop,
      cropAnchor: cropAnchor,
      cropAspectRatio: cropAspectRatio,
      aspectRatioWidth: aspectRatioWidth,
      aspectRatioHeight: aspectRatioHeight,
      applyExifOrientation: applyExifOrientation,
    );
  }

  /// Resize image file and save to output path.
  ///
  /// Reads the file at [inputPath], resizes it, and writes the result to [outputPath].
  ///
  /// [inputPath] - Path to the input image file (JPEG or PNG)
  /// [outputPath] - Path where the resized image will be saved
  static void resizeFileToFile({
    required String inputPath,
    required String outputPath,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    int compressionLevel = 6,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    final result = resizeFile(
      inputPath: inputPath,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      quality: quality,
      compressionLevel: compressionLevel,
      filter: filter,
      edgeMode: edgeMode,
      crop: crop,
      cropAnchor: cropAnchor,
      cropAspectRatio: cropAspectRatio,
      aspectRatioWidth: aspectRatioWidth,
      aspectRatioHeight: aspectRatioHeight,
      applyExifOrientation: applyExifOrientation,
    );
    File(outputPath).writeAsBytesSync(result);
  }

  /// Async version of [resizeFile]. Runs in a separate isolate.
  static Future<Uint8List> resizeFileAsync({
    required String inputPath,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    int compressionLevel = 6,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    return Isolate.run(
      () => resizeFile(
        inputPath: inputPath,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        quality: quality,
        compressionLevel: compressionLevel,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
        applyExifOrientation: applyExifOrientation,
      ),
    );
  }

  /// Async version of [resizeFileToFile]. Runs in a separate isolate.
  static Future<void> resizeFileToFileAsync({
    required String inputPath,
    required String outputPath,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    int compressionLevel = 6,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    return Isolate.run(
      () => resizeFileToFile(
        inputPath: inputPath,
        outputPath: outputPath,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        quality: quality,
        compressionLevel: compressionLevel,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
        applyExifOrientation: applyExifOrientation,
      ),
    );
  }

  // ============================================================================
  // Format conversion (JPEG <-> PNG, no resize)
  // ============================================================================

  /// Convert JPEG to PNG without resizing.
  ///
  /// [jpegBytes] - JPEG encoded image data
  /// [compressionLevel] - PNG compression level (0-9, default 6)
  /// [applyExifOrientation] - Whether to apply EXIF orientation (default: true)
  ///
  /// Returns PNG encoded data.
  static Uint8List jpegToPng({
    required Uint8List jpegBytes,
    int compressionLevel = 6,
    bool applyExifOrientation = true,
  }) {
    final inputPtr = calloc<Uint8>(jpegBytes.length);
    final outputDataPtr = calloc<Pointer<Uint8>>();
    final outputSizePtr = calloc<Int32>();

    try {
      inputPtr.asTypedList(jpegBytes.length).setAll(0, jpegBytes);

      final result = NativeBindings.instance.bicubicJpegToPng(
        inputPtr,
        jpegBytes.length,
        compressionLevel,
        applyExifOrientation ? 1 : 0,
        outputDataPtr,
        outputSizePtr,
      );

      _throwIfError(result);

      final outputData = outputDataPtr.value;
      final outputSize = outputSizePtr.value;

      final resultBytes = Uint8List.fromList(
        outputData.asTypedList(outputSize),
      );

      NativeBindings.instance.freeBuffer(outputData);

      return resultBytes;
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputDataPtr);
      calloc.free(outputSizePtr);
    }
  }

  /// Convert PNG to JPEG without resizing.
  ///
  /// [pngBytes] - PNG encoded image data
  /// [quality] - JPEG output quality (1-100, default 95)
  ///
  /// Returns JPEG encoded data.
  /// Note: Alpha channel is discarded during conversion.
  static Uint8List pngToJpeg({
    required Uint8List pngBytes,
    int quality = 95,
  }) {
    final inputPtr = calloc<Uint8>(pngBytes.length);
    final outputDataPtr = calloc<Pointer<Uint8>>();
    final outputSizePtr = calloc<Int32>();

    try {
      inputPtr.asTypedList(pngBytes.length).setAll(0, pngBytes);

      final result = NativeBindings.instance.bicubicPngToJpeg(
        inputPtr,
        pngBytes.length,
        quality,
        outputDataPtr,
        outputSizePtr,
      );

      _throwIfError(result);

      final outputData = outputDataPtr.value;
      final outputSize = outputSizePtr.value;

      final resultBytes = Uint8List.fromList(
        outputData.asTypedList(outputSize),
      );

      NativeBindings.instance.freeBuffer(outputData);

      return resultBytes;
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputDataPtr);
      calloc.free(outputSizePtr);
    }
  }

  /// Convert between JPEG and PNG formats (auto-detect input).
  ///
  /// [bytes] - Image data (JPEG or PNG)
  /// [targetFormat] - Desired output format
  /// [quality] - JPEG quality (1-100, default 95). Used when target is JPEG.
  /// [compressionLevel] - PNG compression (0-9, default 6). Used when target is PNG.
  /// [applyExifOrientation] - Whether to apply EXIF orientation (default: true). JPEG input only.
  ///
  /// Returns converted image data. If input already matches [targetFormat],
  /// the original bytes are returned unchanged.
  static Uint8List convertFormat({
    required Uint8List bytes,
    required ImageFormat targetFormat,
    int quality = 95,
    int compressionLevel = 6,
    bool applyExifOrientation = true,
  }) {
    final sourceFormat = detectFormat(bytes);
    if (sourceFormat == null) {
      throw UnsupportedImageFormatException(bytes: bytes);
    }

    if (sourceFormat == targetFormat) {
      return bytes;
    }

    switch (targetFormat) {
      case ImageFormat.png:
        return jpegToPng(
          jpegBytes: bytes,
          compressionLevel: compressionLevel,
          applyExifOrientation: applyExifOrientation,
        );
      case ImageFormat.jpeg:
        return pngToJpeg(
          pngBytes: bytes,
          quality: quality,
        );
    }
  }

  /// Async version of [jpegToPng]. Runs in a separate isolate.
  static Future<Uint8List> jpegToPngAsync({
    required Uint8List jpegBytes,
    int compressionLevel = 6,
    bool applyExifOrientation = true,
  }) {
    return Isolate.run(
      () => jpegToPng(
        jpegBytes: jpegBytes,
        compressionLevel: compressionLevel,
        applyExifOrientation: applyExifOrientation,
      ),
    );
  }

  /// Async version of [pngToJpeg]. Runs in a separate isolate.
  static Future<Uint8List> pngToJpegAsync({
    required Uint8List pngBytes,
    int quality = 95,
  }) {
    return Isolate.run(
      () => pngToJpeg(pngBytes: pngBytes, quality: quality),
    );
  }

  /// Async version of [convertFormat]. Runs in a separate isolate.
  static Future<Uint8List> convertFormatAsync({
    required Uint8List bytes,
    required ImageFormat targetFormat,
    int quality = 95,
    int compressionLevel = 6,
    bool applyExifOrientation = true,
  }) {
    return Isolate.run(
      () => convertFormat(
        bytes: bytes,
        targetFormat: targetFormat,
        quality: quality,
        compressionLevel: compressionLevel,
        applyExifOrientation: applyExifOrientation,
      ),
    );
  }

  // ============================================================================
  // Async wrappers (run in isolate to avoid blocking UI thread)
  // ============================================================================

  /// Async version of [resizeRgb]. Runs in a separate isolate.
  static Future<Uint8List> resizeRgbAsync({
    required Uint8List input,
    required int inputWidth,
    required int inputHeight,
    required int outputWidth,
    required int outputHeight,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
  }) {
    return Isolate.run(
      () => resizeRgb(
        input: input,
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
      ),
    );
  }

  /// Async version of [resizeRgba]. Runs in a separate isolate.
  static Future<Uint8List> resizeRgbaAsync({
    required Uint8List input,
    required int inputWidth,
    required int inputHeight,
    required int outputWidth,
    required int outputHeight,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
  }) {
    return Isolate.run(
      () => resizeRgba(
        input: input,
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
      ),
    );
  }

  /// Async version of [resizeJpeg]. Runs in a separate isolate.
  static Future<Uint8List> resizeJpegAsync({
    required Uint8List jpegBytes,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    return Isolate.run(
      () => resizeJpeg(
        jpegBytes: jpegBytes,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        quality: quality,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
        applyExifOrientation: applyExifOrientation,
      ),
    );
  }

  /// Async version of [resizePng]. Runs in a separate isolate.
  static Future<Uint8List> resizePngAsync({
    required Uint8List pngBytes,
    required int outputWidth,
    required int outputHeight,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    int compressionLevel = 6,
  }) {
    return Isolate.run(
      () => resizePng(
        pngBytes: pngBytes,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
        compressionLevel: compressionLevel,
      ),
    );
  }

  /// Async version of [resize]. Runs in a separate isolate.
  static Future<Uint8List> resizeAsync({
    required Uint8List bytes,
    required int outputWidth,
    required int outputHeight,
    int quality = 95,
    int compressionLevel = 6,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
  }) {
    return Isolate.run(
      () => resize(
        bytes: bytes,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        quality: quality,
        compressionLevel: compressionLevel,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
        applyExifOrientation: applyExifOrientation,
      ),
    );
  }

  /// Async version of [resizeForModel]. Runs in a separate isolate.
  static Future<Float32List> resizeForModelAsync({
    required Uint8List bytes,
    required int outputWidth,
    required int outputHeight,
    NormalizationType normalization = NormalizationType.none,
    ChannelOrder channelOrder = ChannelOrder.rgb,
    TensorLayout layout = TensorLayout.hwc,
    BicubicFilter filter = BicubicFilter.catmullRom,
    EdgeMode edgeMode = EdgeMode.clamp,
    double crop = 1.0,
    CropAnchor cropAnchor = CropAnchor.center,
    CropAspectRatio cropAspectRatio = CropAspectRatio.square,
    double aspectRatioWidth = 1.0,
    double aspectRatioHeight = 1.0,
    bool applyExifOrientation = true,
    double meanR = 0.0,
    double meanG = 0.0,
    double meanB = 0.0,
    double stdR = 1.0,
    double stdG = 1.0,
    double stdB = 1.0,
  }) {
    return Isolate.run(
      () => resizeForModel(
        bytes: bytes,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        normalization: normalization,
        channelOrder: channelOrder,
        layout: layout,
        filter: filter,
        edgeMode: edgeMode,
        crop: crop,
        cropAnchor: cropAnchor,
        cropAspectRatio: cropAspectRatio,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
        applyExifOrientation: applyExifOrientation,
        meanR: meanR,
        meanG: meanG,
        meanB: meanB,
        stdR: stdR,
        stdG: stdG,
        stdB: stdB,
      ),
    );
  }
}
