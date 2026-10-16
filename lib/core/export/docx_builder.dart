/// Builds a genuine Office Open XML `.docx` package.
///
/// A `.docx` file is a ZIP archive containing XML parts, so this is constructed
/// directly rather than by renaming another format. The result is fully
/// editable in Word, LibreOffice, Google Docs and Pages.
///
/// Content comes from the same [flattenDocument] reading order the PDF exporter
/// uses, so visibility, ordering and hidden-entry filtering behave identically.
/// Text is written as UTF-8, which means Word performs Arabic shaping and
/// bidirectional layout itself — no pre-shaping is required (or wanted) here.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';

/// Everything needed to build a DOCX.
class DocxBuildRequest {
  const DocxBuildRequest({required this.resolved, this.languageCode = 'en'});

  final ResolvedDocument resolved;
  final String languageCode;
}

/// The WordprocessingML namespace.
const String _w =
    'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

/// The OOXML relationships namespace.
const String _r =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

/// Builds DOCX bytes.
class DocxDocumentBuilder {
  const DocxDocumentBuilder();

  /// Generates the package for [request].
  Uint8List build(DocxBuildRequest request) {
    final resolved = request.resolved;
    final lines = flattenDocument(resolved, languageCode: request.languageCode);
    final rtl = resolved.design.isRtl;

    // Collect hyperlinks first: the relationship ids are referenced inline.
    final links = <String, String>{};
    for (final line in lines) {
      final url = line.url?.trim() ?? '';
      if (url.isEmpty) continue;
      if (!isNavigableUrl(url)) continue;
      links.putIfAbsent(url, () => 'rIdLink${links.length + 1}');
    }

    final body = StringBuffer();
    for (final line in lines) {
      body.write(_paragraph(line, rtl: rtl, links: links));
    }
    body.write(_sectionProperties(resolved));

    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$_w" xmlns:r="$_r">'
        '<w:body>$body</w:body>'
        '</w:document>';

    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes()))
      ..addFile(_file('_rels/.rels', _rootRels()))
      ..addFile(_file('word/document.xml', document))
      ..addFile(_file('word/styles.xml', _styles()))
      ..addFile(_file('word/numbering.xml', _numbering()))
      ..addFile(_file('word/_rels/document.xml.rels', _documentRels(links)));

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}

ArchiveFile _file(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

/// Escapes XML text so user content can never break the document structure.
String escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// `true` for URLs that may be written as an external relationship.
bool isNavigableUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return const {'http', 'https', 'mailto'}.contains(uri.scheme);
}

/// One paragraph, mapped onto the document's heading hierarchy.
String _paragraph(
  DocumentLine line, {
  required bool rtl,
  required Map<String, String> links,
}) {
  final style = switch (line.level) {
    0 => 'Title',
    1 => 'Heading1',
    2 => 'Heading2',
    _ => null,
  };

  final props = StringBuffer();
  if (style != null) props.write('<w:pStyle w:val="$style"/>');
  if (rtl) props.write('<w:bidi/>');
  if (line.isBullet) {
    props.write('<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>');
  }

  final run = _run(line.text, rtl: rtl);
  final url = line.url?.trim() ?? '';
  final relId = links[url];
  final content = relId != null && isNavigableUrl(url)
      ? '<w:hyperlink r:id="$relId">$run</w:hyperlink>'
      : run;

  return '<w:p><w:pPr>$props</w:pPr>$content</w:p>';
}

String _run(String text, {required bool rtl}) =>
    '<w:r><w:rPr>${rtl ? '<w:rtl/>' : ''}</w:rPr>'
    '<w:t xml:space="preserve">${escapeXml(text)}</w:t></w:r>';

/// Page size and margins, taken from the saved design.
String _sectionProperties(ResolvedDocument resolved) {
  final design = resolved.design;
  final (shortSide, longSide) = switch (design.page.pageSize) {
    'letter' => (12240, 15840),
    'legal' => (12240, 20160),
    _ => (11906, 16838),
  };
  final width = design.page.portrait ? shortSide : longSide;
  final height = design.page.portrait ? longSide : shortSide;
  final margin = ((design.spacing.pageMargin + design.spacing.pagePadding) * 20)
      .round();
  return '<w:sectPr><w:pgSz w:w="$width" w:h="$height"/>'
      '<w:pgMar w:top="$margin" w:right="$margin" w:bottom="$margin" '
      'w:left="$margin"/></w:sectPr>';
}

String _contentTypes() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
    '</Types>';

String _rootRels() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '</Relationships>';

String _documentRels(Map<String, String> links) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '<Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>',
  );
  links.forEach((url, id) {
    buffer.write(
      '<Relationship Id="$id" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" '
      'Target="${escapeXml(url)}" TargetMode="External"/>',
    );
  });
  buffer.write('</Relationships>');
  return buffer.toString();
}

/// Minimal but valid style definitions so the headings render as headings and
/// remain navigable in Word's outline view.
String _styles() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:styles xmlns:w="$_w">'
    '<w:docDefaults><w:rPrDefault><w:rPr>'
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>'
    '<w:sz w:val="21"/>'
    '</w:rPr></w:rPrDefault><w:pPrDefault/></w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
    '<w:name w:val="Normal"/></w:style>'
    '<w:style w:type="paragraph" w:styleId="Title">'
    '<w:name w:val="Title"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:after="120"/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="48"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1">'
    '<w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:before="240" w:after="80"/>'
    '<w:outlineLvl w:val="0"/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading2">'
    '<w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:before="160" w:after="60"/>'
    '<w:outlineLvl w:val="1"/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="23"/></w:rPr></w:style>'
    '</w:styles>';

/// A single bullet list definition, referenced by bullet paragraphs.
String _numbering() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:numbering xmlns:w="$_w">'
    '<w:abstractNum w:abstractNumId="0">'
    '<w:multiLevelType w:val="singleLevel"/>'
    '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/>'
    '<w:lvlText w:val="\u2022"/><w:lvlJc w:val="left"/>'
    '<w:pPr><w:ind w:left="360" w:hanging="180"/></w:pPr>'
    '</w:lvl></w:abstractNum>'
    '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
    '</w:numbering>';
