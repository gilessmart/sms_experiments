import sys
import os
from PIL import Image

VALID_SMS_RGB_VALUES = {0, 85, 170, 255}
TILE_SIZE=8

def read_tile_sheet(file_path):
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

def is_sms_color(color):
    r, g, b = color[:3]
    return all(c in VALID_SMS_RGB_VALUES for c in (r, g, b))

def extract_tiles(img):
    tiles = []

    width, height = img.size
    cols, rows = width // 8, height // 8
    for y in range(rows):
        for x in range(cols):
            tiles.append(img.crop((
                x * TILE_SIZE,
                y * TILE_SIZE,
                (x+1) * TILE_SIZE,
                (y+1) * TILE_SIZE)))
    
    return tiles

def write_tile_data(output_dir, tiles, tile_palette):
    data = [get_tile_planar_data(tile, tile_palette) for tile in tiles]
    
    # Determine output file path
    if output_dir is None:
        output_dir = "."
    else:
        os.makedirs(output_dir, exist_ok=True)
    
    output_file = os.path.join(output_dir, "tile_patterns.asm")

    # Write the assembly file
    try:
        f = open(output_file, "w")
    except Exception as e:
        print(f"Error: Could not open data file for writing: {output_file}\n{e}")
        sys.exit(1)
    
    with f:
        f.write("TilePatterns:\n")
        
        for tile_num, tile_data in enumerate(data):
            f.write(f"; Tile {tile_num:02x}\n")

            for group_of_16 in [tile_data[i:i+16] for i in range(0, len(tile_data), 16)]:
                f.write(".db ")
                group_strs = []
                for group_of_4 in [group_of_16[i:i+4] for i in range(0, len(group_of_16), 4)]:
                    group_strs.append(",".join([f"${val:02x}" for val in group_of_4]))
                f.write(", ".join(group_strs) + "\n")
                
        f.write("TilePatternsEnd:\n")
    
    print(f"Wrote tile data to {output_file}")

def get_tile_planar_data(tile, tile_palette):
    tile_bytes = []
    for line in iterate_tile_lines(tile):
        indices = [tile_palette.index(c) for c in line]
        bytes = get_line_planar_data(indices)
        tile_bytes.extend(bytes)
    return tile_bytes

def iterate_tile_lines(tile):
    pixels = list(tile.getdata())
    for line_num in range(8):
        start = line_num * TILE_SIZE
        end = (line_num+1) * TILE_SIZE
        yield pixels[start:end]

def get_line_planar_data(indices):
    """Convert 8 4-bit integers to 4 8-bit integers using planar bit layout.
    
    Pivots bits so that bit plane N becomes output byte N.
    For each output byte, bit position (7-i) comes from bit plane N of input[i].
    """
    output = []
    for bit_plane in range(4):
        byte = 0
        for i, index in enumerate(indices):
            bit = (index >> bit_plane) & 1
            byte |= (bit << (7 - i))
        output.append(byte)
    return output