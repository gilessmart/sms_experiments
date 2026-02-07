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

At least one of the **background file path**, **background tiles file path** and **sprites file path** must be supplied.

The **background file path**, **background tiles file path** and **sprites file path** must all be unique.

### Example

```
python main.py -b test_images/background.png -t test_images/background-tiles.png -s test_images/sprites.png -o output
```

## Operation

The tool takes as input (at least one of) the following image files:

* **Background file** - background image constructed from 8x8 pixel tiles.

  Should be 32 tiles (256 pixels) wide and 24 - 28 tiles (192 - 224 pixels) high.  
  See combined rules below.

* **Background tiles file** - image of individual 8x8 pixel tiles usable in a background.  

  A 16 tile (128 pixel) wide grid is recommended.  
  Unused space at the end of the image can be left transparent. Otherwise, no transparency is allowed.  
  See combined rules below.

* **Sprites file** - image of individual 8x8 pixel tiles usable in sprites.  

  A maximum of 192 tiles are allowed. A 16 tile (128 pixel) wide grid is recommended.  
  Unused space can be left transparent.  
  Transparent (but not translucent) pixels are allowed and a maximum of 15 other valid SMS colors may be used.

Combined rules for the **background file** / **background tiles file**:

* A maximum of 16 colors may be used across the two images.  
  All must be valid SMS colors. No transparency is allowed, except for any unused space at the end of the **background tiles file**.

* A maximum of 256 distinct tiles may be used across the two images, consisting of all tiles from the **background tiles file** plus any tiles from the **background file** that don't match, and are not reflections of, other tiles already in the set.

See [test images](./test_images) for examples.

The following files are written to the output directory:

* **palette.asm** - background tile and sprite color data.

* **tile_patterns.asm** - background tile pattern data.  
  (Written if a **background tiles file** or a **background file** was supplied.)
  
  All tiles from the **background tiles file** are included first, with their order preserved, followed by any **background file** tiles that do not match (and are not reflections of) a previous tile in the set.  
  
* **tile_patterns.png** - the same patterns but as **tile_patterns.asm** but as an image file.  
  (Written if a **background tiles file** or a **background file** was supplied.)  
  Shows which tile is at which index.

* **tilemap.asm** - tilemap / name table data.  
  (Written if a **background file** was supplied.)

* **sprite_patterns.asm** - patterns extracted from the **sprites file**.  
  (Written if a **sprites file** was supplied.)

## Limitations

* The generated tilemap only uses background tile patterns and the background tile palette.  
  (Use of sprite tiles and the sprite palette in the tilemap is possible on SMS but isn't supported by this tool.)

* The priority flag in the the tilemap is unsupported.

## Test

```
python -m pytest tests/
```

## Possible future enhancements

* **Support for priority tiles**  
  The user would need to specify:
  * a color that would be used as the first color in the background palette
  * a list tile coordinates in the background file to be considered priority tiles
