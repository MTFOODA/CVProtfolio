import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as im;

/// Validated embedded pictures; storage paths never become public OOXML links.
class DocxImagePart {
  const DocxImagePart(this.id, this.name, this.bytes, this.width, this.height);
  final int id;
  final String name;
  final Uint8List bytes;
  final int width, height;
  String get relationship =>
      '<Relationship Id="rIdImage$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$name"/>';
  String get drawing {
    final scale = math.min(5486400 / width, 3657600 / height);
    final cx = (width * scale).round(), cy = (height * scale).round();
    return '<w:p><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$id" name="Entry image $id"/>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="$name"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="rIdImage$id"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
        '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>';
  }
}

Map<String, DocxImagePart> docxImageParts(Map<String, Uint8List> sources) {
  final result = <String, DocxImagePart>{};
  for (final entry in sources.entries) {
    var bytes = entry.value;
    if (bytes.length < 4 || bytes.length > 8 * 1024 * 1024) continue;
    var extension = bytes[0] == 0x89 && bytes[1] == 0x50
        ? 'png'
        : bytes[0] == 0xff && bytes[1] == 0xd8
        ? 'jpg'
        : bytes[0] == 0x47 && bytes[1] == 0x49
        ? 'gif'
        : null;
    try {
      final image = pw.MemoryImage(bytes);
      final width = image.width ?? 0, height = image.height ?? 0;
      if (width <= 0 || height <= 0 || width * height > 30000000) continue;
      if (extension == null) {
        final decoded = im.decodeImage(bytes);
        if (decoded == null) continue;
        bytes = im.encodePng(decoded);
        extension = 'png';
      }
      final id = result.length + 1;
      result[entry.key] = DocxImagePart(
        id,
        'entry-$id.$extension',
        bytes,
        width,
        height,
      );
    } catch (_) {
      /* Invalid media does not discard the entry's text. */
    }
  }
  return result;
}
