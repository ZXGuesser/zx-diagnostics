;
;	ZX Diagnostics - fixing ZX Spectrums in the 21st Century
;	https://github.com/brendanalford/zx-diagnostics
;
;	Original code by Dylan Smith
;	Modifications and 128K support by Brendan Alford
;
;	This code is free software; you can redistribute it and/or
;	modify it under the terms of the GNU Lesser General Public
;	License as published by the Free Software Foundation;
;	version 2.1 of the License.
;
;	This code is distributed in the hope that it will be useful,
;	but WITHOUT ANY WARRANTY; without even the implied warranty of
;	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;	Lesser General Public License for more details.
;
;	defines.asm
;	


;
;	Definitions and macros used by the testing ROM.
;

	define   LED_PORT	63
	define   ULA_PORT	254
	define   ROMPAGE_PORT   31
	define   BORDERRED	2
	define   BORDERGRN	4
	define 	 BORDERYEL	6
	define	 BORDERWHT	7
	define   ERR_FLASH	0xaa   ; alternate lights

;	ROM checksum values

	define	CRC_48K		0xfd5e
	define	CRC_128K	0xeffc
	define	CRC_PLUS2	0x2aa3


;
;	Macro to run a RAM walk test
;
	MACRO WALKLOOP start, length

	ld hl, start
	ld de, length

.walk.loop

	ld a, 1
	ld b, 8     ; test 8 bits
	or a        ; ensure carry is cleared

.walk.checkbits

	ld (hl), a
	ld c, a     ; for compare
	ld a, (hl)
	cp c
	jr nz, .walk.borked
	rla
	djnz .walk.checkbits
	inc hl
	dec de
	ld a, d     ; does de=0?
	or e
	jp z, .walk.done
	jr .walk.loop

.walk.borked

; 	Store dodgy bit in ixh

	xor c

; 	And temporarily in d for BORKEDFLASH

	ld d, a
	ld bc, ix
	or b

;	Out straight to LED's, don't flash

	out (LED_PORT), a
	ld b, a
	ld a, 1	; Bit 0 of ixl: walk test fail
	or c
	ld c, a
	ld ix, bc
	ld a, BORDERRED
	out (ULA_PORT), a
	jr .walk.exit

.walk.done
.walk.exit

	ENDM

;
;	Macro to blank (or fill) an area of memory
;
	MACRO BLANKMEM start, len, pattern

	ld hl, start
	ld de, len

.blankloop

	ld (hl), pattern
	inc hl
	dec de
	ld a, d
	or e
	jr nz, .blankloop

	ENDM

;
;	Macro used during inversion testing
;
	MACRO ALTPATA start,len,fill

	BLANKMEM start, len, fill
	ld hl, start
	ld bc, len

.altpat1.wrloop1

	ld a, fill
	cpl
	ld (hl), a
	inc hl
	inc hl
	dec bc
	dec bc
	ld a, b
	or c
	jr nz, .altpat1.wrloop1

.altpat1.rd

	ld hl, start
	ld bc, len

.altpat1.rdloop1

	ld a, fill
	cpl
	cp (hl)
	jr nz, .altpat1.borked
	inc hl
	dec bc
	cpl
	cp (hl)
	jr nz, .altpat1.borked
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .altpat1.rdloop1 
	jr .altpat1.done

.altpat1.borked

; 	Store dodgy bit in ixh

	xor (hl)
	ld bc, ix
	ld d, a

; 	And also in d for ALTBORKED

	or b

;	OUT to led's

	out (LED_PORT), a
	ld b, a
	ld a, 2	; Bit 0 of ixl: inversion test fail
	or c
	ld c, a
	ld ix, bc

	ld a, BORDERRED
	out (ULA_PORT), a
	jr .altpat1.exit

.altpat1.done
.altpat1.exit

	ENDM

;
;	Macro used during inversion testing
;
	MACRO ALTPATB start,len,fill

	BLANKMEM start, len, fill
	ld hl, start
	ld bc, len

.altpat2.wrloop1

	ld a, fill
	cpl
	inc hl
	ld (hl), a
	inc hl
	dec bc
	dec bc
	ld a, b
	or c
	jr nz, .altpat2.wrloop1

.altpat2.rd

	ld hl, start
	ld bc, len

.altpat2.rdloop1

	ld a, fill
	cp (hl)
	jr nz, .altpat2.borked
	inc hl
	dec bc
	cpl
	cp (hl)
	jr nz, .altpat2.borked
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .altpat2.rdloop1 
	jr .altpat2.done

.altpat2.borked

; 	Store dodgy bit in ixh

	xor (hl)
	ld bc, ix

; 	And also in d for ALTBORKED

	ld d, a
	or b
	out (LED_PORT), a
	ld b, a
	ld a, 2	; Bit 0 of l': inversion test fail
	or c
	ld c, a
	ld ix, bc
	ld a, BORDERRED
	out (ULA_PORT), a
	jr .altpat2.exit

.altpat2.done
.altpat2.exit	

	ENDM

;
;	Algorithm March X
;	Step1: write 0 with up addressing order;
;	Step2: read 0 and write 1 with up addressing order;
;	Step3: read 1 and write 0 with down addressing order;
;	Step4: read 0 with down addressing order. 
;	
; 	Credit - Karl (PokeMon) on WoS for the algorithm description
;

	MACRO MARCHTEST start, len
	
	; Step 1 - write 0 with up addressing order
	; No errors expected with this part :)
	
	ld hl, start
	ld bc, len

.marchtest1.loop
	
	ld (hl), 0
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest1.loop
	
	; Step 2 - read 0 and write 1 with up addressing order
	
	ld hl, start
	ld bc, len

.marchtest2.loop
	ld a, (hl)
	cp 0
	jr z, .marchtest2.next
	
	MARCHBORKED
	jp .marchtest.done
	
.marchtest2.next
	ld a, 0xff
	ld (hl), a
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest2.loop

.marchtest3.start

	; Step 3 - read 1 and write 0 with down addressing order 
	ld hl, start
	ld bc, len - 1
	add hl, bc

.marchtest3.loop

	ld a, (hl)
	cp 0xff
	jr z, .marchtest3.next

	xor a 
	MARCHBORKED
	jp .marchtest.done
	
.marchtest3.next
	
	xor a
	ld (hl), a
	dec hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest3.loop
	
.marchtest4.start
	; Step 4 - read 0 with down addressing order
	ld hl, start
	ld bc, len - 1
	add hl, bc
	
.marchtest4.loop

	ld a, (hl)
	cp 0
	jr z, .marchtest4.next

	MARCHBORKED
	jp .marchtest.done
	
.marchtest4.next

	dec hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest4.loop

.marchtest.done

	ENDM

	MACRO MARCHBORKED
	
	ld b, a
	ld a, ixh
	or b
	ld ixh, a
	ld a, BORDERRED
	out (ULA_PORT), a	
	
	ENDM

;
;	Generate a pseudo random 16-bit number.
; 	see http://map.tni.nl/sources/external/z80bits.html#3.2 for the
; 	basis of the random fill
; 	BC = seed
;

	MACRO RAND16

	ld d, b
	ld e, c
	ld a, d
	ld h, e
	ld l, 253
	or a
	sbc hl, de
	sbc a, 0
	sbc hl, de
	ld d, 0
	sbc a, d
	ld e, a
	sbc hl, de
	jr nc, .rand16.done
	inc hl

.rand16.done

	ld b, h
	ld c, l

	ENDM

;
;	Random fill test in increasing order
;	Args: addr - base address, reps - half memory size being tested,
;	      seed - PRNG seed to use
;

	MACRO RANDFILLUP addr, reps, seed

	ld sp, addr
	exx
	ld bc, seed  
	exx
	ld bc, reps

.randfill.up.loop      

	exx
	RAND16
	ld de, hl
	ld hl, 0
	add hl, sp
	ld (hl), de
	inc sp
	inc sp
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.up.loop

.randfill.up.test      

	ld sp, addr
	exx
	ld bc, seed      
	exx
	ld bc, reps

.randfill.up.testloop

	exx
	RAND16	; byte pair to test now in HL
	pop de	; Pop memory off the stack to test into DE
	ld a, h
	cp d
	jp nz, .randfill.up.borked1
	ld a, l
	cp e
	jp nz, .randfill.up.borked2
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.up.testloop
	jp .randfill.up.done

.randfill.up.borked1

	ld e, d	; bad byte should be in E
	ld l, h   ; expected byte in L 

.randfill.up.borked2

	ld a, e
	xor l
	
; 	Store dodgy bit in ixh

	ld bc, ix
	; And in D for borkedloop
	ld d, a
	or b
	out (LED_PORT), a
	ld b, a
	ld a, 4	; Bit 0 of l': random test fail
	or c
	ld c, a
	ld ix, bc
	ld c, a   ; save good byte
	ld a, BORDERRED
	out (ULA_PORT), a
	jp .randfill.up.exit

.randfill.up.done
.randfill.up.exit
	
	ENDM

;
;	Random fill test in descendingvorder
;	Args: addr - base address, reps - half memory size being tested,
;	      seed - PRNG seed to use
;

	MACRO RANDFILLDOWN addr, reps, seed

	ld sp, addr
	exx
	ld bc, seed  
	exx
	ld bc, reps
	
	; Adjust stack pointer as we won't be popping values off in 
	; the normal sense when testing
	
	inc sp
	inc sp
	
.randfill.down.loop      

	exx
	RAND16
	push hl
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.down.loop

.randfill.down.test      

	ld sp, addr
	exx
	ld bc, seed      
	exx
	ld bc, reps
	
.randfill.down.testloop

	exx
	RAND16		; byte pair to test now in HL
	pop de		; corresponding memory in DE
	dec sp
	dec sp		; Adjust stack pointer back downwards
	dec sp		
	dec sp
	
	ld a, h
	cp d
	jp nz, .randfill.down.borked1
	ld a, l
	cp e
	jp nz, .randfill.down.borked2
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.down.testloop
	jp .randfill.down.done

.randfill.down.borked1

	ld e, d	; bad byte should be in E
	ld l, h   ; expected byte in L 

.randfill.down.borked2

	ld a, e
	xor l
	
; 	Store dodgy bit in ixh

	ld bc, ix
	; And in D for borkedloop
	ld d, a
	or b
	out (LED_PORT), a
	ld b, a
	ld a, 4	; Bit 0 of l': random test fail
	or c
	ld c, a
	ld ix, bc
	ld c, a   ; save good byte
	ld a, BORDERRED
	out (ULA_PORT), a
	jp .randfill.down.exit

.randfill.down.done
.randfill.down.exit
	
	ENDM

;
;	Saves the location of the stack pointer to 
;	memory
;

	MACRO SAVESTACK
	ld (v_stacktmp), sp
	ENDM

;
;	Restores the location of the stack pointer from 
;	memory
;

	MACRO RESTORESTACK
	ld sp, (v_stacktmp)
	ENDM
	
;	
;	Macro to interpret the results of a 48k memory test
;	and store the result, write result to screen etc
;

	MACRO TESTRESULT
	ld bc, ix
	ld a, b
	cp 0
	jr nz, .test.fail

.test.pass

	ld hl, str_testpass
	call print
	jr .test.end

.test.fail

	ld a, (v_fail_ic)
	or b
	ld (v_fail_ic), a
	ld hl, str_testfail
	call print

.test.end

	ENDM


;	
;	Macro to interpret the results of a 128k memory test
;	and store the result
;

	MACRO TESTRESULT128

	ld bc, ix
	ld a, (v_fail_ic)
	or b
	ld (v_fail_ic), a

	ENDM

;
;	Blanks the H register. 
;

	MACRO PREPAREHREG

	exx
	ld a, 0
	ld h, a
	exx

	ENDM

;
;	Macro to sound a tone.
;	Inputs: L=border colour.
;
	MACRO BEEP freq, length

	ld de, length				

.tone.duration

	ld bc, freq			; bc = twice tone freq in Hz

.tone.period

	dec bc
	ld a, b
	or c
	jr nz, .tone.period

;	Toggle speaker output, preserve border

	ld a, l
	xor 0x10				
	ld l, a 
	out (0xfe), a

;	Generate tone for desired duration

	dec de					
	ld a, d
	or e
	jr nz, .tone.duration

	ENDM
	
;	A quick macro to write a value in a to four consecutive
;	memory locations starting at HL.

	MACRO LDHL4TIMES
	
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), a
	
	ENDM