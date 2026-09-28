org 100h
	
start:
	push exprAsk
	call printMsg
	call newLine
	
	jmp getExpr
	retry:
		call newLine
		mov dx,retryMsg
		mov ah,9
		int 0x21
		mov dx,exprAsk
		int 0x21
		
	getExpr:
	mov ah,10
	mov dx,exprBuf
	int 0x21
	
	call makePost
	call evalPost
	call newLine
	
	mov ebx,edx
	push postMsg
	call printMsg
	mov dx,postfix
	mov ah,9
	int 0x21
	mov edx,ebx
	call printRes
	
	call exitProg
	
;data
exprAsk		dw	"Enter a mathematical expression (maximum 25 characters, no spaces): $"
retryMsg		db	"Please try again. $"
postMsg		db	"Expression in RPN (postfix notation): $"
resMsg	db	"Result: $"
errorMsg	db	"WARNING: Your expression contains an error. Reason: $"
divZero	db 	"division by zero. $"
charErr	db	"invalid character. Allowed characters are digits, (, ), +, -, *, and /. $"
emptyErr	db	"the expression is empty. $"
exprErr	db	"invalid expression structure. Operators may be misplaced or missing. $"
missOpen	db	"too few opening parentheses (or too many closing parentheses). $"
missClos	db	"too few closing parentheses (or too many opening parentheses). $"

exprBuf	db	26
		db	0
		times	27	db	'$'
postfix	times	33	db	'$'
fpStat	dw	0

;procedures

makePost:
	xor ax,ax
	xor bx,bx
	xor cx,cx
	xor dx,dx
	mov cl,[exprBuf+1]
	
	cmp cl,0
	jne nonEmpty			;handle an empty expression
	push emptyErr
	call showErr
	
	nonEmpty:
	mov di,postfix			;output
	mov si,exprBuf+2			;input
	mov bp,sp

	
	scanLoop:
		lodsb
		mov bx,ax				;copy the input operator to bx
		cmp al,byte '('			;check the input character
		je leftPar
		cmp al,byte ')'
		je rightPar
		cmp al,byte '*'
		je highOp
		cmp al,byte '/'
		je highOp
		cmp al,byte '+'
		je lowOp
		cmp al,byte '-'
		je lowOp
		cmp al,byte '0'
		jl badChar
		cmp al,byte '9'
		jbe digit
		
		badChar:
			push charErr
			call showErr
		
		highOp:					;operators with higher precedence
			cmp dh,byte '*'		;handle invalid operator sequences
			je opError
			cmp dh,byte '/'
			je opError
			cmp dh,byte '+'
			je opError
			cmp dh,byte '-'
			je opError
			
			jmp popOp
			opError:
				push exprErr
				call showErr
				
			popOp:
			pop dx
			cmp dx,byte '*'
			je emitOp
			cmp dx,byte '/'
			je emitOp
			
			
			push dx
			push bx
			jmp nextChar
			
			emitOp:
				mov al,dl
				stosb
				jmp highOp
		;jmp nextChar
		
		lowOp:					;operators with lower precedence
			cmp bp,sp
			je saveOp
			
			cmp dh,byte '*'		;handle invalid operator sequences
			je opError
			cmp dh,byte '/'
			je opError
			cmp dh,byte '+'
			je opError
			cmp dh,byte '-'
			je opError
				
			pop dx
			cmp dx,byte '('
			je keepOp
			mov al,dl
			stosb
			jmp lowOp
					
			jmp saveOp
			keepOp:
				push dx
				
			saveOp:
				push bx
		jmp nextChar
		
		leftPar:
			push bx
		jmp nextChar
		
		rightPar:
			popToPar:
				cmp bp,sp				;handle a missing opening parenthesis
				jne popMore
							
				mov sp,bp				
				push missOpen			
				call showErr
				
				popMore:
				pop dx
				cmp dl,byte '('
				je nextChar
				
				mov al,dl
				stosb
				jmp popToPar
		
		;jmp nextChar
		
		digit:			;case for a number
			cmp dh,byte '*'
			je emitSp
			cmp dh,byte '/'
			je emitSp
			cmp dh,byte '+'
			je emitSp
			cmp dh,byte '-'
			je emitSp
			cmp dh,byte '('
			je firstNum
			cmp dh,57
			jbe emitNum
			
			firstNum:
				cmp di,postfix
				je emitNum
			
			emitSp:
				mov al,32
				stosb
			
			emitNum:
				mov al,bl
				stosb
		
	nextChar:		
	mov dh,bl			;save the previous input character in dh
	sub cx,1
	jnz scanLoop
	
	flushStk:
		cmp bp,sp
		je parseEnd
		pop ax
		cmp ax, byte '('		;handle too few closing parentheses
		jne emitStk
		push missClos
		call showErr
		
		emitStk:
		stosb
		jmp flushStk
	parseEnd:
	
ret

evalPost:					;evaluate the postfix expression in *postfix* and leave the result in dx
	finit
	mov bp,sp			;configure the FPU to truncate division results
	sub sp,2
	mov bp,sp
	fstcw [bp]
	or word [bp],0x600
	fldcw [bp]
	add sp,2

	mov si,postfix
	xor ah,ah
	xor edx,edx
	xor cx,cx
	mov cx,10
	xor bx,bx			;bx stores the previous character
	
	
	evalLoop:
		lodsb
		
		cmp bl,0		;check whether this is the first character in the string
		jne notFirst
		cmp si,di			;handle invalid operator sequences
		jne startVal		
			push exprErr
			call showErr
		startVal:
		mov bl,al
		sub bl,48
		mov dl,bl
		jmp nextEval
		
		notFirst:
		cmp al,48
		jb evalOp
			
		accumNum:
			cmp di,si
			jne numberOk
				push exprErr
				call showErr
			numberOk:
			mov bl,al	
			mov ax,dx
			mul cx			;multiply ax by 10 and clear dx
			mov dx,ax
			mov ax,bx
			sub ax,48
			add dx,ax
			xor ah,ah
		jmp evalLoop
			
		evalOp:
			cmp bl,48		;check whether the previous character was a digit
			jb applyOp			
			push edx
			xor dx,dx
			cmp al,32
			je nextEval
		
			applyOp:
			cmp al,32
			je nextEval
			
			mov bp,sp
			fild dword [bp]
			add sp,4
			mov bp,sp
			fild dword [bp]
			
			cmp al,byte '*'
			je multiply
			cmp al,byte '/'
			je divide
			cmp al,byte '+'
			je addRes
			cmp al,byte '-'
			je subtract
				
			push exprErr				;handle invalid operator sequences
			call showErr
			
			multiply:
				fmulp
				fistp dword [bp]
			jmp nextEval
			
			divide:
			
				fdivrp
				fstsw [fpStat]
				and word [fpStat], 0x4
				cmp word [fpStat],4
				jne storeRes
				
				push divZero
				call showErr
				
				storeRes:
				fistp dword [bp]
				
			jmp nextEval
			
			addRes:
				faddp
				fistp dword [bp]
			jmp nextEval
			
			subtract:
				fsubrp
				fistp dword [bp]
			jmp nextEval
			
		nextEval:
		mov bl,al				;save the current character for comparison in the next iteration
		cmp si,di
	jne evalLoop
	pop edx
ret

printRes:					;display the value in edx as a decimal number
	push resMsg
	call printMsg
	
	cmp edx,0			;display a negative result
	jge nonNeg
	mov ah,2
	mov ecx,edx
	mov dl,byte '-'
	int 0x21
	mov edx,ecx
	neg edx
	
	nonNeg:
	mov eax,edx
	xor edx,edx
	xor ecx,ecx
	mov ebx,10
	
	divLoop:
		inc cx
		div ebx
		push edx
		xor edx,edx
		
		cmp eax,0
		jne divLoop
		
	mov ah,2
	printDig:
		pop edx
		add edx,48
		int 0x21
		loop printDig
		
ret

showErr:
	pusha
	pushf
	push errorMsg
	call printMsg
	
	mov bp,sp
	mov dx,[bp+20]
	
	mov ah,9
	int 0x21
	
	mov cx,4
	mov bx,postfix
	clearBuf:
		pxor mm0,mm0
		movq [bx],mm0
		add bx,8
	loop clearBuf
	emms
	
	popf
	popa
	add sp,4
	
	jmp retry

;---------------formatting/debugging--------------------
putChar:
	pusha
	pushf
	
	mov bp,sp
	mov bx,[bp+18]
	mov dx,[bp+20]
	mov [bp+20],bx
	
	mov ah,2
	int 0x21
	
	popf
	popa
	add sp,2
ret

printA:
	pusha
	pushf
	
	mov ah,2
	mov dx,65
	int 0x21
	
	popf
	popa
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
	pusha
	pushf
	
	mov ah,2
	mov dl,10
	int 0x21
	mov dl,13
	int 0x21
	
	popf
	popa
ret

exitProg:
	add sp,2
	mov	ax, 4C00h
	int	21h 