"""Render a generated PDF to PNG images and dump its text.

Used for the visual QA pass over the exporter's output: PDFium is an
independent PDF implementation, so both the rendered pixels and the extracted
text act as a cross-check on the Dart tests.

Requirements::

    py -3 -m pip install pypdfium2 pillow

Usage::

    py -3 tools/inspect_pdf.py <input.pdf> <outdir> [scale]

Writes ``page-N.png`` per page plus ``text.txt`` and prints a short summary
(page count, page size, per-page text length).
"""

from __future__ import annotations

import os
import sys


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: inspect_pdf.py <input.pdf> <outdir> [scale]")
        return 2

    src = argv[1]
    outdir = argv[2]
    scale = float(argv[3]) if len(argv) > 3 else 2.0

    import pypdfium2 as pdfium

    os.makedirs(outdir, exist_ok=True)
    pdf = pdfium.PdfDocument(src)
    page_count = len(pdf)
    print(f"file={os.path.basename(src)} pages={page_count} scale={scale}")
    if page_count == 0:
        print("ERROR: document has no pages")
        return 1

    all_text: list[str] = []
    for index in range(page_count):
        page = pdf[index]
        width, height = page.get_size()
        text_page = page.get_textpage()
        text = text_page.get_text_range()
        all_text.append(text.strip())

        bitmap = page.render(scale=scale)
        image = bitmap.to_pil()
        path = os.path.join(outdir, f"page-{index + 1}.png")
        image.save(path)
        print(
            f"page {index + 1}: size={width:.0f}x{height:.0f}pt"
            f" chars={len(text.strip())} image={image.size} -> {path}"
        )

    text_path = os.path.join(outdir, "text.txt")
    with open(text_path, "w", encoding="utf-8") as handle:
        for index, text in enumerate(all_text):
            handle.write(f"--- page {index + 1} ---\n{text}\n")
    print(f"wrote {text_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
