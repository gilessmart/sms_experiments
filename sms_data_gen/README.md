# SMS Data Gen Tool

SMS game image data generator.

Produces color palettes, tile patterns, sprite patterns, and a tilemap in a format that can be used in an SMS game written in WLA Z80 assembler.

## Requirements

Python >= 3.14

(Earlier versions may work but have not been not tested)

## Setup

```
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```
python main.py <arguments>

arguments:
  -b, --bg        background file path
  -t, --bg-tiles  background tiles file path
  -s, --sprites   sprites file path
  -o, --out       output directory path
```

At least one of the background file path, background tiles file path and sprites file path must be supplied.

The background file path, background tiles file path and sprites file path must all be unique.

### Example

```
python main.py -b test_images/background.png -t test_images/background-tiles.png -s test_images/sprites.png -o output
```

## Operation

The tool takes as input (at least one of) the following image files:
* Background file  
  Image file showing the background of the game
* Background tiles file  
  Image file containing 8x8 background tiles usable in the background
* Sprites file  
  Image file containing 8x8 sprites

See [test images](./test_images) for examples.

The following files are generated:

### `palette.asm`

Tile and sprite palettes.  
Tile palette can contain up to 16 colors.  
Sprite palette reserves one entry for tranparent pixels leaving room for 15 other colors.

### `tile_patterns.asm`

Patterns extracted from the *background tiles file*, followed by tiles from the *background file*.  
All tiles from the background tiles file are included.  
Tiles from the background file that match a previous tile, or are horiontal or vertical reflections of a previous tile are not included.  
A maximum of 256 tile patterns can be generated.

### `tile_patterns.png`

Same patterns as `tile_patterns.asm`, in a PNG file.  
Gives a visual reference for which pattern is at each index.

### `tilemap.asm`

Tilemap / name table.  
Uses the tile patterns, and the sprite palette. (Use of sprite tiles and the sprite palette in the tilemap is possible on SMS but unsupported by this tool.)  
Priority tiles are unsupported.

### `sprite_patterns.asm`

Patterns extracted from the *sprites file*.  
A maximum of 192 sprites can be generated.  

## Test

```
python -m pytest tests/
```
