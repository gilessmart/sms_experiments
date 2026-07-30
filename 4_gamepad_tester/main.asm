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

.sdsctag 0.1, "Gamepad Tester", "SMS programming experiment", "Giles Smart"

.include "vdp.asm"
.include "sprites.asm"

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
        ld hl, VDP_CMD_REGISTER_WRITE | (10 << 8) | $ff      ; line interrupt line counter
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

        ; initilise SAT
        ld bc, 0
        call SPRITES_TerminateSAT
        call SPRITES_FlushSAT

        ; turn on display
        ld hl, VDP_CMD_REGISTER_WRITE | (1 << 8) | %11100000 ; 16K VRAM, enable display, frame interrupts
        call VDP_SetAddress

        ei  ; enable interrupts

    MainLoop:
        halt

        ld bc, 0

        in a, $dc

        ; controller 1, d-pad up
        bit 0, a
        jr nz, +
        ex af, af'
        ld a, $09
        ld de, (66 << 8) | 53
        call SPRITES_SetSprite
        ex af, af'
        +:

        ; controller 1, d-pad down
        bit 1, a
        jr nz, +
        ex af, af'
        ld a, $09
        ld de, (66 << 8) | 82
        call SPRITES_SetSprite
        ex af, af'
        +;

        ; controller 1, d-pad left
        bit 2, a
        jr nz, +
        ex af, af'
        ld a, $0a
        ld de, (51 << 8) | 68
        call SPRITES_SetSprite
        ex af, af'
        +;
        
        ; controller 1, d-pad right
        bit 3, a
        jr nz, +
        ex af, af'
        ld a, $0a
        ld de, (80 << 8) | 68
        call SPRITES_SetSprite
        ex af, af'
        +;

        ; controller 1, button 1
        bit 4, a
        jr nz, +
        push af
        ld ix, Button
        ld a, 9
        ld de, (160 << 8) | 65
        call SPRITES_SetSprites
        pop af
        +;

        ; controller 1, button 2
        bit 5, a
        jr nz, +
        push af
        ld ix, Button
        ld a, 9
        ld de, (189 << 8) | 65
        call SPRITES_SetSprites
        pop af
        +;

        ; controller 2, d-pad up
        bit 6, a
        jr nz, +
        ex af, af'
        ld a, $09
        ld de, (66 << 8) | 125
        call SPRITES_SetSprite
        ex af, af'
        +;
        
        ; controller 2, d-pad down
        bit 7, a
        jr nz, +
        ex af, af'
        ld a, $09
        ld de, (66 << 8) | 154
        call SPRITES_SetSprite
        ex af, af'
        +;

        in a, $dd

        ; controller 2, d-pad left
        bit 0, a
        jr nz, +
        ex af, af'
        ld a, $0a
        ld de, (51 << 8) | 140
        call SPRITES_SetSprite
        ex af, af'
        +;
        
        ; controller 2, d-pad right
        bit 1, a
        jr nz, +
        ex af, af'
        ld a, $0a
        ld de, (80 << 8) | 140
        call SPRITES_SetSprite
        ex af, af'
        +;

        ; controller 2, button 1
        bit 2, a
        jr nz, +
        push af
        ld ix, Button
        ld a, 9
        ld de, (160 << 8) | 137
        call SPRITES_SetSprites
        pop af
        +;
        
        ; controller 2, button 2
        bit 3, a
        jr nz, +
        push af
        ld ix, Button
        ld a, 9
        ld de, (189 << 8) | 137
        call SPRITES_SetSprites
        pop af
        +;

        call SPRITES_TerminateSAT

        jp MainLoop
.ends

.section "vdp_data"
    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
    .include "data/tilemap.asm"
    .include "data/sprite_patterns.asm"
.ends

.section "sprite_groups"
    Button:
    ; .db y, x, sprite_pattern_idx
    .db 0, 0, $00
    .db 0, 8, $01
    .db 0, 16, $02
    .db 8, 0, $03
    .db 8, 8, $04
    .db 8, 16, $05
    .db 16, 0, $06
    .db 16, 8, $07
    .db 16, 16, $08
.ends
