from dataclasses import dataclass
from itertools import batched
from typing import Optional, Sequence

from sms_data_gen.file_io import write_file

@dataclass
class TilemapEntry:
    tile_index: int
    h_flip: bool
    v_flip: bool

    def get_bytes(self) -> bytes:
        high_byte = self.tile_index // 256
        if self.h_flip: high_byte += 2
        if self.v_flip: high_byte += 4
        low_byte = self.tile_index % 256
        return bytes([high_byte, low_byte])

class Tilemap:
    cols: int
    rows: int
    entries: list[TilemapEntry]

    def __init__(self, cols: int, rows: int) -> None:
        self.cols = cols
        self.rows = rows
        self.entries = []

    def add_entry(self, entry: TilemapEntry) -> None:
        self.entries.append(entry)

    def is_empty(self) -> bool:
        return len(self.entries) == 0
    
    def get_bytes(self) -> bytes:
        result = []
        for entry in self.entries:
            result.extend(entry.get_bytes())
        return bytes(result)

# ASM output

def write_tilemap_asm(output_dir: Optional[str], tilemap: Tilemap) -> None:
    data = tilemap.get_bytes()
    content = _create_asm_content(data, tilemap.cols)
    write_file(output_dir, "tilemap.asm", content)

def _create_asm_content(data: bytes, cols: int):
    lines = ["Tilemap:"]

    # split the data into rows of the tilemap (each entry is 2 bytes)
    for row_num, row_bytes in enumerate(batched(data, cols * 2)):
        lines.append(f"; row {row_num}")
        # output as lines max 16 hex words
        hex_word_groups = batched(_to_hex_words(row_bytes), 16)
        for group in hex_word_groups:
            lines.append(f".dw " + ",".join(group))
    
    lines.append("TilemapEnd:")

    return "\n".join(lines) + "\n"

def _to_hex_words(data: Sequence[int]) -> list[str]:
    words = []
    for [high_byte, low_byte] in batched(data, 2):
        words.append(f"${high_byte:02x}{low_byte:02x}")
    return words
