import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

typedef OptimizedImage = ({
  Uint8List bytes,
  String extension,
  String contentType,
  bool resized,
});

/// Bound download bytes and decode memory before an image reaches storage.
Future<OptimizedImage?> optimizeUploadImage(
  Uint8List bytes, {
  bool avatar = false,
}) => compute(_optimize, (bytes, avatar));

OptimizedImage? _optimize((Uint8List, bool) input) {
  final decoder = image.findDecoderForData(input.$1);
  final info = decoder?.startDecode(input.$1);
  if (info == null) return null;
  if (info.width * info.height > 40000000) {
    throw const FormatException(
      'Image dimensions are too large. Choose an image under 40 megapixels.',
    );
  }
  var decoded = decoder!.decodeFrame(0);
  if (decoded == null) return null;
  decoded = image.bakeOrientation(decoded);
  final maxEdge = input.$2 ? 512 : 1600;
  final resized = decoded.width > maxEdge || decoded.height > maxEdge;
  if (resized) {
    decoded = image.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? maxEdge : null,
      height: decoded.height > decoded.width ? maxEdge : null,
      interpolation: image.Interpolation.average,
    );
  }
  // Preserve transparent artwork. Flat PNG artwork can also be smaller than a
  // JPEG, so compare both encodings for PNG inputs instead of increasing bytes.
  final preserveAlpha = decoded.hasAlpha && !input.$2;
  if (input.$2 && decoded.hasAlpha) {
    final opaque = image.Image(width: decoded.width, height: decoded.height);
    image.fill(opaque, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(opaque, decoded);
    decoded = opaque;
  }
  final jpeg = preserveAlpha ? null : image.encodeJpg(decoded, quality: 82);
  final png = preserveAlpha || decoder is image.PngDecoder
      ? image.encodePng(decoded, level: 6)
      : null;
  final usePng = png != null && (jpeg == null || png.length < jpeg.length);
  final optimized = usePng ? png : jpeg!;
  return (
    bytes: optimized,
    extension: usePng ? 'png' : 'jpg',
    contentType: usePng ? 'image/png' : 'image/jpeg',
    resized: resized,
  );
}
