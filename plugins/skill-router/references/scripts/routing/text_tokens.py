"""Keyword tokeniser shared by the indexer and the router.

``build_index`` tokenises each skill's description to build the inverted index;
``route`` tokenises the user's prompt to look candidates up in it.  The two
must therefore agree exactly - a difference in the minimum kanji run length, or
in the English stopword set, makes prompt tokens miss postings that were
written under different rules.

The tokeniser lives here rather than in ``build_index`` so that the prompt path
does not have to import the indexer (and, through it, everything the indexer
needs) just to split a string.  The rules are deliberately fixed constants
rather than configuration: two processes reading the same knob from different
places is precisely the failure this module exists to prevent.
"""
from __future__ import annotations

import re

# 漢字は 2 文字以上、カタカナは 4 文字以上を 1 語とみなす。短い連なりは助詞や
# 一般語に寄りすぎて、逆引き索引で overgeneric として捨てられるだけになる。
_KW_KANJI_RE = re.compile(r"[一-鿿]{2,}")
_KW_KATAKANA_RE = re.compile(r"[ァ-ヺー]{4,}")
_KW_ASCII_RE = re.compile(r"[A-Za-z][A-Za-z0-9_-]{1,}")
_STOPWORDS_EN: frozenset[str] = frozenset(
    {"the", "and", "for", "with", "this", "that", "from", "into", "use"}
)


def extract_keywords(*texts: str) -> list[str]:
    """Return the de-duplicated keyword list for ``texts``, order preserved.

    ASCII tokens are lowercased (so ``PDF`` and ``pdf`` collapse); CJK tokens
    are kept verbatim.
    """
    seen: dict[str, None] = {}
    for text in texts:
        if not text:
            continue
        for token in _KW_KANJI_RE.findall(text):
            seen.setdefault(token, None)
        for token in _KW_KATAKANA_RE.findall(text):
            seen.setdefault(token, None)
        for token in _KW_ASCII_RE.findall(text):
            lower = token.lower()
            if lower in _STOPWORDS_EN:
                continue
            seen.setdefault(lower, None)
    return list(seen)
