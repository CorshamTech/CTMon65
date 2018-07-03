;*********************************************************
; FILE: config.inc
;
; General configuration file
;*********************************************************
;
; SS-50 bus constants
;
IO_BASE		equ	$8000
IO_SIZE		equ	4
;
; Memory usage
;
ZERO_PAGE_START	equ	$00f0
ROM_START	equ	$f000
RAM_START	equ	(ROM_START-$0100)
;
; Size of command input buffer
;
BUFFER_SIZE	equ	40
MAX_ARGC	equ	5
;
; If enabled, the debugger will display the flag register
; in ASCII.  Nice, but takes more code.
;
FULL_STATUS	equ	TRUE

EXTENDED_CMDS	equ	FALSE


