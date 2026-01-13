[![Codigee - Best Flutter Experts](logo.jpeg)](https://umami.team.codigee.com/q/FZ9PQYyYN)

# API Documentation

Complete API reference for `flutter_bicubic_resize`.

## Table of Contents

- [BicubicResizer](#bicubicresizer)
  - [resizeJpeg](#resizejpeg)
  - [resizePng](#resizepng)
  - [resizeRgb](#resizergb)
  - [resizeRgba](#resizergba)
  - [resize](#resize)
  - [resizeForModel](#resizeformodel) ✨ NEW
  - [detectFormat](#detectformat)
- [Enums](#enums)
  - [BicubicFilter](#bicubicfilter)
  - [EdgeMode](#edgemode)
  - [CropAnchor](#cropanchor)
  - [CropAspectRatio](#cropaspectratio)
  - [NormalizationType](#normalizationtype) ✨ NEW
  - [ChannelOrder](#channelorder) ✨ NEW
  - [TensorLayout](#tensorlayout) ✨ NEW
- [ML Preprocessing](#ml-preprocessing) ✨ NEW
- [EXIF Orientation](#exif-orientation)
- [Crop System](#crop-system)
- [Error Handling](#error-handling)
- [Performance Tips](#performance-tips)

---

## BicubicResizer

Main class providing static methods for image resizing.

### resizeJpeg

Resize JPEG image bytes using bicubic interpolation.

```dart
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
})
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `jpegBytes` | `Uint8List` | Yes | - | JPEG encoded image data |
| `outputWidth` | `int` | Yes | - | Desired output width in pixels |
| `outputHeight` | `int` | Yes | - | Desired output height in pixels |
| `quality` | `int` | No | 95 | JPEG output quality (1-100) |
| `filter` | `BicubicFilter` | No | `catmullRom` | Bicubic filter type |
| `edgeMode` | `EdgeMode` | No | `clamp` | How to handle pixels outside image bounds |
| `crop` | `double` | No | 1.0 | Crop factor (0.0-1.0). 1.0 = no crop |
| `cropAnchor` | `CropAnchor` | No | `center` | Position to anchor the crop |
| `cropAspectRatio` | `CropAspectRatio` | No | `square` | Aspect ratio mode for crop |
| `aspectRatioWidth` | `double` | No | 1.0 | Custom aspect ratio width (only with `CropAspectRatio.custom`) |
| `aspectRatioHeight` | `double` | No | 1.0 | Custom aspect ratio height (only with `CropAspectRatio.custom`) |
| `applyExifOrientation` | `bool` | No | `true` | Whether to apply EXIF orientation |

**Returns:** `Uint8List` - Resized JPEG encoded data.

**Example:**

```dart
import 'package:flutter_bicubic_resize/flutter_bicubic_resize.dart';

// Simple resize
final resized = BicubicResizer.resizeJpeg(
  jpegBytes: originalBytes,
  outputWidth: 224,
  outputHeight: 224,
);

// With crop from top-left corner, keeping original aspect ratio
final cropped = BicubicResizer.resizeJpeg(
  jpegBytes: originalBytes,
  outputWidth: 800,
  outputHeight: 600,
  crop: 0.8,
  cropAnchor: CropAnchor.topLeft,
  cropAspectRatio: CropAspectRatio.original,
);

// Custom 16:9 aspect ratio crop
final widescreen = BicubicResizer.resizeJpeg(
  jpegBytes: originalBytes,
  outputWidth: 1920,
  outputHeight: 1080,
  cropAspectRatio: CropAspectRatio.custom,
  aspectRatioWidth: 16.0,
  aspectRatioHeight: 9.0,
);

// Disable EXIF orientation (get raw pixels)
final rawOrientation = BicubicResizer.resizeJpeg(
  jpegBytes: originalBytes,
  outputWidth: 224,
  outputHeight: 224,
  applyExifOrientation: false,
);
```

---

### resizePng

Resize PNG image bytes using bicubic interpolation. Preserves alpha channel if present.

```dart
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
})
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `pngBytes` | `Uint8List` | Yes | - | PNG encoded image data |
| `outputWidth` | `int` | Yes | - | Desired output width in pixels |
| `outputHeight` | `int` | Yes | - | Desired output height in pixels |
| `filter` | `BicubicFilter` | No | `catmullRom` | Bicubic filter type |
| `edgeMode` | `EdgeMode` | No | `clamp` | How to handle pixels outside image bounds |
| `crop` | `double` | No | 1.0 | Crop factor (0.0-1.0). 1.0 = no crop |
| `cropAnchor` | `CropAnchor` | No | `center` | Position to anchor the crop |
| `cropAspectRatio` | `CropAspectRatio` | No | `square` | Aspect ratio mode for crop |
| `aspectRatioWidth` | `double` | No | 1.0 | Custom aspect ratio width (only with `CropAspectRatio.custom`) |
| `aspectRatioHeight` | `double` | No | 1.0 | Custom aspect ratio height (only with `CropAspectRatio.custom`) |
| `compressionLevel` | `int` | No | 6 | PNG compression level (0-9, 0=none, 9=max) |

**Returns:** `Uint8List` - Resized PNG encoded data.

**Example:**

```dart
// Simple resize with maximum compression
final resized = BicubicResizer.resizePng(
  pngBytes: originalBytes,
  outputWidth: 512,
  outputHeight: 512,
  compressionLevel: 9,
);

// Crop from bottom-right with wrap edge mode
final cropped = BicubicResizer.resizePng(
  pngBytes: originalBytes,
  outputWidth: 256,
  outputHeight: 256,
  crop: 0.7,
  cropAnchor: CropAnchor.bottomRight,
  edgeMode: EdgeMode.wrap,
);
```

---

### resizeRgb

Resize raw RGB bytes (3 bytes per pixel) using bicubic interpolation.

```dart
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
})
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input` | `Uint8List` | Yes | - | Raw RGB pixel data (3 bytes per pixel) |
| `inputWidth` | `int` | Yes | - | Width of input image in pixels |
| `inputHeight` | `int` | Yes | - | Height of input image in pixels |
| `outputWidth` | `int` | Yes | - | Desired output width |
| `outputHeight` | `int` | Yes | - | Desired output height |
| `filter` | `BicubicFilter` | No | `catmullRom` | Bicubic filter type |
| `edgeMode` | `EdgeMode` | No | `clamp` | How to handle pixels outside image bounds |
| `crop` | `double` | No | 1.0 | Crop factor (0.0-1.0). 1.0 = no crop |
| `cropAnchor` | `CropAnchor` | No | `center` | Position to anchor the crop |
| `cropAspectRatio` | `CropAspectRatio` | No | `square` | Aspect ratio mode for crop |
| `aspectRatioWidth` | `double` | No | 1.0 | Custom aspect ratio width |
| `aspectRatioHeight` | `double` | No | 1.0 | Custom aspect ratio height |

**Returns:** `Uint8List` - Resized RGB pixel data.

**Throws:** `ArgumentError` if input size doesn't match `inputWidth * inputHeight * 3`.

---

### resizeRgba

Resize raw RGBA bytes (4 bytes per pixel) using bicubic interpolation.

```dart
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
})
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input` | `Uint8List` | Yes | - | Raw RGBA pixel data (4 bytes per pixel) |
| `inputWidth` | `int` | Yes | - | Width of input image in pixels |
| `inputHeight` | `int` | Yes | - | Height of input image in pixels |
| `outputWidth` | `int` | Yes | - | Desired output width |
| `outputHeight` | `int` | Yes | - | Desired output height |
| `filter` | `BicubicFilter` | No | `catmullRom` | Bicubic filter type |
| `edgeMode` | `EdgeMode` | No | `clamp` | How to handle pixels outside image bounds |
| `crop` | `double` | No | 1.0 | Crop factor (0.0-1.0). 1.0 = no crop |
| `cropAnchor` | `CropAnchor` | No | `center` | Position to anchor the crop |
| `cropAspectRatio` | `CropAspectRatio` | No | `square` | Aspect ratio mode for crop |
| `aspectRatioWidth` | `double` | No | 1.0 | Custom aspect ratio width |
| `aspectRatioHeight` | `double` | No | 1.0 | Custom aspect ratio height |

**Returns:** `Uint8List` - Resized RGBA pixel data.

**Throws:** `ArgumentError` if input size doesn't match `inputWidth * inputHeight * 4`.

---

### resize

Generic resize with automatic format detection.

```dart
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
})
```

**Returns:** `Uint8List` - Resized image in the same format as input.

**Throws:** `UnsupportedImageFormatException` if format is not JPEG or PNG.

---

### resizeForModel

Resize and normalize image for ML model inference. Returns `Float32List` ready for TensorFlow Lite, PyTorch, or other ML frameworks.

```dart
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
  // Custom normalization parameters (only with NormalizationType.custom)
  double meanR = 0.0,
  double meanG = 0.0,
  double meanB = 0.0,
  double stdR = 1.0,
  double stdG = 1.0,
  double stdB = 1.0,
})
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `bytes` | `Uint8List` | Yes | - | Image data (JPEG or PNG) |
| `outputWidth` | `int` | Yes | - | Desired output width (e.g., 224) |
| `outputHeight` | `int` | Yes | - | Desired output height (e.g., 224) |
| `normalization` | `NormalizationType` | No | `none` | Type of normalization to apply |
| `channelOrder` | `ChannelOrder` | No | `rgb` | RGB or BGR channel ordering |
| `layout` | `TensorLayout` | No | `hwc` | Tensor layout (HWC or CHW) |
| `meanR/G/B` | `double` | No | 0.0 | Custom mean values per channel |
| `stdR/G/B` | `double` | No | 1.0 | Custom std values per channel |

**Returns:** `Float32List` - Tensor data ready for ML model input.

**Example:**

```dart
// For TensorFlow Lite (ImageNet normalization)
final tensor = BicubicResizer.resizeForModel(
  bytes: imageBytes,
  outputWidth: 224,
  outputHeight: 224,
  normalization: NormalizationType.imageNet,
);

// For MobileNet (centered normalization)
final tensor = BicubicResizer.resizeForModel(
  bytes: imageBytes,
  outputWidth: 224,
  outputHeight: 224,
  normalization: NormalizationType.centered,
);

// For PyTorch (CHW layout, ImageNet normalization)
final tensor = BicubicResizer.resizeForModel(
  bytes: imageBytes,
  outputWidth: 224,
  outputHeight: 224,
  normalization: NormalizationType.imageNet,
  layout: TensorLayout.chw,
);

// Custom normalization
final tensor = BicubicResizer.resizeForModel(
  bytes: imageBytes,
  outputWidth: 224,
  outputHeight: 224,
  normalization: NormalizationType.custom,
  meanR: 0.5, meanG: 0.5, meanB: 0.5,
  stdR: 0.5, stdG: 0.5, stdB: 0.5,
);
```

---

### detectFormat

Detect image format from raw bytes.

```dart
static ImageFormat? detectFormat(Uint8List bytes)
```

**Returns:** `ImageFormat.jpeg`, `ImageFormat.png`, or `null` if unsupported.

---

## Enums

### BicubicFilter

Defines available bicubic filter types.

```dart
enum BicubicFilter {
  catmullRom,   // value: 0
  cubicBSpline, // value: 1
  mitchell,     // value: 2
}
```

| Filter | Description | Use Case |
|--------|-------------|----------|
| `catmullRom` | Catmull-Rom spline. Same as OpenCV `INTER_CUBIC` and PIL `BICUBIC`. | **Default.** Best for ML preprocessing. Produces sharp results. |
| `cubicBSpline` | Cubic B-Spline interpolation. | Smoother, more blurry results. Good for artistic effects. |
| `mitchell` | Mitchell-Netravali filter. | Balanced between sharp and smooth. Good general-purpose filter. |

---

### EdgeMode

Defines how pixels outside the image bounds are handled during resize.

```dart
enum EdgeMode {
  clamp,   // value: 0
  wrap,    // value: 1
  reflect, // value: 2
  zero,    // value: 3
}
```

| Mode | Description | Visual Effect |
|------|-------------|---------------|
| `clamp` | Repeat edge pixels | `[A B C D D D]` - extends last pixel |
| `wrap` | Wrap around (tile) | `[A B C D A B]` - image repeats |
| `reflect` | Mirror reflection | `[A B C D C B]` - mirror at edge |
| `zero` | Black/transparent | `[A B C D 0 0]` - black pixels outside |

**Example:**

```dart
// Create tiled pattern effect
final tiled = BicubicResizer.resizeJpeg(
  jpegBytes: textureBytes,
  outputWidth: 512,
  outputHeight: 512,
  edgeMode: EdgeMode.wrap,
);
```

---

### CropAnchor

Defines the anchor position for cropping.

```dart
enum CropAnchor {
  center,       // value: 0
  topLeft,      // value: 1
  topCenter,    // value: 2
  topRight,     // value: 3
  centerLeft,   // value: 4
  centerRight,  // value: 5
  bottomLeft,   // value: 6
  bottomCenter, // value: 7
  bottomRight,  // value: 8
}
```

**Visual representation:**

```
┌─────────────────┐
│ TL    TC    TR  │
│                 │
│ CL  CENTER  CR  │
│                 │
│ BL    BC    BR  │
└─────────────────┘
```

**Example:**

```dart
// Crop from top of image (good for portraits)
final portrait = BicubicResizer.resizeJpeg(
  jpegBytes: photoBytes,
  outputWidth: 200,
  outputHeight: 200,
  crop: 0.8,
  cropAnchor: CropAnchor.topCenter,
);
```

---

### CropAspectRatio

Defines the aspect ratio mode for cropping.

```dart
enum CropAspectRatio {
  square,   // value: 0
  original, // value: 1
  custom,   // value: 2
}
```

| Mode | Description |
|------|-------------|
| `square` | **Default.** Crops to largest square that fits (1:1 ratio) |
| `original` | Keeps original image aspect ratio |
| `custom` | Uses `aspectRatioWidth` and `aspectRatioHeight` parameters |

**Example:**

```dart
// Keep original proportions
final proportional = BicubicResizer.resizeJpeg(
  jpegBytes: originalBytes,
  outputWidth: 800,
  outputHeight: 600,
  cropAspectRatio: CropAspectRatio.original,
);

// Custom 4:3 aspect ratio
final fourByThree = BicubicResizer.resizeJpeg(
  jpegBytes: originalBytes,
  outputWidth: 800,
  outputHeight: 600,
  cropAspectRatio: CropAspectRatio.custom,
  aspectRatioWidth: 4.0,
  aspectRatioHeight: 3.0,
);
```

---

### NormalizationType

Defines normalization schemes for ML model preprocessing.

```dart
enum NormalizationType {
  none,      // No normalization (default) - raw pixel values 0-255 as float
  simple,    // pixel / 255.0 → [0, 1]
  centered,  // (pixel / 127.5) - 1.0 → [-1, 1]
  imageNet,  // ImageNet mean/std normalization
  custom,    // User-defined mean/std values
}
```

| Type | Formula | Output Range | Use Case |
|------|---------|--------------|----------|
| `none` | `pixel` | [0, 255] | Raw values, backward compatible |
| `simple` | `pixel / 255` | [0, 1] | TensorFlow Lite, basic models |
| `centered` | `(pixel / 127.5) - 1` | [-1, 1] | MobileNet, some TFLite models |
| `imageNet` | `(pixel/255 - mean) / std` | ~[-2.5, 2.5] | ResNet, VGG, EfficientNet |
| `custom` | `(pixel/255 - mean) / std` | varies | Custom trained models |

**ImageNet values:**
- mean: [0.485, 0.456, 0.406]
- std: [0.229, 0.224, 0.225]

---

### ChannelOrder

Defines RGB vs BGR channel ordering.

```dart
enum ChannelOrder {
  rgb,  // Red, Green, Blue (default) - TensorFlow, most models
  bgr,  // Blue, Green, Red - OpenCV, some PyTorch models
}
```

---

### TensorLayout

Defines tensor memory layout.

```dart
enum TensorLayout {
  hwc,  // Height, Width, Channels (default) - TensorFlow/TFLite
  chw,  // Channels, Height, Width - PyTorch
}
```

| Layout | Shape | Memory Order | Framework |
|--------|-------|--------------|-----------|
| `hwc` | [H, W, C] | Interleaved | TensorFlow, TFLite |
| `chw` | [C, H, W] | Planar | PyTorch, ONNX |

---

## ML Preprocessing

The `resizeForModel()` method provides a complete ML preprocessing pipeline:

1. **Decode** - JPEG/PNG to raw pixels
2. **EXIF** - Correct orientation (optional)
3. **Crop** - Flexible anchor and aspect ratio
4. **Resize** - Bicubic interpolation
5. **Normalize** - Scale and shift values
6. **Layout** - HWC or CHW format
7. **Channel order** - RGB or BGR

### Performance

The normalization is optimized using pre-computed scale and offset factors:
- Formula: `output = pixel * scale + offset`
- No divisions in the hot loop
- Single pass through all pixels

### Example: Complete TFLite Pipeline

```dart
import 'package:flutter_bicubic_resize/flutter_bicubic_resize.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// Load model
final interpreter = await Interpreter.fromAsset('model.tflite');

// Preprocess image
final Float32List tensor = BicubicResizer.resizeForModel(
  bytes: imageBytes,
  outputWidth: 224,
  outputHeight: 224,
  normalization: NormalizationType.imageNet,
  layout: TensorLayout.hwc,
);

// Run inference
final input = tensor.reshape([1, 224, 224, 3]);
final output = List.filled(1000, 0.0).reshape([1, 1000]);
interpreter.run(input, output);
```

### Example: PyTorch Mobile

```dart
// PyTorch typically uses CHW layout
final Float32List tensor = BicubicResizer.resizeForModel(
  bytes: imageBytes,
  outputWidth: 224,
  outputHeight: 224,
  normalization: NormalizationType.imageNet,
  layout: TensorLayout.chw,  // PyTorch format
);
```

---

## EXIF Orientation

For JPEG images, `resizeJpeg` can automatically read and apply EXIF orientation metadata. This ensures that photos taken with mobile devices are displayed correctly.

**Supported orientations:**

| Value | Transformation |
|-------|----------------|
| 1 | Normal (no transformation) |
| 2 | Flip horizontal |
| 3 | Rotate 180 degrees |
| 4 | Flip vertical |
| 5 | Transpose (rotate 90 degrees CW + flip horizontal) |
| 6 | Rotate 90 degrees clockwise |
| 7 | Transverse (rotate 90 degrees CCW + flip horizontal) |
| 8 | Rotate 90 degrees counter-clockwise |

**Control EXIF behavior:**

```dart
// Default: EXIF orientation is applied
final corrected = BicubicResizer.resizeJpeg(
  jpegBytes: photoBytes,
  outputWidth: 224,
  outputHeight: 224,
);

// Disable EXIF orientation (get raw pixel orientation)
final raw = BicubicResizer.resizeJpeg(
  jpegBytes: photoBytes,
  outputWidth: 224,
  outputHeight: 224,
  applyExifOrientation: false,
);
```

---

## Crop System

The crop system is controlled by three parameters: `crop`, `cropAnchor`, and `cropAspectRatio`.

### How crop factor works

The `crop` parameter (0.0-1.0) determines how much of the image to keep:
- `crop: 1.0` - Use full image (no crop)
- `crop: 0.8` - Use 80% of the image
- `crop: 0.5` - Use 50% of the image

### Aspect ratio behavior

**Square mode (default):**
For an image 1920x1080:
- `crop: 1.0` - crops 1080x1080 square
- `crop: 0.8` - crops 864x864 square (80% of min dimension)

**Original mode:**
For an image 1920x1080:
- `crop: 1.0` - uses full 1920x1080
- `crop: 0.8` - crops 1536x864 (80% of both dimensions)

**Custom mode:**
Crops to the specified aspect ratio that fits within the source.

### Example combinations

```dart
// ML preprocessing: square from center
final ml = BicubicResizer.resizeJpeg(
  jpegBytes: photoBytes,
  outputWidth: 224,
  outputHeight: 224,
  crop: 1.0,  // Max square from center
  cropAnchor: CropAnchor.center,
  cropAspectRatio: CropAspectRatio.square,
);

// Portrait crop: top portion
final portrait = BicubicResizer.resizeJpeg(
  jpegBytes: photoBytes,
  outputWidth: 300,
  outputHeight: 400,
  crop: 0.9,
  cropAnchor: CropAnchor.topCenter,
  cropAspectRatio: CropAspectRatio.custom,
  aspectRatioWidth: 3.0,
  aspectRatioHeight: 4.0,
);

// Thumbnail: keep proportions
final thumb = BicubicResizer.resizeJpeg(
  jpegBytes: photoBytes,
  outputWidth: 150,
  outputHeight: 100,
  cropAspectRatio: CropAspectRatio.original,
);
```

---

## Error Handling

All methods throw exceptions on failure:

| Exception | Cause |
|-----------|-------|
| `ArgumentError` | Input size mismatch for raw pixel methods |
| `Exception` | Native resize operation failed |

**Example:**

```dart
try {
  final resized = BicubicResizer.resizeJpeg(
    jpegBytes: invalidBytes,
    outputWidth: 224,
    outputHeight: 224,
  );
} catch (e) {
  print('Resize failed: $e');
}
```

---

## Performance Tips

1. **Operations are synchronous** - The native C code is very fast, so operations complete quickly without needing async/await.

2. **Memory efficiency** - The entire pipeline (decode -> resize -> encode) runs in native code, minimizing memory overhead.

3. **PNG compression trade-off** - Higher `compressionLevel` (closer to 9) produces smaller files but takes longer. Use 6 (default) for balanced performance.

4. **For batch processing** - Consider using `compute()` to run resizing in an isolate:

```dart
import 'package:flutter/foundation.dart';

Future<Uint8List> resizeInBackground(Uint8List jpegBytes) {
  return compute(
    (bytes) => BicubicResizer.resizeJpeg(
      jpegBytes: bytes,
      outputWidth: 224,
      outputHeight: 224,
    ),
    jpegBytes,
  );
}
```

5. **Choosing output quality** - For JPEG, quality 85-95 provides good balance between file size and visual quality. Use 95+ for archival or when quality is critical.

---

## See Also

- [README](https://github.com/ArcaneArts/flutter_bicubic_resize/blob/main/README.md) - Quick start guide
- [CHANGELOG](https://github.com/ArcaneArts/flutter_bicubic_resize/blob/main/CHANGELOG.md) - Version history
- [Example app](https://github.com/ArcaneArts/flutter_bicubic_resize/tree/main/example) - Working demo application
