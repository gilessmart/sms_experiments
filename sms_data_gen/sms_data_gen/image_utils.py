from PIL import Image

from sms_data_gen.colors import RGBA, as_rgba

def extract_tiles(img: Image.Image, size = 8) -> list[Image.Image]:
    width, height = img.size
    cols, rows = width // 8, height // 8
    return [_extract_tile(img, size, row, col) for row in range(rows) for col in range(cols)]

def _extract_tile(img: Image.Image, size: int, row: int, col: int) -> Image.Image:
    box = (col * size, row * size, (col+1) * size, (row+1) * size)
    return img.crop(box)

def get_colors_as_rgba(tile: Image.Image) -> list[RGBA]:
    colors = tile.getcolors()
    if colors is None: return []
    return [as_rgba(color) for _, color in colors]

def images_are_equal(a: Image.Image, b: Image.Image) -> bool:
    return a.size == b.size and list(a.get_flattened_data()) == list(b.get_flattened_data())

def flip_h(img: Image.Image) -> Image.Image:
    return img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

def flip_v(img: Image.Image) -> Image.Image:
    return img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)

def flip_hv(img: Image.Image) -> Image.Image:
    return flip_v(flip_h(img))
