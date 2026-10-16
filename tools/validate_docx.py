"""Validate generated .docx packages with tools independent of the Dart code.

The Dart tests build and re-read the package with the `archive` package, so a
shared misunderstanding of the OOXML container could go unnoticed. This script
uses CPython's `zipfile` (CRC verification) and `xml.etree.ElementTree`
(well-formedness) instead, which is a genuinely independent check.

It verifies:

* the file is a readable ZIP and every entry's CRC matches;
* the parts OOXML requires are present ([Content_Types].xml, _rels/.rels,
  word/document.xml, ...);
* every XML part parses;
* every declared content type covers a part that exists;
* every relationship target (non-external) resolves inside the package;
* the extracted text is logical (no Arabic presentation forms), keeps Latin
  runs such as e-mail addresses, uses numbering for bullets and marks the RTL
  document with <w:bidi/>.

Usage::

    py -3 tools/validate_docx.py build/export_samples/*.docx
"""

from __future__ import annotations

import re
import sys
import zipfile
from xml.etree import ElementTree

W_NS = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
CT_NS = "{http://schemas.openxmlformats.org/package/2006/content-types}"
REL_NS = "{http://schemas.openxmlformats.org/package/2006/relationships}"

REQUIRED_PARTS = [
    "[Content_Types].xml",
    "_rels/.rels",
    "word/document.xml",
]

# Arabic presentation forms: a shaped glyph must never be stored in the file.
PRESENTATION_FORM = re.compile("[\uFB50-\uFDFF\uFE70-\uFEFF]")


def _check(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def _normalise(path: str) -> str:
    parts: list[str] = []
    for segment in path.split("/"):
        if segment in ("", "."):
            continue
        if segment == "..":
            if parts:
                parts.pop()
            continue
        parts.append(segment)
    return "/".join(parts)


def validate(path: str) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    notes: list[str] = []

    try:
        archive = zipfile.ZipFile(path)
    except zipfile.BadZipFile as error:
        return [f"not a readable ZIP: {error}"], notes

    with archive:
        bad = archive.testzip()
        _check(bad is None, f"CRC mismatch in {bad}", failures)

        names = set(archive.namelist())
        for part in REQUIRED_PARTS:
            _check(part in names, f"missing required part {part}", failures)

        # Every XML/rels part must parse.
        parsed: dict[str, ElementTree.Element] = {}
        for name in sorted(names):
            if name.endswith((".xml", ".rels")):
                try:
                    parsed[name] = ElementTree.fromstring(archive.read(name))
                except ElementTree.ParseError as error:
                    failures.append(f"{name} is not well-formed XML: {error}")

        # Content types must cover the parts that are present.
        overrides: set[str] = set()
        defaults: set[str] = set()
        types = parsed.get("[Content_Types].xml")
        if types is not None:
            for child in types:
                if child.tag == f"{CT_NS}Override":
                    overrides.add(child.get("PartName", "").lstrip("/"))
                elif child.tag == f"{CT_NS}Default":
                    defaults.add(child.get("Extension", "").lower())
            for name in names:
                if name == "[Content_Types].xml" or name.endswith("/"):
                    continue
                if name in overrides:
                    continue
                extension = name.rsplit(".", 1)[-1].lower() if "." in name else ""
                _check(
                    extension in defaults,
                    f"{name} has no declared content type",
                    failures,
                )
            for part in sorted(overrides):
                _check(part in names, f"declared part {part} is absent", failures)

        # Every relationship target must resolve inside the package.
        for name, root in parsed.items():
            if not name.endswith(".rels"):
                continue
            base = name.rsplit("_rels/", 1)[0]
            for rel in root:
                if rel.tag != f"{REL_NS}Relationship":
                    continue
                if rel.get("TargetMode") == "External":
                    continue
                target = rel.get("Target", "")
                resolved = (
                    target.lstrip("/")
                    if target.startswith("/")
                    else _normalise(base + target)
                )
                _check(
                    resolved in names,
                    f"{name} -> {target} does not resolve ({resolved})",
                    failures,
                )

        # Content checks.
        document = parsed.get("word/document.xml")
        if document is not None:
            paragraphs = [
                "".join(node.text or "" for node in para.iter(f"{W_NS}t"))
                for para in document.iter(f"{W_NS}p")
            ]
            text = "\n".join(paragraphs)
            body = document.find(f"{W_NS}body")

            _check(
                PRESENTATION_FORM.search(text) is None,
                "text contains Arabic presentation forms (should be logical)",
                failures,
            )
            _check(
                "ahmed@example.com" in text or "ada@example.com" in text,
                "the e-mail address is missing from the text",
                failures,
            )
            numbering = sum(1 for _ in document.iter(f"{W_NS}numPr"))
            notes.append(f"bullet paragraphs: {numbering}")
            _check(numbering > 0, "no bullets declared", failures)

            bidi = sum(1 for _ in document.iter(f"{W_NS}bidi"))
            arabic = any("\u0600" <= ch <= "\u06FF" for ch in text)
            notes.append(f"arabic: {arabic}, bidi paragraphs: {bidi}")
            if arabic:
                _check(
                    bidi > 0,
                    "an Arabic document should mark paragraphs right-to-left",
                    failures,
                )

            headings = sum(1 for _ in document.iter(f"{W_NS}pStyle"))
            notes.append(f"styled paragraphs: {headings}")
            _check(headings > 0, "no paragraph styles are applied", failures)
            _check(body is not None, "document.xml has no body", failures)

        notes.append(f"parts: {len(names)}")

    return failures, notes


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: validate_docx.py <file.docx> [...]")
        return 2

    status = 0
    for path in argv[1:]:
        failures, notes = validate(path)
        label = path.replace("\\", "/").rsplit("/", 1)[-1]
        state = "FAIL" if failures else "OK"
        print(f"[{state}] {label}  ({'; '.join(notes)})")
        for failure in failures:
            print(f"       - {failure}")
        if failures:
            status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

