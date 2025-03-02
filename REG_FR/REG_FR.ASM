.model tiny
.code
org 100h
locals @@

; CONSTANTS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
VIDEOSEG	equ 0b800h					; Start of video segment

TEXTLINELEN	equ 7d						; Length of one text line of frame
TEXTLINENUM equ 13d						; Number of lines in text of frame

FRAMESTART	equ 2d*80d*2d + 65d*2d		; Left upper corner of the frame
FRAMECOLUM	equ TEXTLINELEN + 4d		; Number of frame columns with edges (width)
FRAMEROW	equ TEXTLINENUM + 2d		; Number of frame rows with edges (height)
FRAMESIZE	equ FRAMECOLUM*FRAMEROW*2d	; Size of registers frame

FRAMECOLOR	equ byte ptr 0ch			; Color of the frame

SCREENSHFT	equ 80d*2d - FRAMECOLUM*2	; Value to move to next line from the end of current
BUFFERSHIFT	equ (FRAMECOLUM - 4d)*2		; To move to next register value in buffer

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

			push ax cx dx ds si es di	; SAVE AX CX DX DS DI ES DI

			push cs
			pop ds					; DS = CS (to access variables)
			mov ax, VIDEOSEG
			mov es, ax				; ES = VIDEOSEG

			mov cx, FRAMECOLUM
			mov dx, FRAMEROW
			mov di, FRAMESTART		; Set params for drawing and saving buffers

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

			cmp FlagTurnOn, 00h
			jz @@FrameIsOff			; if (FlagTurnOn != 0) {save screen and draw FrameBuffer}
		   ;{
		    mov si, offset OldScreenBuffer
			push cx dx di			; SAVE CX DX DI
			call SaveBuffer
			pop di dx cx			; LOAD DI DX CX
			mov si, offset FrameBuffer
			call DrawBuffer
			jmp @@EndIfTurnOn
		   ;}
@@FrameIsOff:						; else {draw OldScreenBuffer}
		   ;{
			mov si, offset OldScreenBuffer
			call DrawBuffer
		   ;}
@@EndIfTurnOn:

ChainOld09: pop di es si ds dx cx ax	; LOAD DI ES SI DS DX CX AX
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

			push bp sp ss di es si ds dx cx bx ax	; SAVE all* registers

			push cs
			pop ds					; DS = CS (to access variables)

			mov al, FlagTurnOn
			cmp al, 00h
			jz ChainOld08			; if (FlagTurnOn == 0) {skip drawing frame}

			mov al, FlagInited
			cmp al, 00h				; if (FlagInited != 0) {skip init}
			jnz @@FrameInited
		   ;{
			inc al
			mov FlagInited, al		; ++FlagInited

			push cs
			pop es					; ES = CS

			mov ah, FRAMECOLOR
			mov bx, offset RegsZeroLabel
			mov cx, TEXTLINELEN
			mov dx, TEXTLINENUM
			mov si, offset FrameSample
			mov di, offset FrameBuffer
			call InitFrame			; Set frame params and initialize
		   ;}
@@FrameInited:
			push cs
			pop es					; ES = CS
			push ss
			pop ds					; DS = SS

			mov cx, 13				; 13 registers to update
			mov si, sp
			mov di, offset FrameBuffer
			add di, (FRAMECOLUM + 5)*2	; Skip one line and first characters in buffer

			call ChangeRegs			; Set buffer and stack params and change registers values in buffer

			push cs
			pop ds					; DS = CS
			mov ax, VIDEOSEG
			mov es, ax				; ES = VIDEOSEG

			mov cx, FRAMECOLUM
			mov dx, FRAMEROW
			mov si, offset FrameBuffer

			mov di, FRAMESTART
			call DrawBuffer			; Set buffer and screen params and draw buffer

ChainOld08:	pop ax bx cx dx ds si es di ss sp bp	; LOAD all* registers
			db 0eah					; <=> jmp
Old08Ofs	dw 0
Old08Seg	dw 0					; 0000:0000 (but it will be changed earlier)

@@Exit:		iret					; Interrupt return
			endp


;---------------------------------------------------------------
; Change registers in buffer
; Entry:	CX		= number of registers
;			DS:SI	= pointer to stack where real registers are
;			ES:DI	= buffer
; Exit:		buffer with new registers
; Destr:	AX
;---------------------------------------------------------------
ChangeRegs	proc

@@NextReg:	mov ax, ds:[si]			; Load register from stack

			call NumberToHex

			add si, 2				; Go to next register (+ 2 bytes)
			add di, BUFFERSHIFT		; Go to next register value in buffer
			loop @@NextReg			; Do CX times

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Convert 4 bits (hex-digit) to ascii (hex)
; Entry:	AL	= digit to convert (0d <= Al <= 15d)
; Exit:		AL	= digit in ascii (hex)
; Destr:	none
;---------------------------------------------------------------
DigitToHex	proc

			add al, '0'			; Convert decimal digit
			cmp al, '9'
			jbe @@Exit

			add al, 'A' - '9' - 1	; if (al > '9') al += 'A' - '9' - 1

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Convert 1 byte (2 hex digits) to ascii (hex)
; Entry:	AL 		= byte to convert
;			ES:DI	= buffer to put digits
; Exit:		string with converted byte
;			DI 		= DI + 4
; Destr:	AH
;---------------------------------------------------------------
ByteToHex	proc

			mov ah, al

			shr al, 4			; First goes most significant digit
			call DigitToHex		; Convert digit to ascii (hex)
			stosb				; Put hex in buffer
			inc di				; Skip color attr

			mov al, ah
			and al, 0fh			; Now least significant digit
			call DigitToHex		; Convert digit to ascii (hex)
			stosb				; Put hex in buffer
			inc di				; Skip color attr

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Convert number (4 hex digits) to ascii (hex)
; Entry:	AX 		= number to convert
;			ES:DI	= buffer to put digits
; Exit:		string with converted byte
;			DI 		= DI + 4
; Destr:	none
;---------------------------------------------------------------
NumberToHex	proc

			xchg ah, al			; First goes most significant digit
			push ax				; SAVE AX
			call ByteToHex		; Convert and put in buffer
			pop ax				; LOAD AX

			xchg ah, al			; Now least significant digit
			push ax				; SAVE AX
			call ByteToHex		; Convert and put in buffer
			pop ax				; LOAD AX

@@Exit:		ret
			endp


;---------------------------------------------------------------
; Save part of screen in buffer
; Entry:	CX		= width of frame
;			DX		= height of frame
;			DS:SI	= buffer where to save
;			ES:DI	= begin of screen
;
; Exit:		CX		= 0
;			DX		= 0
;			SI		= SI + CX*DX
;
; Destr:	DI
;---------------------------------------------------------------
SaveBuffer	proc


@@NextLine:	push cx			; SAVE CX
@@NextChar:	mov ax, es:[di]	; Save character and move to next
			add di, 2

			mov ds:[si], ax	; Put character in buffer and move to next
			add si, 2

			loop @@NextChar	; Put one line from buffer on the screen
			pop cx			; LOAD CX

			add di, SCREENSHFT	; Move to next line
			dec dx
			jnz @@NextLine	; Do DX times

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
FrameBuffer:		dw FRAMESIZE dup (0)	; Buffer to save frame when it's off
OldScreenBuffer:	dw FRAMESIZE dup (0)	; Buffer to save part of screen when frame's on

RegsZeroLabel:	db "AX=0000BX=0000CX=0000DX=0000DS=0000SI=0000ES=0000DI=0000"
				db "SS=0000SP=0000BP=0000CS=0000IP=0000"	; Default frame label
FrameSample:	db 0dah, 0c4h, 0bfh, 0b3h, ' ', 0b3h, 0c0h, 0c4h, 0d9h	; Frame sample

FlagTurnOn db 0d	; Flag = 1 (if frame is opened), = 0 (else)
FlagInited db 0d	; Flag = 1 (if frame is inited), = 0 (else)

EndOfCode:			; Just to set length of code

end Start
; END OF PROGRAM !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
