.memorymap
    defaultslot 0
    slot 0 $0000 $8000  ; 32K ROM
    slot 1 $c000 $2000  ; 8K RAM
.endme

.rombankmap
    bankstotal 1
    banksize $8000
    banks 1
.endro

.bank 0
.slot 0

.org $0000
.section "startup" force
    di              ; disable interrupts
    im 1            ; use interrupt mode 1
    ld sp, $dff0    ; leave 16KB free in case the BIOS has left anything there
    jp main
.ends

.sdsctag 0.1, "Hello World!", "SMS programming experiment", "Giles Smart"

.org $0038
.section "interrupt_handler" force
    retn
.ends

.org $0038
.section "pause_handler" force
    retn
.ends

.section "main"
    main:
        ; initialise VDP registers
        ld hl, $8000 + %00000100    ; enable mode 4
        call VDP_SetAddress
        ld hl, $8100 + %10100000    ; 16K VRAM, frame interrupts
        call VDP_SetAddress
        ld hl, $82ff                ; name table base address $3800
        call VDP_SetAddress
        ld hl, $83ff                ; color table base address (mostly redundant in mode 4)
        call VDP_SetAddress
        ld hl, $84ff                ; pattern generator table base address (mostly redundant in mode 4)
        call VDP_SetAddress
        ld hl, $85ff                ; SAT base address ($ff gives base address of $3f00)
        call VDP_SetAddress
        ld hl, $86ff                ; sprite pattern table at $2000
        call VDP_SetAddress
        ld hl, $8700                ; BG color (from sprite palette)
        call VDP_SetAddress
        ld hl, $8800                ; BG X Scroll
        call VDP_SetAddress
        ld hl, $8900                ; BG Y Scroll
        call VDP_SetAddress
        ld hl, $8aff                ; line interrupt line counter
        call VDP_SetAddress

        ; setup CRAM (palette)
        ld hl, VDP_CMD_CRAM_WRITE | $0000
        call VDP_SetAddress
        ld hl, Palette
        ld bc, PaletteEnd - Palette
        call VDP_CopyData

        ; setup tile patterns
        ld hl, VDP_CMD_VRAM_WRITE | $0000
        call VDP_SetAddress
        ld hl, TilePatterns
        ld bc, TilePatternsEnd - TilePatterns
        call VDP_CopyData

        ; setup tilemap
        ld hl, VDP_CMD_VRAM_WRITE | $3800
        call VDP_SetAddress
        ld hl, Tilemap
        ld bc, TilemapEnd - Tilemap
        call VDP_CopyData

        ; setup empty SAT table
        ld hl, VDP_CMD_VRAM_WRITE | $3f00
        call VDP_SetAddress
        ld a, $d0 ; y = $d0 terminates the table
        out (VDP_DATA_PORT), a

        ; turn on display
        ld hl, $8100 + %11100000 ; 16K VRAM, enable display, frame interrupts
        call VDP_SetAddress

        ; loop
    -:jr -

    .include "vdp.asm"
    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
    .include "data/tilemap.asm"
.ends
