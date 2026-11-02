; fundo.asm - Cenário retrowave: paleta, desenho e cópia do fundo na memória
;
; O cenário (cenario.asm, com as retas de cenario.inc, gerado por
; ferramentas/gera_fundo.py) é uma lista de
; retas desenhadas com a função line do professor. Desenhar tudo leva quase
; dois segundos, então isso só é feito uma vez por partida.
;
; Esta versão não escreve na memória de vídeo: tudo vai para a tela pela BIOS
; (plot_xy). Enquanto o cenário é desenhado, cada reta também é gravada em uma
; cópia do fundo na memória do programa (4 bits por pixel, dois segmentos), só
; na faixa por onde os lutadores e as mensagens passam. Para apagar alguma
; coisa, os mesmos pixels são pintados de novo com plot_xy, cada um na cor que
; o fundo tem ali (lida da cópia).
;
; Para apagar uma reta sem deixar sobra, os pixels precisam ser exatamente os
; que a line acendeu: reta_ponto faz a mesma conta da line do professor
; (x ou y calculado por divisão arredondada), mas em cada pixel chama ponto,
; que grava na cópia (desenho do cenário) ou repinta com a cor do fundo (apagar).

%include "defs.inc"

extern cor, line, plot_xy, cenario, copia_a, copia_b
global aplica_paleta, desenha_cenario, restaura_fundo, apaga_reta, fundo_pronto

segment code

;------------------------------------------------------------------------------
; aplica_paleta: troca as 16 cores do modo 12h pelas da paleta retrowave
; (precisa ser refeito toda vez que o modo de vídeo é trocado)
aplica_paleta:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	ES
		PUSH	DS
		POP		ES							; ES:DX aponta para as tabelas
		MOV		AX,1002h					; Registradores de paleta 0-15 = 0-15
		MOV		DX,reg_paleta				; (cada cor usa a entrada de mesmo número do DAC)
		INT		10h
		MOV		AX,1012h					; Bloco de cores do DAC
		XOR		BX,BX						; primeira cor
		MOV		CX,16						; quantidade de cores
		MOV		DX,dac_paleta
		INT		10h
		POP		ES
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; desenha_cenario: desenha todas as retas do cenário na tela e na cópia do fundo
desenha_cenario:
		PUSH	AX
		PUSH	CX
		PUSH	SI
		PUSH	DI
		PUSH	ES
		CLD									; Cópia começa toda na cor do céu (C_FUNDO = 0)
		XOR		AX,AX
		MOV		CX,SEG copia_a
		MOV		ES,CX
		MOV		DI,copia_a
		MOV		CX,LINHAS_A*BYTES_LINHA/2
		REP		STOSW
		MOV		CX,SEG copia_b
		MOV		ES,CX
		MOV		DI,copia_b
		MOV		CX,LINHAS_B*BYTES_LINHA/2
		REP		STOSW
		MOV		SI,cenario
dc_laco:
		LODSB								; Cor da reta (0FFh = fim da lista)
		CMP		AL,0FFh
		JE		dc_fim
		MOV		[cor],AL
		PUSH	WORD [SI]					; Na tela, com a line do professor
		PUSH	WORD [SI+2]
		PUSH	WORD [SI+4]
		PUSH	WORD [SI+6]
		CALL	line
		PUSH	WORD [SI]					; E os mesmos pixels na cópia
		PUSH	WORD [SI+2]
		PUSH	WORD [SI+4]
		PUSH	WORD [SI+6]
		CALL	guarda_reta
		ADD		SI,8
		JMP		dc_laco
dc_fim:
		MOV		BYTE [fundo_pronto],1
		POP		ES
		POP		DI
		POP		SI
		POP		CX
		POP		AX
		RET

;------------------------------------------------------------------------------
; guarda_reta: grava na cópia do fundo, na cor [cor], os pixels que a line
; acende para a reta. PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL guarda_reta
; Retas horizontais e verticais (88% dos pixels do cenário) são gravadas
; direto, de ponta a ponta, que é o que a line faz com elas; as inclinadas
; passam por reta_ponto, com a mesma conta da line.
guarda_reta:
		PUSH	BP
		MOV		BP,SP
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	DI
		PUSH	ES
		MOV		DX,[BP+8]					; y1
		CMP		DX,[BP+4]
		JNE		gr_nao_horizontal
		MOV		CX,[BP+10]					; Horizontal: CX = menor x, BX = maior x
		MOV		BX,[BP+6]
		CMP		CX,BX
		JLE		gr_h_ordem
		XCHG	CX,BX
gr_h_ordem:
		CALL	endereco					; ES:DI = byte do primeiro pixel
		JNC		gr_h_dentro
		JMP		gr_fim						; Linha fora da faixa: nada a gravar
gr_h_dentro:
		SUB		BX,CX
		INC		BX							; BX = número de pixels
		MOV		AL,[cor]					; AL = cor nos 4 bits de baixo (x par),
		AND		AL,0Fh						; AH = cor nos 4 bits de cima (x ímpar)
		MOV		AH,AL
		PUSH	CX
		MOV		CL,4
		SHL		AH,CL
		POP		CX
gr_h_laco:
		TEST	CL,1
		JNZ		gr_h_impar
		AND		BYTE [ES:DI],0F0h
		OR		[ES:DI],AL
		JMP		gr_h_proximo
gr_h_impar:
		AND		BYTE [ES:DI],0Fh
		OR		[ES:DI],AH
		INC		DI							; Depois do pixel ímpar vem o próximo byte
gr_h_proximo:
		INC		CX
		DEC		BX
		JNZ		gr_h_laco
		JMP		gr_fim
gr_nao_horizontal:
		MOV		CX,[BP+10]					; x1
		CMP		CX,[BP+6]
		JNE		gr_inclinada
		MOV		BX,[BP+4]					; Vertical: DX = menor y, BX = maior y
		CMP		DX,BX
		JLE		gr_v_ordem
		XCHG	DX,BX
gr_v_ordem:
		CMP		DX,FAIXA_Y1					; Corta na faixa da cópia
		JGE		gr_v_y1
		MOV		DX,FAIXA_Y1
gr_v_y1:
		CMP		BX,FAIXA_Y2
		JLE		gr_v_y2
		MOV		BX,FAIXA_Y2
gr_v_y2:
		CMP		DX,BX
		JG		gr_fim
		MOV		AL,[cor]					; AL = cor e AH = máscara do pixel no byte
		AND		AL,0Fh						; (x par: 4 bits de baixo; ímpar: de cima)
		MOV		AH,0F0h
		TEST	CL,1
		JZ		gr_v_par
		PUSH	CX
		MOV		CL,4
		SHL		AL,CL
		POP		CX
		MOV		AH,0Fh
gr_v_par:
		CALL	endereco
gr_v_laco:
		AND		[ES:DI],AH
		OR		[ES:DI],AL
		CMP		DX,BX
		JE		gr_fim
		INC		DX							; Uma linha acima na tela = próxima linha da cópia
		ADD		DI,BYTES_LINHA
		CMP		DX,FAIXA_Y1+LINHAS_A		; Passou para a parte B da cópia
		JNE		gr_v_laco
		CALL	endereco
		JMP		gr_v_laco
gr_inclinada:
		MOV		BYTE [modo],0				; ponto grava na cópia
		PUSH	WORD [BP+10]
		PUSH	WORD [BP+8]
		PUSH	WORD [BP+6]
		PUSH	WORD [BP+4]
		CALL	reta_ponto
gr_fim:
		POP		ES
		POP		DI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POP		BP
		RET		8

;------------------------------------------------------------------------------
; restaura_fundo: repinta um retângulo com as cores do fundo
; PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL restaura_fundo  (coordenadas do
; plot_xy, x1<=x2, y1<=y2). O retângulo é cortado na faixa da cópia.
restaura_fundo:
		PUSH	BP
		MOV		BP,SP
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		MOV		AL,[cor]
		PUSH	AX
		MOV		DX,[BP+8]					; DX = y, de y1 até y2
		CMP		DX,FAIXA_Y1
		JGE		rf_y
		MOV		DX,FAIXA_Y1
rf_y:
		MOV		BX,[BP+4]					; BX = último y
		CMP		BX,FAIXA_Y2
		JLE		rf_linha
		MOV		BX,FAIXA_Y2
rf_linha:
		CMP		DX,BX
		JG		rf_fim
		MOV		CX,[BP+10]					; CX = x, de x1 até x2
rf_pixel:
		CALL	le_fundo					; Cor do fundo neste pixel
		MOV		[cor],AL
		PUSH	CX
		PUSH	DX
		CALL	plot_xy
		INC		CX
		CMP		CX,[BP+6]
		JLE		rf_pixel
		INC		DX
		JMP		rf_linha
rf_fim:
		POP		AX
		MOV		[cor],AL
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POP		BP
		RET		8

;------------------------------------------------------------------------------
; apaga_reta: apaga uma reta desenhada com line, repintando exatamente os
; pixels dela com as cores do fundo
; PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL apaga_reta
apaga_reta:
		PUSH	BP
		MOV		BP,SP
		PUSH	AX
		MOV		AL,[cor]
		MOV		BYTE [modo],1				; ponto repinta com a cor do fundo
		PUSH	WORD [BP+10]
		PUSH	WORD [BP+8]
		PUSH	WORD [BP+6]
		PUSH	WORD [BP+4]
		CALL	reta_ponto
		MOV		BYTE [modo],0
		MOV		[cor],AL
		POP		AX
		POP		BP
		RET		8

;------------------------------------------------------------------------------
; ponto: chamado por reta_ponto em cada pixel. PUSH x; PUSH y; CALL ponto
; [modo] = 0: grava [cor] na cópia do fundo; 1: repinta o pixel na tela com a
; cor que o fundo tem nele.
ponto:
		PUSH	BP
		MOV		BP,SP
		PUSH	AX
		PUSH	CX
		PUSH	DX
		MOV		CX,[BP+6]					; x
		MOV		DX,[BP+4]					; y
		CMP		BYTE [modo],0
		JNE		po_apaga
		MOV		AL,[cor]
		CALL	grava_fundo
		JMP		po_fim
po_apaga:
		CALL	le_fundo
		MOV		[cor],AL
		PUSH	CX
		PUSH	DX
		CALL	plot_xy
po_fim:
		POP		DX
		POP		CX
		POP		AX
		POP		BP
		RET		4

;------------------------------------------------------------------------------
; le_fundo: AL = cor do fundo no pixel (CX = x, DX = y). Fora da faixa da
; cópia, devolve a cor do céu.
le_fundo:
		PUSH	CX
		PUSH	DI
		PUSH	ES
		CALL	endereco
		MOV		AL,C_FUNDO
		JC		lf_fim
		MOV		AL,[ES:DI]
		TEST	CL,1						; x par: 4 bits de baixo; ímpar: de cima
		JZ		lf_par
		MOV		CL,4
		SHR		AL,CL
lf_par:
		AND		AL,0Fh
lf_fim:
		POP		ES
		POP		DI
		POP		CX
		RET

; grava_fundo: grava a cor AL no pixel (CX = x, DX = y) da cópia
grava_fundo:
		PUSH	AX
		PUSH	CX
		PUSH	DI
		PUSH	ES
		CALL	endereco
		JC		gf_fim
		AND		AL,0Fh
		MOV		AH,[ES:DI]
		TEST	CL,1
		JNZ		gf_impar
		AND		AH,0F0h						; x par: troca os 4 bits de baixo
		JMP		gf_junta
gf_impar:
		MOV		CL,4						; x ímpar: troca os 4 bits de cima
		SHL		AL,CL
		AND		AH,0Fh
gf_junta:
		OR		AH,AL
		MOV		[ES:DI],AH
gf_fim:
		POP		ES
		POP		DI
		POP		CX
		POP		AX
		RET

; endereco: CX = x, DX = y. ES:DI = byte do pixel na cópia; CF = 1 se o
; pixel está fora da faixa guardada.
endereco:
		CMP		DX,FAIXA_Y1
		JL		en_fora
		CMP		DX,FAIXA_Y2
		JG		en_fora
		CMP		CX,639						; (sem sinal: x negativo também fica fora)
		JA		en_fora
		PUSH	AX
		PUSH	DX
		MOV		AX,DX
		SUB		AX,FAIXA_Y1					; AX = linha dentro da faixa
		MOV		DI,SEG copia_a				; As primeiras linhas ficam na parte A,
		MOV		ES,DI						; as outras na B
		MOV		DI,copia_a
		CMP		AX,LINHAS_A
		JB		en_parte
		SUB		AX,LINHAS_A
		MOV		DI,SEG copia_b
		MOV		ES,DI
		MOV		DI,copia_b
en_parte:
		MOV		DX,BYTES_LINHA
		MUL		DX							; AX = linha * 320
		ADD		DI,AX
		MOV		AX,CX
		SHR		AX,1						; 2 pixels por byte
		ADD		DI,AX
		POP		DX
		POP		AX
		CLC
		RET
en_fora:
		STC
		RET

;------------------------------------------------------------------------------
; reta_ponto: mesma conta da função line do professor (line.asm), mas em vez
; de plot_xy chama ponto em cada pixel. Assim a cópia guarda e o apagar
; repinta exatamente os pixels que a line acende.
; PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL reta_ponto
reta_ponto:
		PUSH	BP
		MOV		BP,SP
		PUSHF
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		MOV		AX,[BP+10]					; x1
		MOV		BX,[BP+8]					; y1
		MOV		CX,[BP+6]					; x2
		MOV		DX,[BP+4]					; y2
		CMP		AX,CX
		JE		rp_vertical
		JB		rp_inclinada				; x1 < x2
		XCHG	AX,CX						; Senão troca as pontas
		XCHG	BX,DX
		JMP		rp_inclinada
rp_vertical:								; Reta vertical: de y1 a y2
		CMP		BX,DX
		JB		rp_v_laco
		XCHG	BX,DX
rp_v_laco:
		PUSH	AX
		PUSH	BX
		CALL	ponto
		CMP		BX,DX
		JNE		rp_v_proximo				; (rp_fim é longe demais para um salto curto)
		JMP		rp_fim
rp_v_proximo:
		INC		BX
		JMP		rp_v_laco
rp_inclinada:
		PUSH	CX							; |dx| e |dy|
		SUB		CX,AX
		MOV		[deltax],CX
		POP		CX
		PUSH	DX
		SUB		DX,BX
		JA		rp_dy_ok
		NEG		DX
rp_dy_ok:
		MOV		[deltay],DX
		POP		DX
		PUSH	AX
		MOV		AX,[deltax]
		CMP		AX,[deltay]
		POP		AX
		JB		rp_em_y						; Mais alta que larga: anda em y
		PUSH	CX							; Anda em x: y = y1 + dy*(x-x1)/dx arredondado
		SUB		CX,AX
		MOV		[deltax],CX
		POP		CX
		PUSH	DX
		SUB		DX,BX
		MOV		[deltay],DX
		POP		DX
		MOV		SI,AX
rp_x_laco:
		PUSH	AX
		PUSH	DX
		PUSH	SI
		SUB		SI,AX
		MOV		AX,[deltay]
		IMUL	SI
		MOV		SI,[deltax]
		SHR		SI,1
		CMP		DX,0
		JL		rp_x_neg
		ADD		AX,SI
		ADC		DX,0
		JMP		rp_x_div
rp_x_neg:
		SUB		AX,SI
		SBB		DX,0
rp_x_div:
		IDIV	WORD [deltax]
		ADD		AX,BX
		POP		SI
		PUSH	SI
		PUSH	AX
		CALL	ponto
		POP		DX
		POP		AX
		CMP		SI,CX
		JE		rp_fim
		INC		SI
		JMP		rp_x_laco
rp_em_y:									; Anda em y: x = x1 + dx*(y-y1)/dy arredondado
		CMP		BX,DX
		JB		rp_y_ok
		XCHG	AX,CX
		XCHG	BX,DX
rp_y_ok:
		PUSH	CX
		SUB		CX,AX
		MOV		[deltax],CX
		POP		CX
		PUSH	DX
		SUB		DX,BX
		MOV		[deltay],DX
		POP		DX
		MOV		SI,BX
rp_y_laco:
		PUSH	DX
		PUSH	SI
		PUSH	AX
		SUB		SI,BX
		MOV		AX,[deltax]
		IMUL	SI
		MOV		SI,[deltay]
		SHR		SI,1
		CMP		DX,0
		JL		rp_y_neg
		ADD		AX,SI
		ADC		DX,0
		JMP		rp_y_div
rp_y_neg:
		SUB		AX,SI
		SBB		DX,0
rp_y_div:
		IDIV	WORD [deltay]
		MOV		DI,AX
		POP		AX
		ADD		DI,AX
		POP		SI
		PUSH	DI
		PUSH	SI
		CALL	ponto
		POP		DX
		CMP		SI,DX
		JE		rp_fim
		INC		SI
		JMP		rp_y_laco
rp_fim:
		POP		DI
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POPF
		POP		BP
		RET		8

segment data
		FAIXA_Y1	EQU	ARENA_Y1			; Faixa guardada: do chão até acima do pulo
		FAIXA_Y2	EQU	301					; e das mensagens (y do plot_xy)
		N_LINHAS	EQU	FAIXA_Y2-FAIXA_Y1+1
		BYTES_LINHA	EQU	320					; 640 pixels, 2 por byte
		LINHAS_A	EQU	204					; Linhas no segmento A (204*320 cabe em 64 KB;
		LINHAS_B	EQU	N_LINHAS-LINHAS_A	; o resto fica no B). Os dois ficam em copia.asm
fundo_pronto DB	0							; 1 = cenário desenhado e copiado
modo		DB	0							; ponto: 0 grava na cópia, 1 apaga na tela
deltax		DW	0							; reta_ponto (como na line do professor)
deltay		DW	0
; Registradores de paleta (16 cores + borda) e cores do DAC (R, G, B de 0 a 63)
reg_paleta	DB	0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15, 0
dac_paleta	DB	07,00,18					; C_FUNDO        #1f014b  céu e chão
			DB	14,02,26					; C_ROXO         #3a0a6a  montanhas
			DB	35,05,30					; C_MAGENTA      #8c1678  brilho do horizonte
			DB	63,10,52					; C_NEON_ROSA    #ff2bd1  grade e borda
			DB	63,54,19					; C_SOL_AMAR     #ffd84c  sol, títulos
			DB	63,38,19					; C_SOL_LARANJA  #ff9a4c  sol
			DB	63,18,19					; C_SOL_CORAL    #ff4a4e  sol
			DB	63,07,25					; C_SOL_ROSA     #ff1f64  sol, rodas
			DB	02,00,09					; C_SILHUETA     #0b0024  palmeiras
			DB	19,26,63					; C_NEON_AZUL    #4f6bff  arestas das montanhas
			DB	23,10,22					; C_HALO         #5e2a5a  anel do sol
			DB	63,63,63					; C_BRANCO       #ffffff  textos
			DB	00,60,63					; C_CIANO        #00f0ff  lutador
			DB	19,63,11					; C_VERDE        #4dff2e  lutador
			DB	50,42,63					; C_LILAS        #c9a8ff  lutador
			DB	58,04,11					; C_VERMELHO     #e8102e  carro, lutador branco atingido
