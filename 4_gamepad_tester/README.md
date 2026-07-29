# Gamepad Tester

Shows which buttons are pressed on the gamepads.

## Dependencies

* [WLA Assembler](https://github.com/vhelin/wla-dx)

## Build

```sh
make
```

## Regenerate tile / palette data

Use [SMS Data Gen](../sms_data_gen/):

```sh
smsdatagen -b images/background.png -s images/sprites.png -o data
```
