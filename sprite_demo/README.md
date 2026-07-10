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

Use the [SMS Data Gen](../sms_data_gen/) tool to regenerate the tile & palette data from the background and sprite images:

```sh
smsdatagen -b images/background.png -s images/sprites.png -o data
```
