.macro ShiftRightA
    .repeat \1
        srl a
    .endr
.endm

.macro ShiftRightHL
    .repeat \1
        srl h
        rr l
    .endr
.endm

.macro ShiftLeftA
    .repeat \1
        add a, a
    .endr
.endm

.macro ShiftLeftHL
    .repeat \1
        add hl, hl
    .endr
.endm

; Sets a to the lower of a and b
.macro MinB
    cp b            ; sets c if a < b
    jr c, +         ; skip if c set i.e. if a < b
        ld a, b
    +:
.endm
