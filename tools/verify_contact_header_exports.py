"""Independently inspect the contact-header fixtures produced by Flutter tests."""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
import ctypes
import json

import pypdfium2 as pdfium

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
root = Path('build/contact_header_samples')
report = {}
expected = {
    'https://github.com/example-developer',
    'https://www.linkedin.com/in/example-developer',
    'https://example.test/a/very/long/portfolio/path',
}


def font_name(text, index):
    buffer = ctypes.create_string_buffer(256)
    flags = ctypes.c_int()
    pdfium.raw.FPDFText_GetFontInfo(text.raw, index, buffer, len(buffer), ctypes.byref(flags))
    return buffer.value.decode()


for source in sorted(root.glob('*.pdf')):
    doc = pdfium.PdfDocument(str(source))
    page = doc[0]
    text = page.get_textpage()
    value = text.get_text_range()
    icons = source.stem.endswith('icons') or source.stem == 'grid-arabic'
    expected_size = 14 if source.stem == 'grid-arabic' else 18
    logos = []
    for code in (0xf09b, 0xf08c):
        occurrence = text.search(chr(code)).get_next()
        assert bool(occurrence) == icons, (source.name, hex(code))
        if occurrence:
            index, _ = occurrence
            name = font_name(text, index)
            assert 'FontAwesome6Brands' in name, name
            assert abs(pdfium.raw.FPDFText_GetFontSize(text.raw, index) - expected_size) < .1
            logos.append(name)
    if source.stem == 'grid-arabic':
        assert '+20 100 123 4567' in value, value
        marker = text.search(chr(0xf09b)).get_next()
        assert text.get_charbox(marker[0])[0] > page.get_width() - 90
    assert 'dev-name' in value or source.stem == 'grid-arabic'
    assert 'github.com/example-developer' not in value
    # Read actual link actions rather than searching the file's raw bytes.
    position = ctypes.c_int(0)
    link = pdfium.raw.FPDF_LINK()
    destinations = set()
    while pdfium.raw.FPDFLink_Enumerate(page.raw, ctypes.byref(position), ctypes.byref(link)):
        action = pdfium.raw.FPDFLink_GetAction(link)
        size = pdfium.raw.FPDFAction_GetURIPath(doc.raw, action, None, 0)
        if size:
            buffer = ctypes.create_string_buffer(size)
            pdfium.raw.FPDFAction_GetURIPath(doc.raw, action, buffer, size)
            destinations.add(buffer.value.decode())
    assert expected <= destinations, (source.name, destinations)
    report[source.name] = {'pages': len(doc), 'brand_fonts': logos, 'links': len(destinations)}

for source in sorted(root.glob('*.docx')):
    with ZipFile(source) as package:
        assert package.testzip() is None
        for name in package.namelist():
            if name.endswith(('.xml', '.rels')):
                ET.fromstring(package.read(name))
        document = ET.fromstring(package.read('word/document.xml'))
        relationships = ET.fromstring(package.read('word/_rels/document.xml.rels'))
        targets = {r.attrib['Target'] for r in relationships if r.attrib.get('TargetMode') == 'External'}
        assert expected <= targets
        assert len(list(document.iter(W + 'hyperlink'))) >= 3
        text = ''.join(e.text or '' for e in document.iter(W + 't'))
        assert not any(target in text for target in expected)
        report[source.name] = {'clickable_links': len(targets), 'text_length': len(text)}

# Check the actual fonts activated by the Word renderer, when available.
review = Path('build/contact_header_review')
for folder, filename in [('word-grid', 'grid-icons.pdf'), ('word-two-rows', 'twoRows-icons.pdf'),
                         ('word-arabic', 'grid-arabic.pdf')]:
    path = review / folder / filename
    if path.exists():
        doc = pdfium.PdfDocument(str(path))
        text = doc[0].get_textpage()
        names = []
        for code in (0xf09b, 0xf08c):
            match = text.search(chr(code)).get_next()
            assert match is not None, path
            name = font_name(text, match[0])
            assert 'FontAwesome6Brands' in name, (path, name)
            names.append(name)
        report[f'word-render/{filename}'] = {'pages': len(doc), 'brand_fonts': names}

review.mkdir(parents=True, exist_ok=True)
(review / 'verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
