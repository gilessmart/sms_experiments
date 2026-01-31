from itertools import batched
from typing import Optional, Sequence
from PIL import Image

from sms_data_gen.colors import to_rgb
from sms_data_gen.file_io import write_file
from sms_data_gen.palettes import Palette

class PatternList:
    _capacity: int
    _patterns: list[Image.Image]

    def __init__(self, capacity: int) -> None:
        self._capacity = capacity
        self._patterns = []

    def add_pattern(self, pattern: Image.Image) -> int:
        if len(self._patterns) >= self._capacity:
            raise Exception("Tried to add a pattern to an already full pattern list")
        
        self._patterns.append(pattern)
        return len(self._patterns) - 1

    def find_equivalent_pattern(self, candidate: Image.Image) -> Optional[tuple[int, bool, bool]]:
        for pat_idx, pattern in enumerate(self._patterns):
            if pattern == candidate:
                return pat_idx, False, False
            elif pattern == candidate.transpose(Image.Transpose.FLIP_LEFT_RIGHT):
                return pat_idx, True, False
            elif pattern == candidate.transpose(Image.Transpose.FLIP_TOP_BOTTOM):
                return pat_idx, False, True
            elif pattern == candidate.transpose(Image.Transpose.FLIP_LEFT_RIGHT).transpose(Image.Transpose.FLIP_TOP_BOTTOM):
                return pat_idx, True, True
        
        return None

    def get_bytes(self, palette: Palette) -> bytes:
        byte_values = []
        for pattern in self._patterns:
            pattern_bytes = _get_pattern_bytes(pattern, palette)
            byte_values.extend(pattern_bytes)
        return bytes(byte_values)
    
# Planar conversion

def _get_pattern_bytes(pattern: Image.Image, palette: Palette) -> bytes:
    """Generates the planar bytes for an 8 pixel wide image"""
    tile_bytes = []
    pixel_colors = [rgb for color in pattern.getdata() if (rgb := to_rgb(color)) is not None]
    for line_colors in batched(pixel_colors, 8):
        palette_indices = [palette.palette_index(c) for c in line_colors]
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

def write_bg_tile_patterns(output_dir: str, patterns: PatternList, palette: Palette):
    pattern_bytes = patterns.get_bytes(palette)
    content = _create_asm_content(pattern_bytes)
    write_file(output_dir, "tile_patterns.asm", content)

def _create_asm_content(data: bytes):
    """Format pattern data as assembly code."""
    lines = ["TilePatterns:"]

    # split into 32 byte patterns
    for pattern_num, pattern_data in enumerate(batched(data, 32)):
        lines.append(f"; pattern {pattern_num:#04x}")
        # write the hex values of each tile across 2 lines of the ASM
        # by splitting each (32 byte) tile into 2
        lines.append(".db " + ",".join(_to_hex_bytes(pattern_data[:16])))
        lines.append(".db " + ",".join(_to_hex_bytes(pattern_data[16:])))
    
    lines.append("TilePatternsEnd:")
    return "\n".join(lines) + "\n"

def _to_hex_bytes(byte_values: Sequence[int]) -> list[str]:
    return [f"${byte_val:02x}" for byte_val in byte_values]
