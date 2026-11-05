; jogo.asm - Lógica do jogo: seleção, partida, rounds, pausa, saída e Game Over
;
; Fluxo (chamado pelo main):
;   tela_selecao -> partida (melhor de 3 rounds) -> tela_gameover -> de novo
; O laço da luta consome os tiques da INT 8h: cada tique é um passo de jogo
; (lutadores, golpes, tempo do round); depois a tela é atualizada só no que mudou.
;
; Critério de desempate: se o tempo acaba com a mesma energia, o round entra
; em MORTE SÚBITA. A luta continua sem relógio e o próximo golpe válido decide
; (a energia deixa de ser igual e vence quem tiver mais). Se os dois acertam
; no mesmo tique e chegam juntos a zero (duplo nocaute), o round é repetido.

%include "defs.inc"

extern cor, limpa_tela, escreve, escreve_centro, apaga_centro, caixa_mensagem
extern desenha_arena, desenha_energia, desenha_rounds, desenha_tempo, escreve_morte_subita
extern le_teclado, tecla_nova, limpa_novas
extern tiques, zera_tiques, espera_tique
extern jog1, jog2, inicia_jogadores, atualiza_jogador, atualiza_lutadores, desenha_pose
extern esquece_desenho, repinta_lutadores, apaga_lutador, limita_posicoes, energia_mudou, testa_golpe, aplica_golpe
extern encerra, fundo_pronto, restaura_fundo, caixa_aberta
global tela_selecao, partida, tela_gameover

segment code

;==============================================================================
; TELA DE SELEÇÃO DOS LUTADORES
; Jogador 1 troca de cor com W/S, jogador 2 com as setas; ENTER começa.
;==============================================================================
tela_selecao:
		CALL	redesenha_selecao
		CALL	limpa_novas
ts_laco:
		CALL	le_teclado
		MOV		SI,jog1						; Jogador 1: W volta uma cor, S avança
		MOV		DI,idx1
		MOV		BX,idx2
		MOV		AL,TC_W
		MOV		AH,TC_S
		CALL	ts_troca
		MOV		SI,jog2						; Jogador 2: seta para cima e para baixo
		MOV		DI,idx2
		MOV		BX,idx1
		MOV		AL,TC_CIMA
		MOV		AH,TC_BAIXO
		CALL	ts_troca
		MOV		AL,TC_ENTER
		CALL	tecla_nova
		JNZ		ts_fim
		MOV		AL,TC_Q
		CALL	tecla_nova
		JZ		ts_dorme
		MOV		BX,redesenha_selecao
		CALL	checa_sair
ts_dorme:
		CALL	espera_tique
		JMP		ts_laco
ts_fim:
		RET

; ts_troca: SI = lutador, DI = índice da cor dele, BX = índice do outro,
; AL = tecla "anterior", AH = tecla "próxima"
ts_troca:
		MOV		CL,AH						; CL = tecla "próxima"
		CALL	tecla_nova
		MOV		CH,-1						; CH = sentido na lista de cores
		JNZ		tt_muda
		MOV		AL,CL
		CALL	tecla_nova
		MOV		CH,1
		JNZ		tt_muda
		RET
tt_muda:
		MOV		DL,0
		CALL	desenha_escolha				; Apaga a figura atual (cor preta)
		MOV		AL,[DI]
tt_proxima:
		ADD		AL,CH						; Anda na lista de cores, dando a volta
		AND		AL,N_CORES-1
		CMP		AL,[BX]						; Pula a cor que o outro jogador escolheu
		JE		tt_proxima
		MOV		[DI],AL
		MOV		BL,AL
		XOR		BH,BH
		MOV		AL,[BX+lista_cores]
		MOV		[SI+J_COR],AL
		MOV		DL,1
		CALL	desenha_escolha				; Desenha na cor nova
		RET

; desenha_escolha: figura, nome e nome da cor de um jogador na seleção
; SI = lutador, DL = 1 desenha na cor dele, 0 apaga
desenha_escolha:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		MOV		AL,C_FUNDO
		OR		DL,DL
		JZ		de_cor
		MOV		AL,[SI+J_COR]
de_cor:
		MOV		[cor],AL
		MOV		BX,160						; Coluna do jogador 1
		MOV		DL,16
		MOV		CH,1						; e olha para a direita
		CMP		SI,jog1
		JE		de_lado
		MOV		BX,480						; Coluna do jogador 2, olhando para a esquerda
		MOV		DL,56
		MOV		CH,-1
de_lado:
		PUSH	DX
		MOV		DX,240						; Figura do lutador
		MOV		CL,P_PARADO
		CALL	desenha_pose				; (deixa [cor] com a cor usada, para os textos)
		POP		DX
		MOV		DH,5						; Nome do jogador
		MOV		AX,str_jog1
		CMP		SI,jog1
		JE		de_nome
		MOV		AX,str_jog2
de_nome:
		PUSH	SI
		MOV		SI,AX
		CALL	escreve
		POP		SI
		MOV		BX,idx1						; Nome da cor (sempre 8 letras)
		CMP		SI,jog1
		JE		de_idx
		MOV		BX,idx2
de_idx:
		MOV		AL,[BX]
		MOV		BL,9
		MUL		BL							; AX = índice * 9 (8 letras + 0)
		ADD		AX,nomes_cores
		MOV		SI,AX
		MOV		DH,16
		CALL	escreve
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

redesenha_selecao:
		PUSH	DX
		PUSH	SI
		CALL	limpa_tela
		MOV		BYTE [cor],C_SOL_AMAR
		MOV		DH,1
		MOV		SI,str_titulo
		CALL	escreve_centro
		MOV		BYTE [cor],C_BRANCO
		MOV		DH,3
		MOV		SI,str_escolha
		CALL	escreve_centro
		MOV		DL,1
		MOV		SI,jog1
		CALL	desenha_escolha
		MOV		SI,jog2
		CALL	desenha_escolha
		MOV		BYTE [cor],C_LILAS			; Como trocar de cor
		MOV		DH,17
		MOV		DL,13
		MOV		SI,str_troca1
		CALL	escreve
		MOV		DL,53
		MOV		SI,str_troca2
		CALL	escreve
		MOV		BYTE [cor],C_BRANCO			; Tabela de controles
		MOV		SI,str_controles
		MOV		DH,19
rs_controles:
		MOV		DL,10
		CALL	escreve						; Coluna do jogador 1
		CALL	proxima_string
		MOV		DL,50
		CALL	escreve						; Coluna do jogador 2
		CALL	proxima_string
		INC		DH
		CMP		BYTE [SI],0FFh				; Fim da tabela
		JNE		rs_controles
		MOV		BYTE [cor],C_SOL_AMAR
		MOV		DH,28
		MOV		SI,str_enter
		CALL	escreve_centro
		POP		SI
		POP		DX
		RET

; proxima_string: avança SI para depois do 0 da string atual
proxima_string:
		CMP		BYTE [SI],0
		JE		ps_fim
		INC		SI
		JMP		proxima_string
ps_fim:
		INC		SI
		RET

;==============================================================================
; PARTIDA: melhor de três rounds. Devolve AL = 1 ou 2 (vencedor).
;==============================================================================
partida:
		MOV		BYTE [jog1+J_VIT],0
		MOV		BYTE [jog2+J_VIT],0
		MOV		BYTE [str_round+6],'1'
pr_round:
		CALL	inicia_jogadores
		MOV		WORD [tempo],TEMPO_ROUND
		MOV		BYTE [fracao],0
		MOV		BYTE [morte_subita],0
		MOV		BYTE [msg_atual],0
		CALL	redesenha_luta
		MOV		SI,str_round				; Anúncio: "ROUND n" e "LUTEM!"
		MOV		AL,C_SOL_AMAR
		CALL	mostra_msg
		MOV		CX,27						; ~1,5 s
		CALL	espera
		CALL	esconde_msg
		MOV		SI,str_lutem
		MOV		AL,C_BRANCO
		CALL	mostra_msg
		MOV		CX,14						; ~0,8 s
		CALL	espera
		CALL	esconde_msg
		CALL	limpa_novas
		CALL	zera_tiques

; Laço da luta
pr_laco:
		CALL	le_teclado
		MOV		AL,TC_P
		CALL	tecla_nova
		JZ		pr_sair
		CALL	pausa
pr_sair:
		MOV		AL,TC_Q
		CALL	tecla_nova
		JZ		pr_tiques
		MOV		BX,redesenha_luta
		CALL	checa_sair
pr_tiques:
		CLI									; Pega os tiques acumulados pela INT 8h
		MOV		CX,[tiques]
		JCXZ	pr_dorme					; Nenhum: dorme com as interrupções ainda
		MOV		WORD [tiques],0				; desligadas (espera_tique faz STI e HLT juntos)
		STI
		MOV		BL,3						; No máximo 3 passos de jogo por quadro, mas o
pr_passos:									; relógio do round anda com todos os tiques
		OR		BL,BL
		JZ		pr_relogio
		DEC		BL
		CALL	passo
pr_relogio:
		CALL	relogio
		CALL	verifica_fim				; Conferido a cada tique: quem foi nocauteado
		OR		AL,AL						; não continua lutando
		JNZ		pr_acabou
		LOOP	pr_passos
		CALL	atualiza_tela
		JMP		pr_laco
pr_dorme:
		CALL	espera_tique
		JMP		pr_laco
pr_acabou:
		CALL	atualiza_tela				; Mostra o último golpe antes do aviso
		CMP		AL,3
		JNE		pr_fim_round
		MOV		SI,str_duplo				; Duplo nocaute: o round é repetido
		MOV		AL,C_SOL_AMAR
		CALL	mostra_msg
		MOV		CX,45
		CALL	espera
		CALL	esconde_msg
		JMP		pr_round

; Fim do round: AL = vencedor
pr_fim_round:
		MOV		SI,jog1
		CMP		AL,1
		JE		pr_vencedor
		MOV		SI,jog2
pr_vencedor:
		INC		BYTE [SI+J_VIT]
		PUSH	AX
		MOV		DL,0
		PUSH	SI
		MOV		SI,jog1
		CALL	desenha_rounds
		MOV		DL,1
		MOV		SI,jog2
		CALL	desenha_rounds
		POP		SI
		POP		AX
		ADD		AL,'0'
		MOV		[str_vence_round+8],AL
		MOV		AL,[SI+J_COR]
		PUSH	SI
		MOV		SI,str_vence_round
		CALL	mostra_msg
		POP		SI
		MOV		CX,45						; ~2,5 s
		CALL	espera
		CALL	esconde_msg
		MOV		AL,[str_vence_round+8]
		SUB		AL,'0'
		CMP		BYTE [SI+J_VIT],2			; Dois rounds: venceu a partida
		JE		pr_fim
		INC		BYTE [str_round+6]			; Próximo round
		JMP		pr_round
pr_fim:
		RET

;------------------------------------------------------------------------------
; passo: um tique de jogo
passo:
		PUSH	AX
		PUSH	BX
		PUSH	SI
		PUSH	DI
		MOV		SI,jog1						; Os dois lutadores se movem
		MOV		DI,jog2
		CALL	atualiza_jogador
		MOV		SI,jog2
		MOV		DI,jog1
		CALL	atualiza_jogador
		CALL	limita_posicoes
		MOV		SI,jog1						; Os dois golpes são testados com as posições
		MOV		DI,jog2						; deste tique antes de qualquer dano
		CALL	testa_golpe
		MOV		BL,AL						; BL = jogador 1 acertou
		MOV		SI,jog2
		MOV		DI,jog1
		CALL	testa_golpe
		MOV		BH,AL						; BH = jogador 2 acertou
		OR		BL,BL
		JZ		pa_golpe2
		MOV		SI,jog1
		MOV		DI,jog2
		CALL	aplica_golpe
pa_golpe2:
		OR		BH,BH
		JZ		pa_fim
		MOV		SI,jog2
		MOV		DI,jog1
		CALL	aplica_golpe
pa_fim:
		CALL	limita_posicoes				; O empurrão não tira ninguém da arena
		POP		DI
		POP		SI
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; relogio: um tique do tempo do round (91 tiques = 5 segundos, 18,2 por segundo)
relogio:
		CMP		WORD [tempo],0
		JE		rel_fim
		ADD		BYTE [fracao],5
		CMP		BYTE [fracao],91
		JB		rel_fim
		SUB		BYTE [fracao],91
		DEC		WORD [tempo]
		MOV		BYTE [tempo_mudou],1
rel_fim:
		RET

;------------------------------------------------------------------------------
; atualiza_tela: redesenha só o que mudou
atualiza_tela:
		PUSH	AX
		PUSH	DX
		PUSH	SI
		CALL	atualiza_lutadores
		CMP		BYTE [energia_mudou],0
		JE		at_tempo
		MOV		BYTE [energia_mudou],0
		MOV		SI,jog1
		MOV		DL,0
		CALL	desenha_energia
		MOV		SI,jog2
		MOV		DL,1
		CALL	desenha_energia
at_tempo:
		CMP		BYTE [tempo_mudou],0
		JE		at_fim
		MOV		BYTE [tempo_mudou],0
		CMP		BYTE [morte_subita],0
		JNE		at_fim
		MOV		AX,[tempo]
		CALL	desenha_tempo
at_fim:
		POP		SI
		POP		DX
		POP		AX
		RET

;------------------------------------------------------------------------------
; verifica_fim: AL = 0 (round continua), 1 ou 2 (vencedor do round),
; 3 (duplo nocaute)
verifica_fim:
		MOV		AL,3
		CMP		BYTE [jog1+J_ENER],0		; Os dois sem energia no mesmo tique
		JNE		vf_um
		CMP		BYTE [jog2+J_ENER],0
		JE		vf_fim
vf_um:
		MOV		AL,1
		CMP		BYTE [jog2+J_ENER],0		; Recebeu 10 golpes
		JE		vf_fim
		MOV		AL,2
		CMP		BYTE [jog1+J_ENER],0
		JE		vf_fim
		XOR		AL,AL
		CMP		WORD [tempo],0				; Ainda há tempo
		JNE		vf_fim
		MOV		AH,[jog1+J_ENER]			; Tempo esgotado: vence quem tem mais energia
		MOV		AL,1
		CMP		AH,[jog2+J_ENER]
		JA		vf_fim
		MOV		AL,2
		JB		vf_fim
		XOR		AL,AL						; Empate: morte súbita
		CMP		BYTE [morte_subita],0
		JNE		vf_fim
		MOV		BYTE [morte_subita],1
		CALL	escreve_morte_subita
		XOR		AL,AL
vf_fim:
		RET

;------------------------------------------------------------------------------
; redesenha_luta: desenha a tela da luta inteira (início do round e depois de
; fechar o menu de saída). Desenhar o cenário é demorado: se ele já está na
; tela (mesma partida), só o que está na frente dele é apagado: a caixa de
; saída e os lutadores (a mensagem do meio já foi apagada por esconde_msg).
redesenha_luta:
		PUSH	AX
		PUSH	DX
		PUSH	SI
		CMP		BYTE [fundo_pronto],0
		JE		rl_tudo
		CMP		BYTE [caixa_aberta],0
		JE		rl_lutadores_velhos
		MOV		BYTE [caixa_aberta],0
		MOV		AX,176						; Retângulo da caixa de caixa_mensagem
		PUSH	AX
		MOV		AX,226
		PUSH	AX
		MOV		AX,463
		PUSH	AX
		MOV		AX,268
		PUSH	AX
		CALL	restaura_fundo
rl_lutadores_velhos:
		MOV		SI,jog1						; Apaga os lutadores do jeito que estão na tela
		CALL	apaga_lutador
		MOV		SI,jog2
		CALL	apaga_lutador
		CALL	esquece_desenho
		JMP		rl_placar
rl_tudo:
		CALL	esquece_desenho
		CALL	limpa_tela
		CALL	desenha_arena
rl_placar:
		MOV		AL,[jog1+J_COR]				; Placar: nomes, round, energia, rounds, tempo
		MOV		[cor],AL
		MOV		DH,1
		MOV		DL,2
		MOV		SI,str_jog1
		CALL	escreve
		MOV		AL,[jog2+J_COR]
		MOV		[cor],AL
		MOV		DL,69
		MOV		SI,str_jog2
		CALL	escreve
		MOV		BYTE [cor],C_BRANCO
		MOV		SI,str_round
		CALL	escreve_centro
		MOV		SI,jog1
		MOV		DL,0
		CALL	desenha_energia
		CALL	desenha_rounds
		MOV		SI,jog2
		MOV		DL,1
		CALL	desenha_energia
		CALL	desenha_rounds
		MOV		AX,[tempo]
		CALL	desenha_tempo
		CMP		BYTE [morte_subita],0
		JE		rl_msg
		CALL	escreve_morte_subita
rl_msg:
		CMP		BYTE [msg_atual],0			; Mensagem que estava no meio da arena
		JE		rl_lutadores
		MOV		AL,[msg_cor]
		MOV		[cor],AL
		MOV		DH,LINHA_MSG
		MOV		SI,[msg_ptr]
		CALL	escreve_centro
rl_lutadores:
		CALL	atualiza_lutadores
		POP		SI
		POP		DX
		POP		AX
		RET

;------------------------------------------------------------------------------
; mostra_msg: SI = texto, AL = cor. Mensagem no meio da arena (acima dos
; lutadores, na frente do sol); redesenha_luta a repõe se a tela for refeita.
mostra_msg:
		PUSH	DX
		MOV		[msg_ptr],SI
		MOV		[msg_cor],AL
		MOV		BYTE [msg_atual],1
		MOV		[cor],AL
		MOV		DH,LINHA_MSG
		CALL	escreve_centro
		POP		DX
		RET

; esconde_msg: apaga a mensagem do meio da arena (devolve o fundo da linha) e
; desenha de novo os lutadores, caso um deles estivesse no ar atrás dela
esconde_msg:
		PUSH	DX
		PUSH	SI
		MOV		BYTE [msg_atual],0
		MOV		DH,LINHA_MSG
		MOV		SI,[msg_ptr]
		CALL	apaga_centro
		CALL	repinta_lutadores
		POP		SI
		POP		DX
		RET

;------------------------------------------------------------------------------
; espera: espera CX tiques sem rodar o jogo (anúncios). Q continua valendo.
espera:
		PUSH	AX
		PUSH	BX
		CALL	zera_tiques
es_laco:
		CALL	le_teclado
		MOV		AL,TC_Q
		CALL	tecla_nova
		JZ		es_conta
		MOV		BX,redesenha_luta
		CALL	checa_sair
es_conta:
		CLI									; Testa e dorme sem deixar escapar um tique
		CMP		[tiques],CX
		JAE		es_fim
		CALL	espera_tique
		JMP		es_laco
es_fim:
		STI
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; pausa: P para e P volta. O tempo parado não conta no round.
pausa:
		PUSH	AX
		PUSH	BX
		PUSH	SI
		MOV		SI,str_pausa
		MOV		AL,C_SOL_AMAR
		CALL	mostra_msg
pa_laco:
		CALL	le_teclado
		MOV		AL,TC_P
		CALL	tecla_nova
		JNZ		pa_volta
		MOV		AL,TC_Q
		CALL	tecla_nova
		JZ		pa_dorme
		MOV		BX,redesenha_luta			; A mensagem PAUSED volta junto com a tela
		CALL	checa_sair
pa_dorme:
		CALL	espera_tique
		JMP		pa_laco
pa_volta:
		CALL	esconde_msg
		CALL	limpa_novas
		CALL	zera_tiques					; Descarta os tiques da pausa
		POP		SI
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; checa_sair: pergunta "SAIR DO JOGO? (Y/N)". Y encerra o programa; N volta
; ao estado anterior chamando BX (rotina que redesenha a tela de quem chamou).
checa_sair:
		PUSH	AX
		PUSH	SI
		MOV		SI,str_sair
		CALL	caixa_mensagem
		CALL	limpa_novas
cs_laco:
		CALL	le_teclado
		MOV		AL,TC_Y
		CALL	tecla_nova
		JZ		cs_nao
		JMP		encerra						; Sim: restaura o sistema e volta ao DOS
cs_nao:
		MOV		AL,TC_N
		CALL	tecla_nova
		JNZ		cs_volta
		CALL	espera_tique
		JMP		cs_laco
cs_volta:
		CALL	BX							; Não: refaz a tela de antes
		CALL	limpa_novas
		CALL	zera_tiques
		POP		SI
		POP		AX
		RET

;==============================================================================
; GAME OVER: AL = vencedor. Y volta para a seleção (devolve), N encerra.
;==============================================================================
tela_gameover:
		MOV		[vencedor],AL
		CALL	redesenha_gameover
		CALL	limpa_novas
go_laco:
		CALL	le_teclado
		MOV		AL,TC_Y
		CALL	tecla_nova
		JNZ		go_fim
		MOV		AL,TC_N
		CALL	tecla_nova
		JZ		go_sair
		JMP		encerra
go_sair:
		MOV		AL,TC_Q
		CALL	tecla_nova
		JZ		go_dorme
		MOV		BX,redesenha_gameover
		CALL	checa_sair
go_dorme:
		CALL	espera_tique
		JMP		go_laco
go_fim:
		RET

redesenha_gameover:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		CALL	limpa_tela
		MOV		BYTE [cor],C_SOL_AMAR
		MOV		DH,6
		MOV		SI,str_gameover
		CALL	escreve_centro
		MOV		SI,jog1						; SI = vencedor
		CMP		BYTE [vencedor],1
		JE		rg_desenha
		MOV		SI,jog2
rg_desenha:
		MOV		AL,[SI+J_COR]				; Vencedor comemorando com um soco
		MOV		BX,320
		MOV		DX,212
		MOV		CL,P_SOCO
		MOV		CH,[SI+J_DIR]
		CALL	desenha_pose
		MOV		AL,[vencedor]
		ADD		AL,'0'
		MOV		[str_venceu+8],AL
		MOV		AL,[jog1+J_VIT]				; Placar final em rounds
		ADD		AL,'0'
		MOV		[str_placar],AL
		MOV		AL,[jog2+J_VIT]
		ADD		AL,'0'
		MOV		[str_placar+6],AL
		MOV		AL,[SI+J_COR]
		MOV		[cor],AL
		MOV		DH,17
		MOV		SI,str_venceu
		CALL	escreve_centro
		MOV		BYTE [cor],C_BRANCO
		MOV		DH,19
		MOV		SI,str_placar
		CALL	escreve_centro
		MOV		BYTE [cor],C_BRANCO
		MOV		DH,23
		MOV		SI,str_nova
		CALL	escreve_centro
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		RET

segment data
		LINHA_MSG	EQU	13					; Linha de texto das mensagens na arena
		N_CORES		EQU	4					; Tamanho da lista de cores (potência de 2)
tempo		DW	TEMPO_ROUND					; Segundos restantes do round
fracao		DB	0							; Acumula 5 por tique; 91 = 5 segundos
tempo_mudou	DB	0
morte_subita DB	0
vencedor	DB	0
msg_atual	DB	0							; 1 = há mensagem no meio da arena
msg_cor		DB	0
msg_ptr		DW	0
idx1		DB	0							; Cor escolhida (índice em lista_cores)
idx2		DB	1
; Só cores que não aparecem no cenário, para os lutadores se destacarem dele
lista_cores	DB	C_CIANO, C_VERDE, C_LILAS, C_BRANCO
nomes_cores	DB	' CIANO  ',0, ' VERDE  ',0, ' LILAS  ',0, ' BRANCO ',0
str_titulo	DB	'D O J O   8 0 8 6',0
str_escolha	DB	'ESCOLHAM A COR DOS LUTADORES',0
str_jog1	DB	'JOGADOR 1',0
str_jog2	DB	'JOGADOR 2',0
str_troca1	DB	'W / S  troca a cor',0
str_troca2	DB	18h,' / ',19h,'  troca a cor',0
str_controles DB 'A  D   andar',0,		1Bh,'  ',1Ah,'   andar',0
			DB	'W      pular',0,		18h,'      pular',0
			DB	'S      abaixar',0,		19h,'      abaixar',0
			DB	'R      chute',0,		'N      chute',0
			DB	'T      soco',0,		'M      soco',0
			DB	'S + R  rasteira',0,	19h,' + N  rasteira',0
			DB	'tr',0A0h,'s + R  chute girat',0A2h,'rio',0,	'tr',0A0h,'s + N  chute girat',0A2h,'rio',0
			DB	'tr',0A0h,'s + T  investida',0,	'tr',0A0h,'s + M  investida',0
			DB	0FFh
str_enter	DB	'ENTER  come',87h,'a a luta          Q  sai',0
str_round	DB	'ROUND 1',0
str_lutem	DB	'LUTEM!',0
str_duplo	DB	'DUPLO NOCAUTE!  O ROUND SERA REPETIDO',0
str_pausa	DB	'PAUSED',0
str_sair	DB	'SAIR DO JOGO?  (Y/N)',0
str_vence_round DB 'JOGADOR 1 VENCE O ROUND',0
str_gameover DB	'G A M E   O V E R',0
str_venceu	DB	'JOGADOR 1 VENCEU!',0
str_placar	DB	'0  X  0',0
str_nova	DB	'NOVA PARTIDA?  (Y/N)',0
