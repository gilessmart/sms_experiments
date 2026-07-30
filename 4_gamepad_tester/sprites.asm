.ramsection "shadow_sat" slot 1
    ShadowSAT: dsb 256
.ends

.section "spritelibs"    
    ; Writes a sprite to the shadow SAT
    ; Params: 
    ;   a = sprite pattern index
    ;   b = must be 0
    ;   c = SAT index
    ;   d = x coordinate
    ;   e = y coordinate
    ; Clobbers: hl
    ; Updates: c is incremented by 1
    SPRITES_SetSprite:
        ld hl, ShadowSAT        ; base address
        add hl, bc              ; add SAT index
        ld (hl), e              ; store the y coordinate
        
        ld hl, ShadowSAT + $80  ; adr of 2nd part of shadow SAT
        add hl, bc              ; add SAT index
        add hl, bc              ; add SAT index again
        ld (hl), d              ; store the x coordinate
        
        inc hl
        ld (hl), a              ; store the pattern index
        
        inc c

        ret

    ; Writes a set of (up to 256) sprites to shadow SAT
    ; Params: 
    ;   ix = start of sprite data
    ;   a = number of sprites to write
    ;   b = must be 0
    ;   c = SAT index counter
    ;   d = x position
    ;   e = y position
    ; Clobbers: ix, hl, a, a'
    ; Updates:
    ;   c is incremented by the number of sprites written
    SPRITES_SetSprites:
        ex af, af'

        ld a, (ix+0)                ; a = relative y coordinate
        add a, e                    ; add base y coordinate
        ld hl, ShadowSAT
        add hl, bc                  ; add SAT index
        ld (hl), a                  ; store the y coordinate
        
        inc ix                      ; ix now points at x value
        ld a, (ix+0)                ; a = relative x coordinate
        add a, d                    ; add base y coordinate
        ld hl, ShadowSAT + $80
        add hl, bc                  ; add SAT index
        add hl, bc                  ; add SAT index again
        ld (hl), a                  ; store the x coordinate
        
        inc ix                      ; ix now points at sprite pattern index
        ld a, (ix+0)                ; a = sprite pattern index
        inc hl                      ; hl now points to sprite index position
        ld (hl), a                  ; store the sprite index
        
        ex af, af'
        
        inc ix                      ; ix now points at next y value
        inc c                       ; increment SAT index counter
        dec a                       ; decrement remaining sprites
        jr nz, SPRITES_SetSprites   ; if a != 0 then repeat

        ret

    ; Terminates the shadow SAT
    ; Params:
    ;   b = must be 0
    ;   c = SAT index counter
    ; Clobbers: a, c, hl
    SPRITES_TerminateSAT:
        ld hl, ShadowSAT
        add hl, bc      ; hl = adr of next y position
        ld (hl), $d0    ; D0 terminates the table
        ret

    ; Copies the shadow SAT to the VDP
    ; Clobbers: bc, hl
    SPRITES_FlushSAT:
        ld hl, VDP_CMD_VRAM_WRITE | $3f00
        call VDP_SetAddress
        
        ld hl, ShadowSAT
        ld b, 0
        ld c, VDP_DATA_PORT
        otir
        
        ret
.ends