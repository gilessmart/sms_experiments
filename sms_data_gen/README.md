# SMS Data Gen

Produces image data for SMS games written in WLA assembler.

## Setup

```
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run

```
python main.py --tiles test_images/tiles.png \
               --tilemap test_images/background.png \
               --sprites test_images/sprites.png \
               --out output/
```

At least one of `tiles`, `tilemap` and `sprites` must be supplied.

## Test

```
python -m pytest tests/
```

## Operation

* Reads the the `tiles` (optional), `tilemap` & `sprites` PNG files
* Writes palette data to `palette.asm`
  * Tile palette (first 16 bytes) includes all colors in the tiles & tilemap files 
  * Sprite palette (last 16 bytes) includes all colors in the sprites file
* Writes tile pattern data to `tiles.asm`
  * Tile patterns found in the `tiles` file are included first
  * Patterns from the `tilemap` file follow immediately after
    (any patterns that are the same as, or are mirror images of, previously encountered tiles are omitted)
  * If the `tiles` PNG file doesn't contain all the tiles in the order  they are positioned in `tiles.asm`, produces a new one PNG that does
* Writes sprite pattern data to `sprites.asm`
  * Any sprite tiles that are the same as previously encountered sprite tiles are omitted
* Writes a tilemap to `tilemap.asm`

