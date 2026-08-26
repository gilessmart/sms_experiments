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

    ; Copies a contiguous chunk of data from main memory to VRAM
    ; Use VDP_SetAddress to set the destination address in VRAM
    ; Params: hl = source address, de = data length
    ; Clobbers: a, b, c, hl
    VDP_CopyData:
        ld c, VDP_DATA_PORT
        
        ld b, 0
        ld a, d ; data length MSB counter
    -:  sub 1
        jr c, + ; if MSB counter carried, jump ahead
                ; otherwise use otir to copy 256 bytes, and repeat
        otir
        jr -

        ; copy remaining bytes and return
    +:  ld b, e
        otir
        ret
.ends
