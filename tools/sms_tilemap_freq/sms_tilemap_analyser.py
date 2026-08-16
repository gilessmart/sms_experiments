# Determines how many times each pattern is used in a tilemap
# Dependencies: -

import argparse
import pathlib
import re

def add_to_frequency_dict(dict: dict[int, int], val: int):
    if val in dict:
        dict[val] += 1
    else:
        dict[val] = 1

parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=pathlib.Path)
args = parser.parse_args()

file_path = args.file_path

tilemap_value_freqs = {}
tile_pattern_freqs = {}

reg = re.compile(r"\$([0-9a-z]{4})", re.I)
with open(file_path) as f:
    while l := f.readline():
        for match in reg.finditer(l):
            tilemap_value = int(match[1], 16) 
            add_to_frequency_dict(tilemap_value_freqs, tilemap_value)
            tile_pattern = tilemap_value & 511
            add_to_frequency_dict(tile_pattern_freqs, tile_pattern)

print(f"Unique tilemap values used: {len(tilemap_value_freqs)}")

print(f"Unique patterns used: {len(tile_pattern_freqs)}")

print("Infrequently used patterns:")
for k, c in tile_pattern_freqs.items():
    if c < 3:
        print(f"{hex(k)}: {c}")
