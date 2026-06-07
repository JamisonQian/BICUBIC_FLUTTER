#if __has_include(<FlutterMacOS/FlutterMacOS.h>)
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif
#import "resize.h"

// FFI plugin: there is no method channel. This class exists only so that a
// compiled translation unit references the native C symbols, forcing the
// linker to keep them in the final app binary (same trick as the former
// Swift registrant). The C functions are declared in resize.h / resize.c.
@interface FlutterBicubicResizePlugin : NSObject <FlutterPlugin>
+ (void)forceSymbolRetention;
@end

@implementation FlutterBicubicResizePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  // No method channel needed for an FFI plugin.
  [self forceSymbolRetention];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  result(FlutterMethodNotImplemented);
}

// Make real calls to the C functions so the linker cannot strip them as
// "unused". The calls are safe: the zero dimensions make each function return
// early before touching the buffers. Retention is additionally guaranteed by
// __attribute__((used)) on the C exports and DEAD_CODE_STRIPPING=NO.
+ (void)forceSymbolRetention {
  uint8_t dummyInput[1] = {0};
  uint8_t dummyOutput[1] = {0};

  // New API: filter, edge_mode, crop, crop_anchor, aspect_mode, aspect_w, aspect_h
  (void)bicubic_resize_rgb(dummyInput, 0, 0, dummyOutput, 0, 0, 0, 0, 1.0f, 0, 0, 1.0f, 1.0f);
  (void)bicubic_resize_rgba(dummyInput, 0, 0, dummyOutput, 0, 0, 0, 0, 1.0f, 0, 0, 1.0f, 1.0f);

  uint8_t *outPtr = NULL;
  int outSize = 0;
  // JPEG: filter, edge_mode, crop, crop_anchor, aspect_mode, aspect_w, aspect_h, apply_exif
  (void)bicubic_resize_jpeg(dummyInput, 0, 0, 0, 80, 0, 0, 1.0f, 0, 0, 1.0f, 1.0f, 1, &outPtr, &outSize);
  // PNG: filter, edge_mode, crop, crop_anchor, aspect_mode, aspect_w, aspect_h, compression_level
  (void)bicubic_resize_png(dummyInput, 0, 0, 0, 0, 0, 1.0f, 0, 0, 1.0f, 1.0f, 6, &outPtr, &outSize);

  free_buffer(NULL);
}

@end
