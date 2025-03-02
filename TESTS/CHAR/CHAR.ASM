.model tiny
.code
org 100h
Start:			mov dl, 21h	; 21h = '!'
			mov ah, 02h	; DOS Func 02h = putchar(al)
			int 21h

			mov ax, 4c00h
			int 21h

.data

end Start
