import argparse
from PIL import Image

from sms_data_gen.colors import RGBA, is_opaque_sms_color, is_transparent
from sms_data_gen.patterns import PatternList, write_bg_tiles_img, write_patterns_asm
from sms_data_gen.image_utils import extract_tiles, flip_h, flip_hv, flip_v, get_colors_as_rgba
from sms_data_gen.palettes import Palette, write_palettes
from sms_data_gen.tilemap import Tilemap, TilemapEntry, write_tilemap_asm

def main():
    args = parse_args()

    bg_tile_palette = Palette(16)
    bg_tile_patterns = PatternList(256)
    tilemap = Tilemap(32*28)
    sprite_palette = Palette(16)
    sprite_patterns = PatternList(192)
    
    # ingest the background tiles file
    original_bg_tile_count = 0
    if args.bg_tiles_file_path:
        with Image.open(args.bg_tiles_file_path).convert("RGBA") as img:
            colors = get_colors_as_rgba(img)
            validate_bg_tile_colors(colors)
            bg_tile_palette.add_colors(colors)

            tiles = extract_tiles(img)
            original_bg_tile_count = len(tiles)
            bg_tile_patterns.add_patterns(tiles)

    # ingest the background file
    if args.bg_file_path:
        with Image.open(args.bg_file_path).convert("RGBA") as img:
            colors = get_colors_as_rgba(img)
            validate_bg_tile_colors(colors)
            bg_tile_palette.add_new_colors(colors)
            
            for tile in extract_tiles(img):
                if (idx := bg_tile_patterns.index(tile)) is not None:
                    tilemap.add_entry(TilemapEntry(idx, False, False))
                elif (idx := bg_tile_patterns.index(flip_h(tile))) is not None:
                    tilemap.add_entry(TilemapEntry(idx, True, False))
                elif (idx := bg_tile_patterns.index(flip_v(tile))) is not None:
                    tilemap.add_entry(TilemapEntry(idx, False, True))
                elif (idx := bg_tile_patterns.index(flip_hv(tile))) is not None:
                    tilemap.add_entry(TilemapEntry(idx, True, True))
                else:
                    index = bg_tile_patterns.add_pattern(tile)
                    tilemap.add_entry(TilemapEntry(index, False, False))

    # ingest the sprites file
    if args.sprites_file_path:
        with Image.open(args.sprites_file_path).convert("RGBA") as img:
            colors = get_colors_as_rgba(img)
            validate_sprite_colors(colors)
            # palette idx 0 reserved for transparent pixels in sprites
            # so we populate it with a placeholder color
            sprite_palette.add_colors([(0, 0, 0, 0)] + colors)

            tiles = extract_tiles(img)
            sprite_patterns.add_patterns(tiles)
    
    write_palettes(args.output_dir_path, bg_tile_palette, sprite_palette)

    if not bg_tile_patterns.is_empty():
        data = bg_tile_patterns.get_bytes(bg_tile_palette.index)
        write_patterns_asm(args.output_dir_path, "tile_patterns.asm", "TilePatterns", data)
    
    if not tilemap.is_empty():
        data = tilemap.get_bytes()
        write_tilemap_asm(args.output_dir_path, data)
    
    if not sprite_patterns.is_empty():
        def get_sprite_palette_idx(color: RGBA):
            _, _, _, a = color
            return sprite_palette.index(color) if a == 255 else 0
        
        data = sprite_patterns.get_bytes(get_sprite_palette_idx)
        write_patterns_asm(args.output_dir_path, "sprite_patterns.asm", "SpritePatterns", data)

    # Output tile pattern image if new patterns were added
    patterns = bg_tile_patterns.get_patterns()
    if len(patterns) > original_bg_tile_count:
        write_bg_tiles_img(args.output_dir_path, patterns)

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Image Data Generator for SMS Games")
    parser.add_argument("-b", "--bg", metavar="background file path", dest="bg_file_path", help="path to background file")
    parser.add_argument("-t", "--bg-tiles", metavar="background tiles file path", dest="bg_tiles_file_path", help="path to background tiles file")
    parser.add_argument("-s", "--sprites", metavar="sprites file path", dest="sprites_file_path", help="path to sprites file")
    parser.add_argument("-o", "--out", metavar="output directory path", dest="output_dir_path", help="output directory path")
    args = parser.parse_args()
    
    # ensure at least 1 file path is given
    if not (args.sprites_file_path or args.bg_tiles_file_path or args.bg_file_path):
        parser.error("At least one of the background file path, background tiles file path and sprites file path must be supplied")

    # ensure file paths are unique
    file_paths = []
    if args.bg_tiles_file_path: file_paths.append(args.bg_tiles_file_path)
    if args.bg_file_path: file_paths.append(args.bg_file_path)
    if args.sprites_file_path: file_paths.append(args.sprites_file_path)
    if len(file_paths) != len(set(file_paths)):
        parser.error("The background file path, background tiles file path and sprites file path must all be unique")

    return args

def validate_bg_tile_colors(colors: list[RGBA]) -> None:  
    for color in colors:
        if not is_opaque_sms_color(color):
            raise Exception(f"{color} is not a valid color for a background tile")
        
def validate_sprite_colors(colors: list[RGBA]) -> None:
    for color in colors:
        if not is_transparent(color) and not is_opaque_sms_color(color):
            raise Exception(f"{color} is not a valid color for a background tile")

if __name__ == "__main__":
    main()
