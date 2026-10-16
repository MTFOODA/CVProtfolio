/// Hands generated documents to the operating system.
///
/// PDFs delegate to the `printing` plugin so each platform uses its native
/// affordance: a print/preview dialog on desktop, the share sheet on mobile
/// (which includes "Save to Files"), and a direct download on the web.
///
/// DOCX needs a different route on Android. `printing` 5.15.1 hard-codes
/// `application/pdf` in its Android share intent (`PrintingJob.java`), so a
/// `.docx` handed to it is announced to the receiving application with the
/// wrong media type. Android therefore saves the genuine OOXML package through
/// the system document picker, which advertises the type of the `.docx`
/// extension. Every other platform keeps the existing share/save affordance,
/// which resolves the type from the file extension itself.
///
/// No temporary file is written by the application itself, so generated
/// documents never linger on disk: the picker writes the bytes straight to the
/// destination the user chose, and `printing` owns whatever it stages.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

/// The outcome of a delivery attempt.
class DeliveryOutcome {
  const DeliveryOutcome({required this.completed, this.cancelled = false});

  /// `true` when the platform reported success.
  final bool completed;

  /// `true` when the user dismissed the dialog without completing.
  final bool cancelled;

  static const DeliveryOutcome success = DeliveryOutcome(completed: true);
  static const DeliveryOutcome dismissed = DeliveryOutcome(
    completed: false,
    cancelled: true,
  );
  static const DeliveryOutcome failed = DeliveryOutcome(completed: false);
}

/// The media type of an OOXML WordprocessingML document (`.docx`).
///
/// ECMA-376 / ISO 29500 register exactly this type for `.docx`, and it is what
/// a receiving application needs to see in order to treat the file as an
/// editable document rather than an opaque attachment.
const String docxMimeType =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// Saves [bytes] to a file the user names.
///
/// Returns where the bytes landed, or `null` when the user dismissed the picker
/// without saving anything.
typedef SaveFileFn = Future<Uri?> Function({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
});

/// Shares or downloads [bytes]; `false` means the user dismissed the dialog.
typedef SharePdfFn = Future<bool> Function({
  required Uint8List bytes,
  required String filename,
});

/// Platform file delivery for exported documents.
class ExportDelivery {
  const ExportDelivery({
    this.sharePdf = _shareWithPrinting,
    this.saveFile = _saveWithDocumentPicker,
    this.usesDocumentPicker = _usesDocumentPickerOnThisPlatform,
  });

  /// Seam over `Printing.sharePdf`; overridable so tests can assert the exact
  /// payload handed to the platform.
  final SharePdfFn sharePdf;

  /// Seam over `FilePicker.saveFile`; overridable for the same reason.
  final SaveFileFn saveFile;

  /// Whether a DOCX must avoid [share] on this platform.
  ///
  /// `true` on Android, where the underlying share intent advertises every
  /// document it carries as `application/pdf`.
  final bool Function() usesDocumentPicker;

  /// Opens the system preview/print sheet with the real PDF.
  Future<DeliveryOutcome> preview(Uint8List bytes, String fileName) async {
    try {
      final ok = await Printing.layoutPdf(
        name: fileName,
        onLayout: (format) => bytes,
      );
      return ok ? DeliveryOutcome.success : DeliveryOutcome.dismissed;
    } on Object {
      return DeliveryOutcome.failed;
    }
  }

  /// Shares or downloads the PDF.
  ///
  /// On mobile this opens the share sheet, on the web it downloads the file,
  /// and on desktop it offers a save dialog.
  Future<DeliveryOutcome> share(Uint8List bytes, String fileName) async {
    try {
      final ok = await sharePdf(bytes: bytes, filename: fileName);
      return ok ? DeliveryOutcome.success : DeliveryOutcome.dismissed;
    } on Object {
      return DeliveryOutcome.failed;
    }
  }

  /// Delivers a generated OOXML document.
  ///
  /// [bytes] must be the real `.docx` package and [fileName] must keep its
  /// `.docx` extension: Android's document picker derives the media type from
  /// that extension, so a renamed PDF would still be announced as a document.
  /// Nothing is reported as success unless the platform confirmed a save, and
  /// nothing succeeded is deleted by the application afterwards.
  Future<DeliveryOutcome> saveDocument(Uint8List bytes, String fileName) async {
    if (!usesDocumentPicker()) return share(bytes, fileName);
    try {
      final saved = await saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: docxMimeType,
      );
      return saved == null
          ? DeliveryOutcome.dismissed
          : DeliveryOutcome.success;
    } on Object {
      return DeliveryOutcome.failed;
    }
  }
}

/// Shares or downloads [bytes] through the `printing` plugin.
Future<bool> _shareWithPrinting({
  required Uint8List bytes,
  required String filename,
}) => Printing.sharePdf(bytes: bytes, filename: filename);

/// Saves [bytes] where the user chooses, through the system document picker.
Future<Uri?> _saveWithDocumentPicker({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) => FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);

/// `printing`'s Android share intent hard-codes `application/pdf`, so Android
/// delivers DOCX through the document picker instead.
bool _usesDocumentPickerOnThisPlatform() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
