; init.asm - Inicialização e encerramento do sistema
;
; inicializa: guarda o modo de vídeo do DOS e instala as interrupções do jogo.
; encerra: devolve o modo de vídeo e os vetores originais das INT 8h e 9h e
; volta ao DOS. Toda saída do programa (Game Over ou tecla Q) passa por aqui.

extern instala_teclado, restaura_teclado, instala_tempo, restaura_tempo
global inicializa, encerra

segment code

;------------------------------------------------------------------------------
inicializa:
		PUSH	AX
		MOV		AH,0Fh						; Lê o modo de vídeo atual (AL = modo)
		INT		10h
		MOV		[modo_anterior],AL
		CALL	instala_teclado				; INT 9h: teclado do jogo
		CALL	instala_tempo				; INT 8h: tiques do jogo
		POP		AX
		RET

;------------------------------------------------------------------------------
encerra:
		CALL	restaura_tempo				; Vetores originais de volta
		CALL	restaura_teclado
		MOV		AH,0						; Modo de vídeo original de volta
		MOV		AL,[modo_anterior]
		INT		10h
		MOV		AX,4C00h					; Volta ao DOS
		INT		21h

segment data
modo_anterior	DB	0
