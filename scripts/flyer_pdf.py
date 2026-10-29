"""The tear-off flyer as a printable A4 PDF: the lost-pet format of docs/PRODUCT.md § Flyers.

The top holds the headline, one line on what Ronda is, three facts, "Arrancá una tira y
escaneala." and "Ronda nunca pide plata."; the bottom, seven strips to tear off, each with a QR
to the flyer's page and "Ronda nunca pide plata" again, since the strip is what goes home. Each
QR is also a link, so the PDF opens the page when clicked on a screen.

Type and colour follow docs/DESIGN.md: Young Serif for the headline, Atkinson Hyperlegible for
the rest (the app's bundled fonts, packages/ronda_ui/assets/fonts), ink on paper, the ruled
sheet's red margin line as the one accent.
"""

from dataclasses import dataclass
from pathlib import Path

from reportlab.graphics import renderPDF
from reportlab.graphics.barcode.qr import QrCodeWidget
from reportlab.graphics.shapes import Drawing
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen.canvas import Canvas

FONTS = Path(__file__).resolve().parents[1] / "packages" / "ronda_ui" / "assets" / "fonts"
TITLE, BODY, BOLD = "YoungSerif", "Atkinson", "Atkinson-Bold"

INK = HexColor("#18202F")
MUTED = HexColor("#5A6477")
MARGEN = HexColor("#C8433C")
LINE = HexColor("#8792A6")

STRIPS = 7
MARGIN = 14 * mm
STRIP_HEIGHT = 92 * mm
QR_SIZE = 24 * mm


@dataclass(frozen=True)
class FlyerText:
    headline: str
    what: str
    facts: tuple[str, str, str]
    tear: str
    money: str


def write_pdf(path: Path, text: FlyerText, url: str, title: str) -> None:
    """Draws the flyer for `url` on one A4 page at `path`."""
    _register_fonts()
    canvas = Canvas(str(path), pagesize=A4, invariant=True)
    canvas.setTitle(title)
    canvas.setAuthor("Ronda")
    width, height = A4
    _draw_top(canvas, text, width, height)
    _draw_strips(canvas, text, url, width)
    canvas.showPage()
    canvas.save()


def _register_fonts() -> None:
    for name, file in (
        (TITLE, "YoungSerif-Regular.ttf"),
        (BODY, "AtkinsonHyperlegible-Regular.ttf"),
        (BOLD, "AtkinsonHyperlegible-Bold.ttf"),
    ):
        if name not in pdfmetrics.getRegisteredFontNames():
            pdfmetrics.registerFont(TTFont(name, str(FONTS / file)))


def _draw_top(canvas: Canvas, text: FlyerText, width: float, height: float) -> None:
    """The headline, what and the facts from the top down; the money line and "Arrancá una
    tira" from the strips up, so the instruction sits right above what it is about."""
    left = MARGIN + 8 * mm
    right = width - MARGIN
    top = height - MARGIN
    floor = MARGIN + STRIP_HEIGHT
    canvas.setStrokeColor(MARGEN)
    canvas.setLineWidth(1.2)
    canvas.line(MARGIN + 3 * mm, top, MARGIN + 3 * mm, floor + 8 * mm)

    size = _fit(text.headline, TITLE, 52, right - left)
    y = top - size
    canvas.setFillColor(INK)
    canvas.setFont(TITLE, size)
    canvas.drawString(left, y, text.headline)

    y -= 14 * mm
    canvas.setFillColor(MUTED)
    canvas.setFont(BODY, 20)
    for line in _wrap(text.what, BODY, 20, right - left):
        canvas.drawString(left, y, line)
        y -= 26

    y -= 12 * mm
    canvas.setFillColor(INK)
    canvas.setFont(BOLD, 26)
    for fact in text.facts:
        canvas.circle(left + 2.5 * mm, y + 7.5, 2.5 * mm, stroke=0, fill=1)
        for line in _wrap(fact, BOLD, 26, right - left - 10 * mm):
            canvas.drawString(left + 9 * mm, y, line)
            y -= 32
        y -= 7 * mm

    y = floor + 9 * mm
    canvas.setFont(BOLD, 28)
    canvas.drawString(left, y, text.tear)

    size = _fit(text.money, BOLD, 22, right - left - 10 * mm)
    y += 22 * mm
    canvas.setStrokeColor(INK)
    canvas.setLineWidth(1.6)
    box_width = pdfmetrics.stringWidth(text.money, BOLD, size) + 10 * mm
    canvas.roundRect(left, y - 4.5 * mm, box_width, size + 8 * mm, 3 * mm, stroke=1, fill=0)
    canvas.setFont(BOLD, size)
    canvas.drawString(left + 5 * mm, y, text.money)


def _draw_strips(canvas: Canvas, text: FlyerText, url: str, width: float) -> None:
    strip_width = (width - 2 * MARGIN) / STRIPS
    bottom = MARGIN
    top = MARGIN + STRIP_HEIGHT
    canvas.setStrokeColor(LINE)
    canvas.setLineWidth(0.8)
    canvas.setDash(4, 3)
    canvas.line(MARGIN, top, width - MARGIN, top)
    for index in range(1, STRIPS):
        x = MARGIN + index * strip_width
        canvas.line(x, bottom, x, top)
    canvas.setDash()

    short = url.split("://", 1)[-1]
    for index in range(STRIPS):
        x = MARGIN + index * strip_width
        qr_left = x + (strip_width - QR_SIZE) / 2
        qr_bottom = top - 3 * mm - QR_SIZE
        _draw_qr(canvas, url, qr_left, qr_bottom)
        canvas.linkURL(url, (qr_left, qr_bottom, qr_left + QR_SIZE, qr_bottom + QR_SIZE))

        canvas.saveState()
        canvas.translate(x + strip_width / 2, qr_bottom - 3 * mm)
        canvas.rotate(-90)
        canvas.setFillColor(INK)
        lines = ((BOLD, 11, text.headline), (BODY, 10, text.money), (BODY, 7.5, short))
        length = qr_bottom - 3 * mm - bottom - 3 * mm
        # Turned clockwise, the tops of the letters face right: the headline is the rightmost.
        for offset, (font, size, line) in zip((12, 0, -12), lines, strict=True):
            canvas.setFont(font, _fit(line, font, size, length))
            canvas.drawString(0, offset - size / 3, line)
        canvas.restoreState()


def _draw_qr(canvas: Canvas, url: str, left: float, bottom: float) -> None:
    """A QR for `url` at error level Q, which survives a crease or a smudge, with its quiet
    zone (four modules) inside `QR_SIZE`."""
    widget = QrCodeWidget(url, barWidth=QR_SIZE, barHeight=QR_SIZE, barLevel="Q", barBorder=4)
    widget.barFillColor = INK
    widget.barStrokeColor = INK
    drawing = Drawing(QR_SIZE, QR_SIZE)
    drawing.add(widget)
    canvas.setFillColor(white)
    canvas.rect(left, bottom, QR_SIZE, QR_SIZE, stroke=0, fill=1)
    renderPDF.draw(drawing, canvas, left, bottom)


def _fit(line: str, font: str, size: float, width: float) -> float:
    """`size`, or smaller until `line` fits in `width`."""
    return min(size, size * width / pdfmetrics.stringWidth(line, font, size))


def _wrap(paragraph: str, font: str, size: float, width: float) -> list[str]:
    lines: list[str] = []
    for word in paragraph.split():
        if lines and pdfmetrics.stringWidth(f"{lines[-1]} {word}", font, size) <= width:
            lines[-1] = f"{lines[-1]} {word}"
        else:
            lines.append(word)
    return lines
