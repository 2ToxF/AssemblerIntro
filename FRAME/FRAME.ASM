.model tiny
.code
org 100h
locals @@



; CONSTANTS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
VIDEOSEG	equ 0b800h	; Start of video segment
VIDCENTER	equ 1998d	; Middle of the screen (12*80*2 + 39*2)
NEXTLINE	equ 160d	; Move to next screen line

MYLF		equ byte ptr '~' ; My 'end of file' char (MYLF xD)
STREND		equ byte ptr '$' ; My 'string termination' char

SPACE		equ byte ptr ' ' ; Just space :)



; MAIN CODE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Start:
	; Read and process data from cmd
		xor bx, bx		; bx = 0
		mov bl, ds:[80h]	; bl = {length of cmd line}
		mov [bx+81h], STREND	; Put STREND in the end for security

		mov si, 81h		; Start of cmd line

		xor cx, cx		; cx = 0
		xor dx, dx		; dx = 0

		call atoi
		mov cl, bl		; Get frame width
		call atoi
		mov dl, bl		; Get frame height

		call xtoi
		mov ah, bl		; Get color of frame

		push ax			; Save AX
		call atoi
		pop ax			; Load AX

		call SkipSpaces

		cmp bl, 0
		jne ChFromArr		; if (bl == 0) {get sample}
	       ;{
		mov bx, si		; Save sample in BX
		call SkipSpaces		; Go to frame label
		jmp EndChFromArr
	       ;}

ChFromArr:			; Get one of default samples
		dec bl		; Because array starts from zero
		mov al, bl	; Save BL in AL
		shl bl, 3
		add bl, al	; DH *= 9 (DH * 8 + DH)
		add bx, offset Samples

EndChFromArr:	push si			; Save SI (point to text)
		push bx			; Save BX (point to sample)

	; Calc label length and height
		call CalcStrLH

	; Draw frame
		pop si			; Load BX (get back frame sample)
		call DrawFrame

	; Print label
		pop si			; Load SI (get back pointer to text)
		mov bl, bh
		xor bh, bh		; Move bh to bl and bh = 0
		call PrintLabel

	; Exit
		mov ax, 4c00h	; Set DOS-func to termination
		int 21h		; Portal to DOS-func


;---------------------------------------------------------
; Go to near spaces in string and pass it
; Entry: DS:SI = string
; Exit:  SI = first non-space char after first space
; Destr: none
;---------------------------------------------------------
SkipSpaces	proc

@@StartLoop1:	cmp ds:[si], SPACE	; while (string[i] != SPACE) ++i
		je @@EndLoop1
		inc si
		jmp @@StartLoop1
@@EndLoop1:

@@StartLoop2:	cmp ds:[si], SPACE	; while (string[i] == SPACE) ++i
		jne @@EndLoop2
		inc si
		jmp @@StartLoop2
@@EndLoop2:

@@Exit:		ret
		endp


;---------------------------------------------------------
; Convert string (hex) to number
; Entry: DS:SI = string to convert
; Exit:  BX = result
; Destr: none
;---------------------------------------------------------
xtoi		proc

		xor bl, bl		; bl = 0

		call SkipSpaces

@@StartLoop2:	shl bl, 4d		; Multiply by 16 and add next number
		add bl, ds:[si]

		cmp ds:[si], byte ptr 'a'
		jae @@IsLetter		; if (str[i] >= 'a') bl -= 'a'-10
		sub bl, '0'		; else bl -= '0'
		jmp @@Endif
@@IsLetter:	sub bl, 'a'-10
@@EndIf:	inc si

		cmp ds:[si], SPACE
		jne @@StartLoop2
@@EndLoop2:

@@Exit:		ret
		endp


;---------------------------------------------------------
; Convert string (decimal) to number
; Entry: DS:SI = string to convert
; Exit:  BL = result
; Destr: AX
;---------------------------------------------------------
atoi		proc

		xor ax, ax		; ax = 0
		xor bl, bl		; bl = 0

		call SkipSpaces

@@StartLoop2:	shl bl, 1d		; do bl = bl*10 + string[i] - '0'; ...
		mov al, 5d		;		++i
		mul bl			; while (string[i] != SPACE)
		mov bl, al
		add bl, ds:[si]
		sub bl, '0'
		inc si

		cmp ds:[si], SPACE
		jne @@StartLoop2
@@EndLoop2:

@@Exit:		ret
		endp


;---------------------------------------------------------
; Print label on frame
; Entry: AH    = color attr
;	 BX    = number of strings (label height)
;	 DS:SI = label (string) to print
;	 ES    = start of video segment
; Exit:  none
; Destr: AL CX DI
;---------------------------------------------------------
PrintLabel	proc

		cmp ds:[si], STREND
		jz @@EndLoop		; if (string[0] == STREND) return

		push si			; Save SI

@@StartLoop:
	       ;{
		cmp ds:[si], MYLF
		jnz @@NotLF		; if (string[i] == MYLF) {print str}
	       ;{{
		@@IsLF:
			push ax		; Save AX
			xor ax, ax	; ax = 0
			mov di, VIDCENTER

			push bx		; Save BX
			shr bx, 1
			shl bx, 5
			mov al, 5
			mul bx
			mov bx, ax	; bx *= 160

			sub di, bx	; Set row

			pop bx		; Load BX
			pop ax		; Load AX

			push cx		; Save CX
			shr cx, 1	; cx //= 2 <=> cx >> 1
			shl cx, 1	; cx *= 2
			sub di, cx	; Set column
			pop cx		; Load CX

			pop si		; Load SI

		@@Next:	lodsb
			stosw
			loop @@Next	; Print string (CX chars)

			cmp ds:[si], STREND
			jz @@EndLoop	; if (string[i] == STREND) break

			xor cx, cx	; cx = 0
			dec bx
			dec bx		; Move to next line
			inc si		; Skip MYLF or STREND
			push si		; Save SI
			jmp @@StartLoop
	       ;}}
	@@NotLF:
		cmp ds:[si], STREND
		jz @@IsLF		; if (string[i] == STREND) {print str}

		inc cx
	@@EndIf:
		inc si

		jmp @@StartLoop
	       ;}

@@EndLoop:

@@Exit:		ret
		endp


;---------------------------------------------------------
; Calculate length and height of frame label
; Entry: DS:SI = string for label
; Exit:  BH = label height
;	 BL = label length
; Destr: AL
;---------------------------------------------------------
CalcStrLH	proc

		xor bx, bx	; bx = 0
		inc bh		; At least one string
		xor al, al	; al = 0

@@StartLoop:
	       ;{
		cmp ds:[si], STREND
		jz @@EndLoop		; if (string[i] == STREND) break

		cmp ds:[si], MYLF
		jnz @@NotLF		; if (string[i] == MYLF) ++bh ...
	       ;{{
		inc bh
		cmp bl, al
		jae @@BLBigger		; if (bx < al) bx = al
			mov bl, al
	@@BLBigger:	xor al, al	; al = 0
		jmp @@EndIf
	       ;}}
	@@NotLF:			; else ++bl
		inc al
	@@EndIf:
		inc si

		jmp @@StartLoop
	       ;}
@@EndLoop:
		cmp bl, al
		jae @@Exit		; if (bx < al) bx = al
			mov bl, al

@@Exit:		ret
		endp


;---------------------------------------------------------
; Draw frame for text on the center of the screen
; Entry: AH    = color attr
;	 CX    = width of frame
;	 DX    = height of frame
;	 DS:SI = string with frame chars
;	 {Optional}: BH = label height
;		     BL = label length
; Exit:  none
; Destr: ES:DI
;---------------------------------------------------------
DrawFrame	proc

		cmp cx, 0h
		jnz CXnonzero	; if (cx != 0) goto CXnonzero
	      ;{		; CX autocalc
		xor ch, ch
		mov cl, bl
		add cl, 4h	; cl = bl + 4 (left and right columns)
	      ;}

CXnonzero:	cmp dx, 0h
		jnz DXnonzero	; if (dx != 0) goto DXnonzero
	      ;{		; DX autocalc
		xor dh, dh
		mov dl, bh
		add dl, 4h	; dl = bh + 4 (top and bottom rows)
	      ;}

DXnonzero:	push ax		; Save AX
		mov ax, VIDEOSEG
		mov es, ax	; ES = VIDEOSEG

		xor ax, ax	; ax = 0

		mov di, VIDCENTER

		push cx		; Save CX
		shr cx, 1	; cx //= 2 <=> cx >> 1
		shl cx, 1	; cx *= 2
		sub di, cx
		pop cx		; Load CX

		push dx		; Save DX
		shr dx, 1
		shl dx, 5
		mov al, 5
		mul dx
		mov dx, ax	; dx *= 160/2

		sub di, dx
		pop dx		; Load DX

		dec cx
		dec cx
		dec dx
		dec dx		; Exclude edge rows and columns from calc

		pop ax		; Load AX

		push cx		; Save CX
		call DrawLine	; Draw first line
		pop cx		; Load CX

LoopLines:			; Draw central lines
	      ;{
		call MoveLine
		push si		; Save SI (to print same chars)

		push cx		; Save CX
		call Drawline	; Draw central line
		pop cx		; Load CX

		pop si		; Load SI

		dec dx
		jnz LoopLines	; if (--dx != 0) goto LoopLines
	      ;}

		add si, 3h	; To print last 3 chars
		call MoveLine
		call Drawline	; Draw last line

@@Exit:		ret
		endp


;---------------------------------------------------------
; Draw one line of the frame on the sreen
; Entry: AH    = color attr
;	 DS:SI = string with frame chars
;	 ES:DI = beginning of screen line
;	 CX    = length of frame
; Exit:  DS:SI = moved to 3 chars string
;	 ES:DI = end of screen line
; Destr: AL CX
;---------------------------------------------------------
DrawLine	proc

		lodsb		; lodsb= mov al, ds:[si]
		stosw		;	 inc si
				; stosw= mov es:[di], ax
				; 	 add di, 2
		lodsb
		rep stosw	; Next:	mov es:[di], ax
				;	add di, 2
				; 	loop Next

		lodsb
		stosw

@@Exit:		ret
		endp


;---------------------------------------------------------
; Move screen line to next string and return to start pos
; Entry: DI = end of previous line
;	 CX = length of line
; Exit:  DI = start of new line
; Dest:  none
;---------------------------------------------------------
MoveLine	proc

		add di, NEXTLINE
		sub di, cx
		sub di, cx	; Two bytes per each count (CX)
		sub di, 2*2	; Left and right frame columns

@@Exit:		ret
		endp



; DATA PART !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
.data
Samples:    db 01h, 03h, 02h, 03h, 20h, 03h, 05h, 03h, 06h
	    db "+-+| |+-+"
	    db 15h, '#', 15h, '#', ' ', '#', 15h, '#', 15h
	    db 0dah, 0c4h, 0bfh, 0b3h, ' ', 0b3h, 0c0h, 0c4h, 0d9h
	    db 0dh, 1dh, 0bh, 12h, ' ', 12h, 0ch, 1dh, 0eh
	    db 0dbh, 10h, 0dbh, 1eh, ' ', 1fh, 0dbh, 11h, 0dbh
	    db 2fh, 3dh, 5ch, 29h, 0b0h, 28h, 5ch, 3dh, 2fh
	    db 0fh, 07h, 0fh, 07h, ' ', 07h, 0fh, 07h, 0fh ; Preset samples

FrameLabel: db "Masha, I do really love you <3~Happy Valentine's Day!$"  ; Text for frame label



end Start
; END OF PROGRAM !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
