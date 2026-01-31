from sms_data_gen.tilemap import TilemapEntry

def test_get_tilemap_entry_get_bytes():
    """Test tilemap entries return their bytes"""
    assert TilemapEntry(0, False, False).get_bytes() == bytes([0, 0])
    assert TilemapEntry(25, True, False).get_bytes() == bytes([2, 25])
    assert TilemapEntry(50, False, True).get_bytes() == bytes([4, 50])
    assert TilemapEntry(75, True, True).get_bytes() == bytes([6, 75])
    assert TilemapEntry(448, True, True).get_bytes() == bytes([7, 192])
    