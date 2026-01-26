from dataclasses import dataclass
import sys
from PIL import Image
from sms_data_gen.color import is_sms_color
from sms_data_gen.tiles import extract_tiles
from sms_data_gen.utils import group, write_file

def read_background(file_path, tiles, tile_palette):
    try:
        img = Image.open(file_path).convert("RGBA")
    except Exception as e:
        print(f"Error: Could not open background file: {file_path}\n{e}")
        sys.exit(1)

    with img:
        colors = [color for _, color in img.getcolors()]
        validate_tilemap_colors(colors)
        # add background colors to the palette
        for color in colors:
            if color not in tile_palette:
                tile_palette.append(color)
        
        validate_palette_colors(tile_palette)

        tilemap = []
        bg_tiles = extract_tiles(img)
        for bg_tile in bg_tiles:
            tilemap_entry = create_tilemap_entry(tiles, bg_tile)
            tilemap.append(tilemap_entry)
        
        return tilemap

def validate_tilemap_colors(colors):
    if len(colors) > 16:
        print("Error: background file has more than 16 unique colors")
        sys.exit(1)
    
    for color in colors:
        if not is_sms_color(color):
            print(f"Error: tiles file uses a color that isn't a valid SMS color ({color})")
            sys.exit(1)

def validate_palette_colors(tile_palette):
    if len(tile_palette) > 16:
        print("Error: tile file and background file combined contain more than 16 unique colors")
        sys.exit(1)

@dataclass
class TilemapEntry:
    tile_num: int
    horizontal_flip: bool
    vertical_flip: bool

def create_tilemap_entry(tiles, bg_tile):
    for tile_num, tile in enumerate(tiles):
        if tile == bg_tile:
            return TilemapEntry(tile_num, False, False)
        elif tile == bg_tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT):
            return TilemapEntry(tile_num, True, False)
        elif tile == bg_tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM):
            return TilemapEntry(tile_num, False, True)
        elif tile == bg_tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT).transpose(Image.Transpose.FLIP_TOP_BOTTOM):
            return TilemapEntry(tile_num, True, True)
        
    tilemap_entry = TilemapEntry(len(tiles), False, False)
    tiles.append(bg_tile)
    return tilemap_entry

def write_tilemap_data(output_dir, tilemap):
    data = [get_tilemap_entry_data(tilemap_entry) for tilemap_entry in tilemap]
    content = create_tilemap_file_content(data)
    write_file(output_dir, "tilemap.asm", content)

def get_tilemap_entry_data(entry):
    high_byte = 0
    if entry.vertical_flip: high_byte += 4
    if entry.horizontal_flip: high_byte += 2
    return f"${high_byte:02x}{entry.tile_num:02x}"

def create_tilemap_file_content(words):
    lines = ["Tilemap:"]

    for line_num, group_of_32 in enumerate(group(words, 32)):
        lines.append(f"; line {line_num}")
        for group_of_16 in group(group_of_32, 16):
            lines.append(f".dw " + ",".join(group_of_16))
    
    lines.append("TilemapEnd:")

    return "\n".join(lines)