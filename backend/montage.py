DIGIT_SEGMENTS = {
    1: 'bc',
    2: 'abdeg',
    3: 'abcdg',
    4: 'bcfg',
    5: 'acdfg',
}

def sequence_badge_filter(number: int) -> str:
    segment_boxes = {
        'a': 'x=56:y=(h-88)/2+14:w=24:h=5',
        'b': 'x=78:y=(h-88)/2+16:w=5:h=22',
        'c': 'x=78:y=(h-88)/2+39:w=5:h=22',
        'd': 'x=56:y=(h-88)/2+59:w=24:h=5',
        'e': 'x=53:y=(h-88)/2+39:w=5:h=22',
        'f': 'x=53:y=(h-88)/2+16:w=5:h=22',
        'g': 'x=56:y=(h-88)/2+36:w=24:h=5',
    }
    badge = ['drawbox=x=36:y=(h-88)/2:w=64:h=88:color=black@0.72:t=fill']
    badge.extend(f'drawbox={segment_boxes[segment]}:color=white:t=fill' for segment in DIGIT_SEGMENTS[number])
    return ','.join(badge)
