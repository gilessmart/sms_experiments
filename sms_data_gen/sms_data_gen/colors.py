from typing import Any, Optional

RGB = tuple[int, int, int]

VALID_SMS_RGB_VALUES = {0, 85, 170, 255}

def is_sms_color(color: RGB) -> bool:
    r, g, b = color
    return all(c in VALID_SMS_RGB_VALUES for c in (r, g, b))

def to_rgb(color: Any) -> Optional[RGB]:
    if isinstance(color, tuple) \
        and len(color) >= 3 \
        and all(isinstance(ch, int) for ch in color):
        return color[:3]
    return None
