.include "vdu.asm"

.memorymap
	defaultslot 0
  slot 0 $0000 $8000	; 32K of ROM
	slot 1 $c000 $2000	; 8K of RAM
.endme

.rombankmap
	bankstotal 1
	banksize $8000
	banks 1
.endro

.ramsection "shadow_sat" slot 1
	ShadowSAT: dsb 256
.ends

.bank 0
.slot 0

.org $0000
.section "startup" force
	di 							; disable interrupts
	im 1						; use interrupt mode 1
	ld sp, $dff0		; leave 16KB free in case the BIOS has left anything there
	jp main
.ends

.sdsctag 0.1, "Hello World!", "SMS programming experiment", "Giles Smart"

.org $0038
.section "interrupt_handler" force
	retn
.ends

.org $0038
.section "pause_handler" force
	retn
.ends

.section "main"
	main:
		; initialise the VDP registers

		; setup CRAM (palette)

		; setup tile patterns

		; setup sprite patterns

		; setup nametable

		; setup SAT

		; turn on display

		; loop
	-:jr -
.ends
