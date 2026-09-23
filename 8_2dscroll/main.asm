.define VSCROLL_DIR_UP 0
.define VSCROLL_DIR_NONE 1
.define VSCROLL_DIR_DOWN 2

.define SCROLL_INCREMENT 5  ; max = 8
.define BG_ROWS 42          ; cols in background
.define BG_COLS 194         ; cols in background

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
    BGScrollX: dw
    BGScrollY: dw
    VDPScrollX: db
    VDPScrollY: db
    RedrawCol_BGCol: dw
    RedrawCol_VDPCol: dw
    RedrawCol_VDPColAddrOffset: dw
    RedrawCol_BGColAddrOffset: dw
    FirstVisibleVRAMRow: db
    FirstVisibleBGRow: db
    VisibleRowCount: db
    FirstVisibleVRAMCol: db
    FirstVisibleBGCol: db
    VisibleColCount: db
    RedrawRow_BGRow: dw
    RedrawRow_VDPRow: dw
    VScrollDir: db
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

    ; copy (inverted) X scroll value to VDP
    ld a, (VDPScrollX)
    ld l, a             ; l = VDPScrollX
    ld a, 0
    sub l               ; a = 256 - VDPScrollX
    ld l, a             ; l = 256 - VDPScrollX
    VDP_SetRegister 8

    ; copy Y scroll value to VDP
    ld a, (VDPScrollY)
    ld l, a
    VDP_SetRegister 9

    call RedrawCol
    call RedrawRow

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
        ld a, 23*2                      ; a = row index * 2
        -:
            ; set VRAM write command / address

            ld h, 0
            ld l, a                     ; hl = row index * 2

            ld bc, VRAMRowAddrs
            add hl, bc                  ; hl = VRAMRowAddrs + row index * 2

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

            ld bc, BGRowAddrs
            add hl, bc                  ; hl = BGRowAddrs + row index * 2

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
        ld (VDPScrollX), a
        ld (VDPScrollY), a
        ld (FirstVisibleVRAMRow), a
        ld (FirstVisibleBGRow), a
        ld a, 1
        ld (FirstVisibleVRAMCol), a
        ld (FirstVisibleBGCol), a
        ld a, VSCROLL_DIR_NONE
        ld (VScrollDir), a
        ld a, 24
        ld (VisibleRowCount), a
        ld a, 31
        ld (VisibleColCount), a
        ld bc, 0
        ld (BGScrollX), bc
        ld (BGScrollY), bc
        ld bc, 1
        ld (RedrawCol_VDPCol), bc
        ld (RedrawCol_BGCol), bc

        ; turn on display
        VDP_SetRegister 1, %11100000 ; 16K VRAM, enable display, frame interrupts

        ei

    MainLoop:
        halt

        ; read controller state
        in a, CTLR_PORT_AB

        ; scroll up / down
        ld hl, VScrollDir
        ld (hl), VSCROLL_DIR_NONE
        bit CTLR_PORT_AB_A_UP, a
        jr nz, +
            ex af, af'
                call ScrollUp
                ld hl, VScrollDir
                ld (hl), VSCROLL_DIR_UP
            ex af, af'
        jr ++
        +:
        bit CTLR_PORT_AB_A_DOWN, a
        jr nz, ++
            ex af, af'
                call ScrollDown
                ld hl, VScrollDir
                ld (hl), VSCROLL_DIR_DOWN
            ex af, af'
        ++:

        ; scroll left / right
        bit CTLR_PORT_AB_A_LEFT, a
        jr nz, +
            ex af, af'
                call ScrollLeft
            ex af, af'
        jr ++
        +:
        bit CTLR_PORT_AB_A_RIGHT, a
        jr nz, ++
            ex af, af'
                call ScrollRight
            ex af, af'
        ++:

        call CalculateVisibleTiles

        jr MainLoop

    ; Calculates and stores the first visible row & col indices and the number of visible rows & cols
    ; Clobbers: a, hl
    CalculateVisibleTiles:
        ; calculate FirstVisibleVRAMRow
        ld a, (VDPScrollY)
        ShiftRightA 3
        ld (FirstVisibleVRAMRow), a

        ; calculate FirstVisibleBGRow
        ld hl, (BGScrollY)
        ShiftRightHL 3
        ld a, l
        ld (FirstVisibleBGRow), a

        ; calculate VisibleRowCount
        ld hl, VisibleRowCount
        ld a, (VDPScrollY)
        and 7                           ; a = fine scroll value
        jr z, +
            ld (hl), 25                 ; a != 0
        jr ++
        +:
            ld (hl), 24                 ; a == 0
        ++:

        ; calculate FirstVisibleVRAMCol
        ld a, (VDPScrollX)
        add a, 8
        ShiftRightA 3
        ld (FirstVisibleVRAMCol), a

        ; calculate FirstVisibleBGCol
        ld hl, (BGScrollX)
        ld bc, 8
        add hl, bc
        ShiftRightHL 3
        ld a, l
        ld (FirstVisibleBGCol), a

        ; calculate VisibleColCount
        ld hl, VisibleColCount
        ld a, (VDPScrollX)
        and 7                           ; a = fine scroll value
        jr z, +
            ld (hl), 32                 ; a != 0
        jr ++
        +:
            ld (hl), 31                 ; a == 0
        ++:

        ret

    ; Decrements vertical scroll values
    ; Clobbers: a, bc, de, hl
    ScrollUp:
        ld hl, (BGScrollY)

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; store original BG scroll value for later
        ld d, h
        ld e, l

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; reduce VDPScrollY by clamped value
        ld a, (VDPScrollY)
        sub a, l
        ld (VDPScrollY), a

        ; reduce BGScrollX by clamped value
        ex de, hl               ; hl = BGScrollY
        or a                    ; clear carry flag
        sbc hl, de              ; hl = BGScrollX - scroll distance
        ld (BGScrollY), hl      ; BGScrollY = BGScrollY - scroll distance

        ret

    ; Increments vertical scroll values
    ; Clobbers: a, bc, de, hl
    ScrollDown:
        ld hl, (BGScrollY)

        ; swap it into de
        ex de, hl

        ; find max available scroll distance
        ; TODO - revert
        ; ld hl, (BG_ROWS - 24) * 8
        ld hl, (28 - 24) * 8
        or a        ; clear carry flag
        sbc hl, de

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; increase VDPScrollY by clamped value
        ld a, (VDPScrollY)
        add a, l
        ld (VDPScrollY), a

        ; increase BGScrollY by clamped value
        ex de, hl               ; hl = BGScrollY
        add hl, de              ; hl = BGScrollY + scroll distance
        ld (BGScrollY), hl      ; BGScrollX = BGScrollY + scroll distance

        ret

    ; Decrements scroll values & sets which column of the background gets shown on the left of the screen
    ; Clobbers: a, hl, bc, de
    ScrollLeft:
        ; load current value of BGScrollX from RAM
        ld hl, (BGScrollX)

        ; the current value of BGScrollX is the max available scroll distance

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; store original BGScrollX value for later
        ld d, h
        ld e, l

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; reduce VDPScrollX by clamped value
        ld a, (VDPScrollX)
        sub a, l
        ld (VDPScrollX), a

        ; find the horizontal offset of the first vertical line of pixels now on the viewport
        add a, 8

        ; (integer) divide by 8 to get column number
        ShiftRightA 3

        ; set the VDP column to be redrawn
        ld (RedrawCol_VDPCol), a

        ; reduce BGScrollX by clamped value
        ex de, hl               ; hl = BGScrollX
        or a                    ; clear carry flag
        sbc hl, de              ; hl = BGScrollX - scroll distance
        ld (BGScrollX), hl      ; BGScrollX = BGScrollX - scroll distance

        ; find the vertical offset of the first vertical line of the background that we want to display
        ld bc, 8
        add hl, bc

        ; integer divide by 8 to get row number
        ShiftRightHL 3

        ; set the background row to be redrawn
        ld (RedrawCol_BGCol), hl

        ret
    
    ; Increments scroll values & sets which column of the background gets shown on the right of the screen
    ; Clobbers: a, hl, bc, de
    ScrollRight:
        ; load current value of BGScrollX from RAM
        ld hl, (BGScrollX)

        ; swap it into de
        ex de, hl

        ; find max available scroll distance
        ld hl, (BG_COLS - 32) * 8
        or a        ; clear carry flag
        sbc hl, de

        ; if distance is 0, nothing to do
        ld a, h
        or l
        ret z

        ; clamp hl value to the size of the scroll increment
        call ClampToScrollIncrement

        ; increase VDPScrollX by clamped value
        ld a, (VDPScrollX)
        add a, l
        ld (VDPScrollX), a

        ; find the horizontal offset of the last vertical line of pixels now on the viewport
        add a, 255

        ; (integer) divide by 8 to get column number
        ShiftRightA 3

        ; set the VDP column to be redrawn
        ld (RedrawCol_VDPCol), a

        ; increase BGScrollX by clamped value
        ex de, hl               ; hl = BGScrollX
        add hl, de              ; hl = BGScrollX + scroll distance
        ld (BGScrollX), hl      ; BGScrollX = BGScrollX + scroll distance

        ; find the horizontal offset of the first vertical line of the background that we want to display
        ld bc, 255
        add hl, bc

        ; divide by 8 to get row number
        ShiftRightHL 3

        ; set the background row to be redrawn
        ld (RedrawCol_BGCol), hl

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

.section "redraw_tiles"
    RedrawCol:
        ; calculate & store col offset
        ld hl, (RedrawCol_VDPCol)
        add hl, hl                              ; hl = col index * 2
        ld (RedrawCol_VDPColAddrOffset), hl     ; RedrawCol_VDPColAddrOffset = col index * 2

        ld hl, (RedrawCol_BGCol)
        add hl, hl                              ; hl = bg col index * 2
        ld (RedrawCol_BGColAddrOffset), hl      ; RedrawCol_BGColAddrOffset = col index * 2
        
        ld a, 0
        -:
            ; copy the counter
            ld d, a
            
            ; set VRAM write command / address
            ld hl, FirstVisibleVRAMRow
            add (hl)                            ; a = FirstVisibleVRAMRow + row index
            cp 28                               ; if a - 28 carries (i.e. a < 28), c flag is set
            jr c, +                             ; skip ahead if c flag is set (i.e. a < 28)
                sub 28
            +:                                  ; a = (FirstVisibleVRAMRow + row index) mod 28
            add a                               ; a = ((FirstVisibleVRAMRow + row index) mod 28) * 2

            ld h, 0
            ld l, a                             ; hl = ((FirstVisibleVRAMRow + row index) mod 28) * 2

            ld bc, VRAMRowAddrs
            add hl, bc                          ; hl = VRAMRowAddrs + ((FirstVisibleVRAMRow + row index) mod 28) * 2

            ld c, (hl)
            inc hl
            ld b, (hl)                          ; bc = VDP write bits + row offset
        
            ld hl, (RedrawCol_VDPColAddrOffset) ; hl = col offset

            add hl, bc                          ; hl = VDP write bits + row offset + col offset

            ld c, VDP_CTRL_PORT
            out (c), l
            out (c), h                          ; output hl to VDP

            ; set VRAM data
            ld a, d                             ; a = row index
            
            ld hl, FirstVisibleBGRow
            add (hl)                            ; a = FirstVisibleBGRow + row index
            add a                               ; a = (FirstVisibleBGRow + row index) * 2

            ld h, 0
            ld l, a                             ; hl = (FirstVisibleBGRow + row index) * 2

            ld bc, BGRowAddrs
            add hl, bc                          ; hl = BGRowAddrs + (FirstVisibleBGRow + row index) * 2

            ld c, (hl)
            inc hl
            ld b, (hl)                          ; bc = Tilemap + row offset

            ld hl, (RedrawCol_BGColAddrOffset)  ; hl = RedrawCol_BGColAddrOffset
            add hl, bc                          ; hl = Tilemap + row offset + col offset

            ld c, VDP_DATA_PORT
            ld b, 2
            otir                                ; output 2 bytes starting at memory address hl to VDP

            ; reinstate the counter
            ld a, d
        
            ; loop if counter != VisibleRowCount
            inc a
            ld hl, VisibleRowCount
            cp (hl)
            jr nz, -
        
        ret

    RedrawRow:
        ; if we've scrolled down, draw the LastVisibleRow
        ; if we've scrolled up, draw the FirstVisibleRow

        ; TODO - pull up 1 level?
        ; if we've not scrolled, do nothing
        ld a, (VScrollDir)
        cp VSCROLL_DIR_NONE
        ret z

        ; draw from FirstVisibleCol index to LastvisibleColIndex

        ; VRAM address of the first tile we want to draw:
        ;   VRAM start + row index * 32 * 2 + col index * 32 * 2
        ; = VRAM start + (row index + col index) * 64
        ; about 8 16bit adds and a 16 bit load from literal
        ; or look it up:
        ; *(VRAMRowAddrs + row index * 2) + col index * 2
        ; about 3 16 bit adds and a 16 bit load from RAM
        ; let's look it up

        ; actually..
        ; we're going to populate the whole row of VRAM every time so always 64 bytes
        ; but it's not simple because we need to go:
        ; from FirstVisibleVDPCol -> col 31, then col 0 -> (FirstVisbileVDPCol - 1) mod 32
        ; populating with:
        ; FirstVisibleBGCol -> ??, then col ?? +1 -> FirstVisibleVDPCol + 31...

        ; let's try just FirstVisibleCol...

        ; lookup the VDP write bits / VDP address of the first tile in the row
        ; and send to VDP

        ld a, (FirstVisibleVRAMRow)
        ld b, a                             ; b = first visible VRAM row idx

        ; TODO skip ahead if we're drawing the top row..
        ld a, (VisibleRowCount)
        add a, b                            ; a = first visible VRAM row idx + visible row count
        sub a, 1                            ; a = last visible VRAM row idx
        
        +:
        add a, a                            ; a = last visible VRAM row addr offset from VRAMRowAddrs

        ld d, 0
        ld e, a                             ; de = last visible VRAM row addr offset from VRAMRowAddrs

        ld hl, VRAMRowAddrs
        add hl, de                          ; hl = &VRAMRowAddrs + last visible VRAM row addr offset from VRAMRowAddrs
        
        ld e, (hl)
        inc hl
        ld d, (hl)                          ; de = VDP write bits + addr of first tile of row

        ld a, (FirstVisibleVRAMCol)         ; a = first visisble VRAM col idx
        add a, a                            ; a = addr offset of first visible VRAM col
        ld h, 0
        ld l, a                             ; hl = addr offset of first visible VRAM col

        add hl, de                          ; hl = VDP write bits + addr of first tile of row + addr offset of first visible col

        ld c, VDP_CTRL_PORT
        out (c), l
        out (c), h                          ; output hl to VDP

        ; lookup the BG address of the first tile in the row
        ; and send to VDP

        ld a, (FirstVisibleBGRow)
        ld b, a                             ; b = first visible BG row idx

        ; TODO skip ahead if we're drawing the top row..
        ld a, (VisibleRowCount)
        add a, b                            ; a = first visible BG row idx + visible row count
        sub a, 1                            ; a = last visible BG row idx
        
        +:
        add a, a                            ; a = last visible BG row addr offset from start of BGRowAddrs table

        ld b, 0
        ld c, a                             ; bc = last visible BG row addr offset from start of BGRowAddrs table

        ld hl, BGRowAddrs                   ; hl = BGRowAddrs
        add hl, bc                          ; hl = BGRowAddrs + last visible BG row addr offset from BGRowAddrs

        ld e, (hl)
        inc hl
        ld d, (hl)                          ; de = addr of first tile of row in BG tilemap

        ld a, (FirstVisibleBGCol)           ; a = first visible BG col idx
        add a, a                            ; a = addr offset of first visible BG col idx (relative to col 0)

        ld h, 0
        ld l, a                             ; hl = addr offset of first visible BG col idx (relative to col 0)

        add hl, de                          ; hl = addr of first tile of row in BG tilemap + addr offset of first visible BG col idx (relative to col 0)

        ld c, VDP_DATA_PORT
        ld b, 2
        otir                                ; output 2 bytes starting at memory address hl to VDP

        ret
.ends

.section "row_addr_tables"
    ; Addresses of each row of VRAM
    VRAMRowAddrs:
        .repeat 28 index i
            .dw (VDP_CMD_VRAM_WRITE << 8 | $3800) + i*32*2  ; VDP write bits + row offset
        .endr

    ; Addresses of each row of the background
    BGRowAddrs:
        .repeat BG_ROWS index i
            .dw Tilemap + i*BG_COLS*2                       ; Tilemap address + row offset
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
