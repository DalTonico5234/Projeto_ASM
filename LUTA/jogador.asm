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
		MOV		SI,jog1						; Cada round começa com os lados originais:
		MOV		WORD [SI+J_X],200			; jogador 1 à esquerda, olhando para a direita
		MOV		BYTE [SI+J_DIR],1
		CALL	ij_comum
		MOV		SI,jog2
		MOV		WORD [SI+J_X],440
		MOV		BYTE [SI+J_DIR],-1
		CALL	ij_comum
		POP		SI
		RET
ij_comum:
		MOV		WORD [SI+J_Y],0
		MOV		WORD [SI+J_VY],0
		MOV		BYTE [SI+J_EST],E_PARADO
		MOV		BYTE [SI+J_POSE],P_PARADO
		MOV		BYTE [SI+J_T],0
		MOV		BYTE [SI+J_PISCA],0
		MOV		BYTE [SI+J_PASSO],0
		MOV		BYTE [SI+J_IMPACTO],0
		MOV		BYTE [SI+J_ATQ],ATQ_NENHUM
		MOV		BYTE [SI+J_TBX],0
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
; Lê as teclas do lutador, muda a postura e o golpe, move e marca o impacto.
; Postura (J_EST) e golpe (J_ATQ) são separados: em pé ou abaixado, o lutador
; fica travado na postura até o golpe acabar; no ar, o golpe acontece junto
; com o pulo (a gravidade e o movimento para os lados continuam).
; Rasteira: em pé, abaixar e chutar juntos (diferença de até JANELA_RAST
; tiques). Quem já estava abaixado antes faz o chute na diagonal para cima.
atualiza_jogador:
		PUSH	AX
		PUSH	BX
		MOV		BYTE [andou],0
		CMP		BYTE [SI+J_PISCA],0			; O branco de "levou golpe" vai sumindo
		JE		aj_conta
		DEC		BYTE [SI+J_PISCA]
aj_conta:
		MOV		AL,[SI+J_K_ABAIXA]			; Conta há quantos tiques a tecla de abaixar
		CALL	tecla_press					; está apertada (separa rasteira de chute abaixado)
		JNZ		aj_conta_bx
		MOV		BYTE [SI+J_TBX],0
		JMP		aj_estado
aj_conta_bx:
		CMP		BYTE [SI+J_TBX],255
		JE		aj_estado
		INC		BYTE [SI+J_TBX]
aj_estado:
		CMP		BYTE [SI+J_EST],E_PULO
		JE		aj_no_ar
		CMP		BYTE [SI+J_ATQ],ATQ_NENHUM
		JE		aj_no_chao

; Golpe no chão (em pé ou abaixado): o lutador não sai do lugar até o golpe acabar
		CALL	vira_rasteira
		CALL	avanca_golpe
		JMP		aj_fim

; No ar: pode começar um golpe (se não houver um em andamento), sobe e desce
; pela gravidade e pode se mover para os lados
aj_no_ar:
		CMP		BYTE [SI+J_ATQ],ATQ_NENHUM
		JNE		aj_ar_golpe
		CALL	inicia_golpe
		JMP		aj_fisica
aj_ar_golpe:
		CALL	avanca_golpe
aj_fisica:
		MOV		AL,[SI+J_K_PULA]			; Pulo apertado no ar não fica guardado
		CALL	tecla_nova					; para depois de cair
		MOV		AX,[SI+J_VY]
		ADD		[SI+J_Y],AX
		SUB		WORD [SI+J_VY],GRAV
		CMP		WORD [SI+J_Y],0				; Voltou ao chão
		JG		aj_anda
		MOV		WORD [SI+J_Y],0
		MOV		BYTE [SI+J_EST],E_PARADO
		MOV		BYTE [SI+J_ATQ],ATQ_NENHUM	; Golpe aéreo termina ao tocar o chão
		MOV		BYTE [SI+J_T],0
		MOV		BYTE [SI+J_IMPACTO],0
		JMP		aj_anda

; No chão, sem golpe: a postura vem da tecla de abaixar; depois golpe, pulo ou andar
aj_no_chao:
		MOV		BYTE [SI+J_EST],E_PARADO
		MOV		AL,[SI+J_K_ABAIXA]
		CALL	tecla_press
		JZ		aj_golpe
		MOV		BYTE [SI+J_EST],E_ABAIXADO
aj_golpe:
		CALL	inicia_golpe				; Golpe na postura atual (em pé ou abaixado)
		JNZ		aj_fim
		MOV		AL,[SI+J_K_PULA]			; Pula se a tecla está apertada ou foi
		CALL	tecla_nova					; apertada e solta dentro do mesmo tique
		JNZ		aj_pula
		MOV		AL,[SI+J_K_PULA]
		CALL	tecla_press
		JZ		aj_anda
aj_pula:
		MOV		BYTE [SI+J_EST],E_PULO
		MOV		WORD [SI+J_VY],PULO_V
		JMP		aj_fisica

; Andar: esquerda e direita juntas se anulam. Abaixado anda na metade da velocidade
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
		CMP		BYTE [SI+J_EST],E_ABAIXADO
		JNE		aj_soma
		SAR		BX,1						; Abaixado: metade do passo
aj_soma:
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
; inicia_golpe: se a tecla de soco ou de chute do lutador SI foi apertada,
; começa o golpe (J_ATQ e J_T). ZF = 0 se começou um golpe, ZF = 1 se não.
inicia_golpe:
		PUSH	AX
		MOV		AL,[SI+J_K_SOCO]
		CALL	tecla_nova
		MOV		AH,ATQ_SOCO					; MOV não altera o ZF de tecla_nova
		JNZ		ig_comeca
		MOV		AL,[SI+J_K_CHUTE]
		CALL	tecla_nova
		MOV		AH,ATQ_CHUTE
		JNZ		ig_chute
		POP		AX							; ZF = 1: nenhum golpe
		RET
ig_chute:
		CMP		BYTE [SI+J_EST],E_ABAIXADO	; Chute abaixado: se acabou de abaixar,
		JNE		ig_comeca					; é rasteira; se já estava abaixado,
		CMP		BYTE [SI+J_TBX],JANELA_RAST	; é o chute na diagonal para cima
		JA		ig_comeca
		MOV		AH,ATQ_RASTEIRA
ig_comeca:
		MOV		[SI+J_ATQ],AH
		MOV		BYTE [SI+J_T],T_GOLPE
		MOV		BYTE [SI+J_ACERTOU],0
		OR		AH,AH						; ZF = 0: começou um golpe (AH > 0)
		POP		AX							; POP não altera os flags
		RET

;------------------------------------------------------------------------------
; vira_rasteira: chute em pé que acabou de começar vira rasteira se a tecla de
; abaixar for apertada logo depois (até JANELA_RAST tiques, antes do impacto)
vira_rasteira:
		CMP		BYTE [SI+J_ATQ],ATQ_CHUTE
		JNE		vr_fim
		CMP		BYTE [SI+J_EST],E_PARADO
		JNE		vr_fim
		CMP		BYTE [SI+J_T],T_GOLPE-JANELA_RAST+1
		JB		vr_fim						; O chute já está adiantado demais
		CMP		BYTE [SI+J_TBX],0			; Tecla de abaixar não está apertada
		JE		vr_fim
		CMP		BYTE [SI+J_ACERTOU],0		; O chute já acertou: continua chute
		JNE		vr_fim
		MOV		BYTE [SI+J_ATQ],ATQ_RASTEIRA
		MOV		BYTE [SI+J_EST],E_ABAIXADO
		MOV		BYTE [SI+J_T],T_GOLPE		; A rasteira começa do início
vr_fim:
		RET

;------------------------------------------------------------------------------
; avanca_golpe: um tique do golpe em andamento do lutador SI. Marca o impacto
; no tique em que braço ou perna estão esticados (o acerto é conferido pelo
; passo, depois dos dois lutadores) e encerra o golpe quando o tempo acaba.
avanca_golpe:
		CALL	descarta_ataques
		DEC		BYTE [SI+J_T]
		CMP		BYTE [SI+J_ACERTOU],0		; Já acertou: não confere de novo
		JNE		avg_fim
		MOV		AL,[SI+J_T]
		CMP		AL,T_IMPACTO
		JE		avg_impacto
		CMP		BYTE [SI+J_EST],E_PULO		; No ar, braço ou perna ficam esticados por
		JNE		avg_fim						; 3 tiques enquanto o lutador cai sobre o
		CMP		AL,T_IMPACTO-2				; adversário: o acerto é conferido em cada um
		JB		avg_fim
		CMP		AL,T_IMPACTO
		JA		avg_fim
avg_impacto:
		MOV		BYTE [SI+J_IMPACTO],1
avg_fim:
		CMP		BYTE [SI+J_T],0				; Golpe acabou: volta à guarda da postura
		JNE		avg_volta
		MOV		BYTE [SI+J_ATQ],ATQ_NENHUM
avg_volta:
		RET

;------------------------------------------------------------------------------
; descarta_ataques: golpe ou pulo apertado enquanto o lutador está ocupado não
; fica guardado para depois
descarta_ataques:
		PUSH	AX
		MOV		AL,[SI+J_K_PULA]
		CALL	tecla_nova
		MOV		AL,[SI+J_K_SOCO]
		CALL	tecla_nova
		MOV		AL,[SI+J_K_CHUTE]
		CALL	tecla_nova
		POP		AX
		RET

;------------------------------------------------------------------------------
; escolhe_pose: pose da postura; com golpe em andamento, a pose do golpe
; naquela postura (tabela poses_golpe); andando (neste tique) em pé, alterna
; com a pose de passo a cada 2 tiques; andando abaixado, alterna passada larga
; e pernas cruzando a cada 4 tiques (passos largos e lentos)
escolhe_pose:
		PUSH	AX
		PUSH	BX
		MOV		AL,[SI+J_EST]				; Sem golpe: a pose é a da postura
		MOV		BL,[SI+J_ATQ]
		OR		BL,BL
		JZ		ep_sem_golpe
		MOV		AH,AL						; BX = postura*3 + (golpe-1)
		SHL		AL,1
		ADD		AL,AH
		ADD		BL,AL
		DEC		BL
		XOR		BH,BH
		MOV		AL,[BX+poses_golpe]
		JMP		ep_fim
ep_sem_golpe:
		CMP		BYTE [andou],0				; Parou de andar: volta à guarda
		JE		ep_fim
		CMP		AL,E_PARADO
		JNE		ep_abaixado
		TEST	BYTE [SI+J_PASSO],2			; Em pé: troca de perna a cada 2 tiques
		JZ		ep_fim
		MOV		AL,P_ANDA
		JMP		ep_fim
ep_abaixado:
		CMP		AL,E_ABAIXADO				; No ar não há passo
		JNE		ep_fim
		MOV		AL,P_PASSADA_BX				; Abaixado: troca a cada 4 tiques
		TEST	BYTE [SI+J_PASSO],4
		JZ		ep_fim
		MOV		AL,P_ANDA_BX
ep_fim:
		MOV		[SI+J_POSE],AL
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; atualiza_lutadores: põe na tela o que mudou nos lutadores desde o último
; desenho. Apagar é redesenhar em preto. Só quem mudou é apagado e
; redesenhado. Perto, um pode estar por cima do outro: apagar um pode tirar
; pixels do outro, então o outro é desenhado de novo por cima (sem apagar
; antes, então ele não pisca).
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
		XOR		AX,AX						; AL = 1 se o jogador 1 mudou, AH = 1 se o 2 mudou
		MOV		SI,jog1
		CALL	mudou
		JZ		al_m2
		INC		AL
al_m2:
		MOV		SI,jog2
		CALL	mudou
		JZ		al_m1
		INC		AH
al_m1:
		OR		AL,AL						; Quem mudou: apaga e desenha logo em seguida
		JZ		al_r2
		MOV		SI,jog1
		CALL	apaga_lutador
		CALL	desenha_lutador
al_r2:
		OR		AH,AH
		JZ		al_conserta
		MOV		SI,jog2
		CALL	apaga_lutador
		CALL	desenha_lutador
		MOV		SI,jog1						; Apagar o 2 pode ter tirado pixels do 1
		CALL	desenha_lutador
		JMP		al_fim
al_conserta:
		OR		AL,AL						; Só o 1 mudou: conserta o 2
		JZ		al_fim
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
		MOV		AL,[SI+J_DIR]				; Trocou de lado: virou para o outro lado
		CMP		AL,[SI+J_DDIR]
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

; apaga_lutador: redesenha em preto o desenho que está na tela. Se o lutador
; continua no mesmo lugar e virado para o mesmo lado (só a pose ou a cor
; mudou), apaga só as retas da pose antiga que não existem na nova: as que
; continuam não somem da tela (desenha_lutador passa por cima delas depois).
apaga_lutador:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		CMP		BYTE [SI+J_VIS],0
		JE		apl_fim
		MOV		AX,[SI+J_X]
		CMP		AX,[SI+J_DX]
		JNE		apl_tudo
		MOV		AX,[SI+J_Y]
		CMP		AX,[SI+J_DY]
		JNE		apl_tudo
		MOV		AL,[SI+J_DIR]
		CMP		AL,[SI+J_DDIR]
		JNE		apl_tudo
		MOV		BL,[SI+J_POSE]				; Mesmo lugar: compara com a pose nova
		XOR		BH,BH
		SHL		BX,1
		MOV		AX,[BX+poses]
		MOV		[filtro],AX
apl_tudo:
		MOV		BX,[SI+J_DX]
		MOV		DX,[SI+J_DY]
		ADD		DX,CHAO
		MOV		CL,[SI+J_DPOSE]
		MOV		CH,[SI+J_DDIR]				; Apaga virado para onde foi desenhado
		MOV		AL,preto
		CALL	desenha_pose
		MOV		WORD [filtro],0
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
		MOV		[SI+J_DDIR],CH
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
; Se [filtro] aponta para outra pose, a cabeça e as retas que também existem
; nela são puladas (usado para apagar só o que muda entre duas poses).
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
		MOV		BX,[filtro]					; Cabeça no mesmo lugar da pose do filtro:
		OR		BX,BX						; pula
		JZ		dp_cabeca
		MOV		AX,[SI]
		CMP		AX,[BX]
		JNE		dp_cabeca
		ADD		SI,2
		JMP		dp_retas
dp_cabeca:
		LODSB								; Cabeça: círculo cheio
		CALL	conv_x
		PUSH	AX
		LODSB
		CALL	conv_y
		PUSH	AX
		MOV		AX,RAIO
		PUSH	AX
		CALL	full_circle
dp_retas:
		LODSB
		MOV		CL,AL						; CX = número de retas
		XOR		CH,CH
dp_laco:
		CALL	reta_no_filtro				; Reta que também existe na pose do filtro:
		JNC		dp_desenha					; pula
		ADD		SI,4
		JMP		dp_proxima
dp_desenha:
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
dp_proxima:
		LOOP	dp_laco
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

; reta_no_filtro: SI = reta (dx1,dy1,dx2,dy2). CF = 1 se a mesma reta (em
; qualquer sentido) existe na pose apontada por [filtro]; CF = 0 se não, ou
; se não há filtro.
reta_no_filtro:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DI
		MOV		DI,[filtro]
		OR		DI,DI
		JZ		rf_nao
		MOV		CL,[DI+2]					; Número de retas da pose do filtro
		XOR		CH,CH
		ADD		DI,3						; Primeira reta
		MOV		AX,[SI]						; AX = ponta 1 (dx,dy), BX = ponta 2
		MOV		BX,[SI+2]
rf_laco:
		CMP		AX,[DI]
		JNE		rf_inversa
		CMP		BX,[DI+2]
		JE		rf_sim
rf_inversa:
		CMP		AX,[DI+2]
		JNE		rf_proxima
		CMP		BX,[DI]
		JE		rf_sim
rf_proxima:
		ADD		DI,4
		LOOP	rf_laco
rf_nao:
		CLC
		JMP		rf_fim
rf_sim:
		STC
rf_fim:
		POP		DI
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
filtro		DW	0							; Pose cujas retas desenha_pose pula (0 = nenhuma)

; Lutadores. Teclas: esquerda, direita, pular, abaixar, chute, soco
jog1:		DW	200,0,0						; J_X, J_Y, J_VY
			DB	1,E_PARADO,0,ENERGIA,0,vermelho,0,P_PARADO,0	; J_DIR ... J_PASSO
			DB	TC_A,TC_D,TC_W,TC_S,TC_R,TC_T	; J_K_...
			DB	0FFh						; J_DENER
			DW	0,0							; J_DX, J_DY
			DB	0,0,0,0,0,0,1,0				; J_DPOSE, J_DCOR, J_VIS, J_IMPACTO, J_ATQ, J_TBX, J_DDIR, J_ACERTOU
jog2:		DW	440,0,0
			DB	-1,E_PARADO,0,ENERGIA,0,azul_claro,0,P_PARADO,0
			DB	TC_ESQ,TC_DIR,TC_CIMA,TC_BAIXO,TC_N,TC_M
			DB	0FFh
			DW	0,0
			DB	0,0,0,0,0,0,-1,0

; Poses (olhando para a direita; y = 0 no pé)
poses		DW	p_parado, p_abaixado, p_pulo, p_soco, p_chute, p_anda
			DW	p_soco_bx, p_chute_bx, p_soco_ar, p_chute_ar, p_rasteira, p_anda_bx
			DW	p_passada_bx

; Pose de cada golpe em cada postura: índice = postura*3 + (golpe-1)
; Golpes: soco, chute, rasteira (a rasteira sempre acontece abaixada)
poses_golpe	DB	P_SOCO, P_CHUTE, P_RASTEIRA			; em pé: reto
			DB	P_SOCO_BX, P_CHUTE_BX, P_RASTEIRA	; abaixado: diagonal para cima
			DB	P_SOCO_AR, P_CHUTE_AR, P_CHUTE_AR	; no ar: diagonal para baixo

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
p_soco_bx	DB	4,66, 7
			DB	0,58,0,30
			DB	0,30,14,18, 14,18,12,0
			DB	0,30,-10,16, -10,16,-16,0
			DB	0,54,26,80						; braço da frente na diagonal para cima
			DB	0,54,6,42, 6,42,12,50
p_chute_bx	DB	-6,62, 8
			DB	-4,54,0,30						; tronco inclinado para trás
			DB	0,30,20,42, 20,42,40,60			; perna da frente na diagonal para cima
			DB	0,30,-8,14, -8,14,-6,0			; perna de apoio dobrada
			DB	-4,50,6,42, 6,42,10,52
			DB	-4,50,-14,40
p_soco_ar	DB	12,94, 8
			DB	8,86,0,52						; tronco inclinado para a frente (mergulho)
			DB	0,52,12,40, 12,40,4,26			; pernas encolhidas
			DB	0,52,-6,38, -6,38,-12,26
			DB	7,82,28,48						; braço da frente na diagonal para baixo
			DB	7,82,10,70, 10,70,16,76
p_chute_ar	DB	-6,98, 8
			DB	-4,88,0,52
			DB	0,52,18,30, 18,30,36,6			; perna da frente na diagonal para baixo
			DB	0,52,-8,40, -8,40,-14,30		; outra perna encolhida
			DB	-4,84,6,76, 6,76,12,86
			DB	-4,84,-16,74
p_anda_bx	DB	4,66, 9
			DB	0,58,0,30
			DB	0,30,16,22, 16,22,4,0			; pernas cruzando por baixo do corpo,
			DB	0,30,8,12, 8,12,-6,0			; os dois joelhos para a frente
			DB	0,54,12,44, 12,44,18,56
			DB	0,54,6,42, 6,42,12,50
p_passada_bx DB	4,62, 9
			DB	0,54,0,26						; corpo um pouco mais baixo na passada
			DB	0,26,18,18, 18,18,26,0			; perna da frente bem à frente
			DB	0,26,-14,10, -14,10,-28,0		; perna de trás bem atrás
			DB	0,50,12,40, 12,40,18,52
			DB	0,50,6,38, 6,38,12,46
p_rasteira	DB	-24,40, 9
			DB	-18,30,0,14						; tronco baixo, inclinado para trás
			DB	0,14,22,4, 22,4,46,1			; perna da frente rente ao chão
			DB	0,14,10,20, 10,20,6,0			; perna de apoio bem dobrada
			DB	-18,30,-26,16, -26,16,-28,0		; mão apoiada no chão (braço do tamanho normal)
			DB	-18,30,-6,34, -6,34,0,42		; outro braço em guarda
