#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Typeset the volunteer guide as OBS-Multistream-Guide.pdf.

    python3 docs/guide/build-guide.py [--output PATH] [--sections 2,6]

What it says lives in content.py; this file decides how it looks. Every
section starts on a fresh page, and --sections renders only the ones named,
which is how a change gets proof-read without rebuilding the whole guide.

Font sizes are written in px and converted on the way in: CSS treats 1px as
1/96 inch, so PX below is exactly that, and 14 * PX is the same size as a
14px rule in a stylesheet.

Needs reportlab:  python3 -m pip install reportlab
"""
from __future__ import annotations

import argparse
import io
import os
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (BaseDocTemplate, Frame, Image, KeepTogether,
                                PageBreak, PageTemplate, Paragraph, Spacer, Table,
                                TableStyle)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import content  # noqa: E402

# One CSS pixel. Every font size below is in px and scaled by this.
PX = inch / 96.0

IMAGES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "images")

PAGE_WIDTH, PAGE_HEIGHT = letter
MARGIN = 0.72 * inch
CONTENT_WIDTH = PAGE_WIDTH - 2 * MARGIN

INK = colors.HexColor("#1b1f24")        # body text
MUTED = colors.HexColor("#5b6670")      # intro lines, running head
ACCENT = colors.HexColor("#1f5c99")     # headings, step badges
RULE = colors.HexColor("#d4dae0")       # hairlines and table grid
BAND = colors.HexColor("#f1f4f7")       # table header fill, callout fill
WARN_EDGE = colors.HexColor("#b4581a")  # the "do this first" boxes
WARN_FILL = colors.HexColor("#fdf4ec")

ARROW = "\u203a"  # the menu arrow, as in Docks › Custom Browser Docks.
#                  U+203A and not U+25B8: the built-in Helvetica is a WinAnsi
#                  font, and anything outside that set draws as a black box.


def markup(text: str) -> str:
    """content.py writes ARROW where a menu path needs its arrow."""
    return text.replace("ARROW", '<font color="#7d8894">%s</font>' % ARROW)


def style(name, size_px, leading_px=None, colour=INK, font="Helvetica",
          space_before=0, space_after=0, left=0, align=TA_LEFT):
    return ParagraphStyle(
        name,
        fontName=font,
        fontSize=size_px * PX,
        leading=(leading_px or size_px * 1.45) * PX,
        textColor=colour,
        spaceBefore=space_before * PX,
        spaceAfter=space_after * PX,
        leftIndent=left * PX,
        alignment=align,
    )


S = {
    "cover_title": style("cover_title", 44, 50, ACCENT, "Helvetica-Bold", space_after=10),
    "cover_sub": style("cover_sub", 17, 25, MUTED, space_after=42),
    "cover_toc_head": style("cover_toc_head", 19, 26, INK, "Helvetica-Bold", space_after=12),
    "cover_note": style("cover_note", 12, 18, MUTED, space_before=34),
    "toc_num": style("toc_num", 13, 20, INK),
    "toc_page": style("toc_page", 13, 20, MUTED),
    "toc_head": style("toc_head", 11, 18, MUTED, "Helvetica-Bold"),
    "head_left": style("head_left", 11, 14, MUTED, "Helvetica-Bold"),
    "head_right": style("head_right", 11, 14, MUTED),
    "section": style("section", 30, 36, ACCENT, "Helvetica-Bold", space_after=6),
    "intro": style("intro", 14, 21, MUTED, space_after=16),
    "step_num": style("step_num", 13, 16, colors.white, "Helvetica-Bold",
                      align=TA_CENTER),
    "step": style("step", 14, 21, INK),
    "cell": style("cell", 12.5, 18, INK),
    "cell_head": style("cell_head", 12.5, 18, INK, "Helvetica-Bold"),
    "callout_head": style("callout_head", 14, 20, INK, "Helvetica-Bold", space_after=4),
    "callout": style("callout", 13, 20, INK),
    "caption": style("caption", 11, 16, MUTED, space_before=4, space_after=4),
    "warn_head": style("warn_head", 14, 20, WARN_EDGE, "Helvetica-Bold", space_after=5),
    "warn": style("warn", 13, 20, INK, space_after=5),
}


def para(text, key):
    return Paragraph(markup(text), S[key])


def figure(name, caption, width):
    """A screenshot under a step, at column width but never upscaled."""
    path = os.path.join(IMAGES, name)
    native_w, native_h = ImageReader(path).getSize()
    w = min(width, native_w * PX)
    picture = Image(path, width=w, height=w * native_h / native_w)
    picture.hAlign = "LEFT"
    return [Spacer(1, 7 * PX), picture, para(caption, "caption")]


def steps_table(steps):
    """Numbered steps: a filled badge on the left, the instruction on the right.

    A step is a string, or a dict with an image and its caption underneath.
    """
    badge = 23 * PX
    gutter = 13 * PX
    body_width = CONTENT_WIDTH - badge - gutter
    rows, heights = [], []
    for i, step in enumerate(steps, 1):
        text = step["text"] if isinstance(step, dict) else step
        number = Table(
            [[para(str(i), "step_num")]],
            colWidths=[badge], rowHeights=[badge], hAlign="LEFT",
            style=TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), ACCENT),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                ("TOPPADDING", (0, 0), (-1, -1), 0),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
            ]),
        )
        cell = [para(text, "step")]
        if isinstance(step, dict) and step.get("image"):
            cell += figure(step["image"], step.get("caption", ""), body_width)
        rows.append([number, cell])
        heights.append(None)
    # Cell padding in reportlab comes out of the column width rather than
    # adding to it, so the gap after the badge is part of column 0's width and
    # the badge itself is left-aligned inside it.
    return Table(
        rows,
        colWidths=[badge + gutter, body_width],
        rowHeights=heights,
        hAlign="LEFT",
        style=TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("ALIGN", (0, 0), (0, -1), "LEFT"),
            ("LEFTPADDING", (0, 0), (0, -1), 0),
            ("RIGHTPADDING", (0, 0), (0, -1), gutter),
            ("LEFTPADDING", (1, 0), (1, -1), 0),
            ("RIGHTPADDING", (1, 0), (1, -1), 0),
            ("TOPPADDING", (0, 0), (-1, -1), 3 * PX),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 7 * PX),
        ]),
    )


def data_table(headers, rows):
    ncols = len(headers)
    if ncols == 2:
        widths = [0.34, 0.66]
    else:
        widths = [0.30, 0.37, 0.33]
    widths = [w * CONTENT_WIDTH for w in widths]

    body = [[para(h, "cell_head") for h in headers]]
    body += [[para(c, "cell") for c in row] for row in rows]

    return Table(
        body, colWidths=widths, hAlign="LEFT", repeatRows=1,
        style=TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), BAND),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("GRID", (0, 0), (-1, -1), 0.5, RULE),
            ("LEFTPADDING", (0, 0), (-1, -1), 8 * PX),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8 * PX),
            ("TOPPADDING", (0, 0), (-1, -1), 6 * PX),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6 * PX),
        ]),
    )


def boxed(flowables, fill, edge, edge_width=0.9):
    return Table(
        [[flowables]], colWidths=[CONTENT_WIDTH], hAlign="LEFT",
        style=TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), fill),
            ("BOX", (0, 0), (-1, -1), edge_width, edge),
            ("LEFTPADDING", (0, 0), (-1, -1), 14 * PX),
            ("RIGHTPADDING", (0, 0), (-1, -1), 14 * PX),
            ("TOPPADDING", (0, 0), (-1, -1), 11 * PX),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 12 * PX),
        ]),
    )


def warning_box(heading, lines):
    inner = [para(heading, "warn_head")]
    inner += [para(line, "warn") for line in lines]
    return boxed(inner, WARN_FILL, WARN_EDGE, 1.1)


def callout_box(heading, body):
    return boxed([para(heading, "callout_head"), para(body, "callout")], BAND, RULE)


def cover(sections, pages):
    story = [
        Spacer(1, 48 * PX),
        para(content.TITLE, "cover_title"),
        para(content.SUBTITLE, "cover_sub"),
        para(content.CONTENTS_HEADING, "cover_toc_head"),
    ]
    rows = [[para("", "toc_head"), para("Page", "toc_head")]]
    for i, section in enumerate(sections, 1):
        # Measured on the first pass: a section that runs long pushes every
        # section after it down a page, so these cannot be counted off.
        rows.append([para("%d. %s" % (i, section["title"]), "toc_num"),
                     para(str(pages[i]), "toc_page")])
    story.append(Table(
        rows, colWidths=[CONTENT_WIDTH - 1.0 * inch, 1.0 * inch], hAlign="LEFT",
        style=TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("ALIGN", (1, 0), (1, -1), "RIGHT"),
            ("LINEBELOW", (0, 0), (-1, -2), 0.5, RULE),
            ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ("RIGHTPADDING", (0, 0), (-1, -1), 0),
            ("TOPPADDING", (0, 0), (-1, -1), 5 * PX),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 5 * PX),
        ]),
    ))
    story.append(para(content.COVER_NOTE, "cover_note"))
    return story


def section_story(number, section):
    heading = para("%d. %s" % (number, section["title"]), "section")
    heading.section_number = number  # read back in Guide.afterFlowable
    story = [heading, para(section["intro"], "intro")]

    if "warning" in section:
        heading, lines = section["warning"]
        story.append(warning_box(heading, lines))
        story.append(Spacer(1, 17 * PX))

    if section.get("steps"):
        story.append(steps_table(section["steps"]))

    if "table" in section:
        if section.get("steps"):
            story.append(Spacer(1, 10 * PX))
        headers, rows = section["table"]
        story.append(data_table(headers, rows))

    if "callout" in section:
        story.append(Spacer(1, 18 * PX))
        heading, body = section["callout"]
        story.append(KeepTogether(callout_box(heading, body)))

    return story


class Guide(BaseDocTemplate):
    """Draws the running head, and knows which page is which section."""

    def __init__(self, path, labels):
        super().__init__(
            path, pagesize=letter,
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=MARGIN, bottomMargin=MARGIN,
            title=content.TITLE, author="A/V team",
            subject=content.RUNNING_HEAD,
        )
        self.labels = labels
        self.section_pages = {}
        body = Frame(MARGIN, MARGIN, CONTENT_WIDTH,
                     PAGE_HEIGHT - 2 * MARGIN - 26 * PX, id="body",
                     leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
        self.addPageTemplates([PageTemplate(id="page", frames=[body],
                                            onPage=self.decorate)])

    def afterFlowable(self, flowable):
        number = getattr(flowable, "section_number", None)
        if number is not None:
            self.section_pages[number] = self.page

    def decorate(self, canvas, doc):
        page = canvas.getPageNumber()
        label = self.labels.get(page)
        if not label:
            return  # the cover carries no running head
        canvas.saveState()
        y = PAGE_HEIGHT - MARGIN - 2 * PX
        canvas.setFont("Helvetica-Bold", 11 * PX)
        canvas.setFillColor(MUTED)
        canvas.drawString(MARGIN, y, label)
        canvas.setFont("Helvetica", 11 * PX)
        canvas.drawRightString(PAGE_WIDTH - MARGIN, y, content.RUNNING_HEAD)
        canvas.setStrokeColor(RULE)
        canvas.setLineWidth(0.5)
        canvas.line(MARGIN, y - 7 * PX, PAGE_WIDTH - MARGIN, y - 7 * PX)
        canvas.restoreState()


def render(target, chosen, with_cover, toc_pages, labels):
    story = []
    if with_cover:
        story += cover(content.SECTIONS, toc_pages)
    for number, section in chosen:
        if story:
            story.append(PageBreak())
        story += section_story(number, section)

    doc = Guide(target, labels)
    doc.build(story)
    return doc.section_pages, doc.page


def build(path, only=None):
    """Two passes: the first measures where each section lands, the second
    draws the contents and the running heads from those real page numbers.

    A section that runs onto a second page - section 6, with its screenshots -
    moves every section after it, and a counted-off contents page would then
    send a volunteer to the wrong page.
    """
    chosen = [(i, s) for i, s in enumerate(content.SECTIONS, 1)
              if only is None or i in only]
    if not chosen:
        raise SystemExit("no sections selected")

    with_cover = only is None
    guess = {i: i + 1 for i in range(1, len(content.SECTIONS) + 1)}
    starts, total = render(io.BytesIO(), chosen, with_cover, guess, {})

    labels = {}
    ordered = sorted(starts.items(), key=lambda kv: kv[1])
    for i, (number, first) in enumerate(ordered):
        last = ordered[i + 1][1] - 1 if i + 1 < len(ordered) else total
        for page in range(first, last + 1):
            labels[page] = str(page) if with_cover else "%d." % number

    render(path, chosen, with_cover, starts, labels)
    return path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    here = os.path.dirname(os.path.abspath(__file__))
    default = os.path.join(here, "..", "..", "dist", "OBS-Multistream-Guide.pdf")
    ap.add_argument("--output", default=os.path.normpath(default),
                    help="where to write the PDF")
    ap.add_argument("--sections", default=None,
                    help="render only these section numbers, e.g. 2,6")
    args = ap.parse_args()

    only = None
    if args.sections:
        only = {int(n) for n in args.sections.replace(" ", "").split(",") if n}
        unknown = sorted(n for n in only if not 1 <= n <= len(content.SECTIONS))
        if unknown:
            raise SystemExit("no such section: %s" % ", ".join(map(str, unknown)))

    out = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    build(out, only)
    print(out)


if __name__ == "__main__":
    main()
