import re

from typing import Any, cast

RGBA = tuple[int, int, int, int]

def as_rgba(color: Any) -> RGBA:
    return cast(RGBA, color)

def is_opaque(color: RGBA) -> bool:
    _, _, _, a = color
    return a == 255

def is_transparent(color: RGBA) -> bool:
    _, _, _, a = color
    return a == 0

SMS_RGB_VALUES = {0, 85, 170, 255}

def is_sms_color(color: RGBA) -> bool:
    r, g, b, a = color
    return a == 255 and all(c in SMS_RGB_VALUES for c in (r, g, b))

def parse_hex_colors(colors_arg: str) -> list[RGBA]:
    matches = re.findall(r"#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})", colors_arg, re.I)
    colors: list[RGBA] = []
    for match in matches:
        (hex_r, hex_g, hex_b) = match
        color = (int(hex_r, 16), int(hex_g, 16), int(hex_b, 16), 255)
        colors.append(color)
    return colors
