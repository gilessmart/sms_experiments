.section "vdplibs"

    ; VDP commands
    .define VDP_CMD_VRAM_READ (%00 << 14)
    .define VDP_CMD_VRAM_WRITE (%01 << 14)
    .define VDP_CMD_REGISTER_WRITE (%10 << 14)
    .define VDP_CMD_CRAM_WRITE (%11 << 14)

    ; VDP ports
    .define VDP_DATA_PORT $be
    .define VDP_CTRL_PORT $bf

    ; Set command & address for incoming data
    ; Params: hl = command & address
    ; Clobbers: a
    VDP_SetAddress:
        ld a, l
        out (VDP_CTRL_PORT), a
        ld a, h
        out (VDP_CTRL_PORT), a
        ret

    ; Copies data to the VDP
    ; This is slow but supports larger data blocks than OTIR
    ; Params: hl = data address, bc = data length
    ; Clobbers: a, hl, bc
    VDP_CopyData:
    -:	ld a, (hl)
        out (VDP_DATA_PORT), a
        inc hl
        dec bc
        ld a, b
        or c
        jr nz, -
        ret

.ends