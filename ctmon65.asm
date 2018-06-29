;*********************************************************
;=========================================================
;---------------------------------------------------------



IO_BASE		equ	$8000
IO_SIZE		equ	4
CONSOLE_SLOT	equ	1

ACIA		equ	(CONSOLE_SLOT*IO_SIZE)+IO_BASE
RDRF		equ	%00000001
TDRE		equ	%00000010

LF		equ	$0a
CR		equ	$0d

		bss
		org	$00c0
DPL		ds	1
DPH		ds	1


		code
		org	$e000
		db	"This space for rent.",CR,LF
		db	"Actually, this just forces the "
		db	"binary file to be 8K long."

		org	$f000

RESET		ldx	#$ff
		txs


;
;*********************************************************
; Initialize the ACIA
;
		lda	#%00000011	;reset
		sta	ACIA
		nop
		lda	#%00010001	;8N2
		sta	ACIA
		nop

		jsr	putsil
		db	CR,LF,LF,LF,LF
		db	"CTMON65 rev 0.0"
		db	CR,LF
		db	"06/29/2018 by Bob Applegate K2UT"
		db	", bob@corshamtech.com"
		db	CR,LF,0

prompt		jsr	putsil
		db	"CTMON65> "
		db	0

bozo		jmp	bozo


	if	0

loop1		ldx	#'A'
loop2		lda	ACIA
		and	#TDRE
		beq	loop2		;not empty
;
		stx	ACIA+1
		inx
		cpx	#'Z'+1
		bne	loop2
		beq	loop1
	endif

	if 0
loop1		ldx	#'A'

loop2		txa
		jsr	cout
		inx
		cpx	#'Z'+1
		bne	loop2

		lda	#CR
		jsr	cout
		lda	#LF
		jsr	cout
		jmp	loop1




	endif


cout		pha
cout1		lda	ACIA
		and	#TDRE
		beq	cout1		;not empty
		pla
		sta	ACIA+1
		rts


putsil	pla			; Get the low part of "return" address
                                ; (data start address)
        sta     DPL
        pla
        sta     DPH             ; Get the high part of "return" address
                                ; (data start address)
        ; Note: actually we're pointing one short
PSINB   ldy     #1
        lda     (DPL),y         ; Get the next string character
        inc     DPL             ; update the pointer
        bne     PSICHO          ; if not, we're pointing to next character
        inc     DPH             ; account for page crossing
PSICHO  ora     #0              ; Set flags according to contents of
                                ;    Accumulator
        beq     PSIX1           ; don't print the final NULL
        jsr     cout         ; write it out
        jmp     PSINB           ; back around
PSIX1   inc     DPL             ;
        bne     PSIX2           ;
        inc     DPH             ; account for page crossing
PSIX2   jmp     (DPL)           ; return to byte following final NULL




IGNORE		rti

;
;*********************************************************
; 6502 vectors
;
		org	$fffa
		dw	IGNORE
		dw	RESET
		dw	IGNORE
