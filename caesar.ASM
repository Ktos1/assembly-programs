org 100h

start:	
	call newLine
	push welcome
	call printMsg
	
menuLoop:
	call newLine
	call showMenu
	mov ah,1
	int 0x21
	cmp al,50
	je exitNow
	
	call newLine
	call doCipher
	
	jmp menuLoop
	
	exitNow:
	call exitProg

;------------------------data------------------------------
shiftMsg db	"Enter the Caesar cipher shift (maximum 65535): $"
textMsg	db	"Enter a message to encrypt (maximum 24 characters): $"
cryptMsg	db	"Your encrypted message: $"
waitMsg	db	"Press any key to continue... $"

welcome	db	"Welcome! Enter the number for the action you want to perform. The options are listed below: $"
cryptOpt	db	"1. Encrypt $"
exitOpt	db	"2. Exit $"
choose	db	"Choose an option: $"
exitMsg	db	"Program ended. Goodbye! $"

textBuf	db	24
		db	0
		times	26	db	"$"

shiftBuf	db	6
		db	0
		times	7	db	"$"
		
allOnes	times	8	db	0xFF

upBase	times	8	db	64		;character before A
upLast	times	8	db	90		;uppercase Z
lowBase	times	8	db 	96		;character before a
lowLast	times	8	db	122		;lowercase z
alphaN	times	8	db	26		;number of letters in the ASCII alphabet

		


;----------------------procedures------------------------

;----------------------menu------------------------------

doCipher:
	push shiftMsg
	call printMsg
	call getShift
	call newLine
	push textMsg
	call printMsg
	call getInput
	call newLine
	call encrypt
	push cryptMsg
	call printMsg
	call printBuf
	
	call newLine
	push waitMsg
	call printMsg
	mov ah,7
	int 0x21
	call newLine
	call newLine
ret

exitProg:
	call newLine
	mov ah,9
	mov dx,exitMsg
	int 0x21

	pop cx
	mov ax,0x4C00
	int 21h
ret

showMenu:
	mov ah,9
	mov dx,cryptOpt
	int 0x21
	call newLine
	mov dx,exitOpt
	int 0x21
	call newLine
	mov dx,choose
	int 0x21	
ret
;----------------------main program flow-----------------

encrypt:					;encrypt the converted string in *textBuf*
	pop cx
	xor edx,edx
	pop dx				;shift
	push cx
	mov cx,3
	mov bx,textBuf+2		;pointer to the data block			
	
	movq mm1, [allOnes]		;mm1 = all ones
	movd mm7,edx			;mm7 = shift replicated across all bytes
	
	punpcklbw mm7,mm7
	punpcklwd mm7,mm7
	punpckldq mm7,mm7
	
	nextFrag:
		movq mm0, [bx]			;mm0 = 8 bytes of text
		
		;detect and encrypt uppercase letters
		movq mm6, [upBase]	
		movq mm5, [upLast]
		
		movq mm4,mm0		;check whether the character is greater than or equal to A
		pcmpgtb mm4,mm6	
		
		movq mm3,mm0		;check whether the character is less than or equal to Z
		pcmpgtb mm3,mm5
		pandn mm3,mm1
		
		pand mm4,mm3			;mm4 = mask with 1s for uppercase letters
		
		movq mm3,mm0
		paddb mm3,mm7			;mm3 = all characters shifted by the requested amount
		
		movq mm6, [alphaN]	;wrap around the alphabet
		movq mm2,mm3
		pcmpgtb mm2,mm5
		pand mm6,mm2
		
		psubb mm3,mm6
		pand mm4,mm3
		movq mm2,mm4			;mm2 = encrypted uppercase letters
		
		
		;detect and encrypt lowercase letters
		movq mm6, [lowBase]	
		movq mm5, [lowLast]
		
		movq mm4,mm0		;check whether the character is greater than or equal to a
		pcmpgtb mm4,mm6	
		
		movq mm3,mm0		;check whether the character is less than or equal to z
		pcmpgtb mm3,mm5
		pandn mm3,mm1
		
		pand mm4,mm3			;mm4 = mask with 1s for lowercase letters
		
		movq mm5, [alphaN]	;mm5 = 26 in every byte ;wrap around the alphabet
		movq mm3,mm0			;mm3 = all characters
		paddb mm3,mm7			;mm3 = all characters shifted by the requested amount
		psubb mm3,mm5			;mm3 = shifted characters minus 26
		
		movq mm0,mm3			;mm0 = mm3
		pcmpgtb mm0,mm6			;mm0 = mask with 1s for bytes greater than 96
		pandn mm0,mm1			;mm0 = mask with 1s for bytes less than or equal to 96
		pand mm5,mm0			;mm5 = 26 for bytes less than 97
		
		paddb mm3,mm5
		pand mm4,mm3
		movq mm0,mm4			;mm0 = encrypted lowercase letters
		
		
		;combine uppercase and lowercase letters
		por mm0,mm2
		
		movq [bx],mm0
		
		add bx,8
	cmp cx,0
	dec cx
	jne nextFrag
	emms
ret

getShift:					;read the shift and place it on the stack
	mov bp,sp	
	push word [bp]

	mov dx,shiftBuf
	mov ah,10
	int 0x21
	
	mov bx,shiftBuf+2		;convert the string to a number
	xor ch,ch
	mov cl,[shiftBuf+1]
	xor ax,ax
	numLoop:
		sub [bx],byte 48
		mov dx,[bx]			;[bx] is 8-bit, so load it into dx before adding it to ax to avoid including the next byte
		xor dh,dh
		add ax,dx			
		cmp cl,1
		je mulDone
		mov dx,10
		mul dx
		
		mulDone:
		inc bx
		loop numLoop
	
	mov bx,25				;reduce the shift
	xor dx,dx
	div bx
	
	mov [bp],dx
ret

printBuf:
	push dx
	push ax
	
	mov dx,textBuf+2
	mov ah,9
	int 0x21
	
	pop ax
	pop dx
ret

printMsg:
	pusha
	pushf
	call newLine
	
	mov bp,sp
	mov bx,[bp+18]
	mov dx,[bp+20]
	mov [bp+20],bx
	
	mov ah,9
	int 0x21
	
	popf
	popa
	add sp,2
ret

getInput:					;store the input characters in *textBuf*
	mov cx,3
	mov bx,textBuf+2
	clearBuf:
		pxor mm0,mm0
		movq [bx],mm0
		add bx,8
	loop clearBuf
	emms
	
	mov ah,10
	mov dx,textBuf
	int 0x21
ret

;-----------------formatting-----------------------------
printA:
	pusha
	pushf
	
	mov ah,2
	mov dx,65
	int 0x21
	
	popf
	popa
ret
printSp:
	push dx
	push ax
	
	mov ah,2
	mov dl,32
	int 0x21

	pop ax
	pop dx
ret

newLine:
	push dx
	push ax

	mov ah,2
	mov dl,10
	int 21h
	mov dl,13
	int 21h
	
	pop ax
	pop dx
ret