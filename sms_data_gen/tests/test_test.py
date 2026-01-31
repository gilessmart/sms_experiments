from PIL import Image

from sms_data_gen.image_utils import _extract_tiles


def test_tile_comparison():
    file_path = "test_images/background.png"
    
    img = Image.open(file_path).convert("RGBA")
    tiles = _extract_tiles(img)

    assert len(tiles) == 768
    assert tiles[0] != tiles[31]
    assert tiles[0] == tiles[31].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
