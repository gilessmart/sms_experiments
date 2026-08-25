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
    RedrawBGCol: dw
    VDPScroll: db
    RedrawVDPCol: db
.ends

.bank 0
.slot 0

.sdsctag 0.1, "Long v-scrolling demo", "SMS programming experiment", "Giles Smart"

.include "vdp.asm"
.include "sprites.asm"
.include "controller.asm"
.include "rotate.asm"

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
    ld l, a
    VDP_SetRegister 8

    call RedrawCol

    ei  ; re-enable interrupts  - they're turned off automatically when an interrupt is accepted

    reti
.ends

.org $0066
.section "pause_handler" force
    retn
.ends

.define SCROLL_INCREMENT 4       ; max = 8
.define MAX_BG_SCROLL 768 - 248  ; height of background - width of viewport

.section "main"
    Init:
        ; initialise VDP registers
        VDP_SetRegister 0, %00100100 ; mode 4
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
        ld a, 23
        -:

        ld bc, VDP_CMD_VRAM_WRITE << 8 | ($3800 + 2)    ; set starting VRAM address
        ld h, 0                                         ; load counter into hl
        ld l, a
        RotateLeftHL 6                                  ; multiply counter by 64
        add hl, bc                                      ; add starting VRAM address
        ex af, af'
            call VDP_SetAddress                         ; write address to VDP
        ex af, af'
        
        ld bc, Tilemap                                  ; set starting ROM address
        ld h, 0                                         ; load counter into hl
        ld l, a
        RotateLeftHL 7                                  ; multiply by 128
        ex hl, de                                       ; store in de
        ld h, 0                                         ; load counter into hl again
        ld l, a
        RotateLeftHL 6                                  ; multiply by 64
        add hl, de                                      ; add the * 128 value - should now have counter * 192
        add hl, bc                                      ; add the starting ROM address
        ld de, 62                                       ; write 62 bytes
        ex af, af'
            call VDP_CopyData                           ; write data to VDP
        ex af, af'
        
        sub 1
        jr nc, -

        ; initilise SAT
        ld bc, 0
        call SPRITES_TerminateSAT
        call SPRITES_FlushSAT

        ; initialise scroll offsets / redraw columns
        ld a, 0
        ld (VDPScroll), a
        ld (RedrawVDPCol), a
        ld bc, 0
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

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; store original BGScroll value for later
        ld d, h
        ld e, l

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; TODO - review this modulo - it'll probably need to change from 224 to 248?
        ; reduce VDPScroll by clamped value
        ld a, (VDPScroll)   ; load
        sub a, l            ; reduce
        jr nc, ++           ; if is now less than 0
            add 224         ; add 224
        ++:
        ld (VDPScroll), a   ; store

        ; integer divide by 8 to get row number
        RotateRightA 3

        ; set the VDP row to be redrawn
        ld (RedrawVDPCol), a

        ; reduce BGScroll by clamped value
        ex hl, de
        or a        ; clear carry flag
        sbc hl, de
        ld (BGScroll), hl

        ; integer divide by 8 to get row number
        RotateRightHL 3

        ; set the background row to be redrawn
        ld (RedrawBGCol), hl

        ret
    
    ; Increments scroll values & sets which column of the background gets shown on the right of the screen
    ; Clobbers: a, hl, bc, de
    ScrollRight:
        ; load current BG scroll value from RAM
        ld hl, (BGScroll)

        ; swap it into de
        ex hl, de

        ; find max available scroll distance
        ld hl, MAX_BG_SCROLL
        or a        ; clear carry flag
        sbc hl, de

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; TODO - review the modulos - it'll probably need to change from 224 to 248?

        ; increase VDPScroll by clamped value
        ld a, (VDPScroll)
        add a, l
        cp 224
        jr c, +     ; if a already less than 224, skip
            sub 224 ; otherwise we subtract 224
        +:
        ld (VDPScroll), a

        ; find the vertical offset of the last line of the tilemap in the viewport
        add a, 191          ; after this, a will be from 191 to 414 - so often overflowing the byte
        jr nc, +            ; if the add overflowed, it essentially did modulo 256
            add a, 32       ; we can add 32 to what we have now to get the right modulo 224 number
            jr ++           ; and skip the regular modulo check
        + 
        cp 224              
        jr c, ++            ; if a already less than 224, skip
            sub 224         ; otherwise we subtract 224
        ++:

        ; divide by 8 to get row number
        RotateRightA 3

        ; set the VDP row to be redrawn
        ld (RedrawVDPCol), a

        ; increase BGScroll by clamped value
        add hl, de
        ld (BGScroll), hl

        ; TODO - update to width of the viewport?
        ; find the vertical offset of the last line of the background that we want to display
        ld bc, 191
        add hl, bc

        ; divide by 8 to get row number
        RotateRightHL 3

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
    ; TODO - this has got to change to actually draw a column instead of a row..
    RedrawCol:
        ; ld a, (RedrawVDPCol)
        
        ; ; load a into hl
        ; ld h, 0
        ; ld l, a
        
        ; ; multiply hl by 64 (number of bytes per row in vram)
        ; RotateLeftHL 6

        ; ; add the base address of the VDP tilemap
        ; ld bc, VDP_CMD_VRAM_WRITE << 8 | $3800
        ; add hl, bc

        ; call VDP_SetAddress

        ; ld hl, (RedrawBGCol)

        ; ; multiply by 64 (number of bytes per row in tilemap data)
        ; RotateLeftHL 6

        ; ; add the start address
        ; ld bc, Tilemap
        ; add hl, bc

        ; ; write one line (64 bytes) of data
        ; ld de, $40
        
        ; call VDP_CopyData
        
        ret
.ends

.section "vdp_data"
    .include "data/palette.asm"
    .include "data/tile_patterns.asm"
.ends

; TODO - tilemap no longer needs to be in a separate bank

.bank 1
.slot 1

.section "tilemap"
    .include "data/tilemap.asm"
.ends
