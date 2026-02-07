from itertools import batched
from math import ceil
from os import path, makedirs
from typing import Callable, Optional, Sequence
from PIL import Image

from sms_data_gen.colors import RGBA, as_rgba
from sms_data_gen.file_io import write_file
from sms_data_gen.image_utils import images_are_equal

class PatternList:
    _capacity: int
    _patterns: list[Image.Image]

    def __init__(self, capacity: int) -> None:
        self._capacity = capacity
        self._patterns = []

    def add_patterns(self, patterns: list[Image.Image]) -> None:
        for pattern in patterns:
            self.add_pattern(pattern)

    def add_pattern(self, pattern: Image.Image) -> int:
        if len(self._patterns) >= self._capacity:
            raise Exception("Tried to add a pattern to an already full pattern list")
        
        self._patterns.append(pattern)
        return len(self._patterns) - 1
    
    def index(self, pattern: Image.Image) -> Optional[int]:
        return next((i for i, candidate in enumerate(self._patterns) if images_are_equal(candidate, pattern)), None)

    def get_bytes(self, get_palette_index: Callable[[RGBA], int]) -> bytes:
        byte_values = []
        for pattern in self._patterns:
            pattern_bytes = _get_pattern_bytes(pattern, get_palette_index)
            byte_values.extend(pattern_bytes)
        return bytes(byte_values)

    def is_empty(self) -> bool:
        return len(self._patterns) == 0
    
    def get_patterns(self) -> list[Image.Image]:
        return self._patterns

# Planar conversion

def _get_pattern_bytes(pattern: Image.Image, get_palette_index: Callable[[RGBA], int]) -> bytes:
    """Generates the planar bytes for an 8 pixel wide image"""
    tile_bytes = []
    pixel_colors = [as_rgba(color) for color in pattern.get_flattened_data()]
    for line_colors in batched(pixel_colors, 8):
        palette_indices = [get_palette_index(c) for c in line_colors]
        line_bytes = _get_pattern_line_bytes(palette_indices)
        tile_bytes.extend(line_bytes)
    return bytes(tile_bytes)

def _get_pattern_line_bytes(palette_indices: list[int]) -> list[int]:
    """Generates the planar bytes for a single line of a tile
    Converts 8 4-bit integers to 4 8-bit integers using planar bit layout."""
    output = []
    for bit_plane in range(4):
        byte = 0
        for i, palette_index in enumerate(palette_indices):
            # get the bit from this palette index for this bit plane
            bit = (palette_index >> bit_plane) & 1
            # position the bit in the output byte
            byte |= (bit << (7 - i))
        output.append(byte)
    return output

# ASM output

def write_patterns_asm(output_dir: Optional[str], filename: str, label: str, data: bytes):
    content = _create_asm_content(label, data)
    write_file(output_dir, filename, content)

def _create_asm_content(label: str, data: bytes):
    """Format pattern data as assembly code."""
    lines = [f"{label}:"]

    # split into 32 byte patterns
    for pattern_num, pattern_data in enumerate(batched(data, 32)):
        lines.append(f"; pattern {pattern_num:#04x}")
        # write the hex values of each tile across 2 lines of the ASM
        # by splitting each (32 byte) tile into 2
        lines.append(".db " + ",".join(_to_hex_bytes(pattern_data[:16])))
        lines.append(".db " + ",".join(_to_hex_bytes(pattern_data[16:])))
    
    lines.append(f"{label}End:")
    return "\n".join(lines) + "\n"

def _to_hex_bytes(byte_values: Sequence[int]) -> list[str]:
    return [f"${byte_val:02x}" for byte_val in byte_values]

# Image output

def write_bg_tiles_img(output_dir: Optional[str], patterns: list[Image.Image]):
    tiles_per_row = 16
    tile_size = 8
    cols = min(len(patterns), tiles_per_row)
    rows = ceil(len(patterns) / tiles_per_row)

    out_width = cols * tile_size
    out_height = rows * tile_size

    out_img = Image.new("RGBA", (out_width, out_height), (0, 0, 0, 0))
    for idx, tile in enumerate(patterns):
        x = (idx % tiles_per_row) * tile_size
        y = (idx // tiles_per_row) * tile_size
        out_img.paste(tile, (x, y))

    if output_dir is None:
        output_dir = "."
    else:
        makedirs(output_dir, exist_ok=True)

    out_path = path.join(output_dir, "tile_patterns.png")
    out_img.save(out_path)

    print(f"Wrote {out_path}")
