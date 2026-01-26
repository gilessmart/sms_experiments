# SMS Data Gen Tool

SMS game image data generator.

Produces color palettes, tile patterns, sprite patterns, and a tilemap in a format that can be used in an SMS game written in WLA Z80 assembler.

## Operation

The tool takes as input (at least one of) the following image files:
* Background file  
  Image file showing the background of the game
* Background tiles file  
  Image file containing 8x8 background tiles usable in the background
* Sprites file  
  Image file containing 8x8 sprites

See [test images](./test_images) for examples.

The following data files are generated:
* palette.asm
* tile_patterns.asm
* tilemap.asm

The generated tile patterns data file includes all the tiles from the background tiles file, in the order they are found.
These are followed by all the unique tiles found in the background file.

The tool generates tile and sprite patterns as distinct sets with no overlap.
The tilemap exlusively uses the tile patterns, and the first 16 colors of the palette.

A maximum of 256 background tiles and 192 sprites can be produced.

There is no support for priority tiles.

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

## Test

```
python -m pytest tests/
```
