; colisao.asm - Acerto dos golpes e limites de posição dos lutadores
;
; Regras do acerto (conferidas no tique em que o golpe está esticado):
;   soco : acerta se a distância entre os lutadores for até ALC_SOCO
;          e o adversário NÃO estiver abaixado (o soco passa por cima)
;   chute: acerta se a distância for até ALC_CHUTE e o adversário NÃO
;          estiver no ar a pelo menos ALT_DESVIO pixels (o chute passa por baixo)
; Os dois golpes de um tique são testados antes de qualquer dano ser aplicado,
; então golpes simultâneos valem para os dois lados (ninguém tem prioridade).
; Golpe válido: tira 1 de energia, empurra o adversário para trás e o faz piscar.

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
		JE		tg_fim
		MOV		BYTE [SI+J_IMPACTO],0
		PUSH	BX
		MOV		BX,[DI+J_X]					; BX = |x do adversário - x de quem golpeia|
		SUB		BX,[SI+J_X]
		JNS		tg_dist_ok
		NEG		BX
tg_dist_ok:
		CMP		BYTE [SI+J_EST],E_CHUTE
		JE		tg_chute
; Soco
		CMP		BX,ALC_SOCO					; Longe demais
		JA		tg_volta
		CMP		BYTE [DI+J_EST],E_ABAIXADO	; Defesa: abaixado, o soco passa por cima
		JE		tg_volta
		JMP		tg_acertou
tg_chute:
		CMP		BX,ALC_CHUTE
		JA		tg_volta
		CMP		WORD [DI+J_Y],ALT_DESVIO	; Defesa: pulou alto, o chute passa por baixo
		JGE		tg_volta
tg_acertou:
		MOV		AL,1
tg_volta:
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
		TEST	BYTE [SI+J_DIR],80h			; Quem golpeia olha para a esquerda: empurra
		JZ		ag_empurra					; para a esquerda
		NEG		AX
ag_empurra:
		ADD		[DI+J_X],AX
ag_fim:
		POP		AX
		RET

;------------------------------------------------------------------------------
; limita_posicoes: mantém os lutadores dentro da arena e sem passar um pelo
; outro. O jogador 1 fica sempre à esquerda. Se um anda contra o outro, os
; dois se empurram (cada um recua metade da sobreposição).
limita_posicoes:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		MOV		AX,[jog1+J_X]
		MOV		BX,[jog2+J_X]
		CALL	lp_paredes
		MOV		CX,BX						; CX = distância - DIST_MIN
		SUB		CX,AX
		SUB		CX,DIST_MIN
		JGE		lp_grava					; Distância suficiente
		NEG		CX							; CX = sobreposição
		MOV		DX,CX
		SHR		DX,1
		SUB		AX,DX						; jogador 1 recua metade
		SUB		CX,DX
		ADD		BX,CX						; jogador 2 recua o resto
		CALL	lp_paredes
		CMP		AX,X_MIN					; Encostado na parede esquerda: o 2 cede
		JG		lp_dir
		MOV		BX,AX
		ADD		BX,DIST_MIN
		JMP		lp_grava
lp_dir:
		CMP		BX,X_MAX					; Encostado na parede direita: o 1 cede
		JL		lp_grava
		MOV		AX,BX
		SUB		AX,DIST_MIN
lp_grava:
		MOV		[jog1+J_X],AX
		MOV		[jog2+J_X],BX
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
