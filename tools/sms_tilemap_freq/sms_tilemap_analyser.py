# Determines how many times each pattern is used in a tilemap
# Dependencies: -

import argparse
import pathlib
import re

parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=pathlib.Path)
args = parser.parse_args()

file_path = args.file_path

reg = re.compile(r"\$([0-9a-z]{4})", re.I)
tile_pattern_freqs = {}
with open(file_path) as f:
    while l := f.readline():
        for match in reg.finditer(l):
            tile_pattern = int(match[1], 16) & 511
            if tile_pattern in tile_pattern_freqs:
                tile_pattern_freqs[tile_pattern] += 1
            else:
                tile_pattern_freqs[tile_pattern] = 1

print(f"key count: {len(tile_pattern_freqs)}")
for k, c in tile_pattern_freqs.items():
    if c < 3:
        print(f"{hex(k)}: {c}")
