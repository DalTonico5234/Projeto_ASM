; tempo.asm - Temporização pela interrupção de hardware INT 8h (tique do PIT)
;
; Baseado no ClockINT do professor. A INT 8h chega ~18,2 vezes por segundo
; (a cada ~54,9 ms). A rotina só conta os tiques em "tiques" e repassa a
; interrupção para a rotina original da BIOS, que mantém o relógio do DOS e
; envia o fim de interrupção ao PIC. O laço do jogo consome os tiques: toda a
; animação e o tempo do round andam por tique, sem laços de atraso.

global instala_tempo, restaura_tempo, tiques, zera_tiques, espera_tique

segment code

;------------------------------------------------------------------------------
; instala_tempo: salva o vetor original da INT 8h e aponta para isr_tempo
instala_tempo:
		PUSH	AX
		PUSH	ES
		CLI
		XOR		AX,AX
		MOV		ES,AX						; ES = 0, região dos vetores de interrupção
		MOV		AX,[ES:INT8*4]				; IP original da INT 8h
		MOV		[int8_dos],AX
		MOV		AX,[ES:INT8*4+2]			; CS original da INT 8h
		MOV		[int8_dos+2],AX
		MOV		[ES:INT8*4+2],CS
		MOV		WORD [ES:INT8*4],isr_tempo
		STI
		POP		ES
		POP		AX
		RET

;------------------------------------------------------------------------------
; restaura_tempo: devolve o vetor original da INT 8h
restaura_tempo:
		PUSH	AX
		PUSH	ES
		CLI
		XOR		AX,AX
		MOV		ES,AX
		MOV		AX,[int8_dos+2]
		MOV		[ES:INT8*4+2],AX
		MOV		AX,[int8_dos]
		MOV		[ES:INT8*4],AX
		STI
		POP		ES
		POP		AX
		RET

;------------------------------------------------------------------------------
; isr_tempo: executada a cada tique do relógio (INT 8h)
isr_tempo:
		PUSH	AX
		PUSH	DS
		MOV		AX,data
		MOV		DS,AX
		INC		WORD [tiques]				; Mais um tique para o laço do jogo
		PUSHF								; Simula uma INT: a rotina original termina com IRET
		CALL	FAR [int8_dos]				; BIOS atualiza o relógio e envia o EOI ao PIC
		POP		DS
		POP		AX
		IRET

;------------------------------------------------------------------------------
; zera_tiques: descarta os tiques acumulados (depois de pausa ou menu, para
; o tempo parado não entrar no round)
zera_tiques:
		CLI
		MOV		WORD [tiques],0
		STI
		RET

;------------------------------------------------------------------------------
; espera_tique: dorme (HLT) até chegar uma interrupção. A próxima a chegar é
; a do relógio ou a do teclado, então o laço que chama volta logo a conferir.
espera_tique:
		STI
		HLT
		RET

segment data
		INT8		EQU	8h					; Interrupção de hardware do relógio
int8_dos	DW	0,0							; IP e CS originais da INT 8h
tiques		DW	0							; Tiques ainda não consumidos pelo jogo
