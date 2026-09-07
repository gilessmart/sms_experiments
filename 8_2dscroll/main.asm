.memorymap
    defaultslot 0
    slot 0 $0000 $4000  ; 16K ROM
    slot 1 $4000 $4000  ; 16K ROM
    slot 2 $c000 $2000  ; 8K RAM
.endme

.rombankmap
    bankstotal 2
    banksize $4000
    banks 2
.endro

.ramsection "main_state" slot 2
    BGScroll: dw
    VDPScroll: db
    RedrawBGCol: dw
    RedrawVDPCol: dw
    VDPColOffset: dw
    BGColOffset: dw
.ends

.bank 0
.slot 0

.sdsctag 0.1, "2D Scrolling Demo", "SMS programming experiment", "Giles Smart"

.include "vdp.asm"
.include "sprites.asm"
.include "controller.asm"
.include "shiftutils.asm"

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
    in a, (VDP_CTRL_PORT)  ; read & clear VDP flags, clear interrupt request line

    ; update VDP with new scroll value
    ld a, (VDPScroll)
    ld l, a             ; l = VDPScroll
    ld a, 0
    sub l               ; a = 256 - VDPScroll
    ld l, a             ; l = 256 - VDPScroll
    VDP_SetRegister 8

    call RedrawCol

    ei  ; re-enable interrupts  - they're turned off automatically when an interrupt is accepted

    reti
.ends

.org $0066
.section "pause_handler" force
    retn
.ends

.define SCROLL_INCREMENT 5              ; max = 8
.define COLS 194                        ; cols in background

.section "main"
    Init:
        ; initialise VDP registers
        VDP_SetRegister 0, %00100100 ; hide left-most 8 pixels, mode 4
        VDP_SetRegister 1, %10100000 ; 16K VRAM, frame interrupts
        VDP_SetRegister 2, $ff       ; name table base address $3800
        VDP_SetRegister 3, $ff       ; color table base address (mostly redundant in mode 4)
        VDP_SetRegister 4, $ff       ; pattern generator table base address (mostly redundant in mode 4)
        VDP_SetRegister 5, $ff       ; SAT base address ($ff gives base address of $3f00)
        VDP_SetRegister 6, $ff       ; sprite pattern table at $2000
        VDP_SetRegister 7, 0         ; BG color (from sprite palette)
        VDP_SetRegister 8, 0         ; BG X Scroll
        VDP_SetRegister 9, 0         ; BG Y Scroll
        VDP_SetRegister 10, $ff      ; line interrupt line counter

        ; setup CRAM (palette)
        ld hl, VDP_CMD_CRAM_WRITE << 8 | $0000
        call VDP_SetAddress
        ld hl, Palette
        ld de, PaletteEnd - Palette
        call VDP_CopyData

        ; setup tile patterns
        ld hl, VDP_CMD_VRAM_WRITE << 8 | $0000
        call VDP_SetAddress
        ld hl, TilePatterns
        ld de, TilePatternsEnd - TilePatterns
        call VDP_CopyData

        ; setup tilemap
        ld a, 46                        ; a = row index * 2
        -:
            ; set VRAM write command / address

            ld h, 0
            ld l, a                     ; hl = row index * 2

            ld bc, VRAMOffsetTable
            add hl, bc                  ; hl = VRAMOffsetTable + row index * 2

            ld e, (hl)
            inc hl
            ld d, (hl)                  ; de = VDP write bits + row offset
            ex de, hl                   ; hl = VDP write bits + row offset
            
            ld c, VDP_CTRL_PORT
            out (c), l
            out (c), h                  ; output hl to VDP

            ; set VRAM data

            ld h, 0
            ld l, a                     ; hl = row index * 2

            ld bc, BGRowOffsetTable
            add hl, bc                  ; hl = BGRowOffsetTable + row index * 2

            ld e, (hl)
            inc hl
            ld d, (hl)                  ; de = Tilemap + row offset
            ex de, hl                   ; hl = Tilemap + row offset

            ld c, VDP_DATA_PORT
            ld b, 64
            otir                        ; output 64 bytes starting at memory address hl to VDP
        sub 2
        jr nc, -

        ; initilise SAT
        ld bc, 0
        call SPRITES_TerminateSAT
        call SPRITES_FlushSAT

        ; initialise scroll offsets / redraw columns
        ld a, 0
        ld (VDPScroll), a
        ld bc, 0
        ld (RedrawVDPCol), bc
        ld (BGScroll), bc
        ld (RedrawBGCol), bc

        ; turn on display
        VDP_SetRegister 1, %11100000 ; 16K VRAM, enable display, frame interrupts

        ei

    MainLoop:
        halt

        ; load controller state into register d
        in a, CTLR_PORT_AB

        ; scroll up
        bit CTLR_PORT_AB_A_LEFT, a
        jr nz, +
            call ScrollLeft
            jr MainLoop
        +:

        ; scroll down
        bit CTLR_PORT_AB_A_RIGHT, a
        jr nz, +
            call ScrollRight
            jr MainLoop
        +:

        jr MainLoop

    ; Decrements scroll values & sets which column of the background gets shown on the left of the screen
    ; Clobbers: a, hl, bc, de
    ScrollLeft:
        ; load current BG scroll value from RAM
        ld hl, (BGScroll)

        ; the current BGScroll value is also the max available scroll distance

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; store original BGScroll value for later
        ld d, h
        ld e, l

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; reduce VDPScroll by clamped value
        ld a, (VDPScroll)
        sub a, l
        ld (VDPScroll), a

        ; find the horizontal offset of the first vertical line of pixels on the viewport
        add a, 8

        ; (integer) divide by 8 to get column number
        ShiftRightA 3

        ; set the VDP column to be redrawn
        ld (RedrawVDPCol), a

        ; reduce BGScroll by clamped value
        ex de, hl               ; hl = BGScroll
        or a                    ; clear carry flag
        sbc hl, de              ; hl = BGScroll - scroll distance
        ld (BGScroll), hl       ; BGScroll = BGScroll - scroll distance

        ; find the vertical offset of the first vertical line of the background that we want to display
        ld bc, 8
        add hl, bc

        ; integer divide by 8 to get row number
        ShiftRightHL 3

        ; set the background row to be redrawn
        ld (RedrawBGCol), hl

        ret
    
    ; Increments scroll values & sets which column of the background gets shown on the right of the screen
    ; Clobbers: a, hl, bc, de
    ScrollRight:
        ; load current BG scroll value from RAM
        ld hl, (BGScroll)

        ; swap it into de
        ex de, hl

        ; find max available scroll distance
        ld hl, (COLS - 32) * 8
        or a        ; clear carry flag
        sbc hl, de

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; increase VDPScroll by clamped value
        ld a, (VDPScroll)
        add a, l
        ld (VDPScroll), a

        ; find the horizontal offset of the last vertical line of pixels on the viewport
        add a, 255

        ; (integer) divide by 8 to get column number
        ShiftRightA 3

        ; set the VDP column to be redrawn
        ld (RedrawVDPCol), a

        ; increase BGScroll by clamped value
        ex de, hl               ; hl = BGScroll
        add hl, de              ; hl = BGScroll + scroll distance
        ld (BGScroll), hl       ; BGScroll = BGScroll + scroll distance

        ; find the horizontal offset of the first vertical line of the background that we want to display
        ld bc, 255
        add hl, bc

        ; divide by 8 to get row number
        ShiftRightHL 3

        ; set the background row to be redrawn
        ld (RedrawBGCol), hl

        ret

    ; Adjusts a value to be the max of the current value or SCROLL_INCREMENT
    ; Params: hl: value to adjust
    ; Clobbers: bc
    ; Sets: hl = clamped value
    ClampToScrollIncrement:
        ld bc, SCROLL_INCREMENT
        or a        ; clear c flag
        sbc hl, bc
        jr nc, +
            ; if c is set, bc (SCROLL_INCREMENT) was greater than hl
            add hl, bc  ; restore hl to its previous value
            ret
        +:
        ; otherwise clamp to SCROLL_INCREMENT
        ld hl, SCROLL_INCREMENT
        ret
.ends

.section "redraw_row"
    RedrawCol:
        ; calculate & store col offset
        ld hl, (RedrawVDPCol)
        add hl, hl                      ; hl = col index * 2
        ld (VDPColOffset), hl           ; VDPColOffset = col index * 2

        ld hl, (RedrawBGCol)
        add hl, hl                      ; hl = bg col index * 2
        ld (BGColOffset), hl            ; BGColOffset = col index * 2
        
        ld a, 46                        ; a = row index * 2
        -:
            ; set VRAM write command / address

            ld h, 0
            ld l, a                     ; hl = row index * 2

            ld bc, VRAMOffsetTable
            add hl, bc                  ; hl = VRAMOffsetTable + row index * 2

            ld e, (hl)
            inc hl
            ld d, (hl)                  ; de = VDP write bits + row offset
        
            ld hl, (VDPColOffset)       ; hl = col offset

            add hl, de                  ; hl = VDP write bits + row offset + col offset

            ld c, VDP_CTRL_PORT
            out (c), l
            out (c), h                  ; output hl to VDP

            ; set VRAM data

            ld h, 0
            ld l, a                     ; hl = row index * 2

            ld bc, BGRowOffsetTable
            add hl, bc                  ; hl = BGRowOffsetTable + row index * 2

            ld e, (hl)
            inc hl
            ld d, (hl)                  ; de = Tilemap + row offset

            ld hl, (BGColOffset)        ; hl = BGColOffset
            add hl, de                  ; hl = Tilemap + row offset + BGColOffset

            ld c, VDP_DATA_PORT
            ld b, 2
            otir                        ; output 2 bytes starting at memory address hl to VDP
        sub 2
        jr nc, -
        
        ret
.ends

.section "row_offset_tables"
    VRAMOffsetTable:
        .repeat 24 index i
            .dw (VDP_CMD_VRAM_WRITE << 8 | $3800) + i*32*2  ; VDP write bits + row offset
        .endr

    BGRowOffsetTable:
        .repeat 24 index i
            .dw Tilemap + i*COLS*2                          ; Tilemap address + row offset
        .endr
.ends

.section "vdp_data"
    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
.ends

.bank 1
.slot 1

.section "tilemap"
    .include "data/tilemap.asm"
.ends
