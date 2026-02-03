from dataclasses import dataclass
from itertools import batched
from typing import Sequence

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
    _capacity: int
    _entries: list[TilemapEntry]

    def __init__(self, capacity: int) -> None:
        self._capacity = capacity
        self._entries = []

    def add_entry(self, entry: TilemapEntry) -> None:
        if len(self._entries) >= self._capacity:
            raise Exception("Tried to add tilemap entry to an already full tilemap")
        self._entries.append(entry)

    def is_empty(self) -> bool:
        return len(self._entries) == 0
    
    def get_bytes(self) -> bytes:
        result = []
        for entry in self._entries:
            result.extend(entry.get_bytes())
        return bytes(result)

# ASM output

def write_tilemap_asm(output_dir: str, data: bytes) -> None:
    content = _create_asm_content(data)
    write_file(output_dir, "tilemap.asm", content)

def _create_asm_content(data: bytes):
    lines = ["Tilemap:"]

    # split the data into rows of the tilemap, which are 2 bytes * 32 tiles
    for row_num, row_bytes in enumerate(batched(data, 64)):
        lines.append(f"; row {row_num}")
        # output as 2 lines of ASM
        lines.append(f".dw " + ",".join(_to_hex_words(row_bytes[:32])))
        lines.append(f".dw " + ",".join(_to_hex_words(row_bytes[32:])))
    
    lines.append("TilemapEnd:")

    return "\n".join(lines) + "\n"

def _to_hex_words(data: Sequence[int]) -> list[str]:
    words = []
    for [high_byte, low_byte] in batched(data, 2):
        words.append(f"${high_byte:02x}{low_byte:02x}")
    return words
