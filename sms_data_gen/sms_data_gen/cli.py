import argparse
from sms_data_gen.tiles import read_tiles

def parse_args():
    parser = argparse.ArgumentParser(description="Image Data Generator for SMS Games")
    parser.add_argument('--sprites', help='Path to sprites PNG file')
    parser.add_argument('--tiles', help='Path to tiles PNG file')
    parser.add_argument('--tilemap', help='Path to tilemap PNG file')
    args = parser.parse_args()
    
    # ensure at least 1 file path is given
    if not (args.sprites or args.tiles or args.tilemap):
        parser.error("One of --sprites, --tiles and --tilemap must be supplied")

    # ensure file paths are unique
    file_paths = []
    if args.sprites:
        file_paths.append(args.sprites)
    if args.tiles:
        file_paths.append(args.tiles)
    if args.tilemap:
        file_paths.append(args.tilemap)
    if len(file_paths) != len(set(file_paths)):
        parser.error("All of --sprites, --tiles and --tilemap must be unique")

    return args

def main():
    args = parse_args()

    tiles = []
    tile_palette = []

    if args.tiles:
        tiles, tile_palette = read_tiles(args.tiles)

    print("Tile count", len(tiles))
    print("Tile palette color count", len(tile_palette))