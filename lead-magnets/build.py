#!/usr/bin/env python3
"""Builds the twelve Petite Home lead-magnet PDFs described in docs/lead-magnets.md.

    python3 lead-magnets/build.py            # writes lead-magnets/pdf/<slug>.pdf
    python3 lead-magnets/build.py --preview  # also writes PNG previews of every page

Everything is drawn on a reportlab canvas with the brand tokens from
PetiteHome/Design/Theme.swift (light values). Fonts are embedded: Fraunces
(static instances cut from the app's variable TTF) and Source Sans Pro.
"""
import os, sys
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import simpleSplit
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "pdf")
FONTS = os.path.join(HERE, "fonts")

# ---------- tokens ----------
CREAM, CREAM_DEEP, CREAM_TINT = HexColor("#FCF8F2"), HexColor("#F2E7D8"), HexColor("#F8EFE4")
BLUE, BLUE_DK, BLUE_MIST = HexColor("#A9CBDD"), HexColor("#3F6379"), HexColor("#E7EFF4")
SAND, SAND_DEEP, RULE, INK = HexColor("#C9B69A"), HexColor("#6E6259"), HexColor("#E6DBCC"), HexColor("#2B2420")
DANGER, WHITE = HexColor("#A8584A"), HexColor("#FFFFFF")

SERIF, SERIF_TEXT, SERIF_SEMI = "Fraunces-Display", "Fraunces-Text", "Fraunces-Semi"
SANS, SANS_SEMI, SANS_IT = "SourceSans", "SourceSans-Semibold", "SourceSans-It"
for name, file in [(SERIF, "Fraunces-Display.ttf"), (SERIF_TEXT, "Fraunces-Text.ttf"), (SERIF_SEMI, "Fraunces-Semi.ttf"),
                   (SANS, "SourceSansPro-Regular.ttf"), (SANS_SEMI, "SourceSansPro-Semibold.ttf"), (SANS_IT, "SourceSansPro-It.ttf")]:
    pdfmetrics.registerFont(TTFont(name, os.path.join(FONTS, file)))

LETTER = (612, 792)
M = 56
FOOTER = "Made with Petite Home · petitehome.co"


class Doc:
    """A canvas with a top-down cursor and the brand's drawing vocabulary."""

    def __init__(self, slug, title, subject):
        os.makedirs(OUT, exist_ok=True)
        self.path = os.path.join(OUT, f"{slug}.pdf")
        self.c = canvas.Canvas(self.path, pagesize=LETTER)
        self.c.setTitle(title); self.c.setAuthor("Petite Home Co."); self.c.setSubject(subject)
        self.c.setCreator("Petite Home lead-magnet builder")
        self.pages = 0
        self.w, self.h = LETTER
        self.y = M

    # ----- pages -----
    def page(self, landscape=False, cover=False):
        if self.pages:
            self._footer()
            self.c.showPage()
        self.w, self.h = (LETTER[1], LETTER[0]) if landscape else LETTER
        self.c.setPageSize((self.w, self.h))
        self.pages += 1
        self.c.setFillColor(CREAM); self.c.rect(0, 0, self.w, self.h, stroke=0, fill=1)
        self.y = M
        if not cover:
            self.wordmark()
            self.y = M + 34
        return self

    def _footer(self):
        c = self.c
        c.setFont(SANS, 9); c.setFillColor(SAND_DEEP)
        c.drawString(M, M - 24, FOOTER)
        if self.pages > 1 or getattr(self, "_multi", False):
            c.drawRightString(self.w - M, M - 24, str(self.pages))

    def save(self, multi=None):
        if multi is not None: self._multi = multi
        self._footer()
        self.c.showPage(); self.c.save()
        return self.path

    @property
    def cw(self): return self.w - 2 * M

    # ----- primitives (y is measured from the top) -----
    def Y(self, y): return self.h - y

    def text(self, s, x, y, font=SANS, size=11, color=INK, space=0, right=False, center=False):
        c = self.c; c.setFont(font, size); c.setFillColor(color)
        if right: c.drawRightString(x, self.Y(y), s, charSpace=space)
        elif center: c.drawCentredString(x, self.Y(y), s, charSpace=space)
        else: c.drawString(x, self.Y(y), s, charSpace=space)

    def para(self, s, x=None, y=None, w=None, font=SANS, size=11, color=INK, leading=None, advance=True):
        x = M if x is None else x; y = self.y if y is None else y; w = self.cw if w is None else w
        leading = leading or size * 1.45
        lines = simpleSplit(s, font, size, w)
        for i, line in enumerate(lines):
            self.text(line, x, y + size + i * leading, font, size, color)
        used = len(lines) * leading
        if advance: self.y = y + used
        return used

    def wordmark(self, x=None, y=None, size=14):
        self.text("PETITE HOME CO.", M if x is None else x, (M if y is None else y) + size, SERIF_TEXT, size, BLUE_DK, space=size * 0.3)

    def title(self, s, size=40, gap=14):
        self.y += 6
        self.text(s, M, self.y + size * 0.78, SERIF, size, INK)
        self.y += size * 0.78 + gap

    def intro(self, s, color=SAND_DEEP, size=11):
        self.para(s, font=SANS, size=size, color=color); self.y += 14

    def heading(self, s, size=22, x=None, w=None):
        x = M if x is None else x; w = self.cw if w is None else w
        self.y += 10
        self.text(s, x, self.y + size * 0.78, SERIF, size, INK)
        self.y += size * 0.78 + 8
        self.hr(x, w); self.y += 10

    def hr(self, x=None, w=None, color=RULE):
        x = M if x is None else x; w = self.cw if w is None else w
        self.c.setStrokeColor(color); self.c.setLineWidth(1); self.c.line(x, self.Y(self.y), x + w, self.Y(self.y))

    def label(self, s, x, y, color=SAND_DEEP, size=9):
        self.text(s.upper(), x, y + size, SANS_SEMI, size, color, space=size * 0.16)

    def row(self, label_text, x=None, w=None, label_w=120, y=None, h=28):
        """Label on the left, a write-on line to the right."""
        x = M if x is None else x; w = self.cw if w is None else w; y = self.y if y is None else y
        if label_text:
            self.label(label_text, x, y + 8)
            need = pdfmetrics.stringWidth(label_text.upper(), SANS_SEMI, 9) + len(label_text) * 9 * 0.16 + 10
            label_w = max(label_w, need)
        lx = x + (label_w if label_text else 0)
        self.c.setStrokeColor(SAND_DEEP); self.c.setLineWidth(0.8)
        self.c.line(lx, self.Y(y + h - 6), x + w, self.Y(y + h - 6))
        self.y = y + h
        return self.y

    def rows(self, labels, x=None, w=None, label_w=120, h=28):
        for l in labels: self.row(l, x, w, label_w, h=h)

    def lines(self, n, x=None, w=None, h=24):
        for _ in range(n): self.row("", x, w, 0, h=h)

    def box(self, x, y, w, h, fill=CREAM_DEEP, radius=10, stroke=None):
        self.c.setFillColor(fill)
        if stroke: self.c.setStrokeColor(stroke); self.c.setLineWidth(1)
        self.c.roundRect(x, self.Y(y + h), w, h, radius, stroke=1 if stroke else 0, fill=1)

    def checkbox(self, x, y, label_text=None, font=SANS, size=11, color=INK, w=None):
        self.c.setStrokeColor(SAND); self.c.setLineWidth(1); self.c.setFillColor(WHITE)
        self.c.roundRect(x, self.Y(y + 12), 12, 12, 3, stroke=1, fill=1)
        if label_text:
            lines = simpleSplit(label_text, font, size, (w or (M + self.cw - x - 20)))
            for i, line in enumerate(lines): self.text(line, x + 20, y + 10 + i * size * 1.3, font, size, color)
            return max(1, len(lines)) * size * 1.3
        return 12

    def check_item(self, label_text, note=None, x=None, w=None, h=None):
        x = M if x is None else x; w = self.cw if w is None else w
        used = self.checkbox(x, self.y, label_text, w=w - 20)
        self.y += used + 2
        if note:
            self.para(note, x + 20, self.y, w - 20, SANS, 9.5, SAND_DEEP); self.y += 2
        self.y += (h or 6)

    def caption(self, s, x=None, w=None, color=SAND_DEEP, size=9):
        self.para(s, x, None, w, SANS, size, color); self.y += 4

    def note_box(self, s, x=None, w=None, fill=BLUE_MIST, size=11, strong=None):
        """A tinted box of copy. `strong` is a word rendered in danger color at the start."""
        x = M if x is None else x; w = self.cw if w is None else w
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

    def cover(self, title, subtitle, band_text, line=None, date_line="Filled in on"):
        self.page(cover=True)
        self.wordmark()
        self.text(title, M, 260 + 32, SERIF, 40, INK)
        self.text(subtitle, M, 322 + 12, SANS, 15, SAND_DEEP)
        self.text(f"{date_line} ______________________", M, 352 + 9, SANS, 12, SAND_DEEP)
        if line: self.para(line, M, 380, self.cw, SANS, 12, SAND_DEEP, advance=False)
        band_h = self.h / 3
        self.c.setFillColor(BLUE); self.c.rect(0, 0, self.w, band_h, stroke=0, fill=1)
        lines = simpleSplit(band_text, SERIF_TEXT, 16, self.cw)
        for i, l in enumerate(lines):
            self.text(l, M, self.h - band_h + 56 + i * 24, SERIF_TEXT, 16, CREAM)

    def two_col(self):
        gap = 24; w = (self.cw - gap) / 2
        return (M, w), (M + w + gap, w)

    def app_line(self, s):
        """The closing line that points back to the app."""
        self.y += 6; self.hr(); self.y += 10
        self.para(s, font=SANS_IT, size=10.5, color=BLUE_DK)


# ---------- 1. The Family File ----------
def family_file():
    d = Doc("the-family-file", "The Family File", "Everything a family needs to know, in one place.")
    d.cover("The Family File", "Everything a family needs to know, in one place.",
            "Keep one copy at home and one with the person you'd call first.")
    # 1 In an emergency
    d.page(); d.title("In an emergency", 30)
    d.heading("Who to call first")
    d.rows(["Name", "Relationship", "Phone"])
    d.heading("Second contact")
    d.rows(["Name", "Relationship", "Phone"])
    d.heading("Where we are")
    d.rows(["Home address", "", "Preferred hospital", "Hospital phone"])
    d.y += 8
    d.note_box("Gate and alarm codes don't go on paper. Keep them in the app's vault, where only you can open them.")
    # 2 Medical
    d.page(); d.title("Medical", 30)
    (lx, lw), (rx, rw) = d.two_col()
    for i, x in enumerate([lx, rx]):
        y0 = d.y
        d.y = y0; d.label(f"Child {i + 1}", x, d.y); d.y += 18
        for lab in ["Name", "Birthdate", "Pediatrician", "Doctor's phone", "Allergies", "Meds, dose, when", "", "Blood type", "Notes", ""]:
            d.row(lab, x, lw, 96 if lab else 0, h=26)
        end = d.y
        d.y = y0
    d.y = end + 6
    d.heading("Health insurance")
    d.rows(["Carrier", "Member ID", "Group number", "Phone on the card"])
    d.heading("Dental and vision")
    d.row("Dental", M, lw);
    d.y -= 28; d.row("Dental ID", rx, rw, 70)
    d.row("Vision", M, lw); d.y -= 28; d.row("Vision ID", rx, rw, 70)
    # 3 If something happens
    d.page(); d.title("If something happens to us", 30)
    d.intro("This isn't legal paperwork. It's so the people who love you know what you'd want, without having to guess.")
    d.heading("Guardian")
    d.rows(["Name", "Relationship", "Phone"])
    d.heading("Backup guardian")
    d.rows(["Name", "Relationship", "Phone"])
    d.heading("What we'd want for the kids")
    d.lines(6)
    d.heading("Papers and people")
    d.rows(["Where the will is", "Lawyer", "Lawyer's phone"])
    # 4 Accounts and money
    d.page(); d.title("Accounts and money", 30)
    d.intro("Write where the password is kept, never the password.")
    cols = [("Institution", 0.34), ("What it's for", 0.33), ("Where the login lives", 0.33)]
    xx = M
    for name, frac in cols:
        d.label(name, xx, d.y); xx += d.cw * frac
    d.y += 16; d.hr(); d.y += 2
    for item in ["Bank", "Mortgage or rent", "Utilities", "Utilities", "Utilities", "Utilities", "Phone plan", "Subscriptions", "Subscriptions", "Subscriptions"]:
        d.text(item, M, d.y + 17, SANS, 10.5, SAND_DEEP)
        d.c.setStrokeColor(RULE); d.c.line(M, d.Y(d.y + 26), M + d.cw, d.Y(d.y + 26)); d.y += 26
    d.heading("Life insurance")
    d.rows(["Carrier", "Policy number", "Agent's phone"])
    # 5 Home and vehicles
    d.page(); d.title("Home and vehicles", 30)
    d.heading("Home insurance")
    d.rows(["Carrier", "Policy number", "Phone"])
    d.heading("Vehicles")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for x in [lx, rx]:
        d.y = y0
        for lab in ["Make and model", "Plate", "Registration renews", "Insurance policy"]: d.row(lab, x, lw, 100, h=26)
        end = d.y
    d.y = end
    d.heading("Pets")
    for _ in range(2):
        d.row("Name", M, lw, 60); d.y -= 28; d.row("Vet and phone", rx, rw, 80)
    d.heading("Where things are")
    d.rows(["Water shutoff", "Breaker panel", "Spare key", "Important papers"])
    d.app_line("Done on paper? The app keeps it current, syncs it with your partner and reminds you when things expire. petitehome.co")
    return d.save(multi=True)


# ---------- 2. The sealed envelope ----------
def sealed_envelope():
    d = Doc("sealed-envelope", "Sealed envelope", "For the person who'd step in. Open when you need to.")
    d.cover("Sealed envelope", "For the person who'd step in. Open when you need to.",
            "Keep this with the person you named. It has what they'd need, and nothing they shouldn't carry.",
            date_line="Prepared by ______________________ on")
    d.page(); d.title("Who to call, where to go", 30)
    d.heading("Call first"); d.rows(["Name", "Relationship", "Phone"])
    d.heading("Then"); d.rows(["Name", "Relationship", "Phone"])
    d.heading("Home"); d.rows(["Address", "", "Preferred hospital"])
    d.heading("Where things are in the house"); d.rows(["Water shutoff", "Breaker panel", "Spare key", "Important papers"])
    d.page(); d.title("The kids", 30)
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for i, x in enumerate([lx, rx]):
        d.y = y0; d.label(f"Child {i + 1}", x, d.y); d.y += 18
        for lab in ["Name", "Birthdate", "Pediatrician", "Doctor's phone", "Allergies", "Medications", "", "Bedtime and what works", "", ""]:
            d.row(lab, x, lw, 96 if lab else 0, h=26)
        end = d.y
    d.y = end + 10
    d.caption("Insurance member numbers, account details and codes stay in the Family File at home. This copy travels without them.")
    d.page(); d.title("If something happens to us", 30)
    d.intro("This isn't legal paperwork. It's so the people who love you know what you'd want, without having to guess.")
    d.heading("Guardian"); d.rows(["Name", "Relationship", "Phone"])
    d.heading("Backup guardian"); d.rows(["Name", "Relationship", "Phone"])
    d.heading("What we'd want for the kids"); d.lines(5)
    d.y += 6; d.row("Where the will is", M, d.cw, 120)
    d.app_line("The app prints this version for you, without the numbers that shouldn't travel. petitehome.co")
    return d.save(multi=True)


# ---------- 3. The sitter sheet ----------
def sitter_sheet():
    d = Doc("sitter-sheet", "Tonight", "One page to leave on the counter for the sitter.")
    d.page(); d.title("Tonight")
    d.para("We'll be out from ____________ to ____________, at ______________________________.", size=12); d.y += 10
    (lx, lw), (rx, rw) = d.two_col()
    bw = (d.cw - 2 * 12) / 3
    y0 = d.y; bh = 168
    for i in range(3):
        x = M + i * (bw + 12)
        d.box(x, y0, bw, bh)
        d.y = y0 + 12
        d.label(f"Child {i + 1}", x + 12, d.y); d.y += 16
        for lab in ["Name, age", "Bedtime", "Allergies", "Meds, when", "What works"]:
            d.row(lab, x + 12, bw - 24, 62, h=26)
    d.y = y0 + bh + 16
    d.label("House notes", M, d.y); d.y += 16
    d.caption("Where the snacks are, screen rules, the dog, anything a stranger to the house should know.")
    d.lines(4)
    d.y += 6
    d.heading("If you can't reach us")
    y0 = d.y
    d.y = y0
    for lab in ["Our phones", "", "A neighbor or relative", "Pediatrician"]: d.row(lab, lx, lw, 110, h=26)
    end = d.y; d.y = y0
    for lab in ["Hospital", "Our address", "", ""]: d.row(lab, rx, rw, 80, h=26)
    d.y = max(end, d.y) + 12
    d.note_box("Never put alarm or gate codes on this sheet. Tell the sitter in person.", strong="Never")
    d.app_line("The app fills this in from your Family Vault and texts it to the sitter. petitehome.co")
    return d.save()


# ---------- 4. The recipe card ----------
def recipe_card():
    d = Doc("recipe-card", "Recipe card", "A blank card to write a family recipe on.")
    d.page(cover=True)
    card_w, card_h = 4 * 72, 5 * 72
    gap = 22
    total = 2 * card_h + gap
    top = (d.h - total) / 2
    for i in range(2):
        x = (d.w - card_w) / 2; y = top + i * (card_h + gap)
        d.box(x, y, card_w, card_h, CREAM_TINT, 14, stroke=RULE)
        d.wordmark(x + 18, y + 16, 9)
        d.label("Recipe", x + 18, y + 40)
        d.y = y + 60; d.row("", x + 18, card_w - 36, 0, h=30)
        d.c.setStrokeColor(SAND); d.c.setLineWidth(0.6)
        d.text("Serves ______  ·  ______ minutes", x + 18, y + 108, SANS, 10, SAND_DEEP)
        d.label("Ingredients", x + 18, y + 128); d.label("Steps", x + 18 + 140, y + 128)
        d.y = y + 146
        for _ in range(10): d.row("", x + 18, 124, 0, h=18)
        d.y = y + 146
        for n in range(1, 7):
            d.text(f"{n}.", x + 158, d.y + 14, SANS, 9.5, SAND_DEEP); d.row("", x + 170, card_w - 36 - 152, 0, h=30)
        d.text("From the kitchen of ______________________", x + 18, y + card_h - 20, SANS_IT, 10, SAND_DEEP)
        if i == 0:
            d.c.setStrokeColor(SAND); d.c.setDash(2, 4); d.c.line(M, d.Y(y + card_h + gap / 2), d.w - M, d.Y(y + card_h + gap / 2)); d.c.setDash()
    return d.save()


# ---------- 5. Who to call first ----------
def who_to_call_first():
    d = Doc("who-to-call-first", "Who to call first", "The fridge card: who to call, the doctor, insurance, the guardian.")
    d.page(landscape=True)
    d.text("If something happened to you tonight, would anyone know where to find this?", M, d.y + 2, SANS_IT, 11, SAND_DEEP)
    d.y += 20
    half = (d.w - 2 * M - 40) / 2
    lx, rx = M, M + half + 40
    d.y += 2; d.text("Who to call first", lx, d.y + 30, SERIF, 34, INK); d.y += 50
    y0 = d.y
    for lab, fields in [("If you can't reach us", ["Name", "Phone"]), ("The kids' doctor", ["Name", "Phone"]),
                        ("Health insurance", ["Carrier", "Member ID", "Phone on the card"]), ("If something happens to us", ["Guardian", "Phone"])]:
        d.text(lab, lx, d.y + 16, SERIF, 16, INK); d.y += 24
        for f in fields: d.row(f, lx, half, 78, h=24)
        d.y += 6
    # right half
    d.y = y0 - 20
    d.text("The kids", rx, d.y + 16, SERIF, 16, INK); d.y += 26
    for i in range(3):
        d.row("Name", rx, half, 50, h=22); d.row("Birthdate", rx, half, 70, h=22); d.row("Allergies", rx, half, 70, h=22); d.y += 4
    d.y += 4
    d.row("Our address", rx, half, 86, h=24)
    d.y += 14
    d.note_box("Stick this on the fridge. Put a second copy in the glove box.", rx, half)
    d.c.setStrokeColor(RULE); d.c.setDash(2, 4); d.c.line(d.w / 2, d.Y(M - 10), d.w / 2, M - 30); d.c.setDash()
    return d.save()


# ---------- 6. The expiration tracker ----------
def expiration_tracker():
    d = Doc("expiration-tracker", "What expires", "Everything that quietly expires, with the 60, 30, 7 day reminder rule.")
    d.page(); d.title("What expires")
    d.intro("Three reminders is the rule: 60 days out, 30, then 7. Write the dates, then set the reminders, or let the app do it.")
    cols = [("Item", 0), ("Expires on", 230), ("60 days", 340), ("30 days", 410), ("7 days", 470)]
    for name, off in cols: d.label(name, M + off, d.y)
    d.y += 16; d.hr(); d.y += 2
    items = ["Passport:", "Passport:", "Passport:", "Car seat (date is on the seat)", "Car registration:", "Car registration:",
             "Driver's license:", "Driver's license:", "Health insurance renewal", "Home or renter's insurance", "Life insurance premium",
             "EpiPen or inhaler", "Smoke detector batteries", "", ""]
    for item in items:
        rh = 30
        d.text(item, M, d.y + 19, SANS, 10.5, SAND_DEEP if item else INK)
        if item.endswith(":"):
            w0 = pdfmetrics.stringWidth(item, SANS, 10.5) + 6
            d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.8); d.c.line(M + w0, d.Y(d.y + 22), M + 210, d.Y(d.y + 22))
        elif not item:
            d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.8); d.c.line(M, d.Y(d.y + 22), M + 210, d.Y(d.y + 22))
        d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.8); d.c.line(M + 230, d.Y(d.y + 22), M + 320, d.Y(d.y + 22))
        for off in (340, 410, 470): d.checkbox(M + off + 12, d.y + 9)
        d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(M, d.Y(d.y + rh), M + d.cw, d.Y(d.y + rh))
        d.y += rh
    d.y += 12
    d.caption("Car seats expire. The date is on a sticker on the seat, usually 6 to 10 years from manufacture.")
    d.app_line("The app sets all three reminders the moment you type the date, and puts them in your phone's Calendar. petitehome.co")
    return d.save()


# ---------- 7. The household cadence ----------
CADENCE = [
    ("Every day", [("Plan dinner", "Ten seconds at 3 pm beats the 6 pm scramble."), ("Ten-minute tidy", "A timer, the whole family, one room.")]),
    ("Every week", [("Plan the week together", "Sunday evening. Calendars open, five minutes."), ("Grocery run", "Saturday. From the list, not from memory.")]),
    ("Every month", [("Look at what's coming due", "Passports, registrations, renewals."), ("Check car seat straps and fit", "Kids grow. Straps at or below the shoulders rear-facing, at or above forward-facing.")]),
    ("A few times a year", [("Change the furnace filter", "Every 3 months."), ("Replace smoke detector batteries", "Every 6 months."), ("Flush the water heater", "Every 6 months.")]),
    ("Every year", [("Renew car registration", None), ("Review insurance coverage", "Life, home, auto, health. One sitting."), ("Each child's well-child visit", "Around the birthday.")]),
]


def household_cadence():
    d = Doc("household-cadence", "The house, on a rhythm", "The things a house needs, by rhythm, with room for your own.")
    d.page(); d.title("The house, on a rhythm", 34)
    d.intro("Pick the ones that fit. Either of you can check one off.")
    (lx, lw), (rx, rw) = d.two_col()
    col = [lx, rx]; ci = 0; ystart = d.y; maxy = d.y
    for gi, (group, items) in enumerate(CADENCE):
        if gi == 3: ci = 1; d.y = ystart
        x = col[ci]; w = lw
        d.text(group, x, d.y + 16, SERIF, 17, INK); d.y += 24
        for t, n in items: d.check_item(t, n, x, w, h=4)
        for _ in range(3): d.row("", x + 20, w - 20, 0, h=22)
        d.y += 10
        maxy = max(maxy, d.y)
    d.y = maxy
    # page 2: month grid
    d.page(); d.title("This month", 34)
    d.intro("Print one each month. Weekly items get a 'who' and a tick.")
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    gx, gy = M, d.y; cw = d.cw / 7; rh = 78
    for i, dname in enumerate(days): d.label(dname, gx + i * cw + 6, gy)
    gy += 16
    d.c.setStrokeColor(RULE); d.c.setLineWidth(0.6)
    for r in range(6): d.c.line(gx, d.Y(gy + r * rh), gx + d.cw, d.Y(gy + r * rh))
    for i in range(8): d.c.line(gx + i * cw, d.Y(gy), gx + i * cw, d.Y(gy + 5 * rh))
    for r in range(5):
        for i in range(7):
            x = gx + i * cw + 6; y = gy + r * rh + 8
            d.text("Who", x, y + 9, SANS, 7.5, SAND_DEEP); d.checkbox(x + cw - 24, y - 2)
            d.text("Dinner", x, y + 24, SANS, 7.5, SAND_DEEP); d.checkbox(x + cw - 24, y + 13)
            d.text("Tidy", x, y + 39, SANS, 7.5, SAND_DEEP); d.checkbox(x + cw - 24, y + 28)
    d.y = gy + 5 * rh + 16
    d.text("This week", M, d.y + 14, SERIF, 16, INK); d.y += 22
    for t in ["Plan the week together", "Grocery run", "Look at what's coming due (monthly)"]:
        d.checkbox(M, d.y, t); d.row("Who", M + 260, d.cw - 260, 40, h=20); d.y += 2
    d.app_line("The app keeps the rhythm for you, reminds whoever's turn it is, and puts the chores in your phone's Reminders. petitehome.co")
    return d.save(multi=True)


# ---------- 8. If something happens to us ----------
def if_something_happens():
    d = Doc("if-something-happens", "If something happens to us", "The guardian wishes worksheet.")
    d.page(); d.title("If something happens to us", 32)
    d.intro("This isn't legal paperwork. It's so the people who love you know what you'd want, without having to guess.")
    d.heading("Who would step in")
    d.rows(["Name", "Relationship", "Phone"]); d.row("Why them", M, d.cw, 120); d.lines(1)
    d.heading("A backup, in case")
    d.rows(["Name", "Relationship", "Phone"]); d.row("Why them", M, d.cw, 120); d.lines(1)
    d.page(); d.title("What we'd want for the kids", 32)
    d.intro("Short answers are fine. The point is that someone knows.")
    for prompt in ["Where they'd live", "School", "Faith or traditions", "The people we'd want in their lives", "What we'd want them to know about us"]:
        d.text(prompt, M, d.y + 12, SANS_SEMI, 11, INK); d.y += 18; d.lines(3, h=24); d.y += 10
    d.page(); d.title("Where things are", 32)
    d.rows(["The will", "Life insurance", "Accounts and money", "The Family File", "Passports and birth certificates"], h=34)
    d.heading("Who we've told")
    for _ in range(3):
        d.row("Name", M, 300, 50); d.y -= 28; d.row("Date", M + 320, d.cw - 320, 40)
    d.y += 24
    d.note_box("Now tell the person. A plan nobody knows about isn't a plan.")
    d.app_line("The app keeps this with the rest of the Family Vault and shares it with the guardian, read-only. petitehome.co")
    return d.save(multi=True)


# ---------- 9. The week on one page ----------
def week_on_one_page():
    d = Doc("week-on-one-page", "This week", "The Planner's week on paper, for two adults.")
    d.page(landscape=True)
    d.text("This week", M, d.y + 26, SERIF, 30, INK)
    d.text("Week of ______________", d.w - M - 100, d.y + 20, SANS, 11, SAND_DEEP, right=True)
    d.y += 34
    d.text("________________  and  ________________", M, d.y + 12, SANS, 11, SAND_DEEP)
    d.text("your names, one per row", M + 300, d.y + 12, SANS_IT, 9, SAND_DEEP)
    d.y += 26
    strip = 96; gap = 16
    gw = d.cw - strip - gap; cw = gw / 7
    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    gy = d.y
    bands = [("Row 1", 92), ("Row 2", 92), ("Kids", 78), ("Dinner", 44), ("Bedtime", 32), ("Sitter?", 26)]
    total_h = sum(h for _, h in bands)
    for i, dname in enumerate(days):
        x = M + i * cw
        if i >= 5: d.box(x, gy, cw, 16 + total_h, BLUE_MIST, 0)
        d.label(dname, x + 6, gy + 2)
    gy += 16
    d.c.setStrokeColor(RULE); d.c.setLineWidth(0.6)
    yy = gy
    for name, h in bands:
        d.c.line(M, d.Y(yy), M + gw, d.Y(yy))
        d.text(name, M + 4, yy + 9, SANS, 7, SAND_DEEP)
        if name == "Sitter?":
            for i in range(7): d.checkbox(M + i * cw + cw - 20, yy + 5)
        yy += h
    d.c.line(M, d.Y(yy), M + gw, d.Y(yy))
    for i in range(8): d.c.line(M + i * cw, d.Y(gy), M + i * cw, d.Y(yy))
    # right strip
    sx = M + gw + gap
    d.y = gy - 16
    d.text("This week's three", sx, d.y + 12, SERIF, 13, INK); d.y += 20
    for _ in range(3): d.checkbox(sx, d.y); d.row("", sx + 20, strip - 20, 0, h=24)
    d.y += 8
    d.text("Date night", sx, d.y + 12, SERIF, 13, INK); d.y += 18; d.row("", sx, strip, 0, h=24)
    d.y += 8
    d.text("Next week, already", sx, d.y + 12, SERIF, 13, INK); d.y += 18; d.lines(2, sx, strip, h=24)
    d.y = yy + 12
    d.app_line("The app merges both of your calendars, the chores and dinner onto one week you can both see. petitehome.co")
    return d.save()


# ---------- 10. The meal week and shopping list ----------
def meal_week():
    d = Doc("meal-week", "Dinner this week", "Seven dinners and a grouped shopping list.")
    d.page(); d.title("Dinner this week", 32)
    lw = d.cw * 0.55 - 12; rx = M + d.cw * 0.55 + 12; rw = d.cw * 0.45 - 12
    y0 = d.y
    d.label("Day", M, d.y); d.label("What", M + 70, d.y); d.label("Who cooks", M + lw - 92, d.y); d.label("Left", M + lw - 22, d.y, size=7)
    d.y += 16
    for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]:
        d.text(day, M, d.y + 19, SANS, 10.5, SAND_DEEP)
        d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.8)
        d.c.line(M + 70, d.Y(d.y + 22), M + lw - 100, d.Y(d.y + 22)); d.c.line(M + lw - 92, d.Y(d.y + 22), M + lw - 30, d.Y(d.y + 22))
        d.checkbox(M + lw - 12, d.y + 9)
        d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(M, d.Y(d.y + 34), M + lw, d.Y(d.y + 34))
        d.y += 34
    d.y += 20
    d.text("Three dinners you always come back to", M, d.y + 14, SERIF, 15, INK); d.y += 22
    d.lines(3, M, lw, h=24)
    left_end = d.y
    d.y = y0 - 10
    d.text("The list", rx, d.y + 14, SERIF, 18, INK); d.y += 30
    for group in ["Produce", "Meat and fish", "Dairy and eggs", "Pantry", "Frozen", "Household"]:
        d.label(group, rx, d.y); d.y += 14
        for _ in range(4): d.checkbox(rx, d.y); d.row("", rx + 20, rw - 20, 0, h=17)
        d.y += 4
    d.y = max(d.y, left_end) + 6
    d.app_line("The app plans the week with your partner, saves the recipes, and writes the list for you. petitehome.co")
    return d.save()


# ---------- 11. What to keep in the vault ----------
def what_to_keep():
    d = Doc("what-to-keep-in-the-vault", "What to keep", "The documents worth photographing, and where the originals live.")
    d.page(); d.title("What to keep", 34)
    d.intro("A photo of a birth certificate is a good start. Here's the rest.")
    cols = [("Identity", ["Birth certificates", "Social Security cards", "Passports", "Marriage certificate"]),
            ("Medical", ["Insurance cards, front and back", "Vaccination records", "Prescriptions", "Allergy plans"]),
            ("Home and money", ["Deed or lease", "Vehicle titles", "Insurance policies", "The will", "Tax returns", "Warranties"])]
    gap = 16; cw = (d.cw - 2 * gap) / 3
    y0 = d.y; maxy = y0
    for i, (name, items) in enumerate(cols):
        x = M + i * (cw + gap); d.y = y0
        d.text(name, x, d.y + 16, SERIF, 17, INK); d.y += 26
        for it in items:
            used = d.checkbox(x, d.y, it, w=cw - 20); d.y += used + 2
            d.label("Original is", x + 20, d.y + 2, size=7); d.row("", x + 72, cw - 72, 0, h=18); d.y += 8
        maxy = max(maxy, d.y)
    d.y = maxy + 16
    d.note_box("Never keep these as plain photos in your camera roll. The app encrypts them on your phone and in your iCloud, and only you can open them.", strong="Never")
    d.app_line("Photograph each one into the Vault once, and the app reminds you before any of them expire. petitehome.co")
    return d.save()


# ---------- 12. Date night, found ----------
def date_night_found():
    d = Doc("date-night-found", "Find the evening", "Two weeks of evenings. Cross out what's taken, circle two.")
    d.page(); d.title("Find the evening", 34)
    d.intro("Two weeks of evenings. Cross out what's taken, circle two, then ask the sitter before you talk yourselves out of it.")
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    gap = 8; bw = (d.cw - 6 * gap) / 7; bh = 92
    for r in range(2):
        for i, dname in enumerate(days):
            x = M + i * (bw + gap); y = d.y
            d.box(x, y, bw, bh, BLUE_MIST if i >= 5 else CREAM_DEEP, 10)
            d.text(dname, x + 8, y + 18, SERIF, 13, INK)
            d.c.setStrokeColor(SAND); d.c.setLineWidth(1); d.c.circle(x + bw - 14, y + 14, 7, stroke=1, fill=0)
            d.label("Taken by", x + 8, y + 36, size=6.5)
            d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.8); d.c.line(x + 8, d.Y(y + 62), x + bw - 8, d.Y(y + 62))
            d.c.line(x + 8, d.Y(y + 80), x + bw - 8, d.Y(y + 80))
        d.y += bh + gap
    d.y += 10
    d.para("Two we circled: ______________________ and ______________________", size=12); d.y += 12
    d.heading("Sitter")
    d.label("Name", M, d.y); d.label("Phone", M + 170, d.y); d.label("Asked on", M + 310, d.y); d.label("Confirmed", M + 420, d.y); d.y += 16
    for _ in range(3):
        d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.8)
        for a, b in [(0, 160), (170, 300), (310, 400)]: d.c.line(M + a, d.Y(d.y + 20), M + b, d.Y(d.y + 20))
        d.checkbox(M + 440, d.y + 7); d.y += 28
    d.y += 10
    d.text("The ask, ready to text", M, d.y + 14, SERIF, 15, INK); d.y += 24
    d.note_box("Hi ________, are you free on ________ from ______ to ______? The kids would love to see you.", fill=CREAM_DEEP)
    d.app_line("The app finds the free evenings on both calendars, keeps the sitter list, and sends the ask for you. petitehome.co")
    return d.save()


BUILDERS = [family_file, sealed_envelope, sitter_sheet, recipe_card, who_to_call_first, expiration_tracker,
            household_cadence, if_something_happens, week_on_one_page, meal_week, what_to_keep, date_night_found]


def previews():
    import pypdfium2 as pdfium
    out = os.path.join(HERE, "preview"); os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(OUT)):
        if not f.endswith(".pdf"): continue
        pdf = pdfium.PdfDocument(os.path.join(OUT, f))
        for i in range(len(pdf)):
            img = pdf[i].render(scale=1.2).to_pil()
            img.save(os.path.join(out, f"{f[:-4]}-{i + 1}.png"))
    print("previews in", out)


if __name__ == "__main__":
    for b in BUILDERS:
        print("wrote", os.path.relpath(b(), HERE))
    if "--preview" in sys.argv: previews()
