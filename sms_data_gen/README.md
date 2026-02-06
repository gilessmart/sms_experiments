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

* **Background file** - background image constructed from 8x8 pixel tiles.

  Should be 32 tiles (256 pixels) wide and 24 - 28 tiles (192 - 224 pixels) high.  
  See [limitations](#limitations) below.

* **Background tiles file** - image of individual 8x8 pixel tiles usable in a background.  

  A 16 tile (128 pixel) wide grid is recommended.  
  See [limitations](#limitations) below.  
  Unused space can be left as any of the 16 background colors.

* **Sprites file** - image of individual 8x8 pixel tiles usable in sprites.  

  A maximum of 192 tiles are allowed. A 16 tile (128 pixel) wide grid is recommended.  
  Unused space can be left transparent.  
  Transparent (but not translucent) pixels are allowed and a maximum of 15 other valid SMS colors may be used.

See [test images](./test_images) for example background, background tiles and sprites files.

The following files are generated to the output directory:

* **palette.asm** - background tile and sprite color data.

* **tile_patterns.asm** - background tile pattern data.  
  (Generated if a **background tiles file** or a **background file** was supplied.)
  
  All tiles from the **background tiles file** are included first, with their order preserved.  
  They are followed by any **background file** tiles that do not match (and are not reflections of) a previous tile in the set.  
  
* **tile_patterns.png** - the same patterns but as **tile_patterns.asm** but as an image file.  
  (Generated if a **background tiles file** or a **background file** was supplied.)  
  Shows which tile is at which index.

* **tilemap.asm** - tilemap / name table data.  
  (Generated if a **background file** was supplied.)

* **sprite_patterns.asm** - patterns extracted from the **sprites file**.  
  (Generated if a **sprites file** was supplied.)

## Limitations

* The **background file** and **background tiles file** share these limits:
  * They may use a maximum of 16 colors between them. The colors must be valid SMS colors. No transparency is allowed.
  * They may use a maximum of 256 tiles between them. The 256 consists of:
    * All tiles from the **background tiles file**
    * Tiles from the **background file** that don't match, and are not reflections of, other tiles in the set.

* The generated tilemap only uses background tile patterns and the tile palette.  
  (Use of sprite tiles and the sprite palette in the tilemap is possible on SMS but isn't supported by this tool.)

* The priority flag in the the tilemap is unsupported.

## Test

```
python -m pytest tests/
```

## Possible future enhancements

* Ignore contiguous blocks of fully transparent tiles at the end of the background tiles and sprite files.

  This would prevent unecessary patterns being included in the data.  
  That's only an issue if the unused space is needed for tiles in the background file that need to be added to the pattern list, but maybe it's clearer to not require the user to fill unused space in the tiles file with a valid palette color anyway.

* Support priority tiles.  
  
  The user could specify:
  * a color on the command line that would be used as the first color in the background palette
  * a list of background tile coordinates to be considered priority tiles?
