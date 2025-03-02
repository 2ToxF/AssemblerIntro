.model tiny
.code
org 100h
Start:			mov dx, offset String	; dx = String
			mov ah, 09h		; DOS Func 09h = puts(dx)
			int 21h

			mov ax, 4c00h		; DOS Func 4ch = exit(al)
			int 21h

.data
String: db "Hello, Toxa! :copyright:", 0dh, 0ah, '$'

end Start

Here I can write EvERYthiNg i want :)
