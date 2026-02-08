from typing import Any, Optional, cast

RGBA = tuple[int, int, int, int]

VALID_SMS_RGB_VALUES = {0, 85, 170, 255}

def is_opaque_sms_color(color: RGBA) -> bool:
    r, g, b, a = color
    return a == 255 and all(c in VALID_SMS_RGB_VALUES for c in (r, g, b))

def is_transparent(color: RGBA) -> bool:
    _, _, _, a = color
    return a == 0
    
def as_rgba(color: Any) -> RGBA:
    return cast(RGBA, color)
