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

import 'docx_images.dart';

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';

import '../design/cv_design_options.dart';
import '../domain/document_models.dart';
import '../render/section_titles.dart';
import '../utils/contact_links.dart';

import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';

/// Everything needed to build a DOCX.
class DocxBuildRequest {
  const DocxBuildRequest({
    required this.resolved,
    this.languageCode = 'en',
    this.fontFiles = const {},
    this.images = const {},
  });

  final ResolvedDocument resolved;
  final String languageCode;
  final Map<String, Uint8List> fontFiles;
  final Map<String, Uint8List> images;
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
    final pictures = docxImageParts({
      for (final line in lines)
        if (line.role == 'customImage' && request.images.containsKey(line.url))
          line.url!: request.images[line.url]!,
    });

    // Collect hyperlinks first: the relationship ids are referenced inline.
    final links = <String, String>{};
    for (final line in lines) {
      if (line.role == 'customImage') continue;
      final url = line.url?.trim() ?? '';
      if (url.isEmpty) continue;
      if (!isNavigableUrl(url)) continue;
      links.putIfAbsent(url, () => 'rIdLink${links.length + 1}');
    }

    final body = StringBuffer();
    final design = resolved.design;
    final contacts = lines.where((l) => l.role == 'contact').toList();
    var contactsWritten = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.role == 'customImage') {
        final picture = pictures[line.url];
        if (picture != null) body.write(picture.drawing);
        continue;
      }
      if (line.role == 'contact') continue;
      if (line.level != 0 &&
          line.role != 'professionalTitle' &&
          !contactsWritten) {
        body.write(_contacts(contacts, design, rtl: rtl, links: links));
        contactsWritten = true;
      }
      if (design.presentation.identityArrangement == 'inline' &&
          line.level == 0 &&
          i + 1 < lines.length &&
          lines[i + 1].role == 'professionalTitle') {
        body.write(_identityLine(line, lines[++i], design, rtl));
      } else if (design.presentation.dateLocationPosition == 'right' &&
          line.level == 2 &&
          i + 1 < lines.length &&
          lines[i + 1].role == 'entryMeta') {
        body.write(_entryRow(line, lines[++i], design, rtl: rtl, links: links));
      } else {
        body.write(_paragraph(line, design: design, rtl: rtl, links: links));
      }
    }
    if (!contactsWritten) {
      body.write(_contacts(contacts, design, rtl: rtl, links: links));
    }
    body.write(_sectionProperties(resolved));

    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$_w" xmlns:r="$_r" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>$body</w:body>'
        '</w:document>';

    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes()))
      ..addFile(_file('_rels/.rels', _rootRels()))
      ..addFile(_file('word/document.xml', document))
      ..addFile(_file('word/styles.xml', _styles(design)))
      ..addFile(_file('word/numbering.xml', _numbering()))
      ..addFile(
        _file(
          'word/_rels/document.xml.rels',
          _documentRels(links).replaceFirst(
            '</Relationships>',
            '${pictures.values.map((p) => p.relationship).join()}</Relationships>',
          ),
        ),
      );

    for (final picture in pictures.values) {
      archive.addFile(
        ArchiveFile(
          'word/media/${picture.name}',
          picture.bytes.length,
          picture.bytes,
        ),
      );
    }
    _embedFonts(archive, request.fontFiles);
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
  required DocumentDesign design,
  String? alignment,
  bool entryCell = false,
  required Map<String, String> links,
}) {
  final style = line.role == 'professionalTitle'
      ? 'ProfessionalTitle'
      : switch (line.level) {
          0 => 'Title',
          1 => 'Heading1',
          2 => 'Heading2',
          _ => null,
        };

  final props = StringBuffer();
  if (style != null) props.write('<w:pStyle w:val="$style"/>');
  if (entryCell) props.write('<w:keepNext/>');
  if (line.isBullet) {
    props.write('<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>');
  }
  if (rtl) props.write('<w:bidi/>');
  if (entryCell) {
    props.write('<w:spacing w:before="0" w:after="0"/>');
  }
  final isHeader =
      line.level == 0 ||
      line.role == 'professionalTitle' ||
      line.role == 'contact';
  final align =
      alignment ??
      (isHeader && design.presentation.headerStyle == 'center'
          ? 'center'
          : rtl
          ? 'right'
          : 'left');
  props.write(
    '<w:jc w:val="${align == 'right' && rtl
        ? 'start'
        : align == 'left' && rtl
        ? 'end'
        : align}"/>',
  );

  final text =
      line.level == 1 &&
          line.isHeading &&
          design.typography.uppercaseSectionTitles
      ? line.text.toUpperCase()
      : line.text;
  final run = line.role == 'contact'
      ? _contactRuns(line, design, rtl)
      : line.boldPrefix != null && text.startsWith(line.boldPrefix!)
      ? _run(line.boldPrefix!, rtl: rtl, bold: true) +
            _run(text.substring(line.boldPrefix!.length), rtl: rtl)
      : _run(text, rtl: rtl);
  final url = line.url?.trim() ?? '';
  final relId = links[url];
  final content = relId != null && isNavigableUrl(url)
      ? '<w:hyperlink r:id="$relId">$run</w:hyperlink>'
      : run;

  return '<w:p><w:pPr>$props</w:pPr>$content</w:p>';
}

String _run(String text, {required bool rtl, bool bold = false}) =>
    '<w:r><w:rPr>${rtl ? '<w:rtl/>' : ''}${bold ? '<w:b/><w:bCs/>' : ''}</w:rPr>'
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
  final horizontal = (design.spacing.resolvedHorizontalMargin * 20).round();
  final vertical = (design.spacing.resolvedVerticalMargin * 20).round();
  return '<w:sectPr><w:pgSz w:w="$width" w:h="$height"/>'
      '<w:pgMar w:top="$vertical" w:right="$horizontal" w:bottom="$vertical" '
      'w:left="$horizontal"/></w:sectPr>';
}

String _contentTypes() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Default Extension="png" ContentType="image/png"/>'
    '<Default Extension="jpg" ContentType="image/jpeg"/>'
    '<Default Extension="gif" ContentType="image/gif"/>'
    '<Default Extension="odttf" ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"/>'
    '<Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>'
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
    '<Relationship Id="rIdFonts" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>'
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
String _fontName(String id) => cvFontNames[id] ?? id;
String _hex(int argb) =>
    (argb & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase();
String _styles(DocumentDesign d) {
  final t = d.typography;
  final s = d.spacing;
  String fonts(String id) =>
      '<w:rFonts w:ascii="${escapeXml(_fontName(id))}" w:hAnsi="${escapeXml(_fontName(id))}" w:cs="Noto Naskh Arabic"/>';
  String size(double pt) =>
      '<w:sz w:val="${(pt * 2).round()}"/><w:szCs w:val="${(pt * 2).round()}"/>';
  String style(
    String id,
    double pt, {
    String? font,
    String extra = '',
    String paragraph = '',
  }) =>
      '<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$id"/><w:basedOn w:val="Normal"/>'
      '<w:pPr><w:keepNext/>$paragraph</w:pPr><w:rPr><w:b/><w:bCs/>${fonts(font ?? t.bodyFont)}${size(pt)}$extra</w:rPr></w:style>';
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="$_w">'
      '<w:docDefaults><w:rPrDefault><w:rPr>${fonts(t.bodyFont)}${size(t.bodyFontSize)}<w:color w:val="${_hex(d.colors.bodyText)}"/>'
      '</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="${(s.paragraphSpacing * 20).round()}" w:line="${(t.bodyLineHeight * 240).round()}" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>'
      '${style('Title', t.headingFontSize * t.headingScale, font: t.resolvedNameFont, extra: '<w:spacing w:val="${(t.headingLetterSpacing * 20).round()}"/>', paragraph: '<w:spacing w:after="${(s.itemSpacing * 10).round()}"/>')}'
      '${style('ProfessionalTitle', t.resolvedProfessionalTitleFontSize)}'
      '${style('Heading1', t.sectionTitleFontSize * t.headingScale, paragraph: '<w:spacing w:before="${(s.sectionSpacing * 20).round()}" w:after="${(s.itemSpacing * 10).round()}"/><w:outlineLvl w:val="0"/>')}'
      '${style('Heading2', t.resolvedEntryHeaderFontSize, paragraph: '<w:spacing w:before="${(s.itemSpacing * 20).round()}"/><w:outlineLvl w:val="1"/>')}'
      '</w:styles>';
}

String _identityLine(
  DocumentLine name,
  DocumentLine title,
  DocumentDesign d,
  bool rtl,
) {
  final size = (d.typography.resolvedProfessionalTitleFontSize * 2).round();
  final body = escapeXml(_fontName(d.typography.bodyFont));
  final align = d.presentation.headerStyle == 'center'
      ? 'center'
      : rtl
      ? 'start'
      : 'left';
  return '<w:p><w:pPr><w:pStyle w:val="Title"/><w:keepNext/>${rtl ? '<w:bidi/>' : ''}<w:jc w:val="$align"/></w:pPr>'
      '${_run(name.text, rtl: rtl)}${_run('  ', rtl: rtl)}'
      '<w:r><w:rPr><w:rFonts w:ascii="$body" w:hAnsi="$body" w:cs="Noto Naskh Arabic"/>'
      '<w:spacing w:val="0"/><w:sz w:val="$size"/><w:szCs w:val="$size"/>${rtl ? '<w:rtl/>' : ''}'
      '</w:rPr><w:t xml:space="preserve">${escapeXml(title.text)}</w:t></w:r></w:p>';
}

String _contactRuns(DocumentLine line, DocumentDesign d, bool rtl) {
  final p = d.presentation;
  final brand = contactBrandCodes[line.contactLabel];
  final code = brand ?? contactIconCodes[line.contactLabel] ?? 0xe157;
  final family = brand == null ? 'Material Icons' : contactBrandFontFamily;
  final size = (p.resolvedContactIconSize(d.typography.bodyFontSize) * 2)
      .round();
  final decorated = p.contactIconStyle != 'plain';
  final icon = p.showContactIcons
      ? '<w:r><w:rPr><w:rFonts w:ascii="$family" w:hAnsi="$family" w:eastAsia="$family" w:cs="$family"/><w:b w:val="0"/><w:bCs w:val="0"/><w:sz w:val="$size"/><w:szCs w:val="$size"/>'
            '${decorated ? '<w:bdr w:val="single" w:sz="4" w:space="2" w:color="888888"/><w:shd w:val="clear" w:fill="F3F1FF"/>' : ''}'
            '</w:rPr><w:t>${String.fromCharCode(code)}</w:t></w:r>${_run(' ', rtl: rtl)}'
      : '';
  return '$icon${_run(line.text, rtl: rtl)}';
}

String _contacts(
  List<DocumentLine> contacts,
  DocumentDesign d, {
  required bool rtl,
  required Map<String, String> links,
}) {
  if (contacts.isEmpty) return '';
  final arrangement = d.presentation.resolvedContactArrangement;
  String row(List<DocumentLine> values) {
    final runs = values
        .map((line) {
          final run = _contactRuns(line, d, rtl);
          final relId = links[line.url];
          return relId == null
              ? run
              : '<w:hyperlink r:id="$relId">$run</w:hyperlink>';
        })
        .join(_run(arrangement == 'compact' ? '  |  ' : '   ', rtl: rtl));
    return '<w:p><w:pPr>${rtl ? '<w:bidi/>' : ''}<w:jc w:val="${d.presentation.headerStyle == 'center'
        ? 'center'
        : rtl
        ? 'start'
        : 'left'}"/></w:pPr>$runs</w:p>';
  }

  if (arrangement == 'compact' || arrangement == 'oneRow') return row(contacts);
  if (arrangement == 'twoRows') {
    final middle = (contacts.length / 2).ceil();
    return row(contacts.take(middle).toList()) +
        row(contacts.skip(middle).toList());
  }
  if (d.presentation.resolvedContactArrangement == 'grid') {
    return _table(
      [
        for (var i = 0; i < contacts.length; i += 2)
          [
            _paragraph(contacts[i], design: d, rtl: rtl, links: links),
            if (i + 1 < contacts.length)
              _paragraph(contacts[i + 1], design: d, rtl: rtl, links: links)
            else
              '<w:p/>',
          ],
      ],
      d,
      rtl,
    );
  }
  return contacts
      .map((line) => _paragraph(line, design: d, rtl: rtl, links: links))
      .join();
}

String _entryRow(
  DocumentLine title,
  DocumentLine meta,
  DocumentDesign d, {
  required bool rtl,
  required Map<String, String> links,
}) => _table(
  [
    [
      _paragraph(title, design: d, rtl: rtl, links: links, entryCell: true),
      _paragraph(
        meta,
        design: d,
        rtl: rtl,
        links: links,
        alignment: rtl ? 'left' : 'right',
        entryCell: true,
      ),
    ],
  ],
  d,
  rtl,
  firstFraction: .6,
);
String _table(
  List<List<String>> rows,
  DocumentDesign d,
  bool rtl, {
  double firstFraction = .5,
}) {
  final (shortSide, longSide) = switch (d.page.pageSize) {
    'letter' => (612.0, 792.0),
    'legal' => (612.0, 1008.0),
    _ => (595.28, 841.89),
  };
  final pageWidth = d.page.portrait ? shortSide : longSide;
  final width = ((pageWidth - d.spacing.resolvedHorizontalMargin * 2) * 20)
      .round();
  final first = (width * firstFraction).round();
  final widths = [first, width - first];
  return '<w:tbl><w:tblPr><w:tblW w:w="$width" w:type="dxa"/><w:tblLayout w:type="fixed"/>'
      '${rtl ? '<w:bidiVisual/>' : ''}<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr>'
      '<w:tblGrid><w:gridCol w:w="${widths[0]}"/><w:gridCol w:w="${widths[1]}"/></w:tblGrid>'
      '${rows.map((row) => '<w:tr><w:trPr><w:cantSplit/></w:trPr>${[for (var i = 0; i < row.length; i++) '<w:tc><w:tcPr><w:tcW w:w="${widths[i]}" w:type="dxa"/></w:tcPr>${row[i]}</w:tc>'].join()}</w:tr>').join()}</w:tbl>';
}

/// ECMA-376 font obfuscation keeps the licensed fonts inside the editable file.
void _embedFonts(Archive archive, Map<String, Uint8List> files) {
  final fonts = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><w:fonts xmlns:w="$_w" xmlns:r="$_r">',
  );
  final rels = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );
  var index = 0;
  for (final entry in {
    ...cvFontAssets,
    'material': ('ContactIcons-Regular.ttf', 'ContactIcons-Regular.ttf'),
    'brands': ('ContactBrands-Regular.ttf', 'ContactBrands-Regular.ttf'),
  }.entries) {
    final family = switch (entry.key) {
      'material' => 'Material Icons',
      'brands' => contactBrandFontFamily,
      _ => cvFontNames[entry.key]!,
    };
    fonts.write('<w:font w:name="${escapeXml(family)}">');
    for (final weight in [0, 1]) {
      final file = weight == 0 ? entry.value.$1 : entry.value.$2;
      final data = files[file];
      if (data == null) continue;
      final guid = const Uuid().v4().toUpperCase();
      final hex = guid.replaceAll('-', '');
      final key = [
        for (var i = 0; i < 32; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ].reversed.toList();
      final bytes = Uint8List.fromList(data);
      for (var i = 0; i < 32 && i < bytes.length; i++) {
        bytes[i] ^= key[i % 16];
      }
      final id = 'rIdFont${++index}';
      final path = 'fonts/font$index.odttf';
      archive.addFile(ArchiveFile('word/$path', bytes.length, bytes));
      fonts.write(
        '<w:embed${weight == 0 ? 'Regular' : 'Bold'} r:id="$id" w:fontKey="{$guid}"/>',
      );
      rels.write(
        '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/font" Target="$path"/>',
      );
    }
    fonts.write('</w:font>');
  }
  fonts.write('</w:fonts>');
  rels.write('</Relationships>');
  archive.addFile(_file('word/fontTable.xml', fonts.toString()));
  archive.addFile(_file('word/_rels/fontTable.xml.rels', rels.toString()));
}

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
