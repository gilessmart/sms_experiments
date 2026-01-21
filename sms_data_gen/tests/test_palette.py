from sms_data_gen.palette import to_6_bit_color

def test_to_6_bit_color():
    """Test that to_6_bit_color converts RGB colors to the SMS values."""
    assert to_6_bit_color((0, 0, 0)) == 0
    assert to_6_bit_color((255, 255, 255)) == 63
    assert to_6_bit_color((0, 85, 170)) == 36
