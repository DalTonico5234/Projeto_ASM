; jogador.asm - Lutadores: estado, controles, movimento e desenho
;
; Os dois lutadores usam a mesma estrutura (deslocamentos J_... em defs.inc)
; e o mesmo código; muda só a tabela de teclas de cada um. As poses são tabelas
; de retas relativas ao pé do lutador, espelhadas conforme o lado para onde ele
; olha, e desenhadas com line e full_circle do professor.

%include "defs.inc"

extern line, full_circle, cor
extern tecla_nova, tecla_press
global jog1, jog2, inicia_jogadores, atualiza_jogador, desenha_pose, atualiza_lutadores
global esquece_desenho

segment code

;------------------------------------------------------------------------------
; inicia_jogadores: posições e energia do começo de um round
inicia_jogadores:
		PUSH	SI
		MOV		SI,jog1
		MOV		WORD [SI+J_X],200
		CALL	ij_comum
		MOV		SI,jog2
		MOV		WORD [SI+J_X],440
		CALL	ij_comum
		POP		SI
		RET
ij_comum:
		MOV		WORD [SI+J_Y],0
		MOV		WORD [SI+J_VY],0
		MOV		BYTE [SI+J_EST],E_PARADO
		MOV		BYTE [SI+J_POSE],E_PARADO
		MOV		BYTE [SI+J_T],0
		MOV		BYTE [SI+J_PISCA],0
		MOV		BYTE [SI+J_PASSO],0
		MOV		BYTE [SI+J_IMPACTO],0
		MOV		BYTE [SI+J_ENER],ENERGIA
		MOV		BYTE [SI+J_VIS],0			; Nada desenhado ainda
		RET

;------------------------------------------------------------------------------
; esquece_desenho: avisa que a tela foi limpa, então não há o que apagar
esquece_desenho:
		MOV		BYTE [jog1+J_VIS],0
		MOV		BYTE [jog2+J_VIS],0
		MOV		BYTE [jog1+J_DENER],0FFh	; Barras de energia: desenhar inteiras
		MOV		BYTE [jog2+J_DENER],0FFh
		RET

;------------------------------------------------------------------------------
; atualiza_jogador: um tique de jogo para o lutador SI (DI = adversário)
; Lê as teclas do lutador, muda o estado, move e verifica golpes.
atualiza_jogador:
		PUSH	AX
		PUSH	BX
		MOV		BYTE [andou],0
		CMP		BYTE [SI+J_PISCA],0			; O branco de "levou golpe" vai sumindo
		JE		aj_estado
		DEC		BYTE [SI+J_PISCA]
aj_estado:
		MOV		AL,[SI+J_EST]
		CMP		AL,E_SOCO
		JE		aj_golpe
		CMP		AL,E_CHUTE
		JE		aj_golpe
		CMP		AL,E_PULO
		JE		aj_no_ar
		JMP		aj_no_chao

; Soco ou chute em andamento: o lutador fica parado até o golpe acabar
aj_golpe:
		CALL	descarta_ataques
		DEC		BYTE [SI+J_T]
		CMP		BYTE [SI+J_T],T_IMPACTO		; Braço ou perna esticados: o acerto é
		JNE		aj_golpe_fim				; conferido pelo passo, depois dos dois lutadores
		MOV		BYTE [SI+J_IMPACTO],1
aj_golpe_fim:
		CMP		BYTE [SI+J_T],0				; Golpe acabou: volta à guarda
		JNE		aj_ate_fim
		MOV		BYTE [SI+J_EST],E_PARADO
aj_ate_fim:
		JMP		aj_fim

; No ar: sobe e desce pela gravidade e pode se mover para os lados
aj_no_ar:
		CALL	descarta_ataques
		MOV		AX,[SI+J_VY]
		ADD		[SI+J_Y],AX
		SUB		WORD [SI+J_VY],GRAV
		CMP		WORD [SI+J_Y],0				; Voltou ao chão
		JG		aj_anda
		MOV		WORD [SI+J_Y],0
		MOV		BYTE [SI+J_EST],E_PARADO
		JMP		aj_anda

; No chão: golpe, pulo, abaixar ou andar
aj_no_chao:
		MOV		AL,[SI+J_K_SOCO]
		CALL	tecla_nova
		JZ		aj_chute
		MOV		BYTE [SI+J_EST],E_SOCO
		JMP		aj_inicia_golpe
aj_chute:
		MOV		AL,[SI+J_K_CHUTE]
		CALL	tecla_nova
		JZ		aj_pulo
		MOV		BYTE [SI+J_EST],E_CHUTE
aj_inicia_golpe:
		MOV		BYTE [SI+J_T],T_GOLPE
		JMP		aj_fim
aj_pulo:
		MOV		AL,[SI+J_K_PULA]
		CALL	tecla_press
		JZ		aj_abaixa
		MOV		BYTE [SI+J_EST],E_PULO
		MOV		WORD [SI+J_VY],PULO_V
		JMP		aj_no_ar
aj_abaixa:
		MOV		BYTE [SI+J_EST],E_PARADO
		MOV		AL,[SI+J_K_ABAIXA]
		CALL	tecla_press
		JZ		aj_anda
		MOV		BYTE [SI+J_EST],E_ABAIXADO	; Abaixado não anda
		JMP		aj_fim

; Andar: esquerda e direita juntas se anulam
aj_anda:
		XOR		BX,BX						; BX = deslocamento deste tique
		MOV		AL,[SI+J_K_ESQ]
		CALL	tecla_press
		JZ		aj_dir
		SUB		BX,VEL
aj_dir:
		MOV		AL,[SI+J_K_DIR]
		CALL	tecla_press
		JZ		aj_move
		ADD		BX,VEL
aj_move:
		ADD		[SI+J_X],BX
		OR		BX,BX
		JZ		aj_fim
		MOV		BYTE [andou],1
		INC		BYTE [SI+J_PASSO]			; Conta passos para a animação
aj_fim:
		CALL	escolhe_pose
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; descarta_ataques: golpe apertado enquanto o lutador está ocupado não fica
; guardado para depois
descarta_ataques:
		PUSH	AX
		MOV		AL,[SI+J_K_SOCO]
		CALL	tecla_nova
		MOV		AL,[SI+J_K_CHUTE]
		CALL	tecla_nova
		POP		AX
		RET

;------------------------------------------------------------------------------
; escolhe_pose: pose do estado; andando (neste tique) alterna a pose de passo
escolhe_pose:
		PUSH	AX
		MOV		AL,[SI+J_EST]
		CMP		AL,E_PARADO
		JNE		ep_fim
		CMP		BYTE [andou],0				; Parou de andar: volta à guarda
		JE		ep_fim
		TEST	BYTE [SI+J_PASSO],2			; Troca de perna a cada 2 tiques andando
		JZ		ep_fim
		MOV		AL,P_ANDA
ep_fim:
		MOV		[SI+J_POSE],AL
		POP		AX
		RET

;------------------------------------------------------------------------------
; atualiza_lutadores: põe na tela o que mudou nos lutadores desde o último
; desenho. Apagar é redesenhar em preto. Longe um do outro, cada lutador é
; apagado e redesenhado sozinho, só se mudou. Perto, um pode estar por cima do
; outro: se algum mudou, os dois são apagados e depois os dois desenhados.
atualiza_lutadores:
		PUSH	AX
		PUSH	SI
		MOV		AX,[jog1+J_X]				; Perto agora?
		SUB		AX,[jog2+J_X]
		CALL	perto
		JB		al_juntos
		MOV		AX,[jog1+J_DX]				; Ou perto no desenho que está na tela?
		SUB		AX,[jog2+J_DX]
		CALL	perto
		JB		al_juntos
		MOV		AX,[jog1+J_X]				; Ou o desenho novo de um perto do antigo do outro?
		SUB		AX,[jog2+J_DX]
		CALL	perto
		JB		al_juntos
		MOV		AX,[jog1+J_DX]
		SUB		AX,[jog2+J_X]
		CALL	perto
		JB		al_juntos
		MOV		SI,jog1						; Longe: um de cada vez
		CALL	redesenha_se_mudou
		MOV		SI,jog2
		CALL	redesenha_se_mudou
		JMP		al_fim
al_juntos:
		MOV		SI,jog1
		CALL	mudou
		JNZ		al_os_dois
		MOV		SI,jog2
		CALL	mudou
		JZ		al_fim
al_os_dois:
		MOV		SI,jog1
		CALL	apaga_lutador
		MOV		SI,jog2
		CALL	apaga_lutador
		MOV		SI,jog1
		CALL	desenha_lutador
		MOV		SI,jog2
		CALL	desenha_lutador
al_fim:
		POP		SI
		POP		AX
		RET

; perto: AX = diferença entre dois x. CF = 1 se |AX| < PERTO
perto:
		OR		AX,AX
		JNS		pt_positivo
		NEG		AX
pt_positivo:
		CMP		AX,PERTO
		RET

; redesenha_se_mudou: apaga e desenha o lutador SI, se ele mudou
redesenha_se_mudou:
		CALL	mudou
		JZ		rm_fim
		CALL	apaga_lutador
		CALL	desenha_lutador
rm_fim:
		RET

; mudou: ZF = 0 se o lutador SI está diferente do que está na tela
mudou:
		PUSH	AX
		CMP		BYTE [SI+J_VIS],0			; Ainda não desenhado: precisa desenhar
		JE		md_sim
		MOV		AX,[SI+J_X]
		CMP		AX,[SI+J_DX]
		JNE		md_fim
		MOV		AX,[SI+J_Y]
		CMP		AX,[SI+J_DY]
		JNE		md_fim
		MOV		AL,[SI+J_POSE]
		CMP		AL,[SI+J_DPOSE]
		JNE		md_fim
		CALL	cor_atual
		CMP		AL,[SI+J_DCOR]
		JMP		md_fim
md_sim:
		OR		SP,SP						; SP nunca é zero: força ZF = 0
md_fim:
		POP		AX
		RET

; cor_atual: AL = cor com que o lutador SI deve aparecer agora
cor_atual:
		MOV		AL,[SI+J_COR]
		CMP		BYTE [SI+J_PISCA],0
		JE		ca_fim
		MOV		AL,branco_intenso			; Acabou de levar golpe: pisca em branco
ca_fim:
		RET

; apaga_lutador: redesenha em preto o desenho que está na tela
apaga_lutador:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		CMP		BYTE [SI+J_VIS],0
		JE		apl_fim
		MOV		BX,[SI+J_DX]
		MOV		DX,[SI+J_DY]
		ADD		DX,CHAO
		MOV		CL,[SI+J_DPOSE]
		MOV		CH,[SI+J_DIR]
		MOV		AL,preto
		CALL	desenha_pose
		MOV		BYTE [SI+J_VIS],0
apl_fim:
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

; desenha_lutador: desenha o lutador SI como está agora e guarda o que desenhou
desenha_lutador:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		MOV		BX,[SI+J_X]
		MOV		[SI+J_DX],BX
		MOV		DX,[SI+J_Y]
		MOV		[SI+J_DY],DX
		ADD		DX,CHAO
		MOV		CL,[SI+J_POSE]
		MOV		[SI+J_DPOSE],CL
		MOV		CH,[SI+J_DIR]
		CALL	cor_atual
		MOV		[SI+J_DCOR],AL
		CALL	desenha_pose
		MOV		BYTE [SI+J_VIS],1
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; desenha_pose: desenha um lutador
; AL = cor, BX = x do centro, DX = y do pé, CL = pose, CH = 1 (olha para a
; direita) ou -1 (olha para a esquerda)
; Formato da pose: db dx, dy da cabeça; db número de retas; db dx1,dy1,dx2,dy2...
; As retas são desenhadas duas vezes, lado a lado, para ter 2 pixels de largura.
desenha_pose:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		MOV		[cor],AL
		MOV		[px],BX
		MOV		[py],DX
		MOV		[pdir],CH
		MOV		BL,CL
		XOR		BH,BH
		SHL		BX,1
		MOV		SI,[BX+poses]				; SI = tabela da pose
		CLD
		LODSB								; Cabeça: círculo cheio
		CALL	conv_x
		PUSH	AX
		LODSB
		CALL	conv_y
		PUSH	AX
		MOV		AX,RAIO
		PUSH	AX
		CALL	full_circle
		LODSB
		MOV		CL,AL						; CX = número de retas
		XOR		CH,CH
dp_laco:
		LODSB								; Converte os 4 valores da reta
		CALL	conv_x
		MOV		[x1],AX
		LODSB
		CALL	conv_y
		MOV		[y1],AX
		LODSB
		CALL	conv_x
		MOV		[x2],AX
		LODSB
		CALL	conv_y
		PUSH	WORD [x1]
		PUSH	WORD [y1]
		PUSH	WORD [x2]
		PUSH	AX
		CALL	line
		INC		WORD [x1]					; Segunda passada, 1 pixel ao lado
		INC		WORD [x2]
		PUSH	WORD [x1]
		PUSH	WORD [y1]
		PUSH	WORD [x2]
		PUSH	AX
		CALL	line
		LOOP	dp_laco
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

; conv_x: AL = dx da tabela -> AX = px + dx (espelhado se olha para a esquerda)
conv_x:
		CBW
		TEST	BYTE [pdir],80h
		JZ		cx_dir
		NEG		AX
cx_dir:
		ADD		AX,[px]
		RET

; conv_y: AL = dy da tabela -> AX = py + dy
conv_y:
		CBW
		ADD		AX,[py]
		RET

segment data
		RAIO		EQU	7					; Raio da cabeça
		PERTO		EQU	96					; Distância em que os desenhos podem se encostar
px			DW	0							; Base da pose sendo desenhada
py			DW	0
pdir		DB	0
andou		DB	0							; 1 = o lutador andou neste tique
x1			DW	0
y1			DW	0
x2			DW	0

; Lutadores. Teclas: esquerda, direita, pular, abaixar, chute, soco
jog1:		DW	200,0,0						; J_X, J_Y, J_VY
			DB	1,E_PARADO,0,ENERGIA,0,vermelho,0,E_PARADO,0	; J_DIR ... J_PASSO
			DB	TC_A,TC_D,TC_W,TC_S,TC_R,TC_T	; J_K_...
			DB	0FFh						; J_DENER
			DW	0,0							; J_DX, J_DY
			DB	0,0,0,0						; J_DPOSE, J_DCOR, J_VIS, J_IMPACTO
jog2:		DW	440,0,0
			DB	-1,E_PARADO,0,ENERGIA,0,azul_claro,0,E_PARADO,0
			DB	TC_ESQ,TC_DIR,TC_CIMA,TC_BAIXO,TC_N,TC_M
			DB	0FFh
			DW	0,0
			DB	0,0,0,0

; Poses (olhando para a direita; y = 0 no pé)
poses		DW	p_parado, p_abaixado, p_pulo, p_soco, p_chute, p_anda
p_parado	DB	2,101, 9
			DB	0,90,0,52						; tronco
			DB	0,52,10,28, 10,28,15,0			; perna da frente
			DB	0,52,-8,28, -8,28,-14,0			; perna de trás
			DB	0,86,12,74, 12,74,20,86			; braço da frente em guarda
			DB	0,86,6,72, 6,72,14,80			; braço de trás em guarda
p_anda		DB	2,101, 9
			DB	0,90,0,52
			DB	0,52,5,26, 5,26,6,0
			DB	0,52,-3,26, -3,26,-6,0
			DB	0,86,12,74, 12,74,20,86
			DB	0,86,6,72, 6,72,14,80
p_abaixado	DB	4,66, 9
			DB	0,58,0,30
			DB	0,30,14,18, 14,18,12,0
			DB	0,30,-10,16, -10,16,-16,0
			DB	0,54,12,44, 12,44,18,56
			DB	0,54,6,42, 6,42,12,50
p_pulo		DB	2,101, 9
			DB	0,90,0,52
			DB	0,52,12,40, 12,40,4,26			; pernas encolhidas
			DB	0,52,-6,38, -6,38,-12,26
			DB	0,86,12,74, 12,74,20,86
			DB	0,86,6,72, 6,72,14,80
p_soco		DB	4,101, 8
			DB	0,90,2,52
			DB	2,52,12,28, 12,28,16,0
			DB	2,52,-8,28, -8,28,-14,0
			DB	0,86,38,86						; braço da frente esticado
			DB	0,86,4,72, 4,72,10,80
p_chute		DB	-6,100, 8
			DB	-4,90,0,52
			DB	0,52,22,56, 22,56,44,58			; perna da frente esticada
			DB	0,52,-6,26, -6,26,-8,0			; perna de apoio
			DB	-4,86,6,78, 6,78,12,88
			DB	-4,86,-14,74
