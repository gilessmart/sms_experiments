# Horizontal Scrolling

Scrolls a background left & right by changing the underlying tilemap.

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
