.memorymap
    defaultslot 0
    slot 0 $0000 $4000  ; 16K ROM
    slot 1 $c000 $2000  ; 8K RAM
.endme

.rombankmap
    bankstotal 1
    banksize $4000
    banks 1
.endro

.bank 0
.slot 0

.sdsctag 0.1, "Animated Sprites Demo", "SMS programming experiment", "Giles Smart"

.include "vdp.asm"
.include "sprites.asm"

.ramsection "main_state" slot 1
    FrameCounter: db
.ends

.org $0000
.section "startup" force
    di              ; disable interrupts
    im 1            ; use interrupt mode 1 - is this already done by the SMS boot ROM?
    ld sp, $dff0    ; RAM is at $C000 - $DFFF, and is mirrored at $E000 - $FFFF,
                    ; and $FFFC - $FFFF is used for bank switching, 
                    ; so space is left at top of RAM to prevent bank switching corrupting the stack
    jp Init
.ends

.org $0038
.section "interrupt_handler" force
    push af
        in a, (VDP_CTRL_PORT)   ; read & clear VDP flags, clear interrupt request line
        push bc
            push hl
                call SPRITES_FlushSAT
            pop hl
        pop bc
    pop af
    ei  ; re-enable interrupts  - they're turned off automatically when an interrupt is accepted
    reti
.ends

.org $0066
.section "pause_handler" force
    retn
.ends

.section "main"
    Init:
        ; initialise VDP registers
        ld hl, VDP_CMD_REGISTER_WRITE | (0 << 8) | %00000100 ; mode 4
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (1 << 8) | %10100000 ; 16K VRAM, frame interrupts
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (2 << 8) | $ff       ; name table base address $3800
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (3 << 8) | $ff       ; color table base address (mostly redundant in mode 4)
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (4 << 8) | $ff       ; pattern generator table base address (mostly redundant in mode 4)
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (5 << 8) | $ff       ; SAT base address ($ff gives base address of $3f00)
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (6 << 8) | $ff       ; sprite pattern table at $2000
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (7 << 8) | 0         ; BG color (from sprite palette)
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (8 << 8) | 0         ; BG X Scroll
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (9 << 8) | 0         ; BG Y Scroll
        call VDP_SetAddress
        ld hl, VDP_CMD_REGISTER_WRITE | (10 << 8) | $ff       ; line interrupt line counter
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

        ; initilise SAT index
        ld bc, 0

        ; bored sonic, frame 0
        ld ix, BoredSonic0
        ld a, 9
        ld de, (64 << 8) | 43
        call SPRITES_SetSprites
        ; tails
        ld ix, Tails
        ld a, 8
        ld de, (168 << 8) | 51
        call SPRITES_SetSprites
        ; sonic
        ld ix, Sonic
        ld a, 9
        ld de, (64 << 8) | 115
        call SPRITES_SetSprites
        ; bored tails, frame 0
        ld ix, BoredTails0
        ld a, 8
        ld de, (168 << 8) | 123
        call SPRITES_SetSprites

        call SPRITES_TerminateSAT
        call SPRITES_FlushSAT

        ; turn on display
        ld hl, VDP_CMD_REGISTER_WRITE | (1 << 8) | %11100000 ; 16K VRAM, enable display, frame interrupts
        call VDP_SetAddress

        ; initialise frame counter
        ld a, 20
        ld (FrameCounter), a

        ei  ; enable interrupts

    MainLoop:
        halt

        ld a, (FrameCounter)    ; fetch frame counter
        inc a                   ; increment
        ld (FrameCounter), a    ; store frame counter
        bit 5, a                ; check bit 5 (changes every 16 frames)

        jr z, +

        ; sonic
        ld ix, BoredSonic0
        ld bc, 0
        ld a, 9
        ld de, (64 << 8) | 43
        call SPRITES_SetSprites

        ; tails
        ld ix, BoredTails0
        ld bc, 26
        ld a, 8
        ld de, (168 << 8) | 123
        call SPRITES_SetSprites
    
        jr ++
        
    +:  ; sonic
        ld ix, BoredSonic1
        ld bc, 0
        ld a, 9
        ld de, (64 << 8) | 43
        call SPRITES_SetSprites

        ; tails
        ld ix, BoredTails1
        ld bc, 26
        ld a, 8
        ld de, (168 << 8) | 123
        call SPRITES_SetSprites    

    ++: jr MainLoop
.ends

.section "vdp_data"
    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
    .include "data/tilemap.asm"
    .include "data/sprite_patterns.asm"
.ends

.section "spritedefs"
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
    
    BoredSonic0:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $03
    .db 0, 8, $04
    .db 8, 0, $13
    .db 8, 8, $14
    .db 16, 0, $23
    .db 16, 8, $24
    .db 24, 0, $33
    .db 24, 8, $34
    .db 24, 16, $35

    BoredSonic1:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $03
    .db 0, 8, $02
    .db 8, 0, $13
    .db 8, 8, $12
    .db 16, 0, $23
    .db 16, 8, $24
    .db 24, 0, $33
    .db 24, 8, $22
    .db 24, 16, $36

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

    BoredTails0:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $05
    .db 0, 8, $06
    .db 8, 0, $15
    .db 8, 8, $16
    .db 8, 16, $17
    .db 16, 0, $25
    .db 16, 8, $26
    .db 16, 16, $27

    BoredTails1:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $05
    .db 0, 8, $06
    .db 8, 0, $07
    .db 8, 8, $16
    .db 8, 16, $17
    .db 16, 0, $25
    .db 16, 8, $26
    .db 16, 16, $27
.ends
