import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../data/repositories.dart';
import 'utils.dart';
import 'optimized_image.dart';

bool isProjectVideo(String source) => allowedVideoExtensions.contains(
  fileExtension(Uri.tryParse(source)?.path ?? source),
);

String? projectMediaError(PlatformFile file) {
  final extension = fileExtension(file.name);
  final video = allowedVideoExtensions.contains(extension);
  if (!video && !allowedImageExtensions.contains(extension)) {
    return 'Choose a JPG, PNG, WebP image or MP4, MOV, WebM video.';
  }
  final limit = video ? maxVideoBytes : maxImageBytes;
  final size = file.lengthSync();
  if (size != null && (size <= 0 || size > limit)) {
    return video
        ? 'Video must be between 1 byte and 100 MB.'
        : 'Image must be between 1 byte and 10 MB.';
  }
  return null;
}

/// Upload only on Save, through the same owner-scoped media repository.
Future<String> uploadProjectMedia({
  required PlatformFile file,
  required MediaRepository repository,
  required String ownerId,
  bool avatar = false,
}) async {
  final error = projectMediaError(file);
  if (error != null) throw FormatException(error);
  final extension = fileExtension(file.name);
  if (avatar && !allowedImageExtensions.contains(extension)) {
    throw const FormatException('Choose a JPG, PNG or WebP image.');
  }
  final limit = isProjectVideo(file.name) ? maxVideoBytes : maxImageBytes;
  final buffer = BytesBuilder(copy: false);
  await for (final chunk in file.readAsByteStream()) {
    if (buffer.length + chunk.length > limit) {
      throw const FormatException('The selected file is too large.');
    }
    buffer.add(chunk);
  }
  if (buffer.length == 0 || buffer.length > limit) {
    throw const FormatException('The selected file is empty or too large.');
  }
  const types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };
  var bytes = buffer.takeBytes();
  var uploadExtension = extension;
  var contentType = types[extension]!;
  if (!isProjectVideo(file.name)) {
    final optimized = await optimizeUploadImage(bytes, avatar: avatar);
    if (avatar && optimized == null) {
      throw const FormatException(
        'Could not read this image. Choose another photo.',
      );
    }
    if (optimized != null &&
        (avatar ||
            optimized.resized ||
            optimized.bytes.length < bytes.length ||
            bytes.length > 1024 * 1024)) {
      bytes = optimized.bytes;
      uploadExtension = optimized.extension;
      contentType = optimized.contentType;
    }
  }
  final stored = await repository.uploadBytes(
    userId: ownerId,
    fileName: '${newId()}.$uploadExtension',
    bytes: bytes,
    contentType: contentType,
  );
  // The bucket is private. Never persist getPublicUrl() for these uploads.
  return stored.storagePath;
}
