from sms_data_gen.colors import is_sms_color
from sms_data_gen.file_io import write_file
from sms_data_gen.image_utils import RGB

class Palette:
    _capacity: int
    _colors: list[RGB]

    def __init__(self, capacity: int) -> None:
        self._capacity = capacity
        self._colors = []

    def add_new_colors(self, colors: list[RGB]) -> None:
        for color in colors:
            self._add_color_if_new(color)

    def _add_color_if_new(self, color: RGB) -> None:
        if color in self._colors:
            return
        if len(self._colors) >= self._capacity:
            raise Exception("Tried to add color to already full palette")
        if not is_sms_color(color):
            raise Exception("Tried to add invalid color to palette", color)
        
        self._colors.append(color)

    def get_bytes(self) -> bytes:
        def to_2_bit_color(ch_val: int) -> int:
            return {85: 1, 170: 2, 255: 3}.get(ch_val, 0)

        def to_6_bit_color(color: RGB):
            r, g, b = color
            return to_2_bit_color(b) << 4 | to_2_bit_color(g) << 2 | to_2_bit_color(r)

        byte_values = [to_6_bit_color(color) for color in self._colors]
        byte_values += [0] * (16 - len(self._colors))
        return bytes(byte_values)

    def is_empty(self) -> bool:
        return len(self._colors) == 0
    
    def palette_index(self, color: RGB) -> int:
        return self._colors.index(color)

# ASM output

def write_palettes(output_dir, tile_palette: Palette, sprite_palette: Palette) -> None:
    tile_palette_bytes = tile_palette.get_bytes()
    sprite_palette_bytes = sprite_palette.get_bytes()
    content = _create_asm_content(tile_palette_bytes, sprite_palette_bytes)
    write_file(output_dir, "palette.asm", content)

def _create_asm_content(tile_palette_bytes: bytes, sprite_palette_bytes: bytes) -> str:
    lines = ["Palette:"]
    
    lines.append(f"; background palette")
    tile_palette_hexes = [f"${n:02x}" for n in tile_palette_bytes]
    lines.append(".db " + ",".join(tile_palette_hexes))    
    
    lines.append(f"; sprite palette")
    sprite_palette_hexes = [f"${n:02x}" for n in sprite_palette_bytes]
    lines.append(".db " + ",".join(sprite_palette_hexes))    
    
    lines.append("PaletteEnd:")
    return "\n".join(lines) + "\n"
