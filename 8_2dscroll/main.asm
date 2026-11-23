.define SCROLL_INCREMENT 5  ; max = 8
.define INIT_BG_POSX 84     ; initial x offset
.define INIT_BG_POSY 92     ; initial y offset

.memorymap
    defaultslot 0
    slot 0 $0000 $4000              ; 16K ROM
    slot 1 $4000 $4000              ; 16K ROM
    slot 2 $c000 $2000 "RAMSlot"    ; 8K RAM
.endme

.rombankmap
    bankstotal 2
    banksize $4000
    banks 2
.endro

.bank 0
.slot 0

.sdsctag 0.1, "2D Scrolling Demo", "SMS programming experiment", "Giles Smart"

.include "utils.asm"
.include "vdp.asm"
.include "sprites.asm"
.include "background.asm"
.include "controller.asm"

.org $0000
.section "startup" force
    di                          ; disable interrupts
    im 1                        ; use interrupt mode 1 - is this already done by the SMS boot ROM?
    ld sp, $dff0                ; RAM is at $C000 - $DFFF, and is mirrored at $E000 - $FFFF,
                                ; and $FFFC - $FFFF is used for bank switching, 
                                ; so space is left at top of RAM to prevent bank switching corrupting the stack
    jp Init
.ends

.org $0038
.section "interrupt_handler" force
    in a, (VDP_CTRL_PORT)       ; read & clear VDP flags, clear interrupt request line
    call BG_UpdateBG
    ei                          ; re-enable interrupts (they're turned off automatically when an interrupt is accepted)
    reti
.ends

.org $0066
.section "pause_handler" force
    retn
.ends

.section "main"
    Init:
        ; initialise VDP registers
        VDP_SetRegister 0, %00100100    ; hide left-most 8 pixels, mode 4
        VDP_SetRegister 1, %10100000    ; 16K VRAM, frame interrupts
        VDP_SetRegister 2, $ff          ; name table base address $3800
        VDP_SetRegister 3, $ff          ; color table base address (mostly redundant in mode 4)
        VDP_SetRegister 4, $ff          ; pattern generator table base address (mostly redundant in mode 4)
        VDP_SetRegister 5, $ff          ; SAT base address ($ff gives base address of $3f00)
        VDP_SetRegister 6, $ff          ; sprite pattern table at $2000
        VDP_SetRegister 7, 0            ; BG color (from sprite palette)
        VDP_SetRegister 10, $ff         ; line interrupt line counter

        ; populate SAT
        ld bc, 0
        call SPRITES_TerminateSAT
        call SPRITES_FlushSAT

        ; populate CRAM (palette)
        ld hl, VDP_CMD_CRAM_WRITE << 8 | $0000
        call VDP_SetAddress
        ld hl, Palette
        ld de, PaletteEnd - Palette
        call VDP_CopyData

        ; populate tile patterns
        ld hl, VDP_CMD_VRAM_WRITE << 8 | $0000
        call VDP_SetAddress
        ld hl, TilePatterns
        ld de, TilePatternsEnd - TilePatterns
        call VDP_CopyData

        ; initialise scroll position
        BG_SetScrollOffsets INIT_BG_POSX, INIT_BG_POSY
        BG_UpdateScrollRegisters

        ; draw the background
        call BG_DrawFullBG

        ; turn on display
        VDP_SetRegister 1, %11100000    ; 16K VRAM, enable display, frame interrupts

        ; prepare to draw the leading edges, which will happen when the VBlank fires (on first 'halt')
        call BG_InitDrawRowColParams

        ; read & clear VDP flags, clear interrupt request line..
        ; (forces the first interrupt to fire on the regular scanline, instead of ASAP, 
        ; which could cause the next interrupt to fire after a shorter interval than usual)
        in a, (VDP_CTRL_PORT)
        ; ..then enable interrupts
        ei

    MainLoop:
        halt

        ; read controller state
        in a, CTLR_PORT_AB

        ; scroll up / down
        bit CTLR_PORT_AB_A_UP, a
        jr nz, +
            ex af, af'
                ld c, SCROLL_INCREMENT
                call ScrollUp
            ex af, af'
        jr ++
        +:
        bit CTLR_PORT_AB_A_DOWN, a
        jr nz, ++
            ex af, af'
                ld c, SCROLL_INCREMENT
                call ScrollDown
            ex af, af'
        ++:

        ; scroll left / right
        bit CTLR_PORT_AB_A_LEFT, a
        jr nz, +
            ex af, af'
                ld c, SCROLL_INCREMENT
                call ScrollLeft
            ex af, af'
        jr ++
        +:
        bit CTLR_PORT_AB_A_RIGHT, a
        jr nz, ++
            ex af, af'
                ld c, SCROLL_INCREMENT
                call ScrollRight
            ex af, af'
        ++:

        call BG_PrepUpdateBG

        jr MainLoop
.ends

.section "vdp_data"
    Palette:
    .include "data/palette.asm"
    PaletteEnd:
    TilePatterns:
    .include "data/tile_patterns.asm"
    TilePatternsEnd:
.ends

.bank 1
.slot 1

.section "tilemap"
    Tilemap:
    .include "data/tilemap.asm"
.ends
