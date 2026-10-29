#!/usr/bin/env python3
"""Builds The Petite Home Binder: one fillable PDF that bundles the Family File
and the planning sheets, with a table of contents and index tabs, so it can be
downloaded as the lead magnet, filled in on screen or by hand, and printed
into a binder.

    python3 lead-magnets/binder.py            # writes lead-magnets/pdf/the-petite-home-binder.pdf
    python3 lead-magnets/binder.py --preview  # also writes PNG previews to lead-magnets/preview/

Every write-on line is a real PDF form field (AcroForm), every checkbox a real
checkbox, so the file fills in Preview, Acrobat, Files on iOS and the browser
and still prints clean when left blank. Page geometry is US Letter with a
72 pt binding margin on the left for hole punching. Each section carries a
shaded index tab on the right edge, stepped down the page by section, which
is the cheap substitute for physical tabs that docs/print-binder.md describes.

Design tokens, fonts and the drawing vocabulary are shared with build.py.
"""
import os, sys
from reportlab.pdfgen import canvas
from reportlab.lib.utils import simpleSplit
from reportlab.pdfbase import pdfmetrics

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build import (CREAM, CREAM_DEEP, CREAM_TINT, BLUE, BLUE_DK, BLUE_MIST, SAND, SAND_DEEP, RULE, INK, DANGER, WHITE,
                   SERIF, SERIF_TEXT, SERIF_SEMI, SANS, SANS_SEMI, SANS_IT, OUT, HERE, MORNING, BEDTIME)

SLUG = "the-petite-home-binder"
TITLE = "The Petite Home Binder"
W, H = 612, 792
ML, MR, MT, MB = 72, 56, 56, 56          # binding margin left; the rest match the other lead magnets
TAB_W = 18                               # index tab width on the right edge
FOOTER = "Made with Petite Home · petitehome.co"
FIELD_FONT, FIELD_SIZE = "Helvetica", 10  # AcroForm fields can only use the standard PDF fonts


class Binder:
    """A canvas with a top-down cursor, the brand vocabulary, and form fields."""

    def __init__(self, path):
        self.path = path
        self.c = canvas.Canvas(path, pagesize=(W, H))
        c = self.c
        c.setTitle(TITLE); c.setAuthor("Petite Home Co."); c.setCreator("Petite Home binder builder")
        c.setSubject("Everything someone would need to care for your kids, in one binder.")
        c.setKeywords("family file, emergency contacts, guardian, sitter, routines, binder")
        self.form = c.acroForm
        self.pages = 0
        self.y = MT
        self.section_index = -1
        self.section_title = ""
        self.sections = []              # (title, first page) in order, for the contents page
        self.toc_numbers = {}           # title -> page, from the previous pass
        self.field_count = 0
        self.names = set()

    # ----- geometry -----
    @property
    def cw(self): return W - ML - MR
    @property
    def right(self): return W - MR
    def Y(self, y): return H - y

    # ----- pages -----
    def page(self, cover=False):
        if self.pages:
            self._footer(); self.c.showPage()
        self.pages += 1
        self.c.setFillColor(CREAM); self.c.rect(0, 0, W, H, stroke=0, fill=1)
        self.y = MT
        if not cover:
            self.wordmark()
            if self.section_title:
                self.text(self.section_title, self.right, MT + 11, SANS, 9, SAND_DEEP, right=True)
                self._tab()
            self.y = MT + 34
        self.page_title = self.section_title
        return self

    def _footer(self):
        if getattr(self, "skip_footer", False):
            self.skip_footer = False; return
        if self.y > H - MB:
            print(f"warning: page {self.pages} ({getattr(self, 'page_title', '') or 'front'}) runs {self.y - (H - MB):.0f} pt past the footer line")
        c = self.c
        c.setFont(SANS, 9); c.setFillColor(SAND_DEEP)
        c.drawString(ML, MB - 24, FOOTER)
        if self.pages > 1:
            c.drawRightString(self.right, MB - 24, str(self.pages))

    def _tab(self):
        """A shaded tab on the right edge whose vertical slot is the section's index."""
        n = max(len(SECTIONS), 1)
        top, bottom = 96, H - 96
        slot = (bottom - top) / n
        y0 = top + self.section_index * slot
        x = W - TAB_W - 14          # 14 pt (0.2 in) from the edge, inside most home printers' printable area
        c = self.c
        c.setFillColor(BLUE); c.roundRect(x, self.Y(y0 + slot - 4), TAB_W, slot - 4, 4, stroke=0, fill=1)
        c.saveState()
        c.translate(x + TAB_W / 2 + 3, self.Y(y0 + (slot - 4) / 2))
        c.rotate(90)
        c.setFont(SANS_SEMI, 7); c.setFillColor(BLUE_DK)
        label = self.section_title.upper()
        if pdfmetrics.stringWidth(label, SANS_SEMI, 7) > slot - 16:
            label = SECTION_SHORT.get(self.section_title, label).upper()
        c.drawCentredString(0, 0, label, charSpace=0.8)
        c.restoreState()

    def section(self, title):
        """Starts a tabbed section on a fresh page and records it for the contents and the outline."""
        self.section_index += 1
        self.section_title = title
        self.page()
        self.sections.append((title, self.pages))
        key = f"sec{self.section_index}"
        self.c.bookmarkPage(key)
        self.c.addOutlineEntry(title, key, level=0)
        return self

    def save(self):
        self._footer(); self.c.showPage(); self.c.save()
        return self.path

    # ----- drawing primitives (y measured from the top) -----
    def text(self, s, x, y, font=SANS, size=11, color=INK, space=0, right=False, center=False):
        c = self.c; c.setFont(font, size); c.setFillColor(color)
        if right: c.drawRightString(x, self.Y(y), s, charSpace=space)
        elif center: c.drawCentredString(x, self.Y(y), s, charSpace=space)
        else: c.drawString(x, self.Y(y), s, charSpace=space)

    def para(self, s, x=None, y=None, w=None, font=SANS, size=11, color=INK, leading=None, advance=True):
        x = ML if x is None else x; y = self.y if y is None else y; w = self.cw if w is None else w
        leading = leading or size * 1.45
        lines = simpleSplit(s, font, size, w)
        for i, line in enumerate(lines):
            self.text(line, x, y + size + i * leading, font, size, color)
        used = len(lines) * leading
        if advance: self.y = y + used
        return used

    def wordmark(self, size=14):
        self.text("PETITE HOME CO.", ML, MT + size, SERIF_TEXT, size, BLUE_DK, space=size * 0.3)

    def title(self, s, size=30, gap=14):
        self.y += 6
        self.text(s, ML, self.y + size * 0.78, SERIF, size, INK)
        self.y += size * 0.78 + gap

    def intro(self, s, color=SAND_DEEP, size=11):
        self.para(s, font=SANS, size=size, color=color); self.y += 14

    def heading(self, s, size=20, x=None, w=None):
        x = ML if x is None else x; w = self.cw if w is None else w
        self.y += 6
        self.text(s, x, self.y + size * 0.78, SERIF, size, INK)
        self.y += size * 0.78 + 7
        self.hr(x, w); self.y += 8

    def hr(self, x=None, w=None, color=RULE):
        x = ML if x is None else x; w = self.cw if w is None else w
        self.c.setStrokeColor(color); self.c.setLineWidth(1); self.c.line(x, self.Y(self.y), x + w, self.Y(self.y))

    def label(self, s, x, y, color=SAND_DEEP, size=9):
        self.text(s.upper(), x, y + size, SANS_SEMI, size, color, space=size * 0.16)

    def box(self, x, y, w, h, fill=CREAM_DEEP, radius=10, stroke=None):
        self.c.setFillColor(fill)
        if stroke: self.c.setStrokeColor(stroke); self.c.setLineWidth(1)
        self.c.roundRect(x, self.Y(y + h), w, h, radius, stroke=1 if stroke else 0, fill=1)

    def caption(self, s, x=None, w=None, color=SAND_DEEP, size=9):
        self.para(s, x, None, w, SANS, size, color); self.y += 4

    def note_box(self, s, x=None, w=None, fill=BLUE_MIST, size=11, strong=None):
        x = ML if x is None else x; w = self.cw if w is None else w
        lines = simpleSplit(s, SANS, size, w - 28)
        h = 14 * 2 + len(lines) * size * 1.45
        self.box(x, self.y, w, h, fill)
        yy = self.y + 14
        for i, line in enumerate(lines):
            if i == 0 and strong and line.startswith(strong):
                self.text(strong, x + 14, yy + size, SANS_SEMI, size, DANGER)
                off = pdfmetrics.stringWidth(strong, SANS_SEMI, size)
                self.text(line[len(strong):], x + 14 + off, yy + size, SANS, size, INK)
            else:
                self.text(line, x + 14, yy + size, SANS, size, INK)
            yy += size * 1.45
        self.y += h + 10

    def two_col(self, gap=24):
        w = (self.cw - gap) / 2
        return (ML, w), (ML + w + gap, w)

    def app_line(self, s):
        self.y += 6; self.hr(); self.y += 10
        self.para(s, font=SANS_IT, size=10.5, color=BLUE_DK)

    # ----- form fields -----
    def _name(self, hint):
        base = "".join(ch if ch.isalnum() else "_" for ch in hint.lower()).strip("_") or "field"
        name, i = base, 1
        while name in self.names:
            i += 1; name = f"{base}_{i}"
        self.names.add(name)
        self.field_count += 1
        return name

    def field(self, hint, x, y, w, h, multiline=False, tooltip=None, size=FIELD_SIZE):
        """A borderless, transparent text field whose box sits on the drawn line."""
        self.form.textfield(name=self._name(hint), tooltip=tooltip or hint, x=x, y=self.Y(y + h), width=w, height=h,
                            fontName=FIELD_FONT, fontSize=size, textColor=INK, fillColor=None, borderColor=None, borderWidth=0,
                            fieldFlags="multiline" if multiline else "", maxlen=4000 if multiline else 200)

    def row(self, label_text, x=None, w=None, label_w=120, y=None, h=26, hint=None):
        """Label on the left, a write-on line to the right, with a text field over the line."""
        x = ML if x is None else x; w = self.cw if w is None else w; y = self.y if y is None else y
        if label_text:
            self.label(label_text, x, y + 8)
            need = pdfmetrics.stringWidth(label_text.upper(), SANS_SEMI, 9) + len(label_text) * 9 * 0.16 + 10
            label_w = max(label_w, need)
        lx = x + (label_w if label_text else 0)
        self.c.setStrokeColor(SAND_DEEP); self.c.setLineWidth(0.8)
        self.c.line(lx, self.Y(y + h - 6), x + w, self.Y(y + h - 6))
        fh = min(h - 8, 18)
        self.field(hint or f"{self.section_title} {label_text}", lx + 2, y + h - 7 - fh, x + w - lx - 4, fh)
        self.y = y + h
        return self.y

    def rows(self, labels, x=None, w=None, label_w=120, h=26, prefix=None):
        for l in labels: self.row(l, x, w, label_w, h=h, hint=f"{prefix} {l}" if prefix else None)

    def lines(self, n, x=None, w=None, h=24, hint=None):
        """n ruled lines backed by one multiline field."""
        x = ML if x is None else x; w = self.cw if w is None else w
        y0 = self.y
        for _ in range(n):
            self.c.setStrokeColor(SAND_DEEP); self.c.setLineWidth(0.8)
            self.c.line(x, self.Y(self.y + h - 6), x + w, self.Y(self.y + h - 6))
            self.y += h
        self.field(hint or f"{self.section_title} notes", x + 2, y0 + 2, w - 4, n * h - 8, multiline=True)

    def checkbox(self, x, y, label_text=None, font=SANS, size=11, color=INK, w=None, hint=None):
        self.form.checkbox(name=self._name(hint or label_text or "check"), tooltip=label_text or hint, x=x, y=self.Y(y + 12), size=12,
                           buttonStyle="check", borderColor=SAND, fillColor=WHITE, textColor=INK, borderWidth=1, fieldFlags="")
        if label_text:
            lines = simpleSplit(label_text, font, size, (w or (self.right - x - 20)))
            for i, line in enumerate(lines): self.text(line, x + 20, y + 10 + i * size * 1.3, font, size, color)
            return max(1, len(lines)) * size * 1.3
        return 12

    def check_item(self, label_text, note=None, x=None, w=None, gap=6, hint=None):
        x = ML if x is None else x; w = self.cw if w is None else w
        used = self.checkbox(x, self.y, label_text, w=w - 20, hint=hint)
        self.y += used + 2
        if note:
            self.para(note, x + 20, self.y, w - 20, SANS, 9.5, SAND_DEEP); self.y += 2
        self.y += gap

    def inline(self, s, parts, size=11, hint=None):
        """A sentence with blanks: parts is a list of (text, blank_width) pairs drawn on one line."""
        x = ML
        for i, (txt, blank) in enumerate(parts):
            if txt:
                self.text(txt, x, self.y + size, SANS, size, INK); x += pdfmetrics.stringWidth(txt, SANS, size)
            if blank:
                self.c.setStrokeColor(SAND_DEEP); self.c.setLineWidth(0.8); self.c.line(x + 2, self.Y(self.y + size + 2), x + blank - 2, self.Y(self.y + size + 2))
                self.field(f"{hint or s} {i}", x + 3, self.y - 2, blank - 6, size + 6)
                x += blank
        self.y += size + 14

    def table(self, cols, n, h=26, hint=None):
        """Column labels over n ruled rows, one text field per cell. cols: [(label, fraction)]."""
        xx = ML
        xs = []
        for name, frac in cols:
            self.label(name, xx, self.y, size=7.5); xs.append((xx, self.cw * frac)); xx += self.cw * frac
        self.y += 14; self.hr(); self.y += 2
        for r in range(n):
            for (x, w), (name, _) in zip(xs, cols):
                self.field(f"{hint or self.section_title} {name} {r + 1}", x + 1, self.y + 3, w - 8, h - 8)
            self.c.setStrokeColor(RULE); self.c.setLineWidth(0.5); self.c.line(ML, self.Y(self.y + h), ML + self.cw, self.Y(self.y + h))
            self.y += h


# ---------- the sections ----------
# (title, builder). The order here is the order in the binder and on the tabs.

def cover(d: Binder):
    d.page(cover=True)
    d.wordmark()
    d.text("The Petite Home", ML, 232 + 32, SERIF, 40, INK)
    d.text("Binder", ML, 282 + 32, SERIF, 40, INK)
    d.text("Everything someone would need to care for your kids, in one place.", ML, 344 + 12, SANS, 14, SAND_DEEP)
    d.y = 392
    d.row("The", ML, d.cw, 40, h=34, hint="cover family name")
    d.text("family", ML + d.cw - 36, d.y - 12, SANS, 11, SAND_DEEP)
    d.y += 4
    d.row("Started on", ML, 260, 80, h=30, hint="cover date")
    band_h = H / 3
    d.c.setFillColor(BLUE); d.c.rect(0, 0, W, band_h, stroke=0, fill=1)
    lines = ["If something happened to you tonight, would anyone know where to find this?",
             "Fill it in once. Keep one copy at home and one with the person you'd call first."]
    yy = H - band_h + 56
    for l in lines:
        for ln in simpleSplit(l, SERIF_TEXT, 15, d.cw):
            d.text(ln, ML, yy, SERIF_TEXT, 15, INK); yy += 23
        yy += 8
    d.text("Less to question. More to trust.", ML, H - 52, SANS_IT, 10.5, BLUE_DK)
    d.skip_footer = True


def contents(d: Binder):
    d.section_title = ""
    d.page()
    d.title("Contents", 34)
    d.intro("Fill it in on screen and print it, or print it blank and write. The tabs on the right edge show which section is which. On screen, tap a line to jump to it.")
    for i, (title, _) in enumerate(SECTIONS):
        page_no = d.toc_numbers.get(title, "")
        y = d.y
        d.c.setFillColor(BLUE); d.c.roundRect(ML, d.Y(y + 22), 22, 22, 4, stroke=0, fill=1)
        d.text(str(i + 1), ML + 11, y + 15.5, SANS_SEMI, 10, BLUE_DK, center=True)
        d.text(title, ML + 34, y + 16, SERIF_TEXT, 14, INK)
        d.text(SECTION_BLURB.get(title, ""), ML + 34, y + 33, SANS, 9.5, SAND_DEEP)
        d.text(str(page_no), d.right, y + 16, SANS, 12, SAND_DEEP, right=True)
        d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(ML, d.Y(y + 40), d.right, d.Y(y + 40))
        d.c.linkAbsolute(title, f"sec{i}", (ML, d.Y(y + 40), d.right, d.Y(y)), thickness=0)
        d.y += 41


def start_here(d: Binder):
    d.section("Start here")
    d.title("Start here")
    d.intro("This binder takes about twenty minutes to fill in the first time, and it answers the questions that matter when you're not there: who to call, who the doctor is, what the kids are allergic to, where the insurance card is, and who takes care of them if you can't.")
    d.heading("How to use it")
    for item, note in [
        ("Do the first three sections tonight.", "In an emergency, The kids, and Medical. Those are the pages a sitter, a grandparent or a paramedic would reach for."),
        ("Keep codes off the paper.", "Gate codes, alarm codes, passwords and full account numbers never go in a binder. Write where they're kept instead, and tell the person in person."),
        ("Print three copies.", "One in the kitchen, one with the person you'd call first, one for the glove box. The fridge card in section 2 is the short version."),
        ("Tell someone it exists.", "A plan nobody knows about isn't a plan. The last page keeps a list of who has a copy."),
        ("Read it again every season.", "Sizes change, insurance renews, the sitter moves. Section 12 has a review log so you know when you last looked."),
    ]:
        d.check_item(item, note, hint=f"start {item}")
    d.y += 4
    d.heading("Who's in this house")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for i, x in enumerate([lx, rx]):
        d.y = y0
        d.label(f"Parent or guardian {i + 1}", x, d.y); d.y += 18
        for lab in ["Name", "Mobile", "Email", "Work phone"]:
            d.row(lab, x, lw, 70, h=25, hint=f"adult {i + 1} {lab}")
        end = d.y
    d.y = end + 4
    d.row("The kids, oldest first", ML, d.cw, 150, h=28, hint="kids names")
    d.row("Pets", ML, d.cw, 60, h=28, hint="pets")
    d.y += 6
    d.caption("The paper copy is the one that works when the phone is dead. The app builds the same file from your contacts and the camera and keeps it current.")


def is_it_done(d: Binder):
    d.page()
    d.title("Is it done?")
    d.intro("The same checklist the app uses for its completeness score. The heavier the weight, the more it matters that someone could find it. Tick each one as you fill it in.")
    groups = [
        ("In an emergency", [("Who to call first", 8), ("Second emergency contact", 3), ("Preferred hospital", 4), ("Home address", 5), ("Where the spare key is", 2), ("Vet or pet sitter", 0)]),
        ("Medical", [("Health insurance", 8), ("Each child's pediatrician", 6), ("Family doctor", 3), ("Pharmacy", 3), ("Dental insurance", 2)]),
        ("If something happens to us", [("Who would care for the kids", 8), ("Backup guardian", 3), ("Where the will is", 8), ("Attorney", 2), ("Financial advisor", 1), ("Life insurance", 3), ("Notes for whoever has the kids", 3)]),
        ("Accounts and money", [("Bank accounts", 7), ("Retirement accounts", 2), ("Mortgage or landlord", 3), ("Utilities", 2), ("Recurring bills", 1), ("Password manager", 3)]),
        ("Home and vehicles", [("Home or renters insurance", 4), ("Auto insurance", 3), ("Vehicles", 3)]),
    ]
    (lx, lw), (rx, rw) = d.two_col()
    col = 0; col_y = [d.y, d.y]
    for gi, (name, items) in enumerate(groups):
        if gi == 3: col = 1
        x = lx if col == 0 else rx; d.y = col_y[col]
        d.text(name, x, d.y + 14, SERIF, 15, INK); d.y += 24
        for item, weight in items:
            d.checkbox(x, d.y, hint=f"done {item}")
            d.text(item, x + 20, d.y + 10, SANS, 10.5, INK)
            d.text("optional" if weight == 0 else f"+{weight}", x + lw, d.y + 10, SANS, 9, SAND_DEEP, right=True)
            d.y += 19
        d.y += 10
        col_y[col] = d.y
    d.y = max(col_y) + 4
    d.box(ML, d.y, d.cw, 52, CREAM_DEEP)
    d.text("Add up the ticked weights. Out of 100.", ML + 14, d.y + 20, SANS, 11, INK)
    d.text("Score", ML + d.cw - 150, d.y + 20, SANS_SEMI, 11, INK)
    d.c.setStrokeColor(SAND_DEEP); d.c.line(ML + d.cw - 108, d.Y(d.y + 24), ML + d.cw - 14, d.Y(d.y + 24))
    d.field("done score", ML + d.cw - 106, d.y + 6, 90, 18)
    d.text("Date", ML + 14, d.y + 42, SANS_SEMI, 10, SAND_DEEP)
    d.c.line(ML + 44, d.Y(d.y + 44), ML + 200, d.Y(d.y + 44))
    d.field("done date", ML + 46, d.y + 28, 150, 16)
    d.y += 62
    d.app_line("The app scores this for you and tells you what to add next. petitehome.co")


def emergency(d: Binder):
    d.section("In an emergency")
    # The fridge card
    d.title("Who to call first")
    d.intro("The one-page version. Copy it for the fridge and the glove box.")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for lab, fields in [("If you can't reach us", ["Name", "Phone"]), ("The kids' doctor", ["Name", "Phone"]),
                        ("Health insurance", ["Carrier", "Member ID", "Phone on the card"]), ("If something happens to us", ["Guardian", "Phone"])]:
        d.text(lab, lx, d.y + 14, SERIF, 15, INK); d.y += 22
        for f in fields: d.row(f, lx, lw, 78, h=24, hint=f"fridge {lab} {f}")
        d.y += 6
    left_end = d.y
    d.y = y0
    d.text("The kids", rx, d.y + 14, SERIF, 15, INK); d.y += 24
    for i in range(3):
        d.row("Name", rx, rw, 50, h=22, hint=f"fridge child {i + 1} name"); d.row("Birthdate", rx, rw, 70, h=22, hint=f"fridge child {i + 1} birthdate")
        d.row("Allergies", rx, rw, 70, h=22, hint=f"fridge child {i + 1} allergies"); d.y += 4
    d.y += 4
    d.row("Our address", rx, rw, 86, h=24, hint="fridge address")
    d.y = max(left_end, d.y) + 10
    d.box(ML, d.y, d.cw, 56, CREAM_DEEP)
    d.text("Emergency: 911   ·   Poison Control (US): 1-800-222-1222   ·   Then call us.", ML + 14, d.y + 22, SANS, 10.5, INK)
    d.text("Nearest hospital", ML + 14, d.y + 44, SANS_SEMI, 10, SAND_DEEP)
    d.c.setStrokeColor(SAND_DEEP); d.c.line(ML + 110, d.Y(d.y + 46), ML + d.cw - 14, d.Y(d.y + 46))
    d.field("fridge hospital", ML + 112, d.y + 30, d.cw - 128, 16)
    d.y += 66
    d.caption("Stick this on the fridge. Put a second copy in the glove box.")
    # The full section
    d.page()
    d.title("In an emergency")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    d.heading("Who to call first", 18, lx, lw)
    d.rows(["Name", "Relationship", "Phone", "Email"], lx, lw, 90, prefix="call first")
    end = d.y; d.y = y0
    d.heading("Second contact", 18, rx, rw)
    d.rows(["Name", "Relationship", "Phone", "Email"], rx, rw, 90, prefix="call next")
    d.y = max(end, d.y)
    d.heading("Where we are")
    d.rows(["Home address", "", "Preferred hospital", "Hospital phone", "Nearest urgent care"], prefix="where we are")
    y0 = d.y
    d.heading("Pets", 18, lx, lw)
    d.rows(["Vet or pet sitter", "Phone", "Feeding and meds"], lx, lw, 90, prefix="pets")
    end = d.y; d.y = y0
    d.heading("Keys and codes", 18, rx, rw)
    d.row("Spare key", rx, rw, 70, hint="spare key")
    d.row("Gate code lives", rx, rw, 100, hint="gate code location"); d.row("Alarm code lives", rx, rw, 100, hint="alarm code location")
    d.y = max(end, d.y) + 6
    d.note_box("Gate and alarm codes don't go on paper. Write where they're kept, or tell the person in person. The app keeps them in a vault that opens with Face ID.", strong=None)


def the_kids(d: Binder):
    d.section("The kids")
    for i in range(3):
        if i: d.page()
        d.title(f"Child {i + 1}" if i else "The kids")
        if not i: d.caption("One page per child. A sitter, a grandparent or a paramedic should be able to read it in a minute.")
        p = f"child {i + 1}"
        (lx, lw), (rx, rw) = d.two_col()
        y0 = d.y
        d.row("Name", lx, lw, 60, h=26, hint=f"{p} name"); d.row("Birthdate", lx, lw, 70, h=26, hint=f"{p} birthdate")
        end = d.y; d.y = y0
        d.row("Blood type", rx, rw, 76, h=26, hint=f"{p} blood type"); d.row("Weight (date)", rx, rw, 90, h=26, hint=f"{p} weight")
        d.y = max(end, d.y)
        d.heading("Doctor", 16)
        y0 = d.y
        d.row("Pediatrician", lx, lw, 84, h=26, hint=f"{p} pediatrician"); d.row("Phone", lx, lw, 50, h=26, hint=f"{p} pediatrician phone")
        end = d.y; d.y = y0
        d.row("Practice", rx, rw, 60, h=26, hint=f"{p} practice"); d.row("Dentist", rx, rw, 56, h=26, hint=f"{p} dentist")
        d.y = max(end, d.y)
        d.heading("Allergies and medications", 16)
        d.row("Allergies", hint=f"{p} allergies", h=26); d.row("Reaction and what to do", label_w=150, hint=f"{p} allergy reaction", h=26)
        d.y += 4
        d.table([("Medication", 0.34), ("Dose", 0.22), ("When", 0.24), ("Where it's kept", 0.20)], 2, h=24, hint=f"{p} med")
        d.heading("School or daycare", 16)
        y0 = d.y
        d.row("Name", lx, lw, 50, h=26, hint=f"{p} school"); d.row("Phone", lx, lw, 50, h=26, hint=f"{p} school phone")
        end = d.y; d.y = y0
        d.row("Teacher or room", rx, rw, 100, h=26, hint=f"{p} teacher"); d.row("Pickup list", rx, rw, 80, h=26, hint=f"{p} pickup list")
        d.y = max(end, d.y)
        d.heading("Sizes, with the date", 16)
        y0 = d.y
        d.row("Clothing", lx, lw, 60, h=26, hint=f"{p} clothing size"); d.row("Shoes", lx, lw, 60, h=26, hint=f"{p} shoe size")
        end = d.y; d.y = y0
        d.row("Diapers", rx, rw, 60, h=26, hint=f"{p} diaper size"); d.row("Car seat", rx, rw, 60, h=26, hint=f"{p} car seat")
        d.y = max(end, d.y)
        d.heading("What calms them, what they love, what to know", 16)
        d.lines(3, h=22, hint=f"{p} notes")


def medical(d: Binder):
    d.section("Medical")
    d.title("Medical")
    d.intro("The card numbers printed on the front of the card, never a credential. A photo of the card lives in the app's vault.")
    d.heading("Health insurance")
    d.rows(["Carrier", "Member ID", "Group number", "Phone on the card", "Whose name it's in", "Renews"], prefix="health insurance")
    d.heading("Dental insurance")
    d.rows(["Carrier", "Member ID", "Phone on the card"], prefix="dental insurance")
    d.heading("Vision")
    d.rows(["Carrier", "Member ID"], prefix="vision insurance")
    d.page()
    d.title("Doctors and pharmacy")
    d.heading("Family doctor")
    d.rows(["Name and practice", "Phone", "Address"], prefix="family doctor")
    d.heading("Pharmacy")
    d.rows(["Name", "Phone", "Address"], prefix="pharmacy")
    d.heading("Grown-ups")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for i, x in enumerate([lx, rx]):
        d.y = y0
        d.label(f"Parent or guardian {i + 1}", x, d.y); d.y += 18
        for lab in ["Doctor", "Phone", "Allergies", "Medications", "Blood type"]:
            d.row(lab, x, lw, 80, h=25, hint=f"adult {i + 1} medical {lab}")
        end = d.y
    d.y = end
    d.heading("Specialists and therapists")
    d.table([("Who", 0.30), ("For", 0.30), ("Phone", 0.22), ("Next visit", 0.18)], 3, h=24, hint="specialist")
    d.app_line("Premium reminds you before insurance renews and before prescriptions run out. petitehome.co")


def if_something_happens(d: Binder):
    d.section("If something happens to us")
    d.title("If something happens to us")
    d.intro("This isn't legal paperwork. It's so the people who love you know what you'd want, without having to guess.")
    d.heading("Who would care for the kids")
    d.rows(["Name", "Relationship", "Phone", "Address"], prefix="guardian"); d.row("Why them", label_w=90, hint="guardian why"); d.lines(1, hint="guardian why more")
    d.heading("A backup, in case")
    d.rows(["Name", "Relationship", "Phone"], prefix="backup guardian"); d.row("Why them", label_w=90, hint="backup why")
    d.heading("Have we told them?")
    d.inline("told", [("We talked to our first choice on", 110), (" and the backup on", 110), (".", 0)], hint="told dates")
    d.page()
    d.title("What we'd want for the kids")
    d.intro("Short answers are fine. The point is that someone knows.")
    for prompt in ["Where they'd live", "School", "Faith or traditions", "The people we'd want in their lives", "What we'd want them to know about us"]:
        d.text(prompt, ML, d.y + 12, SANS_SEMI, 11, INK); d.y += 18; d.lines(3, h=23, hint=f"wishes {prompt}"); d.y += 8
    d.page()
    d.title("Papers and people")
    d.heading("The will")
    d.rows(["Where the original is", "Who has a copy", "Date signed"], label_w=140, prefix="will")
    d.heading("Attorney")
    d.rows(["Name and firm", "Phone"], prefix="attorney")
    d.heading("Financial advisor")
    d.rows(["Name and firm", "Phone"], prefix="advisor")
    d.heading("Life insurance")
    d.table([("Carrier", 0.30), ("Policy number", 0.26), ("Whose life", 0.20), ("Agent's phone", 0.24)], 2, h=24, hint="life insurance")
    d.heading("For whoever has the kids")
    d.caption("Routines, comfort items, the things only you'd know. Bedtime words, the stuffed animal, what a bad day looks like.")
    d.lines(3, h=22, hint="instructions for kids")


def accounts(d: Binder):
    d.section("Accounts and money")
    d.title("Accounts and money")
    d.intro("Institution, what it's for, whose name, and the last four digits. Never a full account number, never a password. Write where the login lives.")
    d.heading("Bank accounts")
    d.table([("Institution", 0.30), ("What it's for", 0.26), ("Whose", 0.18), ("Last 4", 0.12), ("Login lives in", 0.14)], 4, h=24, hint="bank")
    d.heading("Retirement and investments")
    d.table([("Institution", 0.30), ("Type (401k, IRA, 529)", 0.26), ("Whose", 0.18), ("Last 4", 0.12), ("Login lives in", 0.14)], 4, h=24, hint="retirement")
    d.heading("Mortgage or landlord")
    d.rows(["Who the payment goes to", "Phone", "Due on the", "Where the lease or deed is"], label_w=160, prefix="mortgage")
    d.page()
    d.title("Bills that keep the lights on")
    d.heading("Utilities")
    d.table([("Service (power, gas, water, internet)", 0.40), ("Company", 0.30), ("Last 4", 0.12), ("Paid how", 0.18)], 5, h=24, hint="utility")
    d.heading("Recurring bills and subscriptions")
    d.table([("What", 0.34), ("Company", 0.26), ("Amount", 0.14), ("When", 0.12), ("Cancel how", 0.14)], 6, h=24, hint="bill")
    d.heading("Password manager")
    d.rows(["Which one we use", "Where the master password is", "Who else can open it"], label_w=190, prefix="password manager")
    d.y += 4
    d.note_box("Never write the master password here. Say where it is.", strong="Never")


def home_and_vehicles(d: Binder):
    d.section("Home and vehicles")
    d.title("Home and vehicles")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    d.heading("Home or renters insurance", 18, lx, lw)
    d.rows(["Carrier", "Policy number", "Phone", "Renews"], lx, lw, 90, prefix="home insurance")
    end = d.y; d.y = y0
    d.heading("Auto insurance", 18, rx, rw)
    d.rows(["Carrier", "Policy number", "Phone", "Renews"], rx, rw, 90, prefix="auto insurance")
    d.y = max(end, d.y)
    d.heading("Vehicles")
    y0 = d.y
    for i, x in enumerate([lx, rx]):
        d.y = y0
        d.label(f"Vehicle {i + 1}", x, d.y); d.y += 18
        for lab in ["Year, make, model", "Plate", "Registration renews", "Where the title is", "Loan servicer"]:
            d.row(lab, x, lw, 100, h=24, hint=f"vehicle {i + 1} {lab}")
        end = d.y
    d.y = end
    d.heading("Where things are")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for lab in ["Water shutoff", "Breaker panel", "Gas shutoff"]: d.row(lab, lx, lw, 90, h=26, hint=f"house {lab}")
    end = d.y; d.y = y0
    for lab in ["Important papers", "Fire extinguisher", "First-aid kit"]: d.row(lab, rx, rw, 100, h=26, hint=f"house {lab}")
    d.y = max(end, d.y)
    d.heading("People who know the house")
    d.table([("Who (neighbor, plumber, landlord, cleaner)", 0.46), ("For", 0.26), ("Phone", 0.28)], 2, h=24, hint="house people")


def documents(d: Binder):
    d.section("Documents")
    d.title("Where the originals are")
    d.intro("Not the documents themselves: where they are. A binder gets left on a counter. The app's vault holds the photos, encrypted on the phone before they're stored.")
    d.table([("Document", 0.34), ("Whose", 0.18), ("Where the original is", 0.30), ("Expires", 0.18)], 0, h=24, hint="doc header")
    d.y -= 2
    docs = ["Birth certificates", "Social Security cards", "Passports", "Marriage certificate", "Insurance cards", "Immunization records",
            "Vehicle titles", "Deed or lease", "The will and powers of attorney", "Custody or adoption papers", "", ""]
    for r, name in enumerate(docs):
        if name: d.text(name, ML, d.y + 16, SANS, 10.5, INK)
        else: d.field(f"doc name {r}", ML + 1, d.y + 3, d.cw * 0.34 - 8, 16)
        for frac0, frac in [(0.34, 0.18), (0.52, 0.30), (0.82, 0.18)]:
            d.field(f"doc {name or r} {frac0}", ML + d.cw * frac0 + 1, d.y + 3, d.cw * frac - 8, 16)
        d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(ML, d.Y(d.y + 24), ML + d.cw, d.Y(d.y + 24)); d.y += 24
    d.y += 8
    d.note_box("A safe-deposit box only helps if someone else is on the signature card. Write who.", strong=None)
    d.row("Who else can open the safe or box", label_w=210, hint="safe access")
    d.page()
    d.title("What's coming due")
    d.intro("Passports, car seats, registrations, prescriptions, insurance. The app reminds you a month out; the binder needs you to look. The monthly job in section 12 is this page.")
    d.table([("What", 0.34), ("Whose", 0.18), ("Expires", 0.18), ("Reminder set", 0.15), ("Done", 0.15)], 13, h=26, hint="expiring")
    d.y += 6
    d.app_line("Premium keeps this for you: reminders before anything expires, and the documents behind Face ID. petitehome.co")


def sitter(d: Binder):
    d.section("The sitter sheet")
    d.title("The sitter sheet", gap=8)
    d.caption("Fill it once, photocopy it, write tonight's times on the copy. Never codes or account details.")
    d.inline("out", [("We'll be out from", 70), (" to", 70), (" at", 160), (". Back by", 70), (".", 0)], hint="sitter tonight")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    d.box(ML, y0, d.cw, 64, BLUE_MIST)
    d.label("Reach us", ML + 14, y0 + 6)
    d.y = y0 + 18
    d.row("Parent 1", ML + 14, lw - 14, 60, h=21, hint="sitter parent 1"); d.row("Parent 2", ML + 14, lw - 14, 60, h=21, hint="sitter parent 2")
    d.y = y0 + 18
    d.row("Backup", rx, rw - 14, 56, h=21, hint="sitter backup"); d.row("Our address", rx, rw - 14, 80, h=21, hint="sitter address")
    d.y = y0 + 64 + 2
    d.heading("The kids", 16)
    d.table([("Name, age", 0.18), ("Bedtime", 0.14), ("Allergies", 0.20), ("Meds and when", 0.24), ("What calms them", 0.24)], 3, h=22, hint="sitter kid")
    y0 = d.y
    d.heading("Tonight's routine", 16, lx, lw)
    for step in ["Dinner", "Bath", "Pajamas and teeth", "Books", "Lights out", "If they wake up"]:
        d.label(step, lx, d.y + 5, size=7.5); d.row("", lx + 92, lw - 92, 0, h=20, hint=f"sitter routine {step}")
    left_end = d.y; d.y = y0
    d.heading("Where things are", 16, rx, rw)
    for thing in ["Snacks and water", "Diapers and wipes", "First-aid kit", "Thermometer", "Flashlight", "Spare clothes"]:
        d.label(thing, rx, d.y + 5, size=7.5); d.row("", rx + 96, rw - 96, 0, h=20, hint=f"sitter where {thing}")
    d.y = max(left_end, d.y)
    d.heading("House rules", 16)
    for rule_text in ["Screens", "Treats", "Doors, yard, pets"]:
        d.row(rule_text, label_w=110, h=22, hint=f"sitter rule {rule_text}")
    d.y += 4
    d.box(ML, d.y, d.cw, 58, CREAM_DEEP)
    d.label("If something's wrong", ML + 14, d.y + 8)
    d.text("Pediatrician", ML + 14, d.y + 34, SANS_SEMI, 10, INK); d.c.setStrokeColor(SAND_DEEP); d.c.line(ML + 76, d.Y(d.y + 36), ML + 230, d.Y(d.y + 36))
    d.field("sitter pediatrician", ML + 78, d.y + 20, 150, 16)
    d.text("Hospital", ML + 250, d.y + 34, SANS_SEMI, 10, INK); d.c.line(ML + 296, d.Y(d.y + 36), ML + d.cw - 14, d.Y(d.y + 36))
    d.field("sitter hospital", ML + 298, d.y + 20, d.cw - 312, 16)
    d.text("Poison Control (US): 1-800-222-1222   ·   Emergency: 911   ·   Then call us.", ML + 14, d.y + 50, SANS, 10, INK)
    d.y += 58 + 8
    d.text("Never", ML, d.y + 9, SANS_SEMI, 9, DANGER)
    d.text("write alarm or gate codes here. Tell the sitter in person.", ML + pdfmetrics.stringWidth("Never ", SANS_SEMI, 9), d.y + 9, SANS, 9, SAND_DEEP)
    d.text("The app fills this in from your Family File and texts it to the sitter in one tap. petitehome.co", ML, d.y + 24, SANS_IT, 9.5, BLUE_DK)


def routines(d: Binder):
    d.section("Routines")
    days = ["M", "T", "W", "T", "F", "S", "S"]

    def chart(title, steps, blank=False, key=""):
        d.text(title, ML, d.y + 18, SERIF, 22, INK); d.y += 30
        step_w = d.cw - 7 * 24 - 70
        d.label("Draw it", ML, d.y, size=7); d.label("Step", ML + 60, d.y, size=7)
        for i, day in enumerate(days): d.text(day, ML + 60 + step_w + i * 24 + 12, d.y + 8, SANS_SEMI, 8, SAND_DEEP, center=True)
        d.y += 14
        for i, step in enumerate(steps):
            y = d.y; rh = 50
            d.box(ML, y, d.cw, rh - 4, CREAM_DEEP if i % 2 == 0 else CREAM_TINT, 8)
            d.c.setStrokeColor(SAND); d.c.setLineWidth(0.8); d.c.roundRect(ML + 8, d.Y(y + rh - 8), 50, rh - 12, 6, stroke=1, fill=0)
            if blank:
                d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7); d.c.line(ML + 68, d.Y(y + 30), ML + 56 + step_w, d.Y(y + 30))
                d.field(f"routine {key} step {i + 1}", ML + 70, y + 12, step_w - 16, 18, size=11)
            else:
                d.text(step, ML + 68, y + 29, SANS_SEMI, 12, INK)
            for k in range(7):
                d.form.checkbox(name=d._name(f"routine {key} {i + 1} day {k + 1}"), x=ML + 60 + step_w + k * 24 + 5, y=d.Y(y + rh - 16), size=14,
                                buttonStyle="check", borderColor=SAND, fillColor=WHITE, textColor=INK, borderWidth=1, fieldFlags="")
            d.y += rh
        d.y += 4
        d.row("When a row is full", label_w=120, h=26, hint=f"routine {key} reward")

    d.title("Our routines", 30)
    d.intro("Kids follow a chart they can see better than a voice they tune out. Let them draw each step in the first box, then tick the day when it's done. Copy the page each week.")
    chart("Morning", MORNING, key="morning")
    d.page(); d.title("Our routines", 30)
    d.intro("Bedtime goes the same way every night: same order, same words.")
    chart("Bedtime", BEDTIME, key="bedtime")
    d.page(); d.title("Make your own", 30)
    d.intro("A blank chart for the afternoon, the weekend, or a different kid. Seven steps is the most a chart should carry.")
    d.row("Chart for", label_w=80, h=28, hint="routine custom title")
    chart("", ["" for _ in range(7)], blank=True, key="custom")


def the_week(d: Binder):
    d.section("The week")
    d.title("The week on one page")
    d.caption("Five minutes on Sunday night: who's where, which nights need a sitter, what's for dinner. Copy it each week.")
    d.row("Week of", label_w=70, h=26, hint="week of")
    d.y += 4
    cols = [("", 0.12), ("Parent 1", 0.26), ("Parent 2", 0.26), ("Kids", 0.20), ("Dinner", 0.16)]
    xx = ML; xs = []
    for name, frac in cols:
        if name: d.label(name, xx, d.y, size=7.5)
        xs.append((xx, d.cw * frac)); xx += d.cw * frac
    d.y += 14; d.hr(); d.y += 2
    rh = 48
    for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]:
        d.text(day, ML, d.y + 16, SANS_SEMI, 10.5, INK)
        d.checkbox(ML, d.y + 26, hint=f"week {day} sitter"); d.text("sitter", ML + 16, d.y + 36, SANS, 8, SAND_DEEP)
        for (x, w), (name, _) in list(zip(xs, cols))[1:]:
            d.field(f"week {day} {name}", x + 1, d.y + 3, w - 8, rh - 8, multiline=True, size=9)
            d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(x - 4, d.Y(d.y), x - 4, d.Y(d.y + rh))
        d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(ML, d.Y(d.y + rh), ML + d.cw, d.Y(d.y + rh))
        d.y += rh
    d.y += 8
    d.heading("This week's house tasks", 16)
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for i in range(4): d.checkbox(lx, d.y, hint=f"week task {i + 1}"); d.row("", lx + 20, lw - 20, 0, h=22, hint=f"week task {i + 1} text")
    end = d.y; d.y = y0
    for i in range(4, 8): d.checkbox(rx, d.y, hint=f"week task {i + 1}"); d.row("", rx + 20, rw - 20, 0, h=22, hint=f"week task {i + 1} text")
    d.y = max(end, d.y)
    d.app_line("The Planner shows both partners' calendars, the chores, meals and plans on one week, and finds the free evenings. petitehome.co")


def household_rhythm(d: Binder):
    d.section("The household rhythm")
    d.title("The household rhythm")
    d.intro("The recurring jobs that keep a house with kids running, at the cadence the app suggests. Write who owns each one and the next date, tick it when it's done, and move the date.")
    groups = [
        ("Every day", [("Plan dinner", "What's for dinner, who's cooking, does anything need to come out of the freezer."),
                       ("Ten-minute tidy", "Kitchen counters, the floor where the kids were. Ten minutes, then stop.")]),
        ("Every week", [("Plan the week together", "Five minutes on Sunday night: who's where, which nights need a sitter, dinners."),
                        ("Grocery run", "The shopping list writes itself from the week's recipes.")]),
        ("Every month", [("Look at what's coming due", "Passports, insurance, registration. Section 8 lists them."),
                         ("Check car seat straps and fit", "Pinch test at the collarbone. Chest clip at armpit level.")]),
        ("A few times a year", [("Change the furnace filter", "Every three months. Write the size on the filter housing."),
                                ("Replace smoke detector batteries", "Every six months, every detector, including the basement and garage."),
                                ("Renew car registration", "Every year."),
                                ("Review insurance coverage", "Every year. Life, home, auto. Has anything changed?"),
                                ("Each child's well-child visit", "Book it around the birthday.")]),
    ]
    for name, items in groups:
        d.text(name, ML, d.y + 14, SERIF, 16, INK)
        d.label("Who", ML + d.cw - 190, d.y + 6, size=7); d.label("Next", ML + d.cw - 100, d.y + 6, size=7); d.label("Done", ML + d.cw - 28, d.y + 6, size=7)
        d.y += 22
        for item, note in items:
            y = d.y
            d.text(item, ML, y + 11, SANS_SEMI, 10.5, INK)
            d.text(note, ML, y + 24, SANS, 8.5, SAND_DEEP)
            d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7)
            d.c.line(ML + d.cw - 190, d.Y(y + 14), ML + d.cw - 112, d.Y(y + 14)); d.field(f"rhythm {item} who", ML + d.cw - 189, y - 1, 76, 15)
            d.c.line(ML + d.cw - 100, d.Y(y + 14), ML + d.cw - 40, d.Y(y + 14)); d.field(f"rhythm {item} next", ML + d.cw - 99, y - 1, 58, 15)
            d.checkbox(ML + d.cw - 24, y, hint=f"rhythm {item} done")
            d.y += 29
        d.y += 0
    d.heading("Ours", 16)
    d.caption("The jobs only your house has.")
    for i in range(2):
        y = d.y
        d.field(f"rhythm custom {i + 1}", ML + 1, y, d.cw - 200, 16)
        d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7); d.c.line(ML, d.Y(y + 14), ML + d.cw - 200, d.Y(y + 14))
        d.c.line(ML + d.cw - 190, d.Y(y + 14), ML + d.cw - 112, d.Y(y + 14)); d.field(f"rhythm custom {i + 1} who", ML + d.cw - 189, y - 1, 76, 15)
        d.c.line(ML + d.cw - 100, d.Y(y + 14), ML + d.cw - 40, d.Y(y + 14)); d.field(f"rhythm custom {i + 1} next", ML + d.cw - 99, y - 1, 58, 15)
        d.checkbox(ML + d.cw - 24, y, hint=f"rhythm custom {i + 1} done")
        d.y += 24
    d.app_line("The app rolls each of these forward on its own, mirrors them into the Reminders app, and tells your partner when one is added. petitehome.co")


def keep_it_current(d: Binder):
    d.section("Keep it current")
    d.title("Who has a copy")
    d.intro("A plan nobody knows about isn't a plan. Write down who has this binder, or the fridge card, and when you gave it to them.")
    d.table([("Who", 0.34), ("What they have", 0.30), ("Given on", 0.18), ("Updated on", 0.18)], 5, h=26, hint="copy holder")
    d.heading("Review log")
    d.caption("Read it again every season. Note what changed so the other copies can catch up, and shred the old pages.")
    d.table([("Date", 0.18), ("What changed", 0.58), ("Copies updated", 0.24)], 6, h=26, hint="review")


def closing(d: Binder):
    d.section_title = ""
    d.page()
    d.y = 150
    d.text("Done on paper?", ML, d.y + 30, SERIF, 34, INK); d.y += 56
    d.para("The Petite Home app keeps this same file current, syncs it with your partner, and shares it with a guardian through a link that updates itself whenever you edit. It fills in from your contacts and reads insurance cards with the camera, so the twenty minutes you just spent is the last time you type it.", size=12, color=INK, leading=18)
    d.y += 18
    d.heading("What the app adds", 18)
    for item, note in [
        ("The Family File, free.", "The first eight sections of this binder, on the phone, with a completeness score and a standing link for the guardian."),
        ("Reminders before things expire.", "Passports, car seats, prescriptions, insurance and registration, a month out."),
        ("A vault that opens with Face ID.", "Birth certificates, Social Security cards, the cards themselves. Encrypted on the phone before it's stored."),
        ("The Planner for two.", "Both calendars, the chores, meals and plans on one week. A free-evening finder that checks both calendars. The sitter sheet, sent by text."),
        ("A printed binder, when you want one.", "The app renders your filled-in Family File and the website prints and mails it, bound and tabbed."),
    ]:
        d.text("•", ML, d.y + 12, SANS, 12, BLUE_DK)
        d.text(item, ML + 16, d.y + 12, SANS_SEMI, 11.5, INK); d.y += 17
        d.para(note, ML + 16, d.y, d.cw - 16, SANS, 10.5, SAND_DEEP); d.y += 10
    d.y += 14
    d.box(ML, d.y, d.cw, 78, BLUE_MIST)
    d.text("petitehome.co", ML + 18, d.y + 32, SERIF, 22, INK)
    d.text("Private by design. No login, no account. Your data lives in your own iCloud; we never see it.", ML + 18, d.y + 58, SANS, 10.5, SAND_DEEP)
    d.c.linkURL("https://petitehome.co", (ML, d.Y(d.y + 78), ML + d.cw, d.Y(d.y)), relative=0, thickness=0)
    d.y += 100
    d.text("Less to question. More to trust.", ML, d.y, SANS_IT, 11, BLUE_DK)


SECTIONS = [
    ("Start here", lambda d: (start_here(d), is_it_done(d))),
    ("In an emergency", emergency),
    ("The kids", the_kids),
    ("Medical", medical),
    ("If something happens to us", if_something_happens),
    ("Accounts and money", accounts),
    ("Home and vehicles", home_and_vehicles),
    ("Documents", documents),
    ("The sitter sheet", sitter),
    ("Routines", routines),
    ("The week", the_week),
    ("The household rhythm", household_rhythm),
    ("Keep it current", keep_it_current),
]
SECTION_SHORT = {"If something happens to us": "If something happens", "The household rhythm": "Rhythm", "Accounts and money": "Money", "Home and vehicles": "Home"}
SECTION_BLURB = {
    "Start here": "How to use it, who's in the house, and the completeness checklist",
    "In an emergency": "The fridge card, who to call, the hospital, the address",
    "The kids": "A page per child: doctor, allergies, meds, school, sizes, what calms them",
    "Medical": "Insurance, doctors, pharmacy, the grown-ups too",
    "If something happens to us": "Who would care for the kids, what you'd want, where the will is",
    "Accounts and money": "Banks, retirement, the mortgage, utilities, bills, the password manager",
    "Home and vehicles": "Insurance, the cars, where the shutoffs are, who knows the house",
    "Documents": "Where the originals are and what's coming due",
    "The sitter sheet": "Fill once, photocopy, hand over at the door",
    "Routines": "Morning and bedtime charts the kids tick themselves",
    "The week": "Who's where, which nights need a sitter, dinner",
    "The household rhythm": "The recurring jobs, daily to yearly, with an owner",
    "Keep it current": "Who has a copy and when you last reviewed it",
}


def build(path, toc_numbers=None):
    d = Binder(path)
    d.toc_numbers = toc_numbers or {}
    cover(d)
    contents(d)
    for _, builder in SECTIONS:
        builder(d)
    closing(d)
    d.save()
    return d


def main():
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{SLUG}.pdf")
    first = build(path)                                  # pass 1: learn where each section lands
    numbers = dict(first.sections)
    final = build(path, numbers)                         # pass 2: the contents page carries the numbers
    assert dict(final.sections) == numbers, "section pages moved between passes"
    print(f"wrote {os.path.relpath(path, HERE)}: {final.pages} pages, {final.field_count} form fields")
    if "--preview" in sys.argv:
        import pypdfium2 as pdfium
        out = os.path.join(HERE, "preview"); os.makedirs(out, exist_ok=True)
        pdf = pdfium.PdfDocument(path); pdf.init_forms()
        for i in range(len(pdf)):
            pdf[i].render(scale=1.2, may_draw_forms=True).to_pil().save(os.path.join(out, f"{SLUG}-{i + 1:02d}.png"))
        print("previews in", out)


if __name__ == "__main__":
    main()
