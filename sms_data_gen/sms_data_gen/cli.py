import argparse
from sms_data_gen.tiles import read_tile_sheet, write_tile_data
from sms_data_gen.palette import write_palette_data
from sms_data_gen.tilemap import read_background, write_tilemap_data

def main():
    args = parse_args()

    if args.bg_tiles_file_path:
        tiles, tile_palette = read_tile_sheet(args.bg_tiles_file_path)

    if args.bg_file_path:
        tilemap = read_background(args.bg_file_path, tiles, tile_palette)

    # TODO read sprite sheet

    write_palette_data(args.output_dir_path, tile_palette, [])
    
    if args.bg_file_path:
        write_tilemap_data(args.output_dir_path, tilemap)
    
    # TODO write sprite data
    
    if len(tiles) > 0:
        write_tile_data(args.output_dir_path, tiles, tile_palette)

def parse_args():
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
