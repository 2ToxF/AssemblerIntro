.model tiny
.code
org 100h
locals @@



; CONSTANTS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
PASSW_BUFFER_LEN    equ 10d             ; Password buffer length
CORRECT_PASSW_LEN   equ 6d              ; Correct password length



; MAIN CODE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Start:
                call ProgEmulate

                mov ax, 4c00h           ; exit(0)
                int 21h                 ; syscall


;---------------------------------------------------------------
; Emulates password-secured program
; Entry:	none
; Exit:		none
; Destr:	{NEED_TO_UPDATE}
;---------------------------------------------------------------
ProgEmulate     proc

                call EnterPassword
                call CheckPassword
                jz @@Correct
                mov dx, offset WrongMessage
                mov ah, 09h     ; puts(WrongMessage)
                int 21h
                jmp @@Exit
@@Correct:
                mov dx, offset CorrectMessage
                mov ah, 09h     ; puts(CorrectMessage)
                int 21h

@@Exit:         ret
                endp


;---------------------------------------------------------------
; Wait for password in stdin
; Entry:	none
; Exit:		password in PasswordBuffer
; Destr:	AX DI
;---------------------------------------------------------------
EnterPassword   proc

                mov di, offset PasswordBuffer   ; Pointer to buffer
                mov ah, 01h         ; getchar()

@@Loop:         int 21h             ; syscall
                cmp al, 0dh         ; '\r' (means end of input)
                jz @@EndLoop        ; while (getchar() != '\r')

                mov [di], al        ; Put character to buffer
                inc di              ; Go to next char
                jmp @@Loop

@@EndLoop:

@@Exit:         ret
                endp


;---------------------------------------------------------------
; Compare password from PasswordBuffer to CorrectPassword
; Entry:	PasswordBuffer  = password to check
;           CorrectPassword = correct password
; Exit:		ZF = 0 (if password is correct), 1 (else)
; Destr:	AL CX SI DI
;---------------------------------------------------------------
CheckPassword   proc

                mov cx, CORRECT_PASSW_LEN
                mov si, offset PasswordBuffer
                mov di, offset CorrectPassword

@@Loop:         mov al, [si]
                cmp al, [di]
                jnz @@EndLoop   ; if ([si] != [di]) break
                inc si
                inc di          ; Go to next characters in both buffers
                loop @@Loop     ; Loop CX times
                cmp al, al      ; Set zero flag
@@EndLoop:

@@Exit:         ret
                endp



; DATA PART !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
.data
CorrectMessage:     db "Good job! You got access!", 0ah, '$'    ; Message to print if password was entered correctly
WrongMessage:       db "Oops, seems you have no access :/", 0ah, '$'
                    ; Message to print if password was entered incorrectly

PasswordBuffer:     db PASSW_BUFFER_LEN dup (0) ; Buffer to save input data
CorrectPassword:    db "123456"                 ; Correct password



end Start
; END OF CODE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
