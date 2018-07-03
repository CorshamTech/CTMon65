;*********************************************************
; CTMON65
;
; This is the monitor for the Corsham Techologies, LLC
; SS-50 65C02 board.  It's a fairly generic monitor that
; can be ported to other 6502 based systems.
;
; Written mostly while on a family vacation in 2018, but
; ideas and code were taken from other Corsham Tech
; projects and various web pages (credit given in the
; code).
;
; Bob Applegate
; bob@corshamtech.com
; www.corshamtech.com
;*********************************************************

;=========================================================
;---------------------------------------------------------


		include	"config.inc"
;
;---------------------------------------------------------
; ASCII constants
;
BELL		equ	$07
LF		equ	$0a
CR		equ	$0d
;
; Zero-page data
;
		zpage
		org	ZERO_PAGE_START
IRQvec		ds	2
NMIvec		ds	2
sptr		ds	2
INL		ds	1
INH		ds	1
;
; Non zero-page data
;
		bss
		org	RAM_START
SaveA		ds	1
SaveX		ds	1
SaveY		ds	1
SavePC		ds	2
SaveC		ds	1
SaveSP		ds	1
SAL		ds	1
SAH		ds	1
EAL		ds	1
EAH		ds	1
tempA		ds	1
;
; This weird bit of DBs is to allow for the fact that
; I'm putting a 4K monitor into the top half of an
; 8K EEPROM.  This forces the actual code to the top
; 4K section.
;
		code
		org	ROM_START-$1000
		db	"This space for rent.",CR,LF
		db	"Actually, this just forces the "
		db	"binary file to be 8K long."
;
		org	ROM_START
;
;=========================================================
; Jump table to common functions.  The entries in this
; table are used by external programs, so nothing can be
; moved or removed from this table.  New entries always
; go at the end.  Many of these are internal functions
; and I figured they might be handy for others.
;
COLDvec		jmp	RESET
WARMvec		jmp	WARM
CINvec		jmp	cin
COUTvec		jmp	cout
CSTATvec	jmp	cstatus
PUTSILvec	jmp	putsil
GETLINEvec	jmp	getline
CRLFvec		jmp	crlf
OUTHEXvec	jmp	HexA


;
;---------------------------------------------------------
; Cold start entry point
;
RESET		ldx	#$ff
		txs
		jsr	cinit
;
; Reset the NMI and IRQ vectors
;
		lda	#DefaultNMI&$ff
		sta	NMIvec
		lda	#DefaultNMI>>8
		sta	NMIvec+1
;
		lda	#DefaultIRQ&$ff
		sta	IRQvec
		lda	#DefaultIRQ>>8
		sta	IRQvec+1
;
; Print start-up message
;
		jsr	putsil
		db	CR,LF,LF,LF,LF
		db	"CTMON65 rev 0.0"
		db	CR,LF
		db	"06/29/2018 by Bob Applegate K2UT"
		db	", bob@corshamtech.com"
		db	CR,LF,LF,0
;
;---------------------------------------------------------
; Warm start entry point.  This is the best place to jump
; in the code after a user program has ended.  Go through
; the vector, of course!
;
WARM		ldx	#$ff
		txs


;
; Prompt the user and get a line of text
;
prompt		jsr	putsil
		db	"CTMON65> "
		db	0
prompt2		jsr	cin
		cmp	#CR
		beq	prompt
		cmp	#LF
		beq	prompt2	;don't prompt
		sta	tempA
;
; Now cycle through the list of commands looking for
; what the user just pressed.
;
		lda	#commandTable&$ff
		sta	sptr
		lda	#commandTable/256
		sta	sptr+1
		jsr	searchCmd	;try to find it
;
; Hmmm... wasn't one of the built in commands, so
; see if it's an extended command.
;
	if	EXTENDED_CMDS
		lda	ExtensionAddr
		sta	sptr
		lda	ExtensionAddr+1
		sta	sptr+1
		jsr	searchCmd	;try to find it
	endif
;
; If that returns, then the command was not found.
; Print that it's unknown.
;
		jsr	putsil
		db	" - Huh?",0
cmdFound	jmp	prompt
;
;=====================================================
; Vector table of commands.  Each entry consists of a
; single ASCII character (the command), a pointer to
; the function which handles the command, and a pointer
; to a string that describes the command.
;
commandTable	db	'?'
		dw	showHelp
		dw	quesDesc
;
;		db	'D'
;		dw	doDiskDir
;		dw	dDesc
;
;		db	'E'	;edit memory
;		dw	editMemory
;		dw	eDesc
;
;		db	'H'	;hex dump
;		dw	hexDump
;		dw	hDesc
;
		db	'J'	;jump to address
		dw	jumpAddress
		dw	jDesc
;
;		db	'L'	;load Intel HEX file
;		dw	loadHex
;		dw	lDesc
;


		db	'M'	;perform memory test
		dw	memTest
		dw	mDesc

		db	0	;marks end of table
;
;=====================================================
; Descriptions for each command in the command table.
; This wastes a lot of space... I'm open for any
; suggestions to keep the commands clear but reducing
; the amount of space this table consumes.
;
quesDesc	db	"? ........... Show this help",0
;dDesc		db	"D ........... Disk directory",0
;eDesc		db	"E xxxx ...... Edit memory",0
;hDesc		db	"H xxxx xxxx . Hex dump memory",0
jDesc		db	"J xxxx ...... Jump to address",0
;lDesc		db	"L ........... Load HEX file",0
mDesc		db	"M xxxx xxxx . Memory test",0
;pDesc		db	"P ........... Ping disk controller",0
;sDesc		db	"S xxxx xxxx . Save memory to file",0
;tDesc		db	"T ........... Type disk file",0
;bangDesc	db	"! ........... Do a cold start",0


;
;=====================================================
; This subroutine will search for a command in a table
; and call the appropriate handler.  See the command
; table near the start of the code for what the format
; is.  If a match is found, pop off the return address
; from the stack and jump to the code.  Else, return.
;
searchCmd	ldy	#0
cmdLoop		lda	(sptr),y
		beq	cmdNotFound
		cmp	tempA	;compare to user's input
		beq	cmdMatch
		iny		;start of function ptr
		iny
		iny		;start of help
		iny
		iny		;move to next command
		bne	cmdLoop
;
; It's found!  Load up the address of the code to call,
; pop the return address off the stack and jump to the
; handler.
;
cmdMatch	iny
		lda	(sptr),y	;handler LSB
		pha
		iny
		lda	(sptr),y	;handler MSB
		sta	sptr+1
		pla
		sta	sptr
		pla		;pop return address
		pla
		jmp	(sptr)
;
; Not found, so just return.
;
cmdNotFound	rts
;

;
;=====================================================
; Handles the command to prompt for an address and then
; jump to it.
;
jumpAddress	jsr	space
		jsr	getStartAddr
		bcs	cmdRet	;branch on bad address
		jsr	crlf
		jmp	(SAL)	;else jump to address
;
cmdRet		jmp	prompt




;
;*********************************************************
; Handlers for the interrupts.  Basiclly just jump 
; through the vectors and hope they are set up properly.
;
HandleNMI	jmp	(NMIvec)
HandleIRQ	jmp	(IRQvec)
;
;*********************************************************
; Default handler.  Save the state of the machine for
; debugging.  This is taken from the KIM monitor SAVE
; routine.
;
DefaultNMI
DefaultIRQ
		sta	SaveA
		pla
		sta	SaveC
		pla
		sta	SavePC
		pla
		sta	SavePC+1
		sty	SaveY
		stx	SaveX
		tsx
		stx	SaveSP
		jsr	DumpRegisters
		jsr	crlf
		jmp	WARM
;
;*********************************************************
; Dump the current registers based on values in the Save*
; locations.
;
DumpRegisters	jsr	putsil
		db	"PC:",0
		lda	SavePC+1
		jsr	HexA
		lda	SavePC
		jsr	HexA
;
		jsr	putsil
		db	" A:",0
		lda	SaveA
		jsr	HexA
;
		jsr	putsil
		db	" X:",0
		lda	SaveX
		jsr	HexA
;
		jsr	putsil
		db	" Y:",0
		lda	SaveY
		jsr	HexA
;
		jsr	putsil
		db	" SP:",0
		lda	SaveSP
		jsr	HexA
;
; Last is the condition register.  For this, print the
; actual flags.  Lower case for clear, upper for set.
;
		jsr	putsil
		db	" Flags:",0
	if	FULL_STATUS
;
; N - bit 7
;
		lda	#$80	;bit to test
		ldx	#'N'	;set ACII char
		jsr	testbit
;
; V - bit 6
;
		lda	#$40	;bit to test
		ldx	#'V'	;set ACII char
		jsr	testbit
;
		lda	#'-'	;unused bit
		jsr	cout
;
; B - bit 4
;
		lda	#$10	;bit to test
		ldx	#'B'	;set ACII char
		jsr	testbit
;
; D - bit 3
;
		lda	#$08	;bit to test
		ldx	#'D'	;set ACII char
		jsr	testbit
;
; I - bit 2
;
		lda	#$04	;bit to test
		ldx	#'I'	;set ACII char
		jsr	testbit
;
; Z - bit 1
;
		lda	#$02	;bit to test
		ldx	#'Z'	;set ACII char
		jsr	testbit
;
; C - bit 0
;
		lda	#$01	;bit to test
		ldx	#'C'	;set ACII char
;
; Fall through...
;
;*********************************************************
; Given a bit mask in A and an upper case character
; indicating the flag name in X, see if the flag is set or
; not.  Output upper case if set, lower case if not.
;
testbit		and	SaveC	;is bit set?
		bne	testbit1	;yes
		txa
		ora	#$20	;make lower case
		jmp	cout
testbit1	txa
		jmp	cout
	else
		lda	SaveSP
		jmp	HexA
	endif
;
;=====================================================
; This gets two hex characters and returns the value
; in A with carry clear.  If a non-hex digit is
; entered, then A contans the offending character and
; carry is set.
;
getHex		jsr	getNibble
		bcs	getNibBad
		asl	a
		asl	a
		asl	a
		asl	a
		and	#$f0
		sta	tempA
		jsr	getNibble
		bcs	getNibBad
		ora	tempA
		clc
		rts
;
; Helper.  Gets next input char and converts to a
; value from 0-F in A and returns C clear.  If not a
; valid hex character, return C set.
;
getNibble	jsr	cin
		ldx	#nibbleHexEnd-nibbleHex-1
getNibble1	cmp	nibbleHex,x
		beq	getNibF	;got match
		dex
		bpl	getNibble1
getNibBad	sec
		rts

getNibF		txa		;index is value
		clc
		rts
;
nibbleHex	db	"0123456789ABCDEF"
nibbleHexEnd	equ	*
;
;=====================================================
; Gets a four digit hex address amd places it in
; SAL and SAH.  Returns C clear if all is well, or C
; set on error and A contains the character.
;
getStartAddr	jsr	getHex
		bcs	getDone
		sta	SAH
		jsr	getHex
		bcs	getDone
		sta	SAL
		clc
getDone		rts
;
;=====================================================
; Gets a four digit hex address amd places it in
; EAL and EAH.  Returns C clear if all is well, or C
; set on error and A contains the character.
;
getEndAddr	jsr	getHex
		bcs	getDone
		sta	EAH
		jsr	getHex
		bcs	getDone
		sta	EAL
		clc
		rts
;
;=====================================================
; Get an address range and leave them in SAL and EAL.
;
getAddrRange	jsr	space
		jsr	getStartAddr
		bcs	getDone
		lda	#'-'
		jsr	cout
		jsr	getEndAddr
		rts
;
;=====================================================
; Command handler for the ? command
;
showHelp	jsr	putsil
		db	CR,LF
		db	"Available commands:"
		db	CR,LF,LF,0
;
; Print help for built-in commands...
;
		lda	#commandTable&$ff
		sta	sptr
		lda	#commandTable/256
		sta	sptr+1
		jsr	displayHelp	;display help
;
; Now print help for the extension commands...
;
	if	EXTENDED_CMDS
		lda	ExtensionAddr
		sta	sptr
		lda	ExtensionAddr+1
		sta	sptr+1
		jsr	displayHelp
		jsr	crlf
	endif
		jmp	prompt
;
;=====================================================
; Given a pointer to a command table in POINT, display
; the help text for all commands in the table.
;
displayHelp	ldy	#0	;index into command table
showHelpLoop	lda	(sptr),y	;get command
		beq	showHelpDone	;jump if at end
;
; Display this entry's descriptive text
;
		iny		;skip over command
		iny		;skip over function ptr
		iny
		lda	(sptr),y
		sta	INL
		iny
		lda	(sptr),y
		sta	INH
		tya
		pha
		jsr	space2
		jsr	puts	;print description
		jsr	crlf
		pla
		tay
		iny		;point to next entry
		bne	showHelpLoop
showHelpDone	rts
;
;=====================================================
; This does a memory test of a region of memory.
;
; Asks for the starting and ending locations.
;
; This cycles a rolling bit, then adds a ninth
; pattern to help detect shorted address bits.
; Ie: 01, 02, 04, 08, 10, 20, 40, 80, BA
;
pattern		equ	SaveA	;re-use some other locations
original	equ	SaveX
;
; Test patterns
;
PATTERN_0	equ	$01
PATTERN_9	equ	$ba
;
memabort	jsr	cin	;eat pending key
cmdRet2		jmp	prompt
;
memTest		jsr	getAddrRange	;get range
		bcs	cmdRet2		;branch if abort
;
		jsr	putsil
		db	CR,LF
		db	"Testing memory.  Press any key to abort"
		db	0
		lda	#PATTERN_0	;only set initial...
		sta	pattern		;..pattern once
;
; Start of loop.  This fills/tests one complete pass
; of memory.
;
memTestMain	jsr	cstatus	;key pressed?
		bne	memabort	;branch if yes
		lda	SAL	;reset pointer to start
		sta	sptr
		lda	SAH
		sta	sptr+1
;
; Fill memory with the rolling pattern until the last
; location is filled.
;
		ldy	#0
		lda	pattern
		sta	original
memTestFill	sta	(sptr),y
		cmp	#PATTERN_9	;at last pattern?
		bne	memFill3
		lda	#PATTERN_0	;restart pattern
		jmp	memFill4
;
; Rotate pattern left one bit
;
memFill3	asl	a
		bcc	memFill4	;branch if not overflow
		lda	#PATTERN_9	;ninth pattern
;
; The new pattern is in A.  Now see if we've reached
; the end of the area to be tested.
;
memFill4	pha		;save pattern
		lda	sptr
		cmp	EAL
		bne	memFill5
		lda	sptr+1
		cmp	EAH
		beq	memCheck
;
; Not done, so move to next address and keep going.
;
memFill5	jsr	INCPT
		pla		;recover pattern
		jmp	memTestFill
;
; Okay, memory is filled, so now go back and test it.
; We kept a backup copy of the initial pattern to
; use, but save the current pattern as the starting
; point for the next pass.
;
memCheck	pla
		sta	pattern	;for next pass
		lda	SAL	;reset pointer to start
		sta	sptr
		lda	SAH
		sta	sptr+1
		lda	original	;restore initial pattern
		ldy	#0
memTest2	cmp	(sptr),y
		bne	memFail
		cmp	#PATTERN_9
		bne	memTest3
;
; Time to reload the pattern
;
		lda	#PATTERN_0
		bne	memTest4
;
; Rotate pattern left one bit
;
memTest3	asl	a
		bcc	memTest4
		lda	#PATTERN_9
;
; The new pattern is in A.
;
memTest4	pha		;save pattern
		lda	sptr
		cmp	EAL
		bne	memTest5	;not at end
		lda	sptr+1
		cmp	EAH
		beq	memDone	;at end of pass
;
; Not at end yet, so inc pointer and continue
;
memTest5	jsr	INCPT
		pla
		jmp	memTest2
;
; Another pass has completed.
;
memDone		pla
		lda	#'.'
		jsr	cout
		jmp	memTestMain
;
; Failure.  Display the failed address, the expected
; value and what was actually there.
;
memFail		pha		;save pattern for error report
		jsr	putsil
		db	CR,LF
		db	"Failure at address ",0
		lda	sptr+1
		jsr	HexA
		lda	sptr
		jsr	HexA
		jsr	putsil
		db	".  Expected ",0
		pla
		jsr	HexA
		jsr	putsil
		db	" but got ",0
		ldy	#0
		lda	(sptr),y
		jsr	HexA
		jsr	crlf
cmdRet4		jmp	prompt
;


INCPT		inc	sptr
		bne	incpt2
		inc	sptr+1
incpt2		rts
;
		include	"io.asm"
		include	"acia.asm"
;
;*********************************************************
; 6502 vectors
;
		org	$fffa
		dw	HandleNMI
		dw	RESET
		dw	HandleIRQ

