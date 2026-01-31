from PIL import Image

from sms_data_gen.colors import RGB, to_rgb

def read_img_as_tiles(file_path: str) -> list[Image.Image]:
    with Image.open(file_path).convert("RGBA") as img:
        return _extract_tiles(img)

def _extract_tiles(img: Image.Image, size = 8) -> list[Image.Image]:
    width, height = img.size
    cols, rows = width // 8, height // 8
    return [_extract_tile(img, size, row, col) for row in range(rows) for col in range(cols)]

def _extract_tile(img: Image.Image, size: int, row: int, col: int) -> Image.Image:
    box = (col * size, row * size, (col+1) * size, (row+1) * size)
    return img.crop(box)

def get_rgb_colors(tile: Image.Image) -> list[RGB]:
    colors = tile.getcolors()
    if colors is None: return []
    return [rgb for _, color in colors if (rgb := to_rgb(color)) is not None]
