from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Protocol


class TimedText(Protocol):
    start: float
    end: float
    text: str


HOOK_WORDS = {
    "bagaimana",
    "bedanya",
    "benar",
    "cara",
    "gimana",
    "harus",
    "intinya",
    "jangan",
    "kenapa",
    "masalahnya",
    "penting",
    "rahasia",
    "salah",
    "ternyata",
    "tips",
    "trik",
}

PAYOFF_WORDS = {
    "akhirnya",
    "hasilnya",
    "intinya",
    "kesimpulannya",
    "makanya",
    "solusinya",
}

WEAK_STARTS = {
    "dan",
    "eh",
    "em",
    "ini",
    "itu",
    "jadi",
    "lalu",
    "nah",
    "terus",
    "ya",
}

FILLER_WORDS = {
    "anu",
    "eh",
    "em",
    "gitu",
    "kayak",
    "mungkin",
    "sih",
    "tuh",
    "ya",
}


@dataclass(frozen=True)
class ScoreResult:
    score: int
    reasons: list[str]
    breakdown: dict[str, int]


def _words(text: str) -> list[str]:
    return re.findall(r"[\w']+", text.lower())


def _opening_score(items: list[TimedText], words: list[str]) -> tuple[int, list[str]]:
    if not words:
        return -15, ["awal tidak terbaca"]

    opening_end = items[0].start + 5
    opening_text = " ".join(item.text for item in items if item.start < opening_end)
    opening_words = _words(opening_text)
    hook_hits = sorted(HOOK_WORDS.intersection(opening_words))

    score = min(20, len(hook_hits) * 6)
    reasons: list[str] = []
    if hook_hits:
        reasons.append("hook awal: " + ", ".join(hook_hits[:3]))
    if "?" in opening_text:
        score += 4
        reasons.append("dibuka dengan pertanyaan")
    if words[0] in WEAK_STARTS:
        score -= 12
        reasons.append("awal menggantung")
    else:
        score += 4
        reasons.append("awal tegas")
    return score, reasons


def _content_score(text: str, words: list[str], duration: float) -> tuple[int, list[str]]:
    density = len(words) / max(duration, 1)
    score = 0
    reasons: list[str] = []

    if 1.4 <= density <= 3.4:
        score += 12
        reasons.append("speech padat dan terbaca")
    elif 1.0 <= density < 1.4:
        score += 7
        reasons.append("speech cukup padat")
    elif density > 3.4:
        score += 4
        reasons.append("speech terlalu padat")
    else:
        score -= 6
        reasons.append("speech renggang")

    if len(words) >= 70:
        score += 8
        reasons.append("konteks cukup")
    elif len(words) >= 55:
        score += 4
    elif len(words) < 45:
        score -= 10
        reasons.append("konteks terlalu sedikit")

    filler_ratio = sum(word in FILLER_WORDS for word in words) / max(len(words), 1)
    if filler_ratio >= 0.12:
        score -= 10
        reasons.append("terlalu banyak filler")
    elif filler_ratio >= 0.07:
        score -= 5
        reasons.append("cukup banyak filler")
    else:
        score += 4
        reasons.append("filler rendah")

    normalized_segments = [" ".join(_words(item)) for item in re.split(r"[.!?]+", text)]
    meaningful = [item for item in normalized_segments if len(item.split()) >= 4]
    duplicate_count = len(meaningful) - len(set(meaningful))
    if duplicate_count:
        score -= min(10, duplicate_count * 5)
        reasons.append("ada pengulangan")
    else:
        score += 3

    return score, reasons


def _ending_score(items: list[TimedText], text: str) -> tuple[int, list[str]]:
    ending_start = items[-1].end - min(12, max(5, (items[-1].end - items[0].start) * 0.2))
    ending_text = " ".join(item.text for item in items if item.end > ending_start)
    payoff_hits = sorted(PAYOFF_WORDS.intersection(_words(ending_text)))

    score = 0
    reasons: list[str] = []
    if text.rstrip().endswith((".", "!", "?")):
        score += 8
        reasons.append("ending selesai")
    else:
        score -= 8
        reasons.append("ending menggantung")
    if payoff_hits:
        score += 8
        reasons.append("payoff akhir: " + ", ".join(payoff_hits[:2]))
    return score, reasons


def _rhythm_score(items: list[TimedText]) -> tuple[int, list[str]]:
    gaps = [max(0.0, current.start - previous.end) for previous, current in zip(items, items[1:])]
    long_gap_count = sum(gap >= 2.0 for gap in gaps)
    if long_gap_count:
        penalty = min(12, long_gap_count * 4)
        return -penalty, [f"{long_gap_count} jeda panjang"]
    return 6, ["ritme stabil"]


def _duration_score(duration: float) -> tuple[int, list[str]]:
    if 35 <= duration <= 90:
        return 10, ["durasi kuat"]
    if 25 <= duration <= 120:
        return 7, ["durasi baik"]
    if 20 <= duration <= 150:
        return 3, ["durasi cukup"]
    return -4, ["durasi kurang ideal"]


def score_window(items: list[TimedText], duration: float) -> ScoreResult:
    text = " ".join(item.text for item in items)
    words = _words(text)
    components = {
        "base": (25, []),
        "opening": _opening_score(items, words),
        "content": _content_score(text, words, duration),
        "ending": _ending_score(items, text),
        "rhythm": _rhythm_score(items),
        "duration": _duration_score(duration),
    }
    breakdown = {name: value for name, (value, _) in components.items()}
    reasons = [reason for _, component_reasons in components.values() for reason in component_reasons]
    score = max(1, min(100, sum(breakdown.values())))
    return ScoreResult(score=score, reasons=reasons, breakdown=breakdown)
