# Hello World

Displays Hello World! using background tiles.

## Dependencies

* [WLA Assembler](https://github.com/vhelin/wla-dx)
* [Python](https://www.python.org) (to regenerate tile / palette data)

## Build

```sh
make
```

## Regenerate tile / palette data

Use the [SMS Data Gen](../sms_data_gen/) tool to regenerate the tile & palette data from the background image:

```sh
smsdatagen -b images/background.png -o data
```
