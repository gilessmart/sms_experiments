# Rounds colors in an image to the nearest valid values on the Sega Master System
# Dependencies: pillow

import argparse
import pathlib

from PIL import Image

def nearest_sms_channel_value(value: int) -> int:
    if value < 43: return 0
    if value < 128: return 85
    if value < 213: return 170
    return 255

def nearest_sms_color(color: tuple[int, int, int]) -> tuple[int, int, int]:
    return (
        nearest_sms_channel_value(color[0]),
        nearest_sms_channel_value(color[1]),
        nearest_sms_channel_value(color[2])
    )

parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=pathlib.Path)
args = parser.parse_args()

with Image.open(args.file_path) as img:
    rgb_img = img.convert("RGB")

data = [nearest_sms_color(color) for color in rgb_img.get_flattened_data()]
rgb_img.putdata(data)
rgb_img.save(args.file_path)
