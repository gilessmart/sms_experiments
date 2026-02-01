import argparse

from sms_data_gen.patterns import PatternList, write_bg_tile_patterns
from sms_data_gen.image_utils import read_img_as_tiles, get_rgb_colors
from sms_data_gen.palettes import Palette, write_palettes
from sms_data_gen.tilemap import Tilemap, TilemapEntry, write_tilemap

def main():
    args = parse_args()

    bg_tile_palette = Palette(16)
    sprite_palette = Palette(16)
    bg_tile_patterns = PatternList(256)
    tilemap = Tilemap(32*28)

    # ingest the background tiles file
    if args.bg_tiles_file_path:
        tiles = read_img_as_tiles(args.bg_tiles_file_path)
        for tile in tiles:
            colors = get_rgb_colors(tile)
            bg_tile_palette.add_new_colors(colors)
            bg_tile_patterns.add_pattern(tile)

    # ingest the background file
    if args.bg_file_path:
        tiles = read_img_as_tiles(args.bg_file_path)
        for tile in tiles:
            colors = get_rgb_colors(tile)
            bg_tile_palette.add_new_colors(colors)
            
            pattern = bg_tile_patterns.find_equivalent_pattern(tile)
            if pattern is None:
                index = bg_tile_patterns.add_pattern(tile)
                tilemap.add_entry(TilemapEntry(index, False, False))
            else:
                index, h_flip, v_flip = pattern
                tilemap.add_entry(TilemapEntry(index, h_flip, v_flip))

    # TODO ingest the sprites file

    write_palettes(args.output_dir_path, bg_tile_palette, sprite_palette)

    if not bg_tile_patterns.is_empty():
        write_bg_tile_patterns(args.output_dir_path, bg_tile_patterns, bg_tile_palette)
    
    if not tilemap.is_empty():
        write_tilemap(args.output_dir_path, tilemap)
    

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

if __name__ == "__main__":
    main()
