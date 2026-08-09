from typing import Literal


OutputAspect = Literal['portrait', 'landscape']
OutputResolution = Literal['720p', '1080p', '1440p']

RESOLUTION_DIMENSIONS = {
    'portrait': {
        '720p': (720, 1280),
        '1080p': (1080, 1920),
        '1440p': (1440, 2560),
    },
    'landscape': {
        '720p': (1280, 720),
        '1080p': (1920, 1080),
        '1440p': (2560, 1440),
    },
}


def resolution_dimensions(aspect: OutputAspect, resolution: OutputResolution) -> tuple[int, int]:
    return RESOLUTION_DIMENSIONS[aspect][resolution]


def build_output_filter(
    portrait_filter: str,
    aspect: OutputAspect,
    resolution: OutputResolution,
) -> str:
    target_width, target_height = resolution_dimensions(aspect, resolution)
    if aspect == 'landscape':
        return (
            f'scale={target_width}:{target_height}:force_original_aspect_ratio=decrease,'
            f'pad={target_width}:{target_height}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1'
        )
    if resolution == '1080p':
        return portrait_filter
    return f'{portrait_filter},scale={target_width}:{target_height}'
