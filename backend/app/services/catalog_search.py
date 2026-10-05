"""Shared normalization for catalogue queries and searchable product text."""

import re
import unicodedata
from html import unescape


def normalize_catalog_search(text: str) -> str:
    text = unescape(text)
    text = re.sub(r"<[^>]*>", " ", text)
    text = "".join(
        character
        for character in unicodedata.normalize("NFKD", text)
        if not unicodedata.combining(character)
    ).casefold()
    text = re.sub(r"(?<=\d),(?=\d)", ".", text)
    # A unit attached to its value and a spaced unit have the same meaning.
    text = re.sub(
        r"(?<=\d)\s+(?=(?:kwc|kwh|kw|wp|w|mm2|mm|ah|a|v|hz)\b)",
        "",
        text,
    )
    return " ".join(re.findall(r"\w+(?:\.\d+\w*)?", text))
