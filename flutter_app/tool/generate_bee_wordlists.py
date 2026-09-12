#!/usr/bin/env python3
"""Builds the Spelling Bee tier word lists from the data already bundled.

Spelling Bee shows two progress bars at once — "normal" (yellow) and
"difficult" (silver) — and awards bonus points for anything else the language
accepts. That split needs a notion of how common a word is, which the Wordle
lists do not provide on their own:

* ``en/difficult.txt`` is a Wordle guess list: outside of five-letter words it
  is identical to ``en/guessable.txt``, so it cannot carry a tier of its own.
* ``de/*.txt`` are three copies of one frequency-ordered list.

So the tiers are derived here, once, and written next to the lists they come
from. Nothing new is downloaded: every input is already in ``assets/``.

English
    Candidates are the headwords of ``assets/dicts/en/dict.json`` that also
    appear in lower case in ``all.txt`` — the dictionary carries proper nouns
    (AACHEN, ZWINGLI) and a word that is never written in lower case is one.
    A word is *normal* when it is in ``guessable.txt`` (a curated common-word
    list) or the dictionary gives it three or more meanings, which separates
    common words from the rest about ten to one. Everything else is
    *difficult*

German
    ``de/all.txt`` is ordered by frequency, so rank is the signal: the most
    common eligible words become *normal*, the next band *difficult*.

Anything a language accepts but neither list holds stays out of both files and
scores as a bonus word at runtime.

Usage:  python tool/generate_bee_wordlists.py [--check]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORDLISTS = ROOT / "assets" / "wordlists"
DICTS = ROOT / "assets" / "dicts"

# A puzzle offers seven letters, and a word shorter than four letters is not
# worth a point — matches kBeeMinWordLength / kBeeLetterCount on the Dart side.
MIN_WORD_LENGTH = 4
LETTER_COUNT = 7

# Three or more dictionary meanings marks a word as common (see module docs).
COMMON_MEANING_COUNT = 3

# German tier sizes, in ranks of the frequency list. Tuned so a puzzle offers
# a yellow bar that can realistically be filled and a silver bar that is a
# stretch, the same shape the English lists produce.
DE_NORMAL_RANK = 2600
DE_DIFFICULT_RANK = 6500

GERMAN_EXTRA_LETTERS = "ÄÖÜß"


def read_lines(path: Path) -> list[str]:
    with path.open(encoding="utf-8") as handle:
        return [line.strip() for line in handle if line.strip()]


def normalize(word: str, german: bool) -> str | None:
    """Upper-cases a word, or returns None when it is not a plain word."""
    word = word.upper().replace("ẞ", "ß")
    alphabet_extra = GERMAN_EXTRA_LETTERS if german else ""
    for char in word:
        if not ("A" <= char <= "Z" or char in alphabet_extra):
            return None
    return word


def is_eligible(word: str) -> bool:
    return len(word) >= MIN_WORD_LENGTH and len(set(word)) <= LETTER_COUNT


def inflection_bases(word: str) -> list[str]:
    """Base forms a regular English inflection of [word] could have come from."""
    bases: list[str] = []
    if word.endswith("S"):
        bases.append(word[:-1])
        if word.endswith("ES"):
            bases.append(word[:-2])
        if word.endswith("IES"):
            bases.append(word[:-3] + "Y")
    if word.endswith("ED"):
        bases += [word[:-1], word[:-2]]
        if word.endswith("IED"):
            bases.append(word[:-3] + "Y")
        if len(word) > 4 and word[-3] == word[-4]:
            bases.append(word[:-3])  # stopped -> stop
    if word.endswith("ING"):
        bases += [word[:-3], word[:-3] + "E"]
        if len(word) > 5 and word[-4] == word[-5]:
            bases.append(word[:-4])  # stopping -> stop
    return bases


def build_english() -> dict[str, list[str]]:
    raw = read_lines(WORDLISTS / "en" / "all.txt")
    # A dictionary headword that never shows up in lower case is a proper noun.
    seen_lower = {word.upper() for word in raw if word.isalpha() and word[0].islower()}

    with (DICTS / "en" / "dict.json").open(encoding="utf-8") as handle:
        dictionary = json.load(handle)

    guessable = {
        normalized
        for word in read_lines(WORDLISTS / "en" / "guessable.txt")
        if (normalized := normalize(word, german=False))
    }

    normal: set[str] = set()
    difficult: set[str] = set()
    for headword, entry in dictionary.items():
        word = normalize(headword, german=False)
        if word is None or word != headword:
            continue
        if word not in seen_lower or not is_eligible(word):
            continue
        meanings = entry.get("MEANINGS") or []
        if word in guessable or len(meanings) >= COMMON_MEANING_COUNT:
            normal.add(word)
        else:
            difficult.add(word)

    listed = normal | difficult
    difficult = {
        word
        for word in difficult
        if not any(base in listed for base in inflection_bases(word))
    }
    return {"normal": sorted(normal), "difficult": sorted(difficult)}


def build_german() -> dict[str, list[str]]:
    ranked: list[str] = []
    seen: set[str] = set()
    for line in read_lines(WORDLISTS / "de" / "all.txt"):
        word = normalize(line, german=True)
        if word is not None and word not in seen:
            seen.add(word)
            ranked.append(word)

    normal = [w for w in ranked[:DE_NORMAL_RANK] if is_eligible(w)]
    difficult = [
        w for w in ranked[DE_NORMAL_RANK:DE_DIFFICULT_RANK] if is_eligible(w)
    ]
    return {"normal": sorted(normal), "difficult": sorted(difficult)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail instead of writing when the lists are out of date",
    )
    args = parser.parse_args()

    stale = False
    for language, build in (("en", build_english), ("de", build_german)):
        for tier, words in build().items():
            path = WORDLISTS / language / f"bee_{tier}.txt"
            content = "\n".join(words) + "\n"
            current = path.read_text(encoding="utf-8") if path.exists() else None
            if args.check:
                if current != content:
                    print(f"out of date: {path.relative_to(ROOT)}")
                    stale = True
                continue
            path.write_text(content, encoding="utf-8")
            print(
                f"{path.relative_to(ROOT)}: {len(words)} words, "
                f"{len(content) / 1024:.0f} KiB"
            )

    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
