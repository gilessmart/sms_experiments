from sms_data_gen.colors import RGBA
from sms_data_gen.palettes import Palette, _to_6_bit_color

def test_to_6_bit_color():
    """Test to_6_bit_color converts RGB colors to the values used by the SMS."""
    assert _to_6_bit_color((0, 0, 0, 255)) == 0
    assert _to_6_bit_color((255, 255, 255, 255)) == 63
    assert _to_6_bit_color((0, 85, 170, 255)) == 36
 
def test_get_bytes_generates_correct_length():
    """Check Palette.get_bytes() returns a list of bytes that matches its capacity"""
    palette = Palette(8)
    assert len(palette.get_bytes()) == 8

    palette = Palette(16)
    palette.add_colors([
        (0, 0, 0, 255),
        (255, 0, 0, 255),
        (0, 255, 0, 255),
        (0, 0, 255, 255),
        (255, 255, 255, 255)
    ])
    assert len(palette.get_bytes()) == 16
