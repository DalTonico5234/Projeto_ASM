; colisao.asm - Acerto dos golpes e limites de posição dos lutadores
;
; Regras do acerto (conferidas no tique em que o golpe está esticado; no ar,
; em 3 tiques seguidos, valendo um acerto por golpe):
;   1) o adversário precisa estar na frente de quem golpeia, a até o alcance
;      do golpe (tabela alc_golpe: ALC_SOCO, ALC_CHUTE, ALC_GIRO, ALC_INV);
;   2) a ponta do golpe (punho ou pé, tabela ponta_golpe, mais a altura do
;      pulo de quem golpeia) precisa estar entre o ponto mais baixo e o topo
;      do adversário, com folga de TOL_V. Topo: ALT_TOPO_PE em pé, ALT_TOPO_BX
;      abaixado; ponto mais baixo: o chão, ou ALT_BASE_AR acima do J_Y no ar.
; Isso dá as defesas do jogo: o soco reto passa por cima de quem está
; abaixado, a rasteira e o chute reto passam por baixo de quem pula, e quem
; passa por cima da cabeça do outro no pulo não é atingido pelos golpes do
; chão (e só acerta do alto com o chute, perto da cabeça).
; Os dois golpes de um tique são testados antes de qualquer dano ser aplicado,
; então golpes simultâneos valem para os dois lados (ninguém tem prioridade).
; Os especiais seguem as mesmas regras: o chute giratório e o soco da
; investida passam por cima de quem está abaixado, como o soco reto.
; Golpe válido: tira 1 de energia, empurra o adversário para trás (EMPURRA, ou
; EMPURRA_ESP nos especiais) e o faz piscar.

%include "defs.inc"

global testa_golpe, aplica_golpe, limita_posicoes, energia_mudou
extern jog1, jog2

segment code

;------------------------------------------------------------------------------
; testa_golpe: SI = quem golpeia, DI = adversário. AL = 1 se há um golpe
; esticado neste tique e ele acerta, 0 se não. Não muda nada no adversário.
testa_golpe:
		XOR		AL,AL
		CMP		BYTE [SI+J_IMPACTO],0		; Nenhum golpe esticado neste tique
		JNE		tg_testa
		JMP		tg_fim						; (tg_fim é longe demais para um salto curto)
tg_testa:
		MOV		BYTE [SI+J_IMPACTO],0
		PUSH	BX
		PUSH	CX
		PUSH	DX
		MOV		BX,[DI+J_X]					; BX = distância até o adversário, medida
		SUB		BX,[SI+J_X]					; para a frente de quem golpeia
		TEST	BYTE [SI+J_DIR],80h
		JZ		tg_frente
		NEG		BX							; Olha para a esquerda: a frente é x menor
tg_frente:
		OR		BX,BX
		JL		tg_volta					; Adversário está atrás: não acerta
		MOV		CX,BX						; CX = distância
		MOV		BL,[SI+J_ATQ]				; Alcance do golpe (tabela alc_golpe)
		XOR		BH,BH
		MOV		DL,[BX+alc_golpe]
		XOR		DH,DH
		CMP		CX,DX
		JA		tg_volta					; Longe demais
; Altura: CX = altura da ponta do golpe
		CMP		BL,ATQ_GIRO					; Especiais: tabela ponta_especial
		JB		tg_altura
		MOV		CL,[BX+ponta_especial-ATQ_GIRO]
		JMP		tg_ponta
tg_altura:
		MOV		BL,[SI+J_EST]				; BX = postura*3 + (golpe-1)
		MOV		BH,BL
		SHL		BL,1
		ADD		BL,BH
		ADD		BL,[SI+J_ATQ]
		DEC		BL
		XOR		BH,BH
		MOV		CL,[BX+ponta_golpe]
tg_ponta:
		XOR		CH,CH
		ADD		CX,[SI+J_Y]					; No ar, soma a altura do pulo
		MOV		DX,[DI+J_Y]					; DX = ponto mais baixo do adversário
		CMP		BYTE [DI+J_EST],E_PULO
		JNE		tg_base
		ADD		DX,ALT_BASE_AR
tg_base:
		SUB		DX,TOL_V
		CMP		CX,DX						; Ponta abaixo do adversário: passa por baixo
		JL		tg_volta
		MOV		DX,[DI+J_Y]					; DX = topo do adversário
		ADD		DX,ALT_TOPO_PE
		CMP		BYTE [DI+J_EST],E_ABAIXADO
		JNE		tg_topo
		SUB		DX,ALT_TOPO_PE-ALT_TOPO_BX
tg_topo:
		ADD		DX,TOL_V
		CMP		CX,DX						; Ponta acima do adversário: passa por cima
		JG		tg_volta
		MOV		AL,1
		MOV		BYTE [SI+J_ACERTOU],1		; Um acerto por golpe
tg_volta:
		POP		DX
		POP		CX
		POP		BX
tg_fim:
		RET

;------------------------------------------------------------------------------
; aplica_golpe: golpe válido de SI em DI. Tira 1 de energia, faz o adversário
; piscar e o empurra na direção em que o golpe foi dado.
aplica_golpe:
		PUSH	AX
		CMP		BYTE [DI+J_ENER],0
		JE		ag_fim
		DEC		BYTE [DI+J_ENER]
		MOV		BYTE [DI+J_PISCA],T_PISCA
		MOV		BYTE [energia_mudou],1
		MOV		AX,EMPURRA
		CMP		BYTE [SI+J_ATQ],ATQ_GIRO	; Especial: empurra bem mais
		JB		ag_sentido
		MOV		AX,EMPURRA_ESP
ag_sentido:
		TEST	BYTE [SI+J_DIR],80h			; Quem golpeia olha para a esquerda: empurra
		JZ		ag_empurra					; para a esquerda
		NEG		AX
ag_empurra:
		ADD		[DI+J_X],AX
ag_fim:
		POP		AX
		RET

;------------------------------------------------------------------------------
; limita_posicoes: mantém os lutadores dentro da arena e decide os lados.
; No chão, um não passa pelo outro: se um anda contra o outro, os dois se
; empurram (cada um recua metade da sobreposição). Se a diferença de altura
; for de pelo menos ALT_CRUZA (um pulando por cima do outro), não há distância
; mínima e eles podem se cruzar. Quando se cruzam, trocam de lado: quem fica à
; esquerda olha para a direita e o outro para a esquerda, e os golpes passam a
; sair para o outro lado. Cruzando de novo, voltam ao sentido original.
limita_posicoes:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		MOV		SI,jog1						; SI = lutador da esquerda, DI = da direita
		MOV		DI,jog2						; (quem olha para a direita está à esquerda)
		TEST	BYTE [jog1+J_DIR],80h
		JZ		lp_lados
		XCHG	SI,DI
lp_lados:
		MOV		AX,[SI+J_X]					; AX = x da esquerda, BX = x da direita
		MOV		BX,[DI+J_X]
		CALL	lp_paredes
		CMP		BX,AX						; Cruzaram: trocam de lado
		JGE		lp_altura
		XCHG	SI,DI
		XCHG	AX,BX
lp_altura:
		MOV		CX,[SI+J_Y]					; CX = |diferença de altura|
		SUB		CX,[DI+J_Y]
		JNS		lp_alt_ok
		NEG		CX
lp_alt_ok:
		CMP		CX,ALT_CRUZA				; Um passa por cima do outro: sem
		JGE		lp_grava					; distância mínima
		MOV		CX,BX						; CX = distância - DIST_MIN
		SUB		CX,AX
		SUB		CX,DIST_MIN
		JGE		lp_grava					; Distância suficiente
		NEG		CX							; CX = sobreposição
		MOV		DX,CX
		SHR		DX,1
		SUB		AX,DX						; o da esquerda recua metade
		SUB		CX,DX
		ADD		BX,CX						; o da direita recua o resto
		CALL	lp_paredes
		CMP		AX,X_MIN					; Encostado na parede esquerda: o outro cede
		JG		lp_dir
		MOV		BX,AX
		ADD		BX,DIST_MIN
		JMP		lp_grava
lp_dir:
		CMP		BX,X_MAX					; Encostado na parede direita: o outro cede
		JL		lp_grava
		MOV		AX,BX
		SUB		AX,DIST_MIN
lp_grava:
		MOV		[SI+J_X],AX
		MOV		[DI+J_X],BX
		MOV		BYTE [SI+J_DIR],1			; Cada um olha para o adversário
		MOV		BYTE [DI+J_DIR],-1
		POP		DI
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

; lp_paredes: limita AX e BX ao intervalo X_MIN..X_MAX
lp_paredes:
		CMP		AX,X_MIN
		JGE		lpp_1
		MOV		AX,X_MIN
lpp_1:	CMP		AX,X_MAX
		JLE		lpp_2
		MOV		AX,X_MAX
lpp_2:	CMP		BX,X_MIN
		JGE		lpp_3
		MOV		BX,X_MIN
lpp_3:	CMP		BX,X_MAX
		JLE		lpp_4
		MOV		BX,X_MAX
lpp_4:	RET

segment data
energia_mudou	DB	0						; 1 = a barra de energia precisa ser redesenhada
; Altura da ponta de cada golpe (punho ou pé), acima do pé de quem golpeia.
; Índice = postura*3 + (golpe-1); golpes: soco, chute, rasteira
ponta_golpe	DB	86, 58, 4					; em pé: reto
			DB	80, 60, 4					; abaixado: diagonal para cima
			DB	48, 6, 6					; no ar: diagonal para baixo
; Especiais (em pé): chute giratório, soco da investida
ponta_especial DB	84, 86
; Alcance de cada golpe (índice = J_ATQ)
alc_golpe	DB	0, ALC_SOCO, ALC_CHUTE, ALC_CHUTE, ALC_GIRO, ALC_INV
