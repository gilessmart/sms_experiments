import sys
from PIL import Image
from sms_data_gen.color import is_sms_color
from sms_data_gen.utils import group, write_file

TILE_SIZE = 8

def read_tile_sheet(file_path):
    try:
        img = Image.open(file_path).convert("RGBA")
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
        print("Error: tiles file has more than 16 unique colors")
        sys.exit(1)
    
    for color in colors:
        if not is_sms_color(color):
            print(f"Error: tiles file uses a color that isn't a valid SMS color ({color})")
            sys.exit(1)

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
    content = format_tile_patterns(data)
    write_file(output_dir, "tile_patterns.asm", content)

def format_tile_patterns(tile_data_list):
    """Format tile data as assembly code content."""
    lines = ["TilePatterns:"]
    
    for tile_num, tile_data in enumerate(tile_data_list):
        lines.append(f"; tile {tile_num:02x}")
        
        for group_of_16 in group(tile_data, 16):
            group_strs = []
            for group_of_4 in group(group_of_16, 4):
                group_strs.append(",".join([f"${val:02x}" for val in group_of_4]))
            lines.append(".db " + ", ".join(group_strs))
    
    lines.append("TilePatternsEnd:")
    return "\n".join(lines) + "\n"

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