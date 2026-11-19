"""Inspect generated CV fixtures independently of Flutter's PDF writer.

Run flutter test test/export_layout_consistency_test.dart first.
Requires PyMuPDF. Writes rendered pages and a verification report under build/.
"""
import json
from pathlib import Path

import pymupdf


def main():
    root = Path('build/export_layout_samples')
    names = ['right', 'below', 'beside', 'with-date', 'multipage', 'arabic',
             'card', 'gallery', 'icons', 'dotted', 'gradient']
    report = {}
    source = 'https://github.com/example/project-with-long-name'
    portfolio = 'https://example.test/p/long-private-looking-path'
    for name in names:
        document = pymupdf.open(root / f'{name}.pdf')
        spans = []
        links = set()
        project_links = []
        for number, page in enumerate(document):
            for block in page.get_text('dict')['blocks']:
                for line in block.get('lines', []):
                    for span in line['spans']:
                        spans.append((number, span))
                        x0, y0, x1, y1 = span['bbox']
                        assert -1 <= x0 <= x1 <= page.rect.width + 1, (name, span)
                        assert -1 <= y0 <= y1 <= page.rect.height + 1, (name, span)
            links.update(link['uri'] for link in page.get_links() if 'uri' in link)
            project_links.extend((number, link) for link in page.get_links()
                                 if link.get('uri') == 'https://example.test/demo')
            page.get_pixmap(matrix=pymupdf.Matrix(1.5, 1.5)).save(root / f'{name}-{number + 1}.png')
        text = '\n'.join(page.get_text() for page in document)
        assert portfolio not in text and source not in text, name
        assert {source, portfolio} <= links, (name, links)
        assert project_links, name
        assert 'Demo' not in text and 'Source' not in text, name
        for number, link in project_links:
            rect = link['from']
            # The clickable demo icon must share the project-heading line,
            # rather than consuming a row after the project description.
            assert any(p == number and s['flags'] & 16 and
                       abs(s['origin'][1] - rect.y1) < 5 and
                       s['bbox'][0] < rect.x0
                       for p, s in spans) or name == 'arabic', (name, rect)
        # Actual PDF text, font sizes and positions: dates cannot lose a year
        # to another line and must reserve their own space beside the title.
        for date in ['Oct 2019 - Oct 2024', 'Sep 2026 - Oct 2026']:
            found = [(p, span) for p, span in spans if date in span['text']]
            assert found, (name, date)
            assert all(abs(span['size'] - 9) < .1 for _, span in found), (name, found)
        if name != 'arabic':
            assert 'PROFILE' in text, name
        if name in ['right', 'card', 'icons', 'dotted', 'gradient']:
            for title, date in [
                ('Bachelor', 'Oct 2019 - Oct 2024'),
                ('Restaurant Management System 0', 'Sep 2026 - Oct 2026'),
            ]:
                title_page, title_span = next((p, s) for p, s in spans if title in s['text'])
                date_page, date_span = next((p, s) for p, s in spans if date in s['text'])
                assert title_page == date_page, name
                assert abs(title_span['origin'][1] - date_span['origin'][1]) < 2, (name, title)
                assert date_span['bbox'][0] > title_span['bbox'][2], (name, title)
                assert abs(date_span['bbox'][2] - (document[date_page].rect.width - 40)) < 2, (name, date)
            school = next(s for _, s in spans if 'Ain Shams University' in s['text'])
            title = next(s for _, s in spans if 'Bachelor' in s['text'])
            assert school['origin'][1] > title['origin'][1] + 8, name
            assert school['color'] != title['color'], name
        if name == 'multipage':
            assert len(document) > 1
            assert 'Restaurant Management System 3' in text
        if name == 'icons':
            assert all(chr(code) in text for code in [0xe7fd, 0xe8f9, 0xe80c, 0xe2c7]), name
        report[name] = {'pages': len(document), 'hyperlinks': len(links), 'verified': True}
        print(f'PASS {name}: {len(document)} page(s), compact links, complete date spans')
    (root / 'verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
