.macro RotateRightA
    .repeat \1
        srl a
    .endr
.endm

.macro RotateRightHL
    .repeat \1
        srl h
        rr l
    .endr
.endm

.macro RotateLeftA
    .repeat \1
        sla a
    .endr
.endm

.macro RotateLeftHL
    .repeat \1
        sla l
        rl h
    .endr
.endm
