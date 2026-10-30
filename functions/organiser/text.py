"""What the gates read in a message's words: Markdown, emoji, tú forms, private places and money.

Every checker here is deliberately simple, and its limits are known:

- `strip_markdown` removes what a chat model writes in an answer (bold, italics, headings, list
  markers, block quotes, inline code and fences, links and images, rules) and joins the lines
  into one. It parses no nesting and no HTML.
- `emoji` finds the pictographic blocks: U+1F000 to 1FAFF (faces, food, 🧉 is U+1F9C9), flags,
  U+2600 to 27BF (symbols and dingbats, ✔ and ✳ among them), the clock and star symbols, and the
  joiners (U+FE0F, U+200D, U+20E3). It leaves typography alone:
  · ¿ ° % … dashes and accented letters.
  Symbols that are emoji only with U+FE0F (©, ®, ↔) pass without it.
- `tu_forms` finds tú-only words: the pronouns (tú, contigo, ti after a preposition) and a list
  of common tú-only verb forms (eres, tienes, puedes, vienes…). Vos and tú share many forms
  ("estás", "vas", "tu"), regular tú presents ("llevas") look like plural nouns to a regex, and
  unaccented imperatives ("avisa") read as a third person, so it catches the frequent slips, not
  every one; vosotros forms are not checked.
- `private_place` finds a home: "en lo de", "en casa de", "mi casa", and a street word or a
  capitalised name followed by a number ("Av. Central 1234"). A capitalised word before a
  three- to five-digit number that is not an address ("Octubre 2026") reads as one too.
- `money` finds a word that asks for or mentions money: plata, dinero, pesos, a "$", dólares,
  the verbs pagar, cobrar, transferir and donar in their usual forms, cuota, Mercado Pago,
  Abitab, RedPagos, "en efectivo", vaquita, colecta, propina, billete, precio, gratis, and a
  number before "lucas". "Plata" as a name passes: "Río de la Plata", "La Plata", "Mar del
  Plata" (capitalised after "la" or "del"); "la plata" in lower case is money. "Pesos" counts
  only in the plural ("el peso de las sillas" passes) and "efectivo" only after "en". Renting a
  cancha ("alquilar") and a price in words with no number ("dos lucas") pass.
"""

import re

_FENCE = re.compile(r"```[^\n]*\n?")
_IMAGE = re.compile(r"!\[([^\]]*)\]\([^)]*\)")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_CODE = re.compile(r"`([^`]*)`")
_BOLD = re.compile(r"(\*\*|__)(.+?)\1")
_ITALIC = re.compile(r"(?<![\w*])([*_])(?!\s)(.+?)(?<!\s)\1(?![\w*])")
_HEADING = re.compile(r"^\s{0,3}#{1,6}\s+", re.MULTILINE)
_QUOTE = re.compile(r"^\s{0,3}>\s?", re.MULTILINE)
_LIST = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+", re.MULTILINE)
_RULE = re.compile(r"^\s*(?:[-*_]\s*){3,}$", re.MULTILINE)
_SPACES = re.compile(r"\s+")


def strip_markdown(text: str) -> str:
    """`text` as plain words on one line, without the Markdown a chat model adds."""
    text = _FENCE.sub("", text)
    text = _RULE.sub("", text)
    text = _IMAGE.sub(r"\1", text)
    text = _LINK.sub(r"\1", text)
    text = _CODE.sub(r"\1", text)
    text = _BOLD.sub(r"\2", text)
    text = _ITALIC.sub(r"\2", text)
    text = _HEADING.sub("", text)
    text = _QUOTE.sub("", text)
    text = _LIST.sub("", text)
    return _SPACES.sub(" ", text).strip()


_EMOJI = re.compile(
    "["
    "\U0001f000-\U0001faff"  # mahjong to symbols and pictographs extended-A, flags included
    "☀-➿"  # miscellaneous symbols and dingbats
    "⌚⌛⌨⏏⏩-⏳⏸-⏺"  # watch, hourglass, play buttons
    "⬅-⬇⬛⬜⭐⭕"  # arrows, squares, star, circle
    "〰〽㊗㊙"
    "️‍⃣"  # emoji presentation, joiner, keycap
    "]"
)


def emoji(text: str) -> str:
    """The first emoji in `text`, or an empty string."""
    match = _EMOJI.search(text)
    return match.group() if match else ""


_TU_VERBS = (
    "eres",
    "tienes",
    "puedes",
    "quieres",
    "vienes",
    "sabes",
    "dices",
    "haces",
    "vuelves",
    "prefieres",
    "sientes",
    "piensas",
    "juegas",
    "duermes",
    "sigues",
    "pides",
    "entiendes",
    "recuerdas",
    "cuentas",
    "empiezas",
    "encuentras",
    "debes",
    "vives",
    "conoces",
    "llevas",
    "traes",
    "avisas",
    "necesitas",
    "llegas",
    "esperas",
    "buscas",
    "eliges",
    "decides",
    "escribes",
    "mandas",
    "cambias",
    "contestas",
    "acuerdas",
    "olvidas",
    "haz",
    "pon",
)
_TU = re.compile(
    r"\b(?:tú|contigo|(?:a|de|en|para|por|sin|sobre|hacia|con)\s+ti|"
    + "|".join(_TU_VERBS)
    + r")\b",
    re.IGNORECASE,
)


def tu_forms(text: str) -> str:
    """The first tú-only word in `text` (Ronda writes in voseo), or an empty string."""
    match = _TU.search(text)
    return match.group() if match else ""


_HOME = re.compile(r"\b(?:en lo de|en casa de|mi casa|su casa|tu casa)\b", re.IGNORECASE)
_STREET = re.compile(
    r"\b(?:av\.?|avenida|calle|pasaje|bulevar|ruta)\s+[^\d,.;]{2,40}?\s*\d{1,5}\b",
    re.IGNORECASE,
)
_NAMED_NUMBER = re.compile(r"\b[A-ZÁÉÍÓÚÑ][\wáéíóúñ.]*(?:\s+[A-ZÁÉÍÓÚÑ][\wáéíóúñ.]*)*\s+\d{3,5}\b")


def private_place(text: str) -> str:
    """What in `text` looks like a home or an address, or an empty string."""
    for pattern in (_HOME, _STREET, _NAMED_NUMBER):
        if match := pattern.search(text):
            return match.group()
    return ""


_PLATA_AS_A_NAME = re.compile(r"\b(?:(?i:r[ií]o\s+de\s+la\s+plata)|(?i:la|del)\s+Plata)\b")
"""The river and the cities: "Plata" capitalised after "la" or "del", and "río de la plata"."""
_MONEY = re.compile(
    r"\$|\b\d+\s*lucas\b|\b(?:"
    r"plata|dinero|pesos|pesitos|d[oó]lares|usd|uyu|billetes?|en\s+efectivo|"
    r"pag(?:ar|á|ás|a|an|amos|o|os|ó|ue|uen|uemos|ando|ado|ada|aste|aron)|"
    r"cobr(?:ar|á|ás|a|an|amos|o|ó|e|en|ando|ado)|"
    r"transfer(?:encia|encias|ir|í|ís|imos|ime|ile|ilo)|"
    r"don(?:ar|á|ás|amos|ación|aciones|ativo)|"
    r"cuotas?|mercado\s*pago|abitab|red\s*pagos|vaquita|colecta|propinas?|precios?|gratis"
    r")\b",
    re.IGNORECASE,
)


def money(text: str) -> str:
    """The first word in `text` that asks for or mentions money, or an empty string."""
    match = _MONEY.search(_PLATA_AS_A_NAME.sub(" ", text))
    return match.group() if match else ""
