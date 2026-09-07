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
