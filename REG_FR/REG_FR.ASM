.model tiny
.code
org 100h
locals @@

; CONSTANTS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
VIDEOSEG	equ 0b800h					; Start of video segment

TEXTLINELEN	equ 7d						; Length of one text line of frame
TEXTLINENUM equ 4d						; Number of lines in text of frame

FRAMESTART	equ 2d*80d*2d + 65d*2d		; Left upper corner of the frame
FRAMECOLUM	equ TEXTLINELEN + 4d		; Number of frame columns with edges (width)
FRAMEROW	equ TEXTLINENUM + 2d		; Number of frame rows with edges (height)
FRAMESHFT	equ 7d						; To move to next register field in buffer
FRAMESIZE	equ FRAMECOLUM*FRAMEROW*2d	; Size of registers frame

FRAMECOLOR	equ byte ptr 08h			; Color of the frame

SCREENSHFT	equ 80d*2d - FRAMECOLUM*2		; Value to move to next line from the end of current

HOTKEY		equ byte ptr 29h			; Scan code of '~'
CTRLMASK	equ byte ptr 04h			; Mask for ctrl



; MAIN CODE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Start:
			; Replace 08h int
			xor ax, ax
			mov es, ax					; Segment 0
			mov bx, 08h*4				; Offset to 08h int

			mov ax, es:[bx]
			mov Old08Ofs, ax			; Save old 08h int offset

			mov ax, es:[bx+2]
			mov Old08Seg, ax			; Save old 08h int segment

			cli							; Turn off interrupts
			mov es:[bx], offset My08Int	; Set new 08h offset
			push cs
			pop ax
			mov es:[bx+2], ax			; Set new 08h segment
			sti							; Turn on interrupts

			; Replace 09h int
			xor ax, ax
			mov es, ax					; Segment 0
			mov bx, 09h*4				; Offset to 09h int (every int = 4 bytes)

			mov ax, es:[bx]
			mov Old09Ofs, ax			; Save old 09h int offset

			mov ax, es:[bx+2]
			mov Old09Seg, ax			; Save old 09h int segment

			cli							; Turn off interrupts
			mov es:[bx], offset My09Int	; Set new 09h offset
			push cs
			pop ax
			mov es:[bx+2], ax			; Set new 09h segment
			sti							; Turn on interrupts

			; mov al, FlagTurnOn
			; inc al
			; mov FlagTurnOn, al
			; call My08Int				; DEBUG

			; Terminate and stay resident
			mov ax, 3100h				; Set TSR-func
			mov dx, offset EndOfCode	; Set length of code to stay

			shr dx, 4					; dx must show num of 16-byte paragraphs
			inc dx						; To let rest of the code stay
			int 21h						; Exit program


;---------------------------------------------------------------
; Turn on/off frame with registers
; Entry:	{all registers}
; Exit:		none
; Destr:	none
;---------------------------------------------------------------
My09Int		proc

			push ax di es			; SAVE ax di es

			;!!!{Проверка ввода} - выполнено
			mov ah, 02h
			int 16h					; Put flags in AL to check ctrl and shift
			cmp al, CTRLMASK
			jnz ChainOld09			; if (al != CTRLMASK) {not my hotkey}

			in al, 60h				; Scan from 60h port
			cmp al, HOTKEY
			jnz ChainOld09			; if (al != HOTKEY) {not my hotkey}

			mov al, FlagTurnOn
			inc al
			and al, 01h
			mov FlagTurnOn, al		; FlagTurnOn = (FlagTurnOn + 1) % 2

			; mov ax, VIDEOSEG
			; mov es, ax
			; mov ax, 4e00h + 'W'
			; xor bx, bx
			; mov es:[bx], ax			; DEBUG
			;!!!{Подмена буферов}

			jmp ChainOld09			; Chain to old Interrupt Service Routine

ChainOld09: pop es di ax			; LOAD es di ax
			db 0eah					; <=> jmp
Old09Ofs	dw 0
Old09Seg	dw 0					; 0000:0000 (but it will be changed earlier)

@@Exit:		iret					; Interrupt return
			endp


;---------------------------------------------------------------
; Displays registers values
; Entry:	{all registers}
; Exit:		none
; Destr:	none
;---------------------------------------------------------------
My08Int		proc

			push es ds di si dx cx bx ax	; SAVE all* registers

			; mov dl, FlagTurnOn
			; inc dl
			; mov ah, 02h
			; int 21h					; DEBUG

			; mov dl, FlagInited
			; inc dl
			; mov ah, 02h
			; int 21h					; DEBUG

			mov al, FlagTurnOn
			cmp al, 00h
			jz ChainOld08			; if (FlagTurnOn == 0) {skip drawing frame}

			mov al, FlagInited
			cmp al, 00h				; if (FlagInited != 0) {skip init}
			jnz @@FrameInited
		   ;{
			inc al
			mov FlagInited, al		; ++FlagInited

			; mov ax, VIDEOSEG
			; mov es, ax
			; mov ax, 5e00h + 'W'
			; xor bx, bx
			; mov es:[bx], ax			; DEBUG

			;!!!{Инициализировать буфер для рамки} - выполнено?
			push cs
			pop ds					; DS = CS
			push cs
			pop es					; ES = CS

			mov ah, FRAMECOLOR
			mov cx, TEXTLINELEN
			mov dx, TEXTLINENUM
			mov si, offset FrameSample
			mov di, offset FrameBuffer
			call InitFrame			; Set frame params and initialize
		   ;}
@@FrameInited:
			;!!!{Поменять значения регистров в буфере}

			;!!!{Вывести рамку на экран}
			push cs
			pop ds					; DS = CS
			mov ax, VIDEOSEG
			mov es, ax				; ES = VIDEOSEG

			mov cx, FRAMECOLUM
			mov dx, FRAMEROW
			mov si, offset FrameBuffer

			mov di, FRAMESTART
			call DrawBuffer			; Set buffer aand screen params and initialize

			jmp ChainOld08

ChainOld08:	pop ax bx cx dx si di ds es   ; LOAD all* registers
			db 0eah					; <=> jmp
Old08Ofs	dw 0
Old08Seg	dw 0					; 0000:0000 (but it will be changed earlier)

@@Exit:		iret					; Interrupt return
			endp


;---------------------------------------------------------------
; Change registers in buffer
; Entry:	CX		= number of register
;			DS:SI	= pointer to stack where real registers are
;			ES:DI	= buffer
; Exit:		buffer with new registers
; Destr:	...
;---------------------------------------------------------------
ChangeRegs	proc

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Draw buffer on the screen
; Entry:	CX		= width of frame
;			DX		= height of frame
;			DS:SI	= buffer to draw
;			ES:DI	= begin of screen
;
; Exit:		CX		= 0
;			DX		= 0
;			SI		= SI + CX*DX
;
; Destr:	DI
;---------------------------------------------------------------
DrawBuffer	proc

@@NextLine:	push cx			; SAVE CX
@@NextChar:	lodsw
			stosw
			loop @@NextChar	; Put one line from buffer on the screen
			pop cx			; LOAD CX

			add di, SCREENSHFT	; Move to next line
			dec dx
			jnz @@NextLine	; Do DX times

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Initialize FrameBuffer as buffer for drawning frame
; Entry:	AH		= color attr
;			CX		= length of frame text
;			DX		= number of frame text lines
;			DS:SI	= frame sample
;			ES:DI	= frame buffer
;
; Exit: 	CX		= 0
;			DX		= 0
;			SI		= SI + 9
;			DI		= DI + (CX+4)*(DX+2)
;
; Destr:	none
;---------------------------------------------------------------
InitFrame	proc

			push cx				; Save CX
			call InitEdgeLine	; Init first line
			pop cx				; Load CX

@@LoopLines:					; Init central lines
		   ;{
			push si				; Save SI (to print same chars)

			push cx				; Save CX
			call InitTextLine	; Init central line
			pop cx				; Load CX

			pop si				; Load SI

			dec dx
			jnz @@LoopLines		; if (--dx != 0) goto LoopLines
		   ;}

			add si, 3h			; To print last 3 chars
			call InitEdgeLine	; Init last line

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Put one line in the frame buffer filled with chars from sample and text
; Entry:	AH		= color attr
;	 		CX		= length of frame text
;	 		DS:SI	= frame line sample
;			ES:BX	= text for frame
;	 		ES:DI	= buffer
;
; Exit: 	SI		= SI + 3
;	 		DI		= DI + (CX+4)
;
; Destr:	AL
;---------------------------------------------------------------
InitTextLine	proc

			; Put first two sample chars
			lodsb			; Take char from sample
			stosw			; Put color and char in buffer

			mov al, ds:[si]	; Take char from sample (SI not changed)
			stosw			; Put color and char in buffer

@@Next:		mov al, es:[bx]	; Take char from text
			inc bx			; ++BX

			stosw			; Put color and char in buffer
			loop @@Next		; Do CX times

			; Put last two sample chars
			lodsb
			stosw

			lodsb
			stosw

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Put one line in the frame buffer filled with chars from sample
; Entry:	AH		= color attr
;	 		CX		= length of frame text
;	 		DS:SI	= frame line sample
;	 		ES:DI	= buffer
;
; Exit: 	SI		= SI + 3
;	 		DI		= DI + (CX+4)
;
; Destr:	AL
;---------------------------------------------------------------
InitEdgeLine	proc

			; Put first two sample chars
			lodsb			; Take char from sample
			stosw			; Put color and char in buffer

			mov al, ds:[si]	; Take char from sample (SI not changed)
			stosw			; Put color and char in buffer

			rep stosw		; Put CX chars from middle of sample

			; Put last two sample chars
			lodsb
			stosw

			lodsb
			stosw

@@Exit:		ret
			endp



; DATA PART !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
.data
FrameBuffer:	dw FRAMESIZE dup (0)	; Init to save frame when it's off
OldScreenInit:	dw FRAMESIZE dup (0)	; Init to save part of screen when frame's on

RegsZeroLabel:	db "AX=0000BX=0000CX=0000DX=0000"				; Default frame label
FrameSample:	db 0fh, 07h, 0fh, 07h, ' ', 07h, 0fh, 07h, 0fh	; Frame sample

FlagTurnOn db 0d	; Flag = 1 (if frame is opened), = 0 (else)
FlagInited db 0d	; Flag = 1 (if frame is inited), = 0 (else)

EndOfCode:			; Just to set length of code

end Start
; END OF PROGRAM !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
