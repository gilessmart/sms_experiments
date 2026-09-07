# 2D Scrolling

Scrolls a background up, down, left & right.

## Dependencies

* [WLA Assembler](https://github.com/vhelin/wla-dx)

## Build

```sh
make
```

## Regenerate tile / palette data

Use [SMS Data Gen](../tools/sms_data_gen/):

```sh
smsdatagen -p "#00aaff" -b images/background.png -o data
```
