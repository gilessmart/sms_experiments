.define REDRAW_COL_TARGET_FIRST 0
.define REDRAW_COL_TARGET_LAST 1
.define REDRAW_ROW_TARGET_FIRST 0
.define REDRAW_ROW_TARGET_LAST 1

.define SCROLL_INCREMENT 5  ; max = 8
.define BG_ROWS 64          ; rows in background
.define BG_COLS 127         ; cols in background
.define INIT_BG_POSX 0
.define INIT_BG_POSY 0

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

.struct RedrawRowsStruct
    VRAMInterval1: dw
    VRAMInterval2: dw
    BGInterval: dw
    ByteCount1: db
    ByteCount2: db
.endst

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
    RedrawColTarget: db
    RedrawRowTarget: db
    RedrawRowParams: instanceof RedrawRowParamsStruct
    RedrawColParams: instanceof RedrawColParamsStruct
    RedrawRows: instanceof RedrawRowsStruct
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

    call UpdateBGScroll
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
    ; Calcualtes the BG tilemap addr of the given index
    ; Parameters: a = row idx, b = col idx
    ; Clobbers: a, de, hl
    ; Sets: hl = calculated addr
    BGAddr:
        ld h, 0
        ld l, a
        add hl, hl                                  ; hl = BG row offset from BGAddrs
        ld de, BGRowAddrs
        add hl, de                                  ; hl = BGAddrs + BG row offset from BGAddrs
        ld e, (hl)                                  
        inc hl
        ld d, (hl)                                  ; de = BG tilemap row start addr
        ld h, 0
        ld l, b
        add hl, hl                                  ; hl = BG col offset from row start
        add hl, de                                  ; hl = BG tilemap row start addr + BG col offset from row start
        ret

    ; Calcualtes the VRAM tilemap addr of the given index
    ; Parameters: a = row idx, b = col idx
    ; Clobbers: a, de, hl
    ; Sets: hl = calculated addr
    VRAMAddr:
        add a, a
        ld h, 0
        ld l, a                                     ; hl = VRAM row offset from VRAMRowAddrs
        ld de, VRAMRowAddrs
        add hl, de                                  ; hl = VRAMRowAddrs + VRAM row offset from VRAMRowAddrs
        ld e, (hl)                                  
        inc hl
        ld d, (hl)                                  ; de = VDP write bits + VDP tilemap row start addr
        ld a, b
        add a, a
        ld h, 0
        ld l, a                                     ; hl = VRAM col offset from row start
        add hl, de                                  ; hl = VDP write bits + VDP tilemap row start addr + col offset from row start
        ret

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

        ; initialise scroll offsets
        ld a, INIT_BG_POSX # 256
        ld (VDPScrollX), a
        ld a, INIT_BG_POSY # 224
        ld (VDPScrollY), a
        ld bc, INIT_BG_POSX
        ld (BGScrollX), bc
        ld bc, INIT_BG_POSY
        ld (BGScrollY), bc

        call CalculateVisibleArea
        call UpdateBGScroll

        ; populate tilemap

        ; draw from FirstVisibleVRAMRow, FirstVisibleVRAMCol to LastRowInTilemap, LastColInTilemap

        ; store interval from first col to first vis. col (bytes)
        ld a, (FirstVisibleVRAMCol)
        ld h, 0
        ld l, a
        add hl, hl
        ld (RedrawRows.VRAMInterval1), hl

        ; store interval from first col to first vis. col on next row (bytes)
        ld de, 64
        add hl, de
        ld (RedrawRows.VRAMInterval2), hl

        ; store BG tilemap interval (bytes) from the end of one line to the start of the next
        ; (BG_COLS - VisColCount) * 2
        ld a, (VisibleColCount)
        ld b, a
        ld a, BG_COLS
        sub a, b
        ld h, 0
        ld l, a
        add hl, hl
        ld (RedrawRows.BGInterval), hl

        ; calculate how many bytes to output when drawing from first vis.
        ; MIN(vis. col count, 32 - first vis. VRAM col idx)
        ld a, (FirstVisibleVRAMCol)
        ld b, a
        ld a, 32
        sub a, b
        ld b, a
        ld a, (VisibleColCount)
        MinB
        add a, a
        ld (RedrawRows.ByteCount1), a
        ; calculate how many bytes to draw from first
        ; vis col count * 2 - bytes from first vis.
        ld b, a
        ld a, (VisibleColCount)
        add a, a
        sub a, b
        ld (RedrawRows.ByteCount2), a
        
        ; calculte start addr in VRAM tilemap
        ld a, (FirstVisibleVRAMRow)
        ld hl, FirstVisibleVRAMCol
        ld b, (hl)
        call VRAMAddr

        ; calculate how many rows to draw in from first vis.
        ; MIN(vis. row count, 28 - first vis. VRAM row idx)
        ld a, (FirstVisibleVRAMRow)
        ld b, a
        ld a, 28
        sub a, b
        ld b, a
        ld a, (VisibleRowCount)
        MinB
        ld b, a

        ; set port
        ld c, VDP_CTRL_PORT
        
        exx
            ; calculte start addr in BG tilemap
            ld a, (FirstVisibleBGRow)
            ld hl, FirstVisibleBGCol
            ld b, (hl)
            call BGAddr

            ; set BG interval
            ld de, (RedrawRows.BGInterval)
            
            ; set port
            ld c, VDP_DATA_PORT
        exx
        
        -:
            out (c), l
            out (c), h
            
            ; draw from first vis. col
            exx
                ld a, (RedrawRows.ByteCount1)
                ld b, a
                otir
            exx

            ; move VRAMAddr back to start of row
            ld de, (RedrawRows.VRAMInterval1)
            or a
            sbc hl, de                              ; hl =- first vis col offset

            out (c), l
            out (c), h

            ; draw from first col
            exx
                ld a, (RedrawRows.ByteCount2)
                cp a, 0
                jr z, +
                    ld b, a
                    otir
                +:
                
                ; move BGAddr to next line
                add hl, de
            exx

            ; move VRAMAddr to first vis. col on next line
            ld de, (RedrawRows.VRAMInterval2)
            add hl, de
        djnz -

        ; turn on display
        VDP_SetRegister 1, %11100000 ; 16K VRAM, enable display, frame interrupts

        ; prepare for redraw
        ld a, REDRAW_ROW_TARGET_FIRST
        ld (RedrawRowTarget), a
        ld a, REDRAW_COL_TARGET_FIRST
        ld (RedrawColTarget), a
        call PrepRedrawRow
        call PrepRedrawCol

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
        ld hl, RedrawRowTarget
        ld (hl), REDRAW_ROW_TARGET_FIRST
        bit CTLR_PORT_AB_A_UP, a
        jr nz, +
            ex af, af'
                call ScrollUp
            ex af, af'
        jr ++
        +:
        bit CTLR_PORT_AB_A_DOWN, a
        jr nz, ++
            ex af, af'
                call ScrollDown
                ld hl, RedrawRowTarget
                ld (hl), REDRAW_ROW_TARGET_LAST
            ex af, af'
        ++:

        ; scroll left / right
        ld hl, RedrawColTarget
        ld (hl), REDRAW_COL_TARGET_FIRST
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
                ld hl, RedrawColTarget
                ld (hl), REDRAW_COL_TARGET_LAST
            ex af, af'
        ++:

        call CalculateVisibleArea
        call PrepRedrawRow
        call PrepRedrawCol

        jr MainLoop

    ; Calculates and stores the first & last visible row & col indices, and the number of visible rows & cols
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
        ; calculate target VDP & BG col indices
        ld a, (RedrawColTarget)
        cp REDRAW_COL_TARGET_LAST
        jr z, +
            ; redraw first col
            ld a, (FirstVisibleVRAMCol)
            ld d, a                                 ; d = target VRAM col index
            ld a, (FirstVisibleBGCol)
            ld e, a                                 ; e = target BG col index
        jr ++
        +:
            ; redraw last col
            ld a, (LastVisibleVRAMCol)
            ld d, a                                 ; d = target VRAM col index
            ld a, (LastVisibleBGCol)
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

        ; prevent overdraw - don't draw the corner tile because RedrawRow also draws it
        ld a, (RedrawRowTarget)
        cp REDRAW_ROW_TARGET_LAST
        jr z, +
            ; redrawing first row
            ld hl, RedrawColParams.RowCount1
            dec (hl)

            ld hl, (RedrawColParams.BGAddr)
            ld bc, BG_COLS*2
            add hl, bc
            ld (RedrawColParams.BGAddr), hl

            ld hl, (RedrawColParams.VDPAddr1)
            ld bc, 32*2
            add hl, bc
            ld (RedrawColParams.VDPAddr1), hl
        jr ++
        +:
            ; redrawing last row..
            ld a, (RedrawColParams.RowCount2)
            cp 0
            jr z, +
                ; ..and RowCount2 > 0..
                ld hl, RedrawColParams.RowCount2
                dec (hl)
            jr ++
            +:
                ; ..and RowCount2 = 0..
                ld hl, RedrawColParams.RowCount1
                dec (hl)
        ++:
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
        ; calculate target VDP & BG row indices
        ld a, (RedrawRowTarget)
        cp REDRAW_ROW_TARGET_LAST
        jr z, +
            ; redraw first row
            ld a, (FirstVisibleVRAMRow)
            ld d, a
            ld a, (FirstVisibleBGRow)
            ld e, a
        jr ++
        +:
            ; redraw last row
            ld a, (LastVisibleVRAMRow)
            ld d, a
            ld a, (LastVisibleBGRow)
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

    UpdateBGScroll:
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
