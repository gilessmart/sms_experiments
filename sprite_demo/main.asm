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
        ld bc, 0    ; set SAT index = 0

        ; draw grey robot
        ld ix, Robot
        ld a, 6
        ld de, (163 << 8) | 16
        call SPRITE_SetSprites

        ; draw grey robot
        ld ix, Robot
        ld a, 6
        ld de, (76 << 8) | 31
        call SPRITE_SetSprites

        ; draw green alien
        ld ix, Alien
        ld a, 10
        ld de, (191 << 8) | 63
        call SPRITE_SetSprites

        ; draw alien shot
        ld ix, AlienShot
        ld a, 3
        ld de, (138 << 8) | 70
        call SPRITE_SetSprites

        ; draw player ship
        ld ix, PlayerShip
        ld a, 5
        ld de, (37 << 8) | 81
        call SPRITE_SetSprites

         ; draw player shots
        ld a, $17
        ld de, (84 << 8) | 86
        call SPRITE_SetSprite
        ld de, (124 << 8) | 86
        call SPRITE_SetSprite
        ld de, (164 << 8) | 86
        call SPRITE_SetSprite

        ; draw butterfly
        ld ix, Butterfly
        ld a, 4
        ld de, (156 << 8) | 105
        call SPRITE_SetSprites

        ; draw butterfly
        ld ix, Butterfly
        ld a, 4
        ld de, (218 << 8) | 132
        call SPRITE_SetSprites

        ; draw red balls
        ld a, $0f
        ld de, (36 << 8) | 110
        call SPRITE_SetSprite
        ld de, (84 << 8) | 137
        call SPRITE_SetSprite

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

    Robot:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $0a
    .db 0, 8, $0b
    .db 8, 0, $1a
    .db 8, 8, $1b
    .db 16, 0, $1c
    .db 16, 8, $1d
    
    Alien:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $00
    .db 0, 8, $01
    .db 0, 16, $02
    .db 8, 0, $10
    .db 8, 8, $11
    .db 8, 16, $12
    .db 16, 8, $03
    .db 16, 16, $04
    .db 24, 8, $13
    .db 24, 16, $14

    AlienShot:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $0c
    .db 0, 8, $0d
    .db 0, 16, $0e

    PlayerShip:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $05
    .db 0, 8, $06
    .db 0, 16, $07
    .db 8, 0, $15
    .db 8, 8, $16

    Butterfly:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $08
    .db 0, 8, $09
    .db 8, 0, $18
    .db 8, 8, $19

    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
    .include "data/tilemap.asm"
    .include "data/sprite_patterns.asm"
.ends
