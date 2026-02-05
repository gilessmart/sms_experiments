from PIL import Image

from sms_data_gen.image_utils import extract_tiles, flip_h, flip_hv, flip_v, images_are_equal

def test_images_are_equal():
    with Image.open("test_images/test_tiles.png").convert("RGBA") as img:
        tiles = extract_tiles(img)
        assert images_are_equal(tiles[0], tiles[1])
        assert not images_are_equal(tiles[0], tiles[2])
        assert not images_are_equal(tiles[0], tiles[3])
        assert not images_are_equal(tiles[2], tiles[3])

def test_flip():
    with Image.open("test_images/test_tiles.png").convert("RGBA") as img:
        tiles = extract_tiles(img)
        assert images_are_equal(tiles[0], flip_h(tiles[2]))
        assert images_are_equal(tiles[0], flip_v(tiles[3]))
        assert images_are_equal(tiles[0], flip_hv(tiles[4]))
        assert not images_are_equal(tiles[0], flip_h(tiles[1]))

