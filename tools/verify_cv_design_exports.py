"""Independent PDFium and OOXML checks for generated CV design regressions."""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
import ctypes
import hashlib
import json
import pypdfium2 as pdfium

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
R = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
P = '{http://schemas.openxmlformats.org/package/2006/relationships}'
root = Path('build/cv_design_samples')
report = {}
for pdf in sorted(root.glob('*-*.pdf')):
    if pdf.stem == 'long-entry':
        document = pdfium.PdfDocument(str(pdf))
        assert len(document) > 1
        assert 'FINAL_ENTRY_MARKER' in ''.join(p.get_textpage().get_text_range() for p in document)
        report[pdf.name] = {'pages': len(document), 'tail_preserved': True}
        continue
    custom = 'custom' in pdf.stem
    document = pdfium.PdfDocument(str(pdf))
    assert len(document) > 1
    first = document[0].get_textpage()
    info = {'pages': len(document), 'bytes': pdf.stat().st_size}
    if pdf.stem.startswith('en'):
        for label, text, expected in [('name', 'Alex Morgan', 28 if custom else 18),
                                      ('title', 'Software Engineer', 16 if custom else 11.5),
                                      ('body', 'I build reliable', 12 if custom else 10.5),
                                      ('entry', 'Application Engineer 0', 14 if custom else 10.5)]:
            occurrence = first.search(text).get_next()
            assert occurrence is not None, text
            index, _ = occurrence
            size = pdfium.raw.FPDFText_GetFontSize(first.raw, index)
            assert abs(size - expected) < .1, (label, size, expected)
            buffer = ctypes.create_string_buffer(256)
            flags = ctypes.c_int()
            pdfium.raw.FPDFText_GetFontInfo(first.raw, index, buffer, len(buffer), ctypes.byref(flags))
            font = buffer.value.decode(errors='replace')
            info[label] = {'size': size, 'font': font, 'box': first.get_charbox(index)}
        assert 'Roboto' in info['name']['font'] if custom else 'Inter' in info['name']['font']
        assert 'Lora' in info['body']['font'] if custom else 'Inter' in info['body']['font']
        assert abs(info['body']['box'][0] - (18 * 72 / 25.4 if custom else 40)) < 3
    all_text = '\n'.join(document[i].get_textpage().get_text_range() for i in range(len(document)))
    if pdf.stem.startswith('ar'):
        bullet = first.search('\u2022').get_next()
        assert bullet is not None
        bullet_x = first.get_charbox(bullet[0])[0]
        assert bullet_x > document[0].get_width() - 90, bullet_x
        info['rtl_bullet_x'] = bullet_x
    assert 'alex@example.test' in all_text
    assert 'Application Engineer 15' in all_text if pdf.stem.startswith('en') else len(all_text) > 1000
    report[pdf.name] = info

for word in sorted(root.glob('*.docx')):
    with ZipFile(word) as z:
        assert z.testzip() is None
        for name in z.namelist():
            if name.endswith('.xml') or name.endswith('.rels'):
                ET.fromstring(z.read(name))
        d = ET.fromstring(z.read('word/document.xml'))
        text = ''.join(e.text or '' for e in d.iter(W + 't'))
        assert 'alex@example.test' in text
        assert not any('\uFB50' <= char <= '\uFDFF' or '\uFE70' <= char <= '\uFEFF' for char in text)
        assert len(list(d.iter(W + 'numPr'))) == 48
        styles = z.read('word/styles.xml').decode()
        assert 'w:line="360"' in styles if 'custom' in word.stem else 'w:line="324"' in styles
        fonts = ET.fromstring(z.read('word/fontTable.xml'))
        rels = ET.fromstring(z.read('word/_rels/fontTable.xml.rels'))
        targets = {r.attrib['Id']: r.attrib['Target'] for r in rels}
        embedded = 0
        for font in fonts:
            for child in font:
                key = child.attrib.get(W + 'fontKey')
                if key is None:
                    continue
                data = bytearray(z.read('word/' + targets[child.attrib[R + 'id']]))
                mask = bytes.fromhex(key.strip('{}').replace('-', ''))[::-1]
                for i in range(min(32, len(data))):
                    data[i] ^= mask[i % 16]
                assert data[:4] == b'\x00\x01\x00\x00', font.attrib
                assert any(hashlib.sha256(data).digest() == hashlib.sha256(p.read_bytes()).digest()
                           for p in Path('assets/google_fonts').glob('*.ttf'))
                embedded += 1
        assert embedded >= 6
        if word.stem.startswith('ar'):
            assert list(d.iter(W + 'bidi')) and list(d.iter(W + 'rtl'))
        report[word.name] = {'parts': len(z.namelist()), 'embedded_fonts': embedded, 'text_characters': len(text)}
out = Path('build/cv_design_review/verification.json')
out.parent.mkdir(exist_ok=True, parents=True)
out.write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
