import sys
from PIL import Image

def read_tiles(file_path):
    try:
        img = Image.open(file_path).convert("RGB")
    except Exception as e:
        print(f"Error: Could not open tiles file: {file_path}\n{e}")
        sys.exit(1)

    with img:
        colors = [color for _, color in img.getcolors()]
        validate_colors(colors)
        tiles = extract_tiles(img)
        return tiles, colors

def validate_colors(colors):
    if len(colors) > 16:
        print("Error: tiles file has more than 16 colors")
        sys.exit(1)
    
    for color in colors:
        if not is_sms_color(color):
            print(f"Error: tiles has a color that isn't a valid SMS color")
            sys.exit(1)

VALID_SMS_RGB_VALUES = {0, 85, 170, 255}

def is_sms_color(color):
    r, g, b = color[:3]
    return all(c in VALID_SMS_RGB_VALUES for c in (r, g, b))

def extract_tiles(img, tile_size=8):
    tiles = []

    width, height = img.size
    cols, rows = width // 8, height // 8
    for y in range(rows):
        for x in range(cols):
            tiles.append(img.crop((
                x * tile_size,
                y * tile_size,
                x * tile_size + tile_size,
                y * tile_size + tile_size)))
    
    return tiles
