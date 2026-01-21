from sms_data_gen.utils import write_file

def write_palette_data(output_dir, tile_palette, sprite_palette):
    tile_palette_numbers = [to_6_bit_color(color) for color in tile_palette]
    sprite_palette_numbers = [to_6_bit_color(color) for color in sprite_palette]

    tile_palette_numbers += [0] * (16 - len(tile_palette))
    sprite_palette_numbers += [0] * (16 - len(sprite_palette))

    content = to_asm(tile_palette_numbers, sprite_palette_numbers)
    write_file(output_dir, "palette.asm", content)    

def to_6_bit_color(color):
    r, g, b = color[:3]
    val = 0

    if b == 85: val |= 1
    elif b == 170: val |= 2
    elif b == 255: val |= 3

    val = val << 2
    
    if g == 85: val |= 1
    elif g == 170: val |= 2
    elif g == 255: val |= 3

    val = val << 2
    
    if r == 85: val |= 1
    elif r == 170: val |= 2
    elif r == 255: val |= 3
    
    return val
    
def to_asm(tile_palette_numbers, sprite_palette_numbers):
    lines = ["Palette:"]
    
    lines.append(f"; background palette")
    tile_palette_hexes = [f"${n:02x}" for n in tile_palette_numbers]
    lines.append(".db " + ",".join(tile_palette_hexes))    
    
    lines.append(f"; sprite palette")
    sprite_palette_hexes = [f"${n:02x}" for n in sprite_palette_numbers]
    lines.append(".db " + ",".join(sprite_palette_hexes))    
    
    lines.append("PaletteEnd:")
    return "\n".join(lines) + "\n"
