; grafico.asm - Interface gráfica: tela, textos, arena e placar
;
; Usa as funções gráficas (line, circle, full_circle, cursor,
; caracter, plot_xy) no modo 12h (640x480, 16 cores). Coordenadas no padrão
; do plot_xy: x de 0 a 639 e y de 0 a 479, com y = 0 na parte de baixo.
; Texto: linha 0-29 (de cima para baixo) e coluna 0-79.

%include "defs.inc"

extern line, circle, full_circle, cursor, caracter
extern aplica_paleta, desenha_cenario, restaura_fundo, fundo_pronto
global cor, limpa_tela, ret_cheio, retangulo, escreve, escreve_centro, apaga_centro
global caixa_aberta, caixa_mensagem, desenha_arena, desenha_energia, desenha_rounds, desenha_tempo
global escreve_morte_subita

segment code

;------------------------------------------------------------------------------
; limpa_tela: entra (de novo) no modo 12h, o que também apaga a tela inteira,
; e põe a paleta retrowave
limpa_tela:
		PUSH	AX
		MOV		AX,0012h					; AH = 0 (muda modo), AL = 12h (640x480 16 cores)
		INT		10h
		CALL	aplica_paleta
		MOV		BYTE [fundo_pronto],0		; O cenário precisa ser desenhado de novo
		MOV		BYTE [caixa_aberta],0
		POP		AX
		RET

;------------------------------------------------------------------------------
; ret_cheio: retângulo preenchido com a cor em [cor]
; PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL ret_cheio  (x1<=x2, y1<=y2)
ret_cheio:
		PUSH	BP
		MOV		BP,SP
		PUSH	AX
		PUSH	BX
		PUSH	CX
		MOV		BX,[BP+8]					; y = y1
		MOV		CX,[BP+4]					; y2
rc_laco:
		MOV		AX,[BP+10]					; Uma reta horizontal de x1 a x2 na altura y
		PUSH	AX
		PUSH	BX
		MOV		AX,[BP+6]
		PUSH	AX
		PUSH	BX
		CALL	line
		INC		BX
		CMP		BX,CX
		JBE		rc_laco
		POP		CX
		POP		BX
		POP		AX
		POP		BP
		RET		8

;------------------------------------------------------------------------------
; retangulo: contorno de retângulo com a cor em [cor]
; PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL retangulo
retangulo:
		PUSH	BP
		MOV		BP,SP
		PUSH	AX
		PUSH	WORD [BP+10]				; Lado de baixo: (x1,y1)-(x2,y1)
		PUSH	WORD [BP+8]
		PUSH	WORD [BP+6]
		PUSH	WORD [BP+8]
		CALL	line
		PUSH	WORD [BP+10]				; Lado de cima: (x1,y2)-(x2,y2)
		PUSH	WORD [BP+4]
		PUSH	WORD [BP+6]
		PUSH	WORD [BP+4]
		CALL	line
		PUSH	WORD [BP+10]				; Lado esquerdo: (x1,y1)-(x1,y2)
		PUSH	WORD [BP+8]
		PUSH	WORD [BP+10]
		PUSH	WORD [BP+4]
		CALL	line
		PUSH	WORD [BP+6]					; Lado direito: (x2,y1)-(x2,y2)
		PUSH	WORD [BP+8]
		PUSH	WORD [BP+6]
		PUSH	WORD [BP+4]
		CALL	line
		POP		AX
		POP		BP
		RET		8

;------------------------------------------------------------------------------
; escreve: escreve a string terminada em 0 apontada por SI
; DH = linha (0-29), DL = coluna (0-79), cor em [cor]
escreve:
		PUSH	AX
		PUSH	DX
		PUSH	SI
esc_laco:
		MOV		AL,[SI]
		OR		AL,AL						; Fim da string
		JZ		esc_fim
		CALL	cursor
		CALL	caracter
		INC		SI							; Próximo caractere
		INC		DL							; Avança a coluna
		JMP		esc_laco
esc_fim:
		POP		SI
		POP		DX
		POP		AX
		RET

;------------------------------------------------------------------------------
; escreve_centro: escreve a string de SI centralizada na linha DH
escreve_centro:
		PUSH	AX
		PUSH	DX
		PUSH	SI
		XOR		AX,AX						; Conta os caracteres da string
ec_conta:
		CMP		BYTE [SI],0
		JE		ec_achou
		INC		SI
		INC		AX
		JMP		ec_conta
ec_achou:
		POP		SI
		PUSH	SI
		SHR		AX,1						; Coluna = 40 - tamanho/2
		MOV		DL,40
		SUB		DL,AL
		CALL	escreve
		POP		SI
		POP		DX
		POP		AX
		RET

;------------------------------------------------------------------------------
; apaga_centro: apaga o texto de SI escrito com escreve_centro na linha DH.
; Com o cenário na tela, repinta o retângulo do texto com as cores do fundo;
; senão reescreve o texto na cor do fundo.
apaga_centro:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	SI
		CMP		BYTE [fundo_pronto],0
		JE		ac_reescreve
		XOR		CX,CX						; CX = tamanho do texto
ac_conta:
		CMP		BYTE [SI],0
		JE		ac_contou
		INC		SI
		INC		CX
		JMP		ac_conta
ac_contou:
		MOV		AX,CX						; Coluna = 40 - tamanho/2 (como em escreve_centro)
		SHR		AX,1
		MOV		BX,40
		SUB		BX,AX
		SHL		BX,1						; x1 = coluna * 8
		SHL		BX,1
		SHL		BX,1
		PUSH	BX
		MOV		AL,16						; A linha de texto DH ocupa as linhas da tela
		MUL		DH							; DH*16 a DH*16+15: y = 464-DH*16 a 479-DH*16
		MOV		SI,464
		SUB		SI,AX
		PUSH	SI
		SHL		CX,1						; x2 = x1 + tamanho*8 - 1
		SHL		CX,1
		SHL		CX,1
		ADD		BX,CX
		DEC		BX
		PUSH	BX
		ADD		SI,15
		PUSH	SI
		CALL	restaura_fundo
		JMP		ac_fim
ac_reescreve:
		MOV		AL,[cor]
		MOV		BYTE [cor],C_FUNDO
		CALL	escreve_centro
		MOV		[cor],AL
ac_fim:
		POP		SI
		POP		CX
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; caixa_mensagem: caixa com borda no meio da tela e a string de SI dentro
; (caixa_aberta = 1 avisa redesenha_luta que precisa apagá-la)
caixa_mensagem:
		PUSH	AX
		PUSH	DX
		MOV		BYTE [caixa_aberta],1
		MOV		AL,[cor]
		PUSH	AX
		MOV		BYTE [cor],C_FUNDO			; Fundo da cor do céu
		MOV		AX,176
		PUSH	AX
		MOV		AX,226
		PUSH	AX
		MOV		AX,463
		PUSH	AX
		MOV		AX,268
		PUSH	AX
		CALL	ret_cheio
		MOV		BYTE [cor],C_NEON_ROSA		; Borda dupla em neon
		MOV		AX,176
		PUSH	AX
		MOV		AX,226
		PUSH	AX
		MOV		AX,463
		PUSH	AX
		MOV		AX,268
		PUSH	AX
		CALL	retangulo
		MOV		AX,179
		PUSH	AX
		MOV		AX,229
		PUSH	AX
		MOV		AX,460
		PUSH	AX
		MOV		AX,265
		PUSH	AX
		CALL	retangulo
		MOV		BYTE [cor],C_SOL_AMAR
		MOV		DH,14						; Linha 14 fica no meio da caixa
		CALL	escreve_centro
		POP		AX
		MOV		[cor],AL
		POP		DX
		POP		AX
		RET

;------------------------------------------------------------------------------
; desenha_arena: cenário (com os delimitadores da arena), chão e dica de teclas
desenha_arena:
		PUSH	AX
		PUSH	DX
		PUSH	SI
		CALL	desenha_cenario				; Sol, montanhas, palmeiras, grade, carro e borda
		MOV		BYTE [cor],C_NEON_ROSA		; Faixa neon abaixo do chão
		MOV		AX,ARENA_X1
		PUSH	AX
		MOV		AX,ARENA_Y1-6
		PUSH	AX
		MOV		AX,ARENA_X2
		PUSH	AX
		MOV		AX,ARENA_Y1-2
		PUSH	AX
		CALL	ret_cheio
		MOV		BYTE [cor],C_LILAS			; Dica de teclas abaixo da arena
		MOV		DH,28
		MOV		SI,str_dica
		CALL	escreve_centro
		POP		SI
		POP		DX
		POP		AX
		RET

;------------------------------------------------------------------------------
; desenha_energia: barra de energia de um lutador, com 10 triângulos no
; estilo Karateka. SI = lutador, DL = 0 para o lado esquerdo, 1 para o direito.
; Triângulo aceso (cor do lutador) = energia que resta; apagado = energia perdida.
; Usa J_DENER para redesenhar só os triângulos que mudaram.
desenha_energia:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	DI
		MOV		BX,20						; x da ponta de trás do primeiro triângulo
		MOV		DI,20						; passo entre triângulos (com sinal)
		OR		DL,DL
		JZ		de_lado_ok
		MOV		BX,619						; Lado direito: começa na borda e vem para o centro
		MOV		DI,-20
de_lado_ok:
		XOR		CX,CX						; CX = índice do triângulo (0-9)
de_laco:
		MOV		AL,[SI+J_DENER]				; Só desenha o que mudou desde a última vez:
		CMP		AL,0FFh						; os triângulos entre a energia atual e a
		JE		de_desenha					; desenhada (0FFh = tela nova, desenha todos)
		CMP		CL,[SI+J_ENER]
		JB		de_proximo
		CMP		CL,AL
		JAE		de_proximo
de_desenha:
		MOV		AL,[SI+J_COR]
		CMP		CL,[SI+J_ENER]				; Triângulos abaixo da energia ficam acesos
		JB		de_cor_ok
		MOV		AL,C_HALO
de_cor_ok:
		MOV		[cor],AL
		PUSH	BX
		PUSH	DI
		CALL	triangulo
de_proximo:
		ADD		BX,DI
		INC		CX
		CMP		CX,ENERGIA
		JB		de_laco
		MOV		AL,[SI+J_ENER]
		MOV		[SI+J_DENER],AL
		POP		DI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; triangulo: triângulo cheio de 15x15 apontando para o centro da tela
; PUSH x (lado de trás); PUSH passo (positivo = aponta para a direita)
triangulo:
		PUSH	BP
		MOV		BP,SP
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		MOV		BX,[BP+6]					; x da coluna atual
		MOV		CX,14						; meia-altura*2 da coluna atual (diminui até 0)
tr_laco:
		MOV		DX,CX
		SHR		DX,1						; DX = meia-altura desta coluna
		PUSH	BX							; Reta vertical de (x, 432-DX) a (x, 432+DX)
		MOV		AX,432
		SUB		AX,DX
		PUSH	AX
		PUSH	BX
		MOV		AX,432
		ADD		AX,DX
		PUSH	AX
		CALL	line
		TEST	WORD [BP+4],8000h			; Anda uma coluna para o lado da ponta
		JNZ		tr_esq
		INC		BX
		JMP		tr_prox
tr_esq:
		DEC		BX
tr_prox:
		DEC		CX
		JNS		tr_laco
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POP		BP
		RET		4

;------------------------------------------------------------------------------
; desenha_rounds: marcadores de rounds vencidos de um lutador (dois círculos)
; SI = lutador, DL = 0 para o lado esquerdo, 1 para o direito
desenha_rounds:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		MOV		BX,26						; x do primeiro marcador
		MOV		CX,18						; distância entre marcadores
		OR		DL,DL
		JZ		dr_lado_ok
		MOV		BX,613
		MOV		CX,-18
dr_lado_ok:
		MOV		AL,1						; Marcador 1 aceso se venceu ao menos 1 round
		CALL	dr_marcador
		ADD		BX,CX
		MOV		AL,2						; Marcador 2 aceso se venceu 2 rounds
		CALL	dr_marcador
		POP		CX
		POP		BX
		POP		AX
		RET
dr_marcador:								; AL = rounds necessários, BX = x
		PUSH	AX
		CMP		[SI+J_VIT],AL
		JB		dr_vazio
		MOV		AL,[SI+J_COR]				; Round vencido: círculo cheio na cor do lutador
		MOV		[cor],AL
		PUSH	BX
		MOV		AX,407
		PUSH	AX
		MOV		AX,6
		PUSH	AX
		CALL	full_circle
		POP		AX
		RET
dr_vazio:
		MOV		BYTE [cor],C_LILAS			; Ainda não vencido: só o contorno
		PUSH	BX
		MOV		AX,407
		PUSH	AX
		MOV		AX,6
		PUSH	AX
		CALL	circle
		POP		AX
		RET

;------------------------------------------------------------------------------
; desenha_tempo: tempo restante do round, AX = segundos, no formato M:SS
desenha_tempo:
		PUSH	AX
		PUSH	BX
		PUSH	DX
		PUSH	SI
		MOV		BL,60
		DIV		BL							; AL = minutos, AH = segundos
		ADD		AL,'0'
		MOV		[str_tempo+4],AL
		MOV		AL,AH
		XOR		AH,AH
		MOV		BL,10
		DIV		BL							; AL = dezena, AH = unidade dos segundos
		ADD		AX,'00'
		MOV		[str_tempo+6],AL
		MOV		[str_tempo+7],AH
		MOV		BYTE [cor],C_BRANCO
		MOV		DH,3
		MOV		SI,str_tempo
		CALL	escreve_centro
		POP		SI
		POP		DX
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; escreve_morte_subita: troca o relógio pelo aviso de morte súbita
escreve_morte_subita:
		PUSH	DX
		PUSH	SI
		MOV		BYTE [cor],C_SOL_AMAR
		MOV		DH,3
		MOV		SI,str_morte
		CALL	escreve_centro
		POP		SI
		POP		DX
		RET

segment data
cor			DB	C_BRANCO
caixa_aberta DB	0							; 1 = a caixa de mensagem está na tela				; Cor usada por plot_xy, caracter e line
str_tempo	DB	'    0:00    ',0			; 12 caracteres: cobre "MORTE SUBITA" inteira
str_morte	DB	'MORTE SUBITA',0
str_dica	DB	'P  pausa        Q  sair',0
