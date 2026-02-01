from sms_data_gen.patterns import _get_pattern_line_bytes

def test_line_indices_to_planar():
    """Test that line_indices_to_planar converts 8 indices to 4 bytes correctly."""
    indices = [10, 14, 13, 13, 14, 14, 14, 13]
    expected = [49, 206, 127, 255]
    result = _get_pattern_line_bytes(indices)
    assert result == expected
