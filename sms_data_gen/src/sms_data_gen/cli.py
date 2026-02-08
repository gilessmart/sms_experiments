import argparse
from dataclasses import dataclass
from typing import Optional

@dataclass
class CliArgs:
    bg_file_path: Optional[str]
    bg_tiles_file_path: Optional[str]
    sprites_file_path: Optional[str]
    output_dir_path: Optional[str]

def parse_args() -> CliArgs:
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
    if args.bg_file_path: file_paths.append(args.bg_file_path)
    if args.bg_tiles_file_path: file_paths.append(args.bg_tiles_file_path)
    if args.sprites_file_path: file_paths.append(args.sprites_file_path)
    if len(file_paths) != len(set(file_paths)):
        parser.error("The background file path, background tiles file path and sprites file path must all be unique")

    return CliArgs(
        bg_file_path=args.bg_file_path, 
        bg_tiles_file_path=args.bg_tiles_file_path, 
        sprites_file_path=args.sprites_file_path, 
        output_dir_path=args.output_dir_path)
