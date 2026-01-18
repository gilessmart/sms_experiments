import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description="Image Data Generator for SMS Games")
    parser.add_argument('--sprites', required=True, help='Path to sprites PNG file')
    parser.add_argument('--tiles', required=False, help='Path to tiles PNG file (optional)')
    parser.add_argument('--tilemap', required=True, help='Path to tilemap PNG file')
    args = parser.parse_args()

    # Validate file paths
    missing_files = []
    sprites_path = os.path.abspath(args.sprites)
    tiles_path = os.path.abspath(args.tiles) if args.tiles else None
    tilemap_path = os.path.abspath(args.tilemap)

    if not os.path.isfile(sprites_path):
        missing_files.append(f"sprites: {args.sprites}")
    if tiles_path and not os.path.isfile(tiles_path):
        missing_files.append(f"tiles: {args.tiles}")
    if not os.path.isfile(tilemap_path):
        missing_files.append(f"tilemap: {args.tilemap}")
    if missing_files:
        print("Error: The following files do not exist:")
        for f in missing_files:
            print(f"  {f}")
        sys.exit(1)

    # Ensure no two file paths are the same
    file_paths = [sprites_path, tilemap_path]
    if tiles_path:
        file_paths.append(tiles_path)
    if len(set(file_paths)) != len(file_paths):
      print("Error: Two or more file paths point to the same file.")
      sys.exit(1)

    print(f"Processing images...")

if __name__ == "__main__":
    main()
