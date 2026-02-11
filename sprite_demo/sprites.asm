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
    ld (hl), a              ; store the pattern index

    ret

; Writes a set of (up to 256) sprites to shadow SAT
; Params: 
;   hl = start of sprite data
;   a = number of sprites to write
;   b = must be 0
;   c = SAT index counter
;   d = x position
;   e = y position
; Clobbers: hl, a, e
; Returns:
;   c = is incremented by the number of sprites written
SPRITE_SetSprites:
    ex af, af'

    ld a, (hl)                  ; a = relative y coordinate
    add a, e                    ; add base y coordinate
    push hl
        ld hl, ShadowSAT
        add hl, bc              ; add SAT index
        ld (hl), a              ; store the y coordinate
    pop hl
    
    inc hl                      ; hl now points at x value
    ld a, (hl)                  ; a = relative x coordinate
    add a, d                    ; add base y coordinate
    push hl
        ld hl, ShadowSAT + $80
        add hl, bc              ; add SAT index
        add hl, bc              ; add SAT index again
        ld (hl), a              ; store the x coordinate
    pop hl
    
    inc hl                      ; hl now points at sprite pattern index
    ld a, (hl)                  ; a = sprite pattern index
    push hl
        ld hl, ShadowSAT + $80
        add hl, bc              ; add SAT index
        add hl, bc              ; add SAT index again
        inc hl                  ; hl now points to sprite index position
        ld (hl), a              ; store the sprite index
    pop hl
    
    ex af, af'
    
    inc hl                      ; hl now points at next y value
    inc c                       ; increment SAT index counter
    dec a                       ; decrement remaining sprites
    jr nz, SPRITE_SetSprites    ; if a != 0 then repeat

    ret