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
; Sets: a = lower of a and b
.macro MinB
    cp b            ; sets c if a < b
    jr c, +         ; skip if c set i.e. if a < b
        ld a, b     ; otherwise, set a = b
    +:
.endm

; Sets hl to the lower of hl and bc
; Sets: hl = lower of hl and bc
.macro MinBC
    or a            ; clear c flag
    sbc hl, bc
    jr nc, +
        ; bc was greater; revert hl to previous value
        add hl, bc 
    jr ++
    +:
        ; bc was smaller or equal; set hl to bc
        ld h, b
        ld l, c
    ++:
.endm
