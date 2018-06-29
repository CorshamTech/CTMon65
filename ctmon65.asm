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


IGNORE		rti

;
;*********************************************************
; 6502 vectors
;
		org	$fffa
		dw	IGNORE
		dw	RESET
		dw	IGNORE
