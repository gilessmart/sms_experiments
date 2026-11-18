.define BG_DRAW_COL_TARGET_FIRST 0
.define BG_DRAW_COL_TARGET_LAST 1
.define BG_DRAW_ROW_TARGET_FIRST 0
.define BG_DRAW_ROW_TARGET_LAST 1

.define BG_ROWS 64          ; rows in background
.define BG_COLS 127         ; cols in background

.struct BG_Coord
    X: db
    Y: db
.endst

.struct BG_CoordW
    X: dw
    Y: dw
.endst

.struct BG_ScrollOffsetsSt
    BG: instanceof BG_CoordW
    VDP: instanceof BG_Coord
.endst

.struct BG_VisibleAreaSt
    RowCount: db
    ColCount: db
    FirstBGRow: db
    LastBGRow: db
    FirstBGCol: db
    LastBGCol: db
    FirstVRAMRow: db
    LastVRAMRow: db
    FirstVRAMCol: db
    LastVRAMCol: db
.endst

.struct BG_DrawRowsParamsSt
    VRAMInterval1: dw   ; no. of bytes from the first col to the first visible col in the VRAM tilemap
    VRAMInterval2: dw   ; no. of bytes from the first col to the first visible col on the next line in the VRAM tilemap
    BGInterval: dw      ; no. of bytes from first visible tile of the VRAM tilemap to the last tile of the VRAM tilemap
    ByteCount1: db      ; no. of bytes from first tile of the VRAM tilemap to the last visible tile of the VRAM tilemap
    ByteCount2: db      ; no. of bytes from the last visible tile on one line to the first visible tile of the next line in BG tilemap
.endst

.struct BG_DrawRowParamsSt
    BGAddr: dw          ; addr in the BG tilemap of the first visible tile 
    VDPAddr1: dw        ; addr in the VRAM tilemap of the *first visible* tile in the row
    ByteCount1: db      ; number of bytes to draw from VDPAddr1
    VDPAddr2: dw        ; addr in the VRAM tilemap of the *first* tile in the row
    ByteCount2: db      ; number of bytes to draw from VDPAddr2
.endst

.struct BG_DrawColParamsSt
    BGAddr: dw          ; addr in the BG tilemap of the first visible tile 
    VDPAddr1: dw        ; addr in the VRAM tilemap of the *first visible* tile in the col
    RowCount1: db       ; number of tiles to draw from VDPAddr1
    VDPAddr2: dw        ; addr in the VRAM tilemap of the *first* tile in the col
    RowCount2: db       ; number of tiles to draw from VDPAddr2
.endst

.ramsection "bg_state" slot "RAMSlot"
    BG_ScrollOffsets: instanceof BG_ScrollOffsetsSt
    BG_VisibleArea: instanceof BG_VisibleAreaSt
    BG_DrawRowsParams: instanceof BG_DrawRowsParamsSt
    BG_DrawRowTarget: db
    BG_DrawColTarget: db
    BG_DrawRowParams: instanceof BG_DrawRowParamsSt
    BG_DrawColParams: instanceof BG_DrawColParamsSt
.ends

; Sets the scroll offset RAM addresses
; Clobbers: a, hl
.macro BG_SetScrollOffsets ARGS x, y
    ld a, x # 256
    ld (BG_ScrollOffsets.VDP.X), a
    ld a, y # 224
    ld (BG_ScrollOffsets.VDP.Y), a
    ld bc, x
    ld (BG_ScrollOffsets.BG.X), bc
    ld bc, y
    ld (BG_ScrollOffsets.BG.Y), bc
.endm

; Pushes the scroll offsets to the VDP scroll registers
; Clobbers: a, hl
.macro BG_UpdateScrollRegisters
    ; invert scroll offset & copy to VDP
    ld a, (BG_ScrollOffsets.VDP.X)
    ld l, a                                     ; l = VDP.X
    ld a, 0
    sub l                                       ; a = 256 - VDP.X
    ld l, a                                     ; l = 256 - VDP.X
    VDP_SetRegister 8

    ; copy Y scroll value to VDP
    ld a, (BG_ScrollOffsets.VDP.Y)
    ld l, a
    VDP_SetRegister 9
.endm

; Calcualtes the VRAM tilemap addr of the first col of the given row index
; Parameters: a = row idx
; Clobbers: a, bc, hl
; Sets: bc = calculated tilemap addr
.macro BG_VRAMRowAddr
    add a, a
    ld h, 0
    ld l, a                                     ; hl = VRAM row offset from BG_VRAMRowAddrs
    ld bc, BG_VRAMRowAddrs
    add hl, bc                                  ; hl = BG_VRAMRowAddrs + VRAM row offset from BG_VRAMRowAddrs
    ld c, (hl)                                  
    inc hl
    ld b, (hl)                                  ; bc = VDP write bits + VDP tilemap row start addr
.endm

; Calcualtes the BG tilemap addr of the first col of the given row index
; Parameters: a = row idx
; Clobbers: bc, hl
; Sets: bc = calculated addr
.macro BG_BGRowAddr
    ld h, 0
    ld l, a
    add hl, hl                                  ; hl = BG row offset from BG_BGRowAddrs
    ld bc, BG_BGRowAddrs
    add hl, bc                                  ; hl = BG_BGRowAddrs + BG row offset from BG_BGRowAddrs
    ld c, (hl)                                  
    inc hl
    ld b, (hl)                                  ; bc = BG tilemap row start addr
.endm

; Sets the BG_DrawRowTarget RAM address
; Clobbers: a
.macro BG_SetDrawRowTarget ARGS row_idx
    ld a, row_idx
    ld (BG_DrawRowTarget), a
.endm

; Sets the BG_DrawColTarget RAM address
; Clobbers: a
.macro BG_SetDrawColTarget ARGS col_idx
    ld a, col_idx
    ld (BG_DrawColTarget), a
.endm

.section "bg_lib"
    ; Initialise BG_DrawRowParams & BG_DrawColParams, so BG_DrawRow and BG_DrawCol can run safely
    ; Clobbers: a, bc, de, hl
    BG_InitDrawRowColParams:
        BG_SetDrawRowTarget BG_DRAW_ROW_TARGET_FIRST
        BG_SetDrawColTarget BG_DRAW_COL_TARGET_FIRST
        call BG_CalcDrawRowParams
        call BG_CalcDrawColParams
        ret

    ; Decrements vertical scroll values by a given scroll increment
    ; Params: 
    ;   c = scroll increment (from 1 to 8)
    ; Clobbers: a, b, hl
    ScrollUp:
        BG_SetDrawRowTarget BG_DRAW_ROW_TARGET_FIRST

        ld hl, (BG_ScrollOffsets.BG.Y)           ; hl = BG.Y
        ld b, 0                                     ; bc = scroll increment
        or a                                        ; clear carry flag
        sbc hl, bc                                  ; hl = BG.Y - scroll increment
        jr nc, +
            ld hl, 0
            ld (BG_ScrollOffsets.BG.Y), hl       ; BG.Y = 0
            ld a, 0
            ld (BG_ScrollOffsets.VDP.Y), a       ; VDP.Y = 0
            ret
        +:
        ld (BG_ScrollOffsets.BG.Y), hl           ; BG.Y = BG.Y - scroll increment

        ld a, (BG_ScrollOffsets.VDP.Y)
        sub a, c                                    ; a = VDP.Y - scroll increment
        jr nc, +                                    ; skip if no carry i.e. if a < 0
            add a, 224
        +:                                          ; a = (VDP.Y - scroll increment) % 224
        ld (BG_ScrollOffsets.VDP.Y), a           ; VDP.Y = (VDP.Y - scroll increment) % 224

        ret

    ; Increments vertical scroll values by a given scroll increment
    ; Params:
    ;   c = scroll increment (from 1 to 8)
    ; Clobbers: a, b, de, hl
    ScrollDown:
        BG_SetDrawRowTarget BG_DRAW_ROW_TARGET_LAST

        ld hl, (BG_ROWS - 24) * 8                   ; hl = max scroll position
        ld de, (BG_ScrollOffsets.BG.Y)           ; de = BG.Y
        or a                                        ; clear carry flag
        sbc hl, de                                  ; hl = max scroll increment

        ld b, 0                                     ; bc = requested scroll increment
        MinBC                                       ; hl = scroll increment
        ex de, hl                                   ; hl = BG.Y, de = scroll increment

        add hl, de                                  ; hl = BG.Y + scroll increment
        ld (BG_ScrollOffsets.BG.Y), hl           ; BG.Y = BG.Y + scroll increment

        ld a, (BG_ScrollOffsets.VDP.Y)           ; a = VDP.Y
        add a, e                                    ; a = VDP.Y + scroll increment
        cp 224
        jr c, +
            sub a, 224
        +:                                          ; a = (VDP.Y + scroll increment) % 224
        ld (BG_ScrollOffsets.VDP.Y), a           ; VDP.Y = (VDP.Y + scroll increment) % 224

        ret

    ; Decrements horizontal scroll values by a given scroll increment
    ; Params: 
    ;   c = scroll increment (from 1 to 8)
    ; Clobbers: a, b, hl
    ScrollLeft:
        BG_SetDrawColTarget BG_DRAW_COL_TARGET_FIRST

        ld hl, (BG_ScrollOffsets.BG.X)           ; hl = BG.X
        ld b, 0                                     ; bc = scroll increment
        or a                                        ; clear carry flag
        sbc hl, bc                                  ; hl = BG.X - scroll increment
        jr nc, +
            ld hl, 0
            ld (BG_ScrollOffsets.BG.X), hl       ; BG.X = 0
            ld a, 0
            ld (BG_ScrollOffsets.VDP.X), a       ; VDP.X = 0
            ret
        +:
        ld (BG_ScrollOffsets.BG.X), hl           ; BG.X = BG.X - scroll increment

        ld a, (BG_ScrollOffsets.VDP.X)
        sub a, c                                    ; a = VDP.X - scroll increment
        ld (BG_ScrollOffsets.VDP.X), a           ; VDP.X = VDP.X - scroll increment

        ret
    
    ; Increments horizontal scroll values by a given scroll increment
    ; Params:
    ;   c = scroll increment (from 1 to 8)
    ; Clobbers: a, b, de, hl
    ScrollRight:
        BG_SetDrawColTarget BG_DRAW_COL_TARGET_LAST

        ld hl, (BG_COLS - 32) * 8                   ; hl = max scroll position
        ld de, (BG_ScrollOffsets.BG.X)           ; de = BG.X
        or a                                        ; clear carry flag
        sbc hl, de                                  ; hl = max scroll increment

        ld b, 0                                     ; bc = requested scroll increment
        MinBC                                       ; hl = scroll increment
        ex de, hl                                   ; hl = BG.X, de = scroll increment

        add hl, de                                  ; hl = BG.X + scroll increment
        ld (BG_ScrollOffsets.BG.X), hl           ; BG.X = BG.X + scroll increment

        ld a, (BG_ScrollOffsets.VDP.X)           ; a = VDP.X
        add a, e                                    ; a = VDP.X + scroll increment
        ld (BG_ScrollOffsets.VDP.X), a           ; VDP.X = VDP.X + scroll increment

        ret
    
    ; Populates the BG_VisibleArea RAM addresses
    ; Clobbers: a, bc, de, hl
    BG_CalcVisibleArea:
        ;; Rows ;;

        ; calculate RowCount
        ld a, (BG_ScrollOffsets.VDP.Y)
        ld b, a                                     ; store VDP scroll value for calculating FirstVRAMRow
        and 7                                       ; a = fine scroll value
        jr z, +                                     ; skip forward if a = 0
            ld a, 25
        jr ++
        +:
            ld a, 24
        ++:
        ld (BG_VisibleArea.RowCount), a

        ; store difference between last and first row for calculating last rows
        dec a                                       
        ld c, a

        ; calculate FirstVRAMRow
        ld a, b
        ShiftRightA 3
        ld (BG_VisibleArea.FirstVRAMRow), a

        ; calculate LastVRAMRow
        add a, c                                    ; a = FirstVRAMRow + difference
        cp 28                                       ; apply modulo 28..
        jr c, +                                     ; jump forward if a < 28
            sub a, 28                               ; otherwise, subtract 28    
        +:
        ld (BG_VisibleArea.LastVRAMRow), a

        ; calculate FirstBGRow
        ld hl, (BG_ScrollOffsets.BG.Y)
        ShiftRightHL 3
        ld a, l
        ld (BG_VisibleArea.FirstBGRow), a

        ; calculate LastBGRow
        add a, c                                    ; a = FirstBGRow + difference
        ld (BG_VisibleArea.LastBGRow), a

        ;; Cols ;;

        ; calculate ColCount
        ld a, (BG_ScrollOffsets.VDP.X)
        ld b, a                                     ; store VDP scroll value for calculating FirstVRAMCol
        and 7                                       ; a = fine scroll value
        jr z, +                                     ; skip forward if a = 0
            ld a, 32
        jr ++
        +:
            ld a, 31
        ++:
        ld (BG_VisibleArea.ColCount), a

        ; store difference between last and first row for calculating last cols
        dec a                                       
        ld c, a

        ; calculate FirstVRAMCol
        ld a, b                                     ; a = VDP.X
        add a, 8
        ShiftRightA 3
        ld (BG_VisibleArea.FirstVRAMCol), a

        ; calculate LastVRAMCol
        add a, c                                    ; a = FirstVRAMCol + difference
        and 31                                      ; apply modulo 32
        ld (BG_VisibleArea.LastVRAMCol), a

        ; calculate FirstBGCol
        ld hl, (BG_ScrollOffsets.BG.X)
        ld de, 8
        add hl, de
        ShiftRightHL 3
        ld a, l
        ld (BG_VisibleArea.FirstBGCol), a

        ; calculate LastBGCol
        add a, c                                    ; a = FirstBGCol + difference
        ld (BG_VisibleArea.LastBGCol), a

        ret
    
    ; Populates the full VRAM tilemap based on current background & VRAM tilemap position
    ; Clobbers: a, bc, de, hl, bc', hl'
    BG_DrawFullBG:
        call BG_CalcVisibleArea
        call BG_CalcDrawRowsParams

        ; calculte start addr in VRAM tilemap
        ld a, (BG_VisibleArea.FirstVRAMRow)
        BG_VRAMRowAddr
        ld hl, (BG_DrawRowsParams.VRAMInterval1)
        add hl, bc
        
        ; calculte start addr in BG tilemap
        exx
            ld a, (BG_VisibleArea.FirstBGRow)
            BG_BGRowAddr
            ld a, (BG_VisibleArea.FirstBGCol)
            ld h, 0
            ld l, a
            add hl, hl                              ; hl = BG col offset from row start
            add hl, bc                              ; hl = BG tilemap row start addr + BG col offset from row start
        exx

        ; calculate how many rows to draw from first vis. VRAM tilemap row to last tilemap row
        ; MIN(vis. row count, 28 - first vis. VRAM row idx)
        ld a, (BG_VisibleArea.FirstVRAMRow)
        ld b, a
        ld a, 28
        sub a, b
        ld b, a
        ld a, (BG_VisibleArea.RowCount)
        MinB

        ; draw first set of rows
        ld b, a
        call BG_DrawRows
        
        ; calculate how many rows to draw from the first VRAM row to the last vis. VRAM row
        ; first vis. VRAM row idx + vis. row count - 28
        ld a, (BG_VisibleArea.RowCount)
        ld b, a                                     ; b = vis. row count
        ld a, (BG_VisibleArea.FirstVRAMRow)
        add a, b                                    ; a = first vis. VRAM row idx + vis. row count
        sub a, 28                                   ; a = first vis. VRAM row idx + vis. row count - 28
        
        ; skip if there are no rows to draw
        ret c
        ret z

        ; move VDP address to first vis. col of first row
        ld de, (BG_VRAMRowAddrs)
        ld hl, (BG_DrawRowsParams.VRAMInterval1)
        add hl, de

        ; draw second set of rows
        ld b, a
        call BG_DrawRows
        
        ret

    ; Sets the BG_DrawRowsParams RAM addresses used by the BG_DrawRows routine
    ; Clobbers: a, b, de, hl
    BG_CalcDrawRowsParams:
        ; store interval from first col to first vis. col (bytes)
        ld a, (BG_VisibleArea.FirstVRAMCol)
        add a, a
        ld h, 0
        ld l, a
        ld (BG_DrawRowsParams.VRAMInterval1), hl

        ; store interval from first col to first vis. col on next row (bytes)
        ld de, 64
        add hl, de
        ld (BG_DrawRowsParams.VRAMInterval2), hl

        ; store BG tilemap interval (bytes) from the end of one line to the start of the next
        ; (BG_COLS - VisColCount) * 2
        ld a, (BG_VisibleArea.ColCount)
        ld b, a
        ld a, BG_COLS
        sub a, b
        ld h, 0
        ld l, a
        add hl, hl
        ld (BG_DrawRowsParams.BGInterval), hl

        ; calculate how many bytes to output when drawing from first vis.
        ; MIN(vis. col count, 32 - first vis. VRAM col idx)
        ld a, (BG_VisibleArea.FirstVRAMCol)
        ld b, a
        ld a, 32
        sub a, b
        ld b, a
        ld a, (BG_VisibleArea.ColCount)
        MinB
        add a, a
        ld (BG_DrawRowsParams.ByteCount1), a

        ; calculate how many bytes to draw from first
        ; vis col count * 2 - bytes from first vis.
        ld b, a
        ld a, (BG_VisibleArea.ColCount)
        add a, a
        sub a, b
        ld (BG_DrawRowsParams.ByteCount2), a

        ret

    ; Draw a set of background rows
    ; Params: 
    ;   b = row count
    ;   hl = addr of first visible tile in the VDP tilemap
    ;   hl' = addr of first visible tile in the BG tilemap
    ;   BG_DrawRowsParams
    ; Clobbers: a, bc, de, hl, bc', de', hl'
    ; Sets: hl' = addr of tile following those that have been drawn
    BG_DrawRows:
        ld c, VDP_CTRL_PORT

        exx
            ld de, (BG_DrawRowsParams.BGInterval)
            ld c, VDP_DATA_PORT
        exx

        -:
            out (c), l
            out (c), h
            
            ; draw from first vis. col
            exx
                ld a, (BG_DrawRowsParams.ByteCount1)
                ld b, a
                otir
            exx

            ; move VRAMAddr back to start of row
            ld de, (BG_DrawRowsParams.VRAMInterval1)
            or a
            sbc hl, de                              ; hl =- first vis col offset

            out (c), l
            out (c), h

            ; draw from first col
            exx
                ld a, (BG_DrawRowsParams.ByteCount2)
                cp a, 0
                jr z, +
                    ld b, a
                    otir
                +:
                
                ; move BGAddr to next line
                add hl, de
            exx

            ; move VRAMAddr to first vis. col on next line
            ld de, (BG_DrawRowsParams.VRAMInterval2)
            add hl, de
        djnz -

        ret

    ; Sets the data that allows the BG_UpdateBG routine to update the background efficiently
    ; Clobbers: a, bc, de, hl
    BG_PrepUpdateBG:
        call BG_CalcVisibleArea
        call BG_CalcDrawRowParams
        call BG_CalcDrawColParams
        ret
    
    ; Sets values used during VBlank by the BG_DrawRow routine
    ; Clobbers: a, bc, de, hl
    BG_CalcDrawRowParams:
        ; calculate target VDP & BG row indices
        ld a, (BG_DrawRowTarget)
        cp BG_DRAW_ROW_TARGET_LAST
        jr z, +
            ; draw first row
            ld a, (BG_VisibleArea.FirstVRAMRow)
            ld d, a
            ld a, (BG_VisibleArea.FirstBGRow)
            ld e, a
        jr ++
        +:
            ; draw last row
            ld a, (BG_VisibleArea.LastVRAMRow)
            ld d, a
            ld a, (BG_VisibleArea.LastBGRow)
            ld e, a
        ++:

        ; calculate BG tilemap addr of first visible tile in the row
        ld a, e
        BG_BGRowAddr
        ld a, (BG_VisibleArea.FirstBGCol)           ; a = first visible BG col idx
        ld h, 0
        ld l, a                                     ; hl = first visible BG col idx
        add hl, hl                                  ; hl = addr offset of first visible BG col idx from start of row
        add hl, bc                                  ; hl = addr of first visible tile in BG tilemap
        ld (BG_DrawRowParams.BGAddr), hl

        ; calculate how many bytes to send to the VDP 
        ; (when drawing from first visible tile in row to last tile in row)
        ld a, (BG_VisibleArea.ColCount)
        ld b, a                                     ; b = visible col count
        ld a, 32                                    ; a = 32
        ld hl, BG_VisibleArea.FirstVRAMCol
        sub a, (hl)                                 ; a = 32 - first visible col idx
        MinB                                        ; a = MIN(32 - first visible col idx, visible col count)
        add a, a                                    ; a = MIN(32 - first visible col idx, visible col count) * 2
        ld (BG_DrawRowParams.ByteCount1), a

        ; calculate how many bytes to send to the VDP
        ; (when drawing from first tile in row to last visible tile in row)
        ld c, a                                     ; c = MIN(32 - first visible col idx, visible cols) * 2
        ld a, b                                     ; a = visible col count
        add a, a                                    ; a = visible col count * 2
        sub c                                       ; a = (visible col count - MIN(32 - first visible col idx, visible cols) * 2
        ld (BG_DrawRowParams.ByteCount2), a
        
        ; calculate VRAM tilemap addresses (inc. write bits):
        ; addr of first tile in row, addr of first *visible* tile in row
        ld a, d                                     ; a = target VRAM row idx
        BG_VRAMRowAddr                              ; bc = VDP write bits + start of row addr
        ld (BG_DrawRowParams.VDPAddr2), bc
        ld a, (BG_VisibleArea.FirstVRAMCol)         ; a = first visible VRAM col idx
        add a, a                                    ; a = addr offset of first visible VRAM col
        ld h, 0
        ld l, a                                     ; hl = addr offset of first visible VRAM col
        add hl, bc                                  ; hl = VDP write bits + addr of first tile to draw
        ld (BG_DrawRowParams.VDPAddr1), hl
        
        ret

    ; Sets the values used during VBlank by the BG_DrawCol routine
    ; Clobbers: a, bc, de, hl
    BG_CalcDrawColParams:
        ; calculate target VDP & BG col indices
        ld a, (BG_DrawColTarget)
        cp BG_DRAW_COL_TARGET_LAST
        jr z, +
            ; draw first col
            ld a, (BG_VisibleArea.FirstVRAMCol)
            ld d, a                                 ; d = target VRAM col index
            ld a, (BG_VisibleArea.FirstBGCol)
            ld e, a                                 ; e = target BG col index
        jr ++
        +:
            ; draw last col
            ld a, (BG_VisibleArea.LastVRAMCol)
            ld d, a                                 ; d = target VRAM col index
            ld a, (BG_VisibleArea.LastBGCol)
            ld e, a                                 ; e = target BG col index
        ++:

        ; calculate BG tilemap addr of first visible tile in the column
        ld a, (BG_VisibleArea.FirstBGRow)           ; a = row index
        BG_BGRowAddr
        ld h, 0
        ld l, e                                     ; hl = col index
        add hl, hl                                  ; hl = col offset
        add hl, bc                                  ; hl = Tilemap + row offset + col offset
        ld (BG_DrawColParams.BGAddr), hl

        ; calculate how many rows to draw between the first visible row and last row
        ld a, (BG_VisibleArea.RowCount)
        ld b, a                                     ; b = visible row count
        ld a, 28                                    ; a = 28
        ld hl, BG_VisibleArea.FirstVRAMRow
        sub a, (hl)                                 ; a = 28 - first visible row idx
        MinB                                        ; a = MIN(28 - first visible row idx, visible row count)
        ld (BG_DrawColParams.RowCount1), a

        ; calculate how many rows to draw between the first row and the last visible row
        ld c, a                                     ; c = MIN(28 - first visible row idx, visible row count)
        ld a, b                                     ; a = visible row count
        sub c                                       ; a = visible col count - MIN(28 - first visible row idx, visible row count)
        ld (BG_DrawColParams.RowCount2), a

        ; calculate VRAM tilemap addresses (inc. write bits):
        ; addr of first tile in col, addr of first *visible* tile in col
        ld a, d                                     ; a = VDP col index
        add a, a                                    ; a = VDP col offset (from start of row)
        ld d, 0
        ld e, a                                     ; de = VDP col offset (from start of row)
        ld hl, (BG_VRAMRowAddrs)                    ; hl = VDP write bits + VRAM base address
        add hl, de                                  ; hl = VDP write bits + VRAM base address + col offset
        ld (BG_DrawColParams.VDPAddr2), hl
        ld a, (BG_VisibleArea.FirstVRAMRow)         ; a = row index
        BG_VRAMRowAddr                              ; bc = VDP write bits + start of row addr
        ex de, hl                                   ; hl = VDP col offset (from start of row)
        add hl, bc                                  ; hl = VDP write bits + start of row addr + col offset
        ld (BG_DrawColParams.VDPAddr1), hl

        ; prevent overdraw - don't draw the corner tile because BG_DrawRow also draws it
        ld a, (BG_DrawRowTarget)
        cp BG_DRAW_ROW_TARGET_LAST
        jr z, +
            ; drawing first row
            ld hl, BG_DrawColParams.RowCount1
            dec (hl)

            ld hl, (BG_DrawColParams.BGAddr)
            ld bc, BG_COLS*2
            add hl, bc
            ld (BG_DrawColParams.BGAddr), hl

            ld hl, (BG_DrawColParams.VDPAddr1)
            ld bc, 32*2
            add hl, bc
            ld (BG_DrawColParams.VDPAddr1), hl
        jr ++
        +:
            ; drawing last row..
            ld a, (BG_DrawColParams.RowCount2)
            cp 0
            jr z, +
                ; ..and RowCount2 > 0..
                ld hl, BG_DrawColParams.RowCount2
                dec (hl)
            jr ++
            +:
                ; ..and RowCount2 = 0..
                ld hl, BG_DrawColParams.RowCount1
                dec (hl)
        ++:

        ret

    ; Sets VDP scroll registers & updates the VDP tilemap
    ; Clobbers: a, bc, de, hl, bc', de', hl'
    BG_UpdateBG:
        BG_UpdateScrollRegisters
        call BG_DrawRow
        call BG_DrawCol
        ret

    ; Sets a row in the VRAM tilemap
    ; Clobbers: a, bc, de, hl,
    BG_DrawRow:        
        ld hl, (BG_DrawRowParams.BGAddr)

        ld de, (BG_DrawRowParams.VDPAddr1)
        ld c, VDP_CTRL_PORT
        out (c), e
        out (c), d

        ld a, (BG_DrawRowParams.ByteCount1)
        ld b, a
        ld c, VDP_DATA_PORT
        otir

        ld a, (BG_DrawRowParams.ByteCount2)
        cp 0
        ret z

        ld de, (BG_DrawRowParams.VDPAddr2)
        ld c, VDP_CTRL_PORT
        out (c), e
        out (c), d

        ld b, a
        ld c, VDP_DATA_PORT
        otir

        ret

    ; Sets a column in the VRAM tilemap
    ; Clobbers: a, bc, de, hl, bc', de', hl'
    BG_DrawCol:
        ; write first col group
        ld c, VDP_CTRL_PORT
        ld de, 64
        exx
            ld hl, (BG_DrawColParams.BGAddr)
            ld c, VDP_DATA_PORT
            ld de, BG_COLS * 2 - 2
        exx

        ld a, (BG_DrawColParams.RowCount1)
        cp 0
        jr z, +

        ld b, a
        ld hl, (BG_DrawColParams.VDPAddr1)
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
        ld a, (BG_DrawColParams.RowCount2)
        cp 0
        ret z

        ld b, a
        ld hl, (BG_DrawColParams.VDPAddr2)
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

    ; Addresses of each row of VRAM
    BG_VRAMRowAddrs:
        .repeat 28 index i
            .dw (VDP_CMD_VRAM_WRITE << 8 | $3800) + i*32*2  ; VDP write bits + row offset
        .endr

    ; Addresses of each row of the background
    BG_BGRowAddrs:
        .repeat BG_ROWS index i
            .dw Tilemap + i*BG_COLS*2                       ; Tilemap address + row offset
        .endr
.ends
