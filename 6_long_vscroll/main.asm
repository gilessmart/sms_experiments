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
    RedrawBGRow: dw
    VDPScroll: db
    RedrawVDPRow: db
.ends

.bank 0
.slot 0

.sdsctag 0.1, "Long v-scrolling demo", "SMS programming experiment", "Giles Smart"

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
    in a, (VDP_CTRL_PORT)  ; read & clear VDP flags, clear interrupt request line

    ; update VDP with new scroll value
    ld a, (VDPScroll)
    ld l, a
    VDP_SetRegister 9

    call RedrawRow

    ei  ; re-enable interrupts  - they're turned off automatically when an interrupt is accepted

    reti
.ends

.org $0066
.section "pause_handler" force
    retn
.ends

.define SCROLL_INCREMENT 4       ; max = 8
.define MAX_BG_SCROLL 1904 - 192 ; height of background - 192

.section "main"
    Init:
        ; initialise VDP registers
        VDP_SetRegister 0, %00000100 ; mode 4
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
        ld hl, VDP_CMD_VRAM_WRITE << 8 | $3800
        call VDP_SetAddress
        ld hl, Tilemap
        ld de, $600
        call VDP_CopyData

        ; initilise SAT
        ld bc, 0
        call SPRITES_TerminateSAT
        call SPRITES_FlushSAT

        ; initialise scroll offsets / redraw rows
        ld a, 0
        ld (VDPScroll), a
        ld (RedrawVDPRow), a
        ld bc, 0
        ld (BGScroll), bc
        ld (RedrawBGRow), bc

        ; turn on display
        VDP_SetRegister 1, %11100000 ; 16K VRAM, enable display, frame interrupts

        ei

    MainLoop:
        halt

        ; load current BG scroll value from RAM
        ld bc, (BGScroll)

        ; load controller state into register d
        in a, CTLR_PORT_AB
        ld e, a

        ; check for scroll up
        ; bit CTLR_PORT_AB_A_UP, e
        ; jr nz, +
        ; ; TODO
        ; +:

        ; scroll down
        bit CTLR_PORT_AB_A_DOWN, e
        jr nz, +
            ; find distance to the max scroll distance
            ld hl, MAX_BG_SCROLL
            or a        ; clear carry flag
            sbc hl, bc  ; hl = hl - bc

            ; if distance is 0, nothing to do
            ld a, h
            or l
            jr z, + 

            ; otherwise we need to scroll by the smaller of hl or SCROLL_INCREMENT
            ; 1. check HOB of hl
            ld a, h
            cp 0                            ; if HOB of remaining distance == 0, Z is set
            jr z, ++                        ; in which case move on to check LOB
                ld hl, SCROLL_INCREMENT     ; otherwise clamp to SCROLL_INCREMENT
                jr +++
            ++:
            ; 2. check LOB of HL
            ld a, l
            cp SCROLL_INCREMENT             ; if remaining scroll value < SCROLL_INCREMENT, C is set
            jr c, +++                       ; in which case the remaining scroll distance can be left alone
                ld l, SCROLL_INCREMENT      ; otherwise clamp to SCROLL_INCREMENT
            +++:

            ; update VDPScroll
            ld a, (VDPScroll)
            add a, l
            cp 224
            jr c, ++    ; if a already less than 224, skip
                sub 224 ; otherwise we subtract 224
            ++:
            ld (VDPScroll), a

            ; set the VDP row to be redrawn
            call LastVisibleVDPRow
            ld (RedrawVDPRow), a

            ; udpate BGScroll
            add hl, bc
            ld (BGScroll), hl

            ; set the background row to be redrawn
            call LastVisisbleBgRow
            ld (RedrawBGRow), hl
        +:

        jp MainLoop

    ; Find the index number of the final VDP tilemap row visible on the viewport
    ; for a given VDPScroll value
    ; Params: a = VDPScroll value
    ; Updates: a = calculated index number
    LastVisibleVDPRow:
        ; find the vertical offset of the last line of the tilemap in the viewport
        add a, 191          ; after this, a will be from 191 to 414 - so often overflowing the byte
        jr nc, +            ; if the add overflowed, it essentially did modulo 256
            add a, 32       ; we can add 32 to what we have now to get the right modulo 224 number
            jr ++           ; and skip the regular modulo check
        +: 
        cp 224              
        jr c, ++            ; if a already less than 224, skip
            sub 224         ; otherwise we subtract 224
        ++:

        ; divide by 8 to get row number
        .repeat 3
            srl a
        .endr

        ret

    ; Find the index number of the final background row visible on the viewport
    ; for a given BGScroll offset
    ; Params: hl = BGScroll value
    ; Clobbers: bc
    ; Updates: hl = calculated index number
    LastVisisbleBgRow:
        ; find the vertical offset of the last line of the background that we want to display
        ld bc, 191
        add hl, bc

        ; divide by 8 to get row number
        .repeat 3
            srl h
            rr l
        .endr

        ret

.ends

.section "redraw_row"
    RedrawRow:
        ld a, (RedrawVDPRow)
        
        ; load a into hl
        ld h, 0
        ld l, a
        
        ; multiply hl by 64 (number of bytes per row in vram)
        .repeat 6
            sla l
            rl h
        .endr

        ; add the base address of the VDP tilemap
        ld bc, VDP_CMD_VRAM_WRITE << 8 | $3800
        add hl, bc

        call VDP_SetAddress

        ld hl, (RedrawBGRow)

        ; multiply by 64 (number of bytes per row in tilemap data)
        .repeat 6
            sla l
            rl h
        .endr

        ; add the start address
        ld bc, Tilemap
        add hl, bc

        ; write one line (64 bytes) of data
        ld de, $40
        
        call VDP_CopyData
        
        ret
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
