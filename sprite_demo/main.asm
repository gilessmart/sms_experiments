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

.ramsection "shadow_sat" slot 1
    ShadowSAT: dsb 256
.ends

.bank 0
.slot 0

.org $0000
.section "startup" force
    di              ; disable interrupts
    im 1            ; use interrupt mode 1
    ld sp, $dff0    ; leave 16KB free in case the BIOS has left anything there
    jp main
.ends

.sdsctag 0.1, "Sprite Demo", "SMS programming experiment", "Giles Smart"

.org $0038
.section "interrupt_handler" force
    retn
.ends

.org $0038
.section "pause_handler" force
    retn
.ends

.section "main"
    .include "vdp.asm"
    .include "sprites.asm"

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

        ; setup sprite patterns
        ld hl, VDP_CMD_VRAM_WRITE | $2000
        call VDP_SetAddress
        ld hl, SpritePatterns
        ld bc, SpritePatternsEnd - SpritePatterns
        call VDP_CopyData

        ; draw sonic        
        SPRITE_SETSPRITE 0, $00, 64+0, 115+0
        SPRITE_SETSPRITE 1, $01, 64+8, 115+0
        SPRITE_SETSPRITE 2, $10, 64+0, 115+8
        SPRITE_SETSPRITE 3, $11, 64+8, 115+8
        SPRITE_SETSPRITE 4, $20, 64+0, 115+16
        SPRITE_SETSPRITE 5, $21, 64+8, 115+16
        SPRITE_SETSPRITE 6, $30, 64+0, 115+24
        SPRITE_SETSPRITE 7, $31, 64+8, 115+24
        SPRITE_SETSPRITE 8, $32, 64+16, 115+24

        ; terminate shadow SAT
        ld hl, ShadowSAT + 9
        ld (hl), $d0 ; D0 terminates the table

        ; write SAT
        ld hl, VDP_CMD_VRAM_WRITE | $3f00
        call VDP_SetAddress
        ld hl, ShadowSAT
        ld bc, 256
        call VDP_CopyData

        ; turn on display
        ld hl, $8100 + %11100000 ; 16K VRAM, enable display, frame interrupts
        call VDP_SetAddress

        ; loop
    -:  jr -

    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
    .include "data/tilemap.asm"
    .include "data/sprite_patterns.asm"
.ends
