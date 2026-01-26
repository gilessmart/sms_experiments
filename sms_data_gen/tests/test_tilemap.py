from sms_data_gen.tilemap import TilemapEntry, get_tilemap_entry_data

def test_get_tilemap_entry_data():
    """Test tilemap entries are correctly mapped to hex values"""
    assert get_tilemap_entry_data(TilemapEntry(0, False, False)) == "$0000"
    assert get_tilemap_entry_data(TilemapEntry(25, True, False)) == "$0219"
    assert get_tilemap_entry_data(TilemapEntry(50, False, True)) == "$0432"
    assert get_tilemap_entry_data(TilemapEntry(75, True, True)) == "$064b"
    