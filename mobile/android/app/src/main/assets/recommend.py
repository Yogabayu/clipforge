"""Mobile window selection using the project's canonical scoring.py (copied by Gradle)."""
from __future__ import annotations
import json
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from scoring import score_window


@dataclass(frozen=True)
class Segment:
    start: float
    end: float
    text: str


def recommend(payload: dict, top: int = 10, minimum: float = 35, maximum: float = 180) -> list[dict]:
    duration = float(payload['duration'])
    if not math.isfinite(duration) or duration <= 0 or not 1 <= top <= 12:
        raise ValueError('Invalid duration or recommendation count')
    if not (math.isfinite(minimum) and math.isfinite(maximum) and 1 <= minimum < maximum <= 600):
        raise ValueError('Invalid duration bounds')
    segments = [Segment(max(0, float(s['start'])), min(duration, float(s['end'])), str(s['text']).strip())
                for s in payload.get('segments', [])]
    segments = sorted((s for s in segments if s.text and s.start < s.end), key=lambda s: s.start)
    candidates = []
    for start_index, first in enumerate(segments):
        window = []
        for index in range(start_index, len(segments)):
            item = segments[index]
            if item.end - first.start > maximum:
                break
            window.append(item)
            length = item.end - first.start
            if length < min(minimum, duration):
                continue
            text = ' '.join(part.text for part in window)
            result = score_window(window, length)
            start, end = max(0, first.start - .35), min(duration, item.end + .25)
            end = min(end, start + maximum)
            candidates.append(dict(start=start, end=end, duration=end-start, score=result.score,
                title=' '.join(re.sub(r'\s+', ' ', text).strip(' .,!?:;-').split()[:8]).capitalize() or 'Auto clip',
                reason=', '.join(result.reasons) or 'segmen stabil', text=text, score_breakdown=result.breakdown))
    picked = []
    while candidates and len(picked) < top:
        available = [c for c in candidates if all(c['end'] <= p['start'] or c['start'] >= p['end'] for p in picked)]
        if not available:
            break
        def adjusted(candidate):
            diversity = min((abs(candidate['duration'] - p['duration']) for p in picked), default=999)
            return candidate['score'] - abs(candidate['duration'] - 85) * .04 + (8 if diversity > 18 else 0)
        best = max(available, key=adjusted)
        picked.append(best)
        candidates.remove(best)
    if not picked and segments and duration < minimum:
        result = score_window(segments, duration)
        text = ' '.join(s.text for s in segments)
        picked.append(dict(start=0, end=duration, duration=duration, score=result.score,
            title=' '.join(text.split()[:8]).capitalize() or 'Video pendek',
            reason='video pendek; ' + ', '.join(result.reasons), text=text, score_breakdown=result.breakdown))
    # Silence can produce no full window. Label timeline fallback as unscored.
    if not picked:
        length = min(duration, maximum, max(minimum, 85))
        count = min(top, max(1, int(duration // length)))
        for index in range(count):
            start = 0 if count == 1 else (duration - length) * index / (count - 1)
            picked.append(dict(start=start, end=start+length, duration=length, score=0,
                title=f'Visual clip {index+1}', reason='fallback timeline; tidak dinilai dari dialog',
                text='', score_breakdown={}))
    picked.sort(key=lambda candidate: candidate['start'])
    for index, candidate in enumerate(picked, 1):
        candidate['index'] = index
    return picked


if __name__ == '__main__':
    result = recommend(json.loads(Path(sys.argv[1]).read_text(encoding='utf-8')),
        int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]))
    Path(sys.argv[2]).write_text(json.dumps(result, ensure_ascii=False), encoding='utf-8')
