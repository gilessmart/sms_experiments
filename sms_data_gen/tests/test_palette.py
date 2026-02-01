from sms_data_gen.palettes import _to_6_bit_color

def test_to_6_bit_color():
    """Test to_6_bit_color converts RGB colors to the values used by the SMS."""
    assert _to_6_bit_color((0, 0, 0)) == 0
    assert _to_6_bit_color((255, 255, 255)) == 63
    assert _to_6_bit_color((0, 85, 170)) == 36
