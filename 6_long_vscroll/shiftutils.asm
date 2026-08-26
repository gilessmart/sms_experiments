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
        sla a
    .endr
.endm

.macro ShiftLeftHL
    .repeat \1
        sla l
        rl h
    .endr
.endm
