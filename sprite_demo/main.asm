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

        ; draw sprites
        ld bc, 0        ; set SAT index = 0

        ; draw sonic at (64, 115)
        ld hl, Sonic
        ld a, 9
        ld de, (64 << 8) | 115
        call SPRITE_SetSprites

        ; draw tails at (168, 51)
        ld hl, Tails
        ld a, 8
        ld de, (168 << 8) | 51
        call SPRITE_SetSprites

        ; terminate shadow SAT
        ld hl, ShadowSAT
        add hl, bc      ; hl = adr of next y position
        ld (hl), $d0    ; D0 terminates the table

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

    Sonic:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $00
    .db 0, 8, $01
    .db 8, 0, $10
    .db 8, 8, $11
    .db 16, 0, $20
    .db 16, 8, $21
    .db 24, 0, $30
    .db 24, 8, $31
    .db 24, 16, $32

    Tails:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $08
    .db 0, 8, $09
    .db 8, 0, $18
    .db 8, 8, $19
    .db 8, 16, $1a
    .db 16, 0, $28
    .db 16, 8, $29
    .db 16, 16, $2a

    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
    .include "data/tilemap.asm"
    .include "data/sprite_patterns.asm"
.ends
