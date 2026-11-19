import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../data/repositories.dart';
import 'utils.dart';

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
}) async {
  final error = projectMediaError(file);
  if (error != null) throw FormatException(error);
  final extension = fileExtension(file.name);
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
  final stored = await repository.uploadBytes(
    userId: ownerId,
    fileName: '${newId()}.$extension',
    bytes: buffer.takeBytes(),
    contentType: types[extension]!,
  );
  // The bucket is private. Never persist getPublicUrl() for these uploads.
  return stored.storagePath;
}
