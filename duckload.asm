;
; Loader for Duck Tales: The Quest for Gold (1990)
;
; Copyright (c) 2023 Vitaly Sinilin
;
; 1 July 2023
;

cpu 8086
[map all duckload.map]

%macro res_fptr 0
.off		resw	1
.seg		resw	1
%endmacro

PSP_SZ		equ	100h
STACK_SZ	equ	64

section .text

		org	PSP_SZ

		jmp	short main
byemsg		db	"Visit http://sinil.in/mintware/ducktales/$"

main:		mov	sp, __stktop
		mov	bx, sp
		mov	cl, 4
		shr	bx, cl				; new size in pars
		mov	ah, 4Ah				; resize memory block
		int	21h

		mov	bx, __bss_size
.zero_bss:	dec	bx
		mov	byte [__bss + bx], bh
		jnz	.zero_bss

		mov	[cmdtail.seg], cs		; pass cmd tail from
		mov	word [cmdtail.off], 80h		; our PSP

		mov	ax, 3521h			; read int 21h vector
		int	21h				; es:bx <- cur handler
		mov	[int21.seg], es			; save original
		mov	[int21.off], bx			; int 21h vector

		mov	dx, int_handler			; setup our own
		mov	ax, 2521h			; handler for int 21h
		int	21h				; ds:dx -> new handler

		mov	dx, exe
		push	ds
		pop	es
		mov	bx, parmblk
		mov	ax, 4B00h			; exec
		int	21h

		jnc	.success
		mov	dx, errmsg
		jmp	short .exit

.success:	mov	dx, byemsg
.exit:		mov	ah, 9
		int	21h
		call	uninstall
		mov	ah, 4Dh				; read errorlevel
		int	21h				; errorlevel => AL
		mov	ah, 4Ch				; exit
		int	21h

;------------------------------------------------------------------------------

int_handler:	cmp	ah, 25h
		je	.set_vector
		cmp	ah, 3Fh
		je	.read_file
.legacy:	jmp	far [cs:int21]

.set_vector:	push	ax
		mov	ax, [cs:game_cs]
		test	ax, ax
		jnz	.cs_known			; take note of game's
		mov	ax, ds				; CS on the first call
		mov	[cs:game_cs], ax		; to int 21/AH=25h
.cs_known:	pop	ax
		jmp	short .legacy

		; The game rereads its code from its executable file from
		; time to time. So it's not enough to patch the code only
		; once. Instead we have to inspect each read from file
		; operation and patch loaded code if it's been reverted
		; to the original state.

.read_file:	pop	ax
		mov	[cs:saved_ret.off], ax
		pop	ax
		mov	[cs:saved_ret.seg], ax
		mov	ah, 3Fh
		call	far [cs:int21]
		pushf				; propagate flags to caller
		push	ax
		push	ds
		mov	ax, [cs:game_cs]
		mov	ds, ax
		cmp	word [8EE4h], 0375h
		jne	.code_ok
		mov	byte [8EE5h], 00h
.code_ok:	pop	ds
		pop	ax
		popf
		jmp	far [cs:saved_ret]

;------------------------------------------------------------------------------

uninstall:	push	ds
		lds	dx, [cs:int21]
		mov	ax, 2521h
		pushf
		call	far [cs:int21]
		pop	ds
		ret

;------------------------------------------------------------------------------

errmsg		db	"Unable to exec original "
exe		db	"ducktale.exe",0,"$"


section .bss follows=.text nobits

__bss		equ	$
int21		res_fptr
saved_ret	res_fptr
game_cs		resw	1
parmblk		resw	1				; environment seg
cmdtail		res_fptr				; cmd tail
		resd	1				; first FCB address
		resd	1				; second FCB address
__bss_size	equ	$-__bss


section .stack align=16 follows=.bss nobits

		resb	(STACK_SZ+15) & ~15		; make sure __stktop
__stktop	equ	$				; is on segment boundary
