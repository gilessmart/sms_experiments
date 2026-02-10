# Sprite Demo

Displays sprites.

## Dependencies

* [WLA Assembler](https://github.com/vhelin/wla-dx)
* [Python 3](https://www.python.org) (to regenerate tile / palette data)

## Build

```sh
make
```

## Regenerate tile / palette data

Using the [SMS Data Gen](../sms_data_gen/) tool to regenerate the tile & palette data from a PNG image

### Setup

First time setup:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -e ../sms_data_gen
```

On subsequent setups, only `source .venv/bin/activate` is necessary.

### Run

```sh
smsdatagen -b images/background.png -s images/sprites.png -o data
```
