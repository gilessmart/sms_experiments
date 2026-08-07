# Simple Vertical Scrolling

Scrolls a background up & down 32px without changing the underlying tilemap.

## Dependencies

* [WLA Assembler](https://github.com/vhelin/wla-dx)

## Build

```sh
make
```

## Regenerate tile / palette data

Use [SMS Data Gen](../tools/sms_data_gen/):

```sh
smsdatagen -b images/background.png -o data
```
