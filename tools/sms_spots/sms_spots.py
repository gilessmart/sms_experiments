# Generates Damien Hirst style spot paintings using colours from the SMS colour palette
# Deps: pillow

import math
import random

from PIL import Image, ImageDraw

width = 256
height = 224
spot_size = 14
spot_gap = 18
color_count = 16

def generate_valid_colors() -> list[tuple[int, int, int]]:
    valid_channel_values = [0, 85, 170, 255]
    colors: list[tuple[int, int, int]] = []
    for r in valid_channel_values:
        for g in valid_channel_values:
            for b in valid_channel_values:
                color = (r, g, b)
                colors.append(color)
    return colors

def generate_image(valid_colors: list[tuple[int, int, int]]) -> Image.Image:
    excluded_colors = [(0, 0, 0), (255, 255, 255)]
    candidate_colors = [c for c in valid_colors if c not in excluded_colors]
    spot_colors = random.sample(candidate_colors, color_count - 1)

    im = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(im)

    row_offset = math.isqrt(len(spot_colors))

    row = 0
    while True:
        row_top_y = row * (spot_size + spot_gap)
        if row_top_y > height:
            break;

        col = 0
        while True:
            col_left_x = col * (spot_size + spot_gap)
            if col_left_x > width:
                break

            color_idx = (row * row_offset + col) % len(spot_colors)
            color = spot_colors[color_idx]
            
            # use ImageDraw.elipse() to draw a circle 
            # because ImageDraw.circle() can only draw circles with odd diameters
            # and I want mine to be even
            left = col_left_x + (spot_gap / 2)
            top = row_top_y + (spot_gap / 2)
            right = left + spot_size - 1
            bottom = top + spot_size - 1
            draw.ellipse((left, top, right, bottom), color)

            col += 1
        row += 1

    return im

colors = generate_valid_colors()
img = generate_image(colors)
img.save("spots.png")
