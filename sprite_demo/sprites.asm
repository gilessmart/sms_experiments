.MACRO SPRITE_SETSPRITE ARGS SAT_IDX, PATTERN_IDX, X_POS, Y_POS
    ld   a, PATTERN_IDX
    ld   bc, SAT_IDX
    ld   de, (X_POS << 8) | Y_POS
    call SPRITE_SetSprite
.ENDM

; Writes a sprite to the shadow SAT
; Params: 
;   a = sprite pattern index
;   b = must be 0
;   c = SAT index
;   d = x coordinate
;   e = y coordinate
; Clobbers: hl, c
SPRITE_SetSprite:
    ld hl, ShadowSAT        ; base address
    add hl, bc              ; add SAT index
    ld (hl), e              ; store the y coordinate
    
    ld hl, ShadowSAT + $80  ; adr of 2nd part of shadow SAT
    sla c                   ; double the SAT index
    add hl, bc              ; add the doubled SAT index
    ld (hl), d              ; store the x coordinate

    inc hl
    ld (hl), a

    ret
