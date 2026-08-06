.section "vdp_lib"
    ; VDP commands
    .define VDP_CMD_VRAM_READ (%00 << 6)
    .define VDP_CMD_VRAM_WRITE (%01 << 6)
    .define VDP_CMD_REGISTER_WRITE (%10 << 6)
    .define VDP_CMD_CRAM_WRITE (%11 << 6)

    ; VDP ports
    .define VDP_DATA_PORT $be
    .define VDP_CTRL_PORT $bf

    ; Sets a VDP register
    ; Params:
    ;   num = register number
    ;   val = register value
    ;     optional - value from CPU register l is used if macro arg not supplied
    ; Clobbers: a, hl
    .macro VDP_SetRegister ARGS num, val
        .if NARGS == 1
            ld h, VDP_CMD_REGISTER_WRITE | num
            call VDP_SetAddress
        .elif NARGS == 2
            ld hl, (VDP_CMD_REGISTER_WRITE | num) << 8 | val
            call VDP_SetAddress
        .endif
    .endm

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
