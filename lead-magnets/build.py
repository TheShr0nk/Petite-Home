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



# ---------- 4. The sitter cheat-sheet ----------
def sitter_cheat_sheet():
    d = Doc("sitter-cheat-sheet", "Sitter cheat-sheet", "Everything a sitter needs for tonight, on one page.")
    d.page(); d.title("Sitter cheat-sheet", 30, gap=8)
    d.para("We'll be out from ________ to ________, at ______________________. Back by ________.", size=11); d.y += 6
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    d.box(M, y0, d.cw, 66, BLUE_MIST)
    d.label("Reach us", M + 14, y0 + 8)
    d.y = y0 + 22
    d.row("Parent 1", M + 14, lw - 14, 60, h=20); d.row("Parent 2", M + 14, lw - 14, 60, h=20)
    d.y = y0 + 22
    d.row("Backup (neighbor, relative)", rx, rw - 14, 150, h=20); d.row("Our address", rx, rw - 14, 80, h=20)
    d.y = y0 + 66 + 8
    d.heading("The kids", 16)
    cols = [("Name, age", 0), ("Bedtime", 92), ("Allergies", 160), ("Meds and when", 262), ("What calms them", 384)]
    for name, off in cols: d.label(name, M + off, d.y, size=7.5)
    d.y += 12
    for _ in range(3):
        d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(M, d.Y(d.y + 26), M + d.cw, d.Y(d.y + 26))
        for a, b in [(0, 84), (92, 152), (160, 254), (262, 376), (384, 500)]:
            d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7); d.c.line(M + a, d.Y(d.y + 19), M + b, d.Y(d.y + 19))
        d.y += 26
    y0 = d.y
    d.heading("Tonight's routine", 16, lx, lw)
    for step in ["Dinner", "Bath", "Pajamas and teeth", "Books", "Lights out", "If they wake up"]:
        d.label(step, lx, d.y + 6, size=7.5); d.row("", lx + 92, lw - 92, 0, h=21)
    left_end = d.y
    d.y = y0
    d.heading("Where things are", 16, rx, rw)
    for thing in ["Snacks and water", "Diapers and wipes", "First-aid kit", "Thermometer", "Flashlight", "Spare clothes"]:
        d.label(thing, rx, d.y + 6, size=7.5); d.row("", rx + 96, rw - 96, 0, h=21)
    d.y = max(left_end, d.y)
    d.heading("House rules", 16)
    for rule_text in ["Screens:", "Treats:", "Doors, yard, pets:"]:
        d.text(rule_text, M, d.y + 11, SANS_SEMI, 10, INK)
        w0 = pdfmetrics.stringWidth(rule_text, SANS_SEMI, 10) + 8
        d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7); d.c.line(M + w0, d.Y(d.y + 14), M + d.cw, d.Y(d.y + 14)); d.y += 20
    d.y += 8
    d.box(M, d.y, d.cw, 58, CREAM_DEEP)
    d.label("If something's wrong", M + 14, d.y + 8)
    d.text("Pediatrician: ____________________    Hospital: ____________________", M + 14, d.y + 32, SANS, 10, INK)
    d.text("Poison Control (US): 1-800-222-1222   ·   Emergency: 911   ·   Then call us.", M + 14, d.y + 48, SANS, 10, INK)
    d.y += 58 + 8
    d.text("Never", M, d.y + 9, SANS_SEMI, 9, DANGER)
    d.text("write alarm or gate codes here. Tell the sitter in person.", M + pdfmetrics.stringWidth("Never ", SANS_SEMI, 9), d.y + 9, SANS, 9, SAND_DEEP)
    d.text("The app fills this in from your Family Vault and texts it to the sitter in one tap. petitehome.co", M, d.y + 24, SANS_IT, 9.5, BLUE_DK)
    return d.save()


# ---------- 5. Baby sleep tracker and bedtime routine ----------
WAKE_WINDOWS = [("0 to 1 month", "45 to 60 min", "4 to 6 naps"), ("1 to 2 months", "45 to 75 min", "4 to 5 naps"), ("3 months", "60 to 90 min", "3 to 4 naps"),
                ("4 to 5 months", "90 min to 2 h", "3 to 4 naps"), ("6 to 7 months", "2 to 3 h", "2 to 3 naps"), ("8 to 10 months", "2.5 to 3.5 h", "2 naps"), ("11 to 12 months", "3 to 4 h", "1 to 2 naps")]


def baby_sleep_tracker():
    d = Doc("baby-sleep-tracker", "Baby sleep tracker", "A seven-day sleep log, wake windows by age, and a bedtime routine that sticks.")
    # Page 1: the log
    d.page(landscape=True)
    d.text("Seven nights", M, d.y + 26, SERIF, 30, INK)
    d.text("Week of ______________", d.w - M, d.y + 20, SANS, 11, SAND_DEEP, right=True)
    d.y += 40
    d.para("Shade the hours baby slept. Tick a wake. A pattern shows up by night four.", size=10.5, color=SAND_DEEP); d.y += 8
    label_w = 70; hours = 24
    gx = M + label_w; gw = d.cw - label_w - 110; cw = gw / hours; rh = 46
    # hour labels, starting at 7 pm
    start = 19
    for h in range(hours + 1):
        hr = (start + h) % 24
        if h % 2 == 0:
            lab = "12a" if hr == 0 else ("12p" if hr == 12 else f"{hr % 12}{'a' if hr < 12 else 'p'}")
            d.text(lab, gx + h * cw, d.y + 8, SANS, 7, SAND_DEEP, center=True)
    d.y += 12
    gy = d.y
    d.label("Wakes", gx + gw + 12, gy - 12, size=7); d.label("Total", gx + gw + 62, gy - 12, size=7)
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for r, day in enumerate(days):
        y = gy + r * rh
        d.text(day, M, y + 27, SANS_SEMI, 10.5, INK)
        for h in range(hours):
            hr = (start + h) % 24
            night = hr >= 19 or hr < 7
            d.c.setFillColor(BLUE_MIST if night else WHITE); d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5)
            d.c.rect(gx + h * cw, d.Y(y + rh - 4), cw, rh - 4, stroke=1, fill=1)
        d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7)
        d.c.line(gx + gw + 12, d.Y(y + rh - 10), gx + gw + 48, d.Y(y + rh - 10))
        d.c.line(gx + gw + 62, d.Y(y + rh - 10), gx + gw + 108, d.Y(y + rh - 10))
    d.y = gy + 7 * rh + 6
    d.c.setFillColor(BLUE_MIST); d.c.rect(M, d.Y(d.y + 10), 10, 10, stroke=0, fill=1)
    d.text("night hours, 7 pm to 7 am", M + 16, d.y + 9, SANS, 8.5, SAND_DEEP)
    d.y += 20
    d.para("Notes on the week (teething, a cold, travel, a new routine):", size=10, color=SAND_DEEP); d.lines(3, h=22)
    # Page 2: wake windows and the routine
    d.page(); d.title("Wake windows and bedtime", 30)
    d.intro("Typical ranges, not rules. Your baby's own pattern on the log beats any chart.")
    d.label("Age", M, d.y); d.label("Awake between sleeps", M + 150, d.y); d.label("Naps a day", M + 340, d.y); d.y += 16; d.hr(); d.y += 2
    for age, win, naps in WAKE_WINDOWS:
        d.text(age, M, d.y + 16, SANS_SEMI, 10.5, INK); d.text(win, M + 150, d.y + 16, SANS, 10.5, INK); d.text(naps, M + 340, d.y + 16, SANS, 10.5, INK)
        d.c.setStrokeColor(RULE); d.c.setLineWidth(0.5); d.c.line(M, d.Y(d.y + 24), M + d.cw, d.Y(d.y + 24)); d.y += 24
    d.y += 8
    d.heading("The bedtime routine")
    d.caption("Same order, same words, every night. Twenty to thirty minutes is plenty. Tick what's in yours and write the time.")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    for step in ["Last feed", "Bath", "Pajamas and a clean diaper", "Dim the lights", "A book or a song", "The same goodnight words", "Into the crib awake"]:
        d.checkbox(lx, d.y, step); d.row("", lx + lw - 70, 70, 0, h=22); d.y += 2
    left_end = d.y; d.y = y0
    d.text("Our routine, in order", rx, d.y + 12, SANS_SEMI, 10.5, INK); d.y += 18
    d.lines(7, rx, rw, h=24)
    d.y = max(left_end, d.y) + 8
    d.note_box("Safe sleep, every sleep: on their back, on a flat firm surface of their own, nothing else in the crib. Room-sharing without bed-sharing for the first six months. (American Academy of Pediatrics)")
    d.app_line("The app keeps the kids' doctor, meds and allergies in one place, and shares them with whoever has baby tonight. petitehome.co")
    return d.save(multi=True)


# ---------- 6. Milestone tracker, 0 to 12 months ----------
MILESTONES = [
    ("2 months", ["Calms down when spoken to or picked up", "Looks at your face", "Smiles when you talk or smile at them", "Makes sounds other than crying",
                  "Reacts to loud sounds", "Watches you as you move", "Holds head up when on tummy", "Moves both arms and both legs", "Opens hands briefly"]),
    ("4 months", ["Smiles on their own to get your attention", "Chuckles when you try to make them laugh", "Makes cooing sounds", "Makes sounds back when you talk",
                  "Turns head toward your voice", "Opens mouth when they see the breast or bottle", "Looks at their hands with interest", "Holds head steady when you hold them",
                  "Holds a toy when you put it in their hand", "Brings hands to mouth", "Pushes up on forearms when on tummy"]),
    ("6 months", ["Knows familiar people", "Likes to look in a mirror", "Laughs", "Takes turns making sounds with you", "Blows raspberries", "Makes squealing noises",
                  "Puts things in their mouth to explore", "Reaches to grab a toy they want", "Closes lips to show they don't want more food", "Rolls from tummy to back",
                  "Pushes up with straight arms on tummy", "Leans on hands for support when sitting"]),
    ("9 months", ["Is shy, clingy or fearful around strangers", "Shows several facial expressions", "Looks when you call their name", "Reacts when you leave",
                  "Smiles or laughs at peekaboo", "Makes sounds like mamamama and babababa", "Lifts arms to be picked up", "Looks for things when they drop out of sight",
                  "Bangs two things together", "Gets to a sitting position by themselves", "Moves things from one hand to the other", "Sits without support"]),
    ("12 months", ["Plays games with you, like pat-a-cake", "Waves bye-bye", "Calls a parent mama, dada or another special name", "Understands no, and pauses",
                   "Puts something in a container", "Looks for things they see you hide", "Pulls up to stand", "Walks holding on to furniture",
                   "Drinks from a cup without a lid as you hold it", "Picks things up between thumb and pointer finger"]),
]


def milestone_tracker():
    d = Doc("milestone-tracker", "Milestones, 0 to 12 months", "Month-by-month milestones with photo prompts and notes for the pediatrician.")
    d.page(); d.title("The first year", 34)
    d.intro("These are the CDC's milestone checklists, the ones your pediatrician uses. Most babies reach them on their own schedule. Tick what you see, and bring the page to each well-child visit.")
    (lx, lw), (rx, rw) = d.two_col()
    cols = [lx, rx]
    col_y = [d.y, d.y]
    ci = 0
    for i, (age, items) in enumerate(MILESTONES):
        if i == 2: ci = 1
        if i == 3:
            d.page(); d.title("The first year", 34); col_y = [d.y, d.y]; ci = 0
        if i == 4: ci = 1
        x = cols[ci]; d.y = col_y[ci]
        d.text(age, x, d.y + 16, SERIF, 18, INK); d.y += 26
        for it in items:
            used = d.checkbox(x, d.y, it, size=9.5, w=lw - 20); d.y += used + 3
        d.y += 4
        d.label("Photo this month", x, d.y + 4, size=7); d.row("", x + 86, lw - 86, 0, h=18)
        d.label("Ask the doctor", x, d.y + 4, size=7); d.row("", x + 86, lw - 86, 0, h=18)
        d.y += 14
        col_y[ci] = d.y
    d.y = max(col_y) + 6
    d.heading("Firsts", 20)
    firsts = ["First smile", "First laugh", "Rolled over", "Sat up", "First tooth", "First word", "Crawled", "Stood up", "First steps"]
    y0 = d.y
    for i, f in enumerate(firsts):
        x = lx if i % 2 == 0 else rx; w = lw
        if i % 2 == 0: d.y = y0 + (i // 2) * 24
        d.label(f, x, d.y + 7, size=7.5); d.row("", x + 70, w - 70, 0, h=24)
    d.y = y0 + 5 * 24 + 6
    d.caption("If your baby is missing milestones, or loses skills they had, talk to the pediatrician. Acting early matters. Source: CDC 'Learn the Signs. Act Early.'")
    d.app_line("The app keeps each child's doctor, sizes and well-child visits, and reminds you around the birthday. petitehome.co")
    return d.save(multi=True)


# ---------- 7. Morning and bedtime routine chart ----------
MORNING = ["Wake up and open the curtains", "Potty", "Get dressed", "Breakfast", "Brush teeth", "Shoes and bag", "Out the door"]
BEDTIME = ["Dinner", "Bath", "Pajamas", "Brush teeth", "Two books", "Hugs and goodnight", "Lights out"]


def routine_chart():
    d = Doc("routine-chart", "Morning and bedtime", "A routine chart kids can follow themselves, with a box to tick each day.")
    days = ["M", "T", "W", "T", "F", "S", "S"]

    def chart(title, steps, blank=False):
        d.text(title, M, d.y + 18, SERIF, 22, INK); d.y += 30
        step_w = d.cw - 7 * 24 - 70
        d.label("Draw it", M, d.y, size=7); d.label("Step", M + 60, d.y, size=7)
        for i, day in enumerate(days): d.text(day, M + 60 + step_w + i * 24 + 12, d.y + 8, SANS_SEMI, 8, SAND_DEEP, center=True)
        d.y += 14
        for i, step in enumerate(steps):
            y = d.y; rh = 50
            d.box(M, y, d.cw, rh - 4, CREAM_DEEP if i % 2 == 0 else CREAM_TINT, 8)
            d.c.setStrokeColor(SAND); d.c.setLineWidth(0.8); d.c.roundRect(M + 8, d.Y(y + rh - 8), 50, rh - 12, 6, stroke=1, fill=0)
            if blank:
                d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7); d.c.line(M + 68, d.Y(y + 30), M + 56 + step_w, d.Y(y + 30))
            else:
                d.text(step, M + 68, y + 29, SANS_SEMI, 12, INK)
            for k in range(7):
                d.c.setStrokeColor(SAND); d.c.setLineWidth(1); d.c.setFillColor(WHITE)
                d.c.roundRect(M + 60 + step_w + k * 24 + 5, d.Y(y + rh - 16), 14, 14, 3, stroke=1, fill=1)
            d.y += rh
        d.y += 4
        d.text("When a row is full: ______________________________________", M, d.y + 12, SANS, 10.5, SAND_DEEP); d.y += 28

    d.page(); d.title("Our routines", 34)
    d.intro("Kids follow a chart they can see better than a voice they tune out. Let them draw each step in the first box, then tick the day when it's done.")
    chart("Morning", MORNING)
    d.page(); d.title("Our routines", 34)
    d.intro("Bedtime goes the same way every night: same order, same words.")
    chart("Bedtime", BEDTIME)
    d.page(); d.title("Make your own", 34)
    d.intro("A blank chart for the afternoon, the weekend, or a different kid. Seven steps is the most a chart should carry.")
    chart("______________________", ["" for _ in range(7)], blank=True)
    d.app_line("The app keeps the family's week, the chores and dinner on one screen both parents can see. petitehome.co")
    return d.save(multi=True)


# ---------- 8. Screen-time family agreement ----------
def screen_time_agreement():
    d = Doc("screen-time-agreement", "Our screen-time agreement", "Family screen rules, a device log, a weekend plan and conversation prompts.")
    d.page(); d.title("Our screen-time agreement", 32)
    d.intro("Written together, signed by everyone, stuck on the fridge. Rules you agreed on hold up better than rules you announced.")
    d.heading("When", 18)
    d.para("On school days, screens are OK from ________ to ________, for about ________ minutes.", size=11); d.y += 4
    d.para("On weekends, from ________ to ________, for about ________ minutes.", size=11); d.y += 4
    d.para("No screens: at the table, in bedrooms, in the hour before bed, and ______________________.", size=11); d.y += 10
    d.heading("What", 18)
    d.caption("Apps, shows and games we've agreed on. New ones get asked about first.")
    (lx, lw), (rx, rw) = d.two_col()
    y0 = d.y
    d.lines(4, lx, lw, h=22); end = d.y; d.y = y0; d.lines(4, rx, rw, h=22); d.y = max(end, d.y) + 8
    d.heading("Grown-ups too", 18)
    d.para("We'll put our phones down at ________ and keep them out of ______________________.", size=11); d.y += 10
    d.heading("When it's hard", 18)
    d.para("If a screen is hard to put down, we'll ____________________________ instead of fighting about it. If the rules get broken, what happens is ____________________________.", size=11); d.y += 12
    d.heading("Signed", 18)
    y0 = d.y
    for i in range(4):
        x = lx if i % 2 == 0 else rx
        if i % 2 == 0: d.y = y0 + (i // 2) * 30
        d.row("", x, lw, 0, h=30)
    d.y = y0 + 60 + 4
    d.caption("Everyone who uses a screen in this house, kids and grown-ups.")
    # page 2: log, weekend plan, prompts
    d.page(); d.title("This week's screens", 32)
    d.intro("One line per sitting. Not to catch anyone out: a week of honest lines is what makes the next conversation easy.")
    cols = [("Day", 0), ("Who", 60), ("What", 140), ("Minutes", 330), ("Felt like", 400)]
    for name, off in cols: d.label(name, M + off, d.y, size=7.5)
    d.y += 14
    for i in range(9):
        d.c.setStrokeColor(SAND_DEEP); d.c.setLineWidth(0.7)
        for a, b in [(0, 52), (60, 132), (140, 322), (330, 392), (400, 500)]: d.c.line(M + a, d.Y(d.y + 17), M + b, d.Y(d.y + 17))
        d.y += 24
    d.y += 10
    d.heading("Instead, this weekend", 18)
    d.caption("Three things we'll do that aren't a screen. Pick them together on Friday.")
    for _ in range(3): d.checkbox(M, d.y); d.row("", M + 20, d.cw - 20, 0, h=22)
    d.y += 4
    d.heading("Five questions worth asking", 18)
    for q in ["What's the best thing you watched or played this week?", "Was there anything that made you feel bad, or that you didn't want us to see?",
              "What would you do with an extra hour if screens were off?", "Which rule feels unfair, and what would you change?", "When do you notice us on our phones too much?"]:
        d.checkbox(M, d.y, q, size=10.5); d.y += 20
    d.app_line("The app keeps the family's chores, plans and dinner on one week both parents see, so the weekend plan sticks. petitehome.co")
    return d.save(multi=True)
BUILDERS = [family_file, who_to_call_first, if_something_happens, sitter_cheat_sheet,
            baby_sleep_tracker, milestone_tracker, routine_chart, screen_time_agreement]


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
