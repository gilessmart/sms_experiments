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
.include "controller.asm"

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
        ld bc, $700
        call VDP_CopyData

        ; initilise SAT
        ld bc, 0
        call SPRITES_TerminateSAT
        call SPRITES_FlushSAT

        ; turn on display
        ld hl, VDP_CMD_REGISTER_WRITE | (1 << 8) | %11100000 ; 16K VRAM, enable display, frame interrupts
        call VDP_SetAddress

        ei

    MainLoop:
        halt

        in a, CTLR_PORT_AB

        ; controller 1, d-pad up
        bit CTLR_PORT_AB_A_UP, a
        jr nz, +
            ; move up
        +:

        ; controller 1, d-pad down
        bit CTLR_PORT_AB_A_DOWN, a
        jr nz, +
            ; move down
        +:

        ; controller 1, d-pad left
        bit CTLR_PORT_AB_A_LEFT, a
        jr nz, +
            ; move left
        +:
        
        ; controller 1, d-pad right
        bit CTLR_PORT_AB_A_RIGHT, a
        jr nz, +
            ; move right
        +:

        jp MainLoop
.ends

.section "vdp_data"
    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
    .include "data/tilemap.asm"
.ends
