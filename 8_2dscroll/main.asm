.define HSCROLL_DIR_LEFT 0
.define HSCROLL_DIR_NONE 1
.define HSCROLL_DIR_RIGHT 2
.define VSCROLL_DIR_UP 0
.define VSCROLL_DIR_NONE 1
.define VSCROLL_DIR_DOWN 2

.define SCROLL_INCREMENT 5  ; max = 8
.define BG_ROWS 64          ; rows in background
.define BG_COLS 127         ; cols in background

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

.struct RedrawRowParamsStruct
    BGAddr: dw          ; addr in the BG tilemap of the first visible tile 
    VDPAddr1: dw        ; addr in the VRAM tilemap of the *first visible* tile in the row
    ByteCount1: db      ; number of bytes to draw from VDPAddr1
    VDPAddr2: dw        ; addr in the VRAM tilemap of the *first* tile in the row
    ByteCount2: db      ; number of bytes to draw from VDPAddr2
.endst

.struct RedrawColParamsStruct
    BGAddr: dw          ; addr in the BG tilemap of the first visible tile 
    VDPAddr1: dw        ; addr in the VRAM tilemap of the *first visible* tile in the col
    RowCount1: db       ; number of tiles to draw from VDPAddr1
    VDPAddr2: dw        ; addr in the VRAM tilemap of the *first* tile in the col
    RowCount2: db       ; number of tiles to draw from VDPAddr2
.endst

.ramsection "main_state" slot 2
    VDPScrollX: db
    VDPScrollY: db
    BGScrollX: dw
    BGScrollY: dw
    VisibleRowCount: db
    FirstVisibleVRAMRow: db
    LastVisibleVRAMRow: db
    FirstVisibleBGRow: db
    LastVisibleBGRow: db
    VisibleColCount: db
    FirstVisibleVRAMCol: db
    LastVisibleVRAMCol: db
    FirstVisibleBGCol: db
    LastVisibleBGCol: db
    HScrollDir: db
    VScrollDir: db
    RedrawRowParams: instanceof RedrawRowParamsStruct
    RedrawColParams: instanceof RedrawColParamsStruct
.ends

.bank 0
.slot 0

.sdsctag 0.1, "2D Scrolling Demo", "SMS programming experiment", "Giles Smart"

.include "vdp.asm"
.include "sprites.asm"
.include "controller.asm"
.include "utils.asm"

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

    ; invert scroll offset & copy to VDP
    ld a, (VDPScrollX)
    ld l, a                 ; l = VDPScrollX
    ld a, 0
    sub l                   ; a = 256 - VDPScrollX
    ld l, a                 ; l = 256 - VDPScrollX
    VDP_SetRegister 8

    ; copy Y scroll value to VDP
    ld a, (VDPScrollY)
    ld l, a
    VDP_SetRegister 9

    ld a, (HScrollDir)
    cp HSCROLL_DIR_NONE
    call nz, RedrawCol      ; skip if HScrollDir == HSCROLL_DIR_NONE

    ld a, (VScrollDir)
    cp VSCROLL_DIR_NONE
    call nz, RedrawRow      ; skip if VScrollDir == VSCROLL_DIR_NONE

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
        ld a, HSCROLL_DIR_NONE
        ld (HScrollDir), a
        ld a, VSCROLL_DIR_NONE
        ld (VScrollDir), a
        ld a, 23
        ld (LastVisibleVRAMCol), a
        ld (LastVisibleBGCol), a
        ld a, 24
        ld (VisibleRowCount), a
        ld a, 31
        ld (VisibleColCount), a
        ld bc, 0
        ld (BGScrollX), bc
        ld (BGScrollY), bc

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
        ld hl, HScrollDir
        ld (hl), HSCROLL_DIR_NONE
        bit CTLR_PORT_AB_A_LEFT, a
        jr nz, +
            ex af, af'
                call ScrollLeft
                ld hl, HScrollDir
                ld (hl), HSCROLL_DIR_LEFT
            ex af, af'
        jr ++
        +:
        bit CTLR_PORT_AB_A_RIGHT, a
        jr nz, ++
            ex af, af'
                call ScrollRight
                ld hl, HScrollDir
                ld (hl), HSCROLL_DIR_RIGHT
            ex af, af'
        ++:

        call CalculateVisibleArea
        
        call PrepRedrawRow
        call PrepRedrawCol

        jr MainLoop

    ; Calculates and stores the first visible row & col indices and the number of visible rows & cols
    ; Clobbers: a, bc, de, hl
    CalculateVisibleArea:
        ;; Rows ;;

        ; calculate VisibleRowCount
        ld a, (VDPScrollY)
        ld b, a                                     ; store VDPScroll value for calculating VisibleRowCount
        and 7                                       ; a = fine scroll value
        jr z, +                                     ; skip forward if a = 0
            ld a, 25
        jr ++
        +:
            ld a, 24
        ++:
        ld (VisibleRowCount), a

        ; store difference between last and first row for calculating last rows
        dec a                                       
        ld c, a

        ; calculate FirstVisibleVRAMRow
        ld a, b
        ShiftRightA 3
        ld (FirstVisibleVRAMRow), a

        ; calculate LastVisibleVRAMRow
        add a, c                                    ; a = FirstVisibleVRAMRow + difference
        cp 28                                       ; apply modulo 28..
        jr c, +                                     ; jump forward if a < 28
            sub a, 28                               ; otherwise, subtract 28    
        +:
        ld (LastVisibleVRAMRow), a

        ; calculate FirstVisibleBGRow
        ld hl, (BGScrollY)
        ShiftRightHL 3
        ld a, l
        ld (FirstVisibleBGRow), a

        ; calculate LastVisibleBGRow
        add a, c                                    ; a = FirstVisibleBGRow + difference
        ld (LastVisibleBGRow), a

        ;; Cols ;;

        ; calculate VisibleColCount
        ld a, (VDPScrollX)
        ld b, a                                     ; store VDPScrollX for calculating FirstVisibleVRAMCol
        and 7                                       ; a = fine scroll value
        jr z, +                                     ; skip forward if a = 0
            ld a, 32
        jr ++
        +:
            ld a, 31
        ++:
        ld (VisibleColCount), a

        ; store difference between last and first row for calculating last cols
        dec a                                       
        ld c, a

        ; calculate FirstVisibleVRAMCol
        ld a, b                                     ; a = VDPScrollX
        add a, 8
        ShiftRightA 3
        ld (FirstVisibleVRAMCol), a

        ; calculate LastVisibleVRAMCol
        add a, c                                    ; a = FirstVisibleVRAMCol + difference
        and 31                                      ; apply modulo 32
        ld (LastVisibleVRAMCol), a

        ; calculate FirstVisibleBGCol
        ld hl, (BGScrollX)
        ld de, 8
        add hl, de
        ShiftRightHL 3
        ld a, l
        ld (FirstVisibleBGCol), a

        ; calculate LastVisibleBGCol
        add a, c                                    ; a = FirstVisibleBGCol + difference
        ld (LastVisibleBGCol), a

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
        jr nc, +                ; skip if no carry i.e. if a < 0
            add a, 224
        +:     
        ld (VDPScrollY), a

        ; reduce BGScrollY by clamped value
        ex de, hl               ; hl = BGScrollY
        or a                    ; clear carry flag
        sbc hl, de              ; hl = BGScrollY - scroll distance
        ld (BGScrollY), hl      ; BGScrollY = BGScrollY - scroll distance

        ret

    ; Increments vertical scroll values
    ; Clobbers: a, bc, de, hl
    ScrollDown:
        ld hl, (BGScrollY)

        ; swap it into de
        ex de, hl

        ; find max available scroll distance
        ld hl, (BG_ROWS - 24) * 8
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
        cp 224
        jr c, +                 ; skip if carry i.e. if a < 224
            sub a, 224
        +:
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

        ; reduce BGScrollX by clamped value
        ex de, hl               ; hl = BGScrollX
        or a                    ; clear carry flag
        sbc hl, de              ; hl = BGScrollX - scroll distance
        ld (BGScrollX), hl      ; BGScrollX = BGScrollX - scroll distance

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

        ; increase BGScrollX by clamped value
        ex de, hl               ; hl = BGScrollX
        add hl, de              ; hl = BGScrollX + scroll distance
        ld (BGScrollX), hl      ; BGScrollX = BGScrollX + scroll distance

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

.section "redraw_background"
    ; Sets the values used during VBlank by the RedrawCol routine
    ; Clobbers: a, bc, de, hl
    PrepRedrawCol:
        ld a, (HScrollDir)
        cp HSCROLL_DIR_NONE                         ; check scroll direction

        ret z                                       ; bail out if we're not scrolling left or right

        ; calculate target VDP & BG col indices
        jr c, +                                     ; skip forward if HScrollDir < 1
            ; scrolling right
            ld a, (LastVisibleVRAMCol)
            ld d, a                                 ; d = target VRAM col index
            ld a, (LastVisibleBGCol)
            ld e, a                                 ; e = target BG col index
        jr ++
        +:
            ; scrolling left
            ld a, (FirstVisibleVRAMCol)
            ld d, a                                 ; d = target VRAM col index
            ld a, (FirstVisibleBGCol)
            ld e, a                                 ; e = target BG col index
        ++:

        ; calculate BG tilemap addr of first visible tile in the column
        ld a, (FirstVisibleBGRow)                   ; a = row index
        ld h, 0
        ld l, a                                     ; hl = row index
        add hl, hl                                  ; hl = row offset
        ld bc, BGRowAddrs
        add hl, bc                                  ; hl = BGRowAddrs + row offset (from BGRowAddrs)
        ld c, (hl)
        inc hl
        ld b, (hl)                                  ; bc = Tilemap + row offset (from Tilemap)
        ld h, 0
        ld l, e                                     ; hl = col index
        add hl, hl                                  ; hl = col offset
        add hl, bc                                  ; hl = Tilemap + row offset + col offset
        ld (RedrawColParams.BGAddr), hl

        ; calculate how many rows to draw between the first visible row and last row
        ld a, (VisibleRowCount)
        ld b, a                                     ; b = visible row count
        ld a, 28                                    ; a = 28
        ld hl, FirstVisibleVRAMRow
        sub a, (hl)                                 ; a = 28 - first visible row idx
        MinB                                        ; a = MIN(28 - first visible row idx, visible row count)
        ld (RedrawColParams.RowCount1), a

        ; calculate how many rows to draw between the first row and the last visible row
        ld c, a                                     ; c = MIN(28 - first visible row idx, visible row count)
        ld a, b                                     ; a = visible row count
        sub c                                       ; a = visible col count - MIN(28 - first visible row idx, visible row count)
        ld (RedrawColParams.RowCount2), a

        ; calculate VRAM tilemap addresses (inc. write bits):
        ; addr of first tile in col, addr of first *visible* tile in col
        ld a, d                                     ; a = VDP col index
        add a, a                                    ; a = VDP col offset (from start of VRAM row)
        ld d, 0
        ld e, a                                     ; de = VDP col offset (from start of VRAM row)
        ld hl, (VRAMRowAddrs)                       ; hl = VDP write bits + VRAM base address
        add hl, de                                  ; hl = VDP write bits + VRAM base address + col offset
        ld (RedrawColParams.VDPAddr2), hl
        ld a, (FirstVisibleVRAMRow)                 ; a = row index
        add a, a                                    ; a = row offset
        ld h, 0
        ld l, a                                     ; hl = row offset
        ld bc, VRAMRowAddrs
        add hl, bc                                  ; hl = VRAMRowAddrs + row offset (from VRAMRowAddrs)
        ld c, (hl)
        inc hl
        ld b, (hl)                                  ; bc = VDP write bits + row offset (from start of VRAM tilemap)
        ex de, hl                                   ; hl = VDP col offset (from start of VRAM row)
        add hl, bc                                  ; hl = VDP write bits + row offset + col offset
        ld (RedrawColParams.VDPAddr1), hl

        ret

    ; Sets a column in the VRAM tilemap
    RedrawCol:
        ; write first col group
        ld c, VDP_CTRL_PORT
        ld de, 64
        exx
            ld hl, (RedrawColParams.BGAddr)
            ld c, VDP_DATA_PORT
            ld de, BG_COLS * 2 - 2
        exx

        ld a, (RedrawColParams.RowCount1)
        cp 0
        jr z, +

        ld b, a
        ld hl, (RedrawColParams.VDPAddr1)
        -:
            out (c), l
            out (c), h
            add hl, de
            exx
                ld b, 2
                otir
                add hl, de
            exx
            djnz -

        ; write the second col group
        +:
        ld a, (RedrawColParams.RowCount2)
        cp 0
        ret z

        ld b, a
        ld hl, (RedrawColParams.VDPAddr2)
        -:
            out (c), l
            out (c), h
            add hl, de
            exx
                ld b, 2
                otir
                add hl, de
            exx
            djnz -
        
        ret

    ; Sets values used during VBlank by the RedrawRow routine
    ; Clobbers: a, bc, de, hl
    PrepRedrawRow:
        ld a, (VScrollDir)
        cp VSCROLL_DIR_NONE                         ; checkk scroll direction

        ret z                                       ; bail out if we're not scrolling up or down

        ; calculate target VDP & BG row indices
        jr c, +                                     ; skip forward if VScrollDir < 1
            ; VScrollDir == VSCROLL_DIR_DOWN
            ld a, (LastVisibleVRAMRow)
            ld d, a
            ld a, (LastVisibleBGRow)
            ld e, a
        jr ++
        +:
            ; VScrollDir == VSCROLL_DIR_UP
            ld a, (FirstVisibleVRAMRow)
            ld d, a
            ld a, (FirstVisibleBGRow)
            ld e, a
        ++:

        ; calculate BG tilemap addr of first visible tile in the row
        ld h, 0
        ld l, e                                     ; hl = target BG row idx
        add hl, hl                                  ; hl = target BG row addr offset from BGRowAddrs
        ld bc, BGRowAddrs
        add hl, bc                                  ; hl = &BGRowAddrs + target BG row addr offset from BGRowAddrs
        ld c, (hl)
        inc hl
        ld b, (hl)                                  ; bc = addr of first tile of row in BG tilemap
        ld a, (FirstVisibleBGCol)                   ; a = first visible BG col idx
        ld h, 0
        ld l, a                                     ; hl = first visible BG col idx
        add hl, hl                                  ; hl = addr offset of first visible BG col idx from start of row
        add hl, bc                                  ; hl = addr of first visible tile in BG tilemap
        ld (RedrawRowParams.BGAddr), hl

        ; calculate how many bytes to send to the VDP 
        ; (when drawing from first visible tile in row to last tile in row)
        ld a, (VisibleColCount)
        ld b, a                                     ; b = visible col count
        ld a, 32                                    ; a = 32
        ld hl, FirstVisibleVRAMCol
        sub a, (hl)                                 ; a = 32 - first visible col idx
        MinB                                        ; a = MIN(32 - first visible col idx, visible col count)
        add a, a                                    ; a = MIN(32 - first visible col idx, visible col count) * 2
        ld (RedrawRowParams.ByteCount1), a

        ; calculate how many bytes to send to the VDP
        ; (when drawing from first tile in row to last visible tile in row)
        ld c, a                                     ; c = MIN(32 - first visible col idx, visible cols) * 2
        ld a, b                                     ; a = visible col count
        add a, a                                    ; a = visible col count * 2
        sub c                                       ; a = (visible col count - MIN(32 - first visible col idx, visible cols) * 2
        ld (RedrawRowParams.ByteCount2), a
        
        ; calculate VRAM tilemap addresses (inc. write bits):
        ; addr of first tile in row, addr of first *visible* tile in row
        ld a, d                                     ; a = target VRAM row idx
        add a, a                                    ; a = target VRAM row addr offset from VRAMRowAddrs
        ld b, 0
        ld c, a                                     ; bc = target VRAM row addr offset from VRAMRowAddrs
        ld hl, VRAMRowAddrs
        add hl, bc                                  ; hl = &VRAMRowAddrs + target VRAM row addr offset from VRAMRowAddrs
        ld c, (hl)
        inc hl
        ld b, (hl)                                  ; bc = VDP write bits + addr of first tile of row
        ld (RedrawRowParams.VDPAddr2), bc
        ld a, (FirstVisibleVRAMCol)                 ; a = first visible VRAM col idx
        add a, a                                    ; a = addr offset of first visible VRAM col
        ld h, 0
        ld l, a                                     ; hl = addr offset of first visible VRAM col
        add hl, bc                                  ; hl = VDP write bits + addr of first tile to draw
        ld (RedrawRowParams.VDPAddr1), hl
        
        ret

    ; Sets a row in the VRAM tilemap
    RedrawRow:        
        ld hl, (RedrawRowParams.BGAddr)

        ld de, (RedrawRowParams.VDPAddr1)
        ld c, VDP_CTRL_PORT
        out (c), e
        out (c), d

        ld a, (RedrawRowParams.ByteCount1)
        ld b, a
        ld c, VDP_DATA_PORT
        otir

        ld a, (RedrawRowParams.ByteCount2)
        cp 0
        ret z

        ld de, (RedrawRowParams.VDPAddr2)
        ld c, VDP_CTRL_PORT
        out (c), e
        out (c), d

        ld b, a
        ld c, VDP_DATA_PORT
        otir

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
