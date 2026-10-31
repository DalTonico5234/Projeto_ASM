; defs.inc - Constantes compartilhadas por todos os módulos do DOJO 8086
; Incluído com %include "defs.inc" (só tem EQU, não gera código nem dados)

;------------------------------------------------------------------------------
; Cores da paleta padrão do modo 12h (mesma tabela do Data.asm do professor)
;	I R G B COR
preto		    equ		0
azul		    equ		1
verde		    equ		2
cyan		    equ		3
vermelho	    equ		4
magenta		    equ		5
marrom		    equ		6
branco		    equ		7
cinza		    equ		8
azul_claro	    equ		9
verde_claro	    equ		10
cyan_claro	    equ		11
rosa		    equ		12
magenta_claro	equ		13
amarelo		    equ		14
branco_intenso	equ		15

;------------------------------------------------------------------------------
; Códigos Make das teclas usadas (o código Break é Make + 80h)
TC_ESC		equ		01h
TC_Q		equ		10h
TC_W		equ		11h
TC_R		equ		13h
TC_T		equ		14h
TC_Y		equ		15h
TC_P		equ		19h
TC_ENTER	equ		1Ch
TC_A		equ		1Eh
TC_S		equ		1Fh
TC_D		equ		20h
TC_N		equ		31h
TC_M		equ		32h
TC_CIMA		equ		48h			; setas: o teclado manda E0h antes, que é ignorado
TC_ESQ		equ		4Bh
TC_DIR		equ		4Dh
TC_BAIXO	equ		50h

;------------------------------------------------------------------------------
; Arena (coordenadas do plot_xy: x 0-639, y 0-479 com y=0 embaixo)
ARENA_X1	equ		8			; delimitador esquerdo
ARENA_X2	equ		631			; delimitador direito
ARENA_Y1	equ		46			; delimitador inferior (chão)
ARENA_Y2	equ		396			; delimitador superior (abaixo do placar)
CHAO		equ		49			; y dos pés de um lutador parado no chão
X_MIN		equ		34			; menor x do centro de um lutador
X_MAX		equ		605			; maior x do centro de um lutador

;------------------------------------------------------------------------------
; Regras e física (unidades: pixels e tiques da INT 8h, ~18,2 por segundo)
ENERGIA		equ		10			; energia no início de cada round
TEMPO_ROUND	equ		180			; 3 minutos, em segundos
VEL			equ		6			; passo horizontal por tique
PULO_V		equ		15			; velocidade inicial do pulo
GRAV		equ		2			; quanto a velocidade vertical cai por tique
DIST_MIN	equ		36			; distância mínima entre os centros dos lutadores
ALC_SOCO	equ		54			; distância máxima para o soco acertar
ALC_CHUTE	equ		60			; distância máxima para o chute acertar
ALT_DESVIO	equ		24			; altura de pulo que faz o chute passar por baixo
T_GOLPE		equ		6			; duração de um soco ou chute, em tiques
T_IMPACTO	equ		4			; tique do golpe em que o acerto é verificado
EMPURRA		equ		8			; recuo de quem leva um golpe
T_PISCA		equ		3			; tiques que o lutador atingido fica branco

;------------------------------------------------------------------------------
; Estados (e poses) do lutador
E_PARADO	equ		0
E_ABAIXADO	equ		1
E_PULO		equ		2
E_SOCO		equ		3
E_CHUTE		equ		4
P_ANDA		equ		5			; só pose: passo da caminhada

;------------------------------------------------------------------------------
; Estrutura de um lutador (deslocamentos dentro de jog1/jog2)
J_X			equ		0			; dw  x do centro do corpo
J_Y			equ		2			; dw  altura do pulo (0 = no chão)
J_VY		equ		4			; dw  velocidade vertical (com sinal)
J_DIR		equ		6			; db  1 olha para a direita, -1 (0FFh) para a esquerda
J_EST		equ		7			; db  estado (E_...)
J_T			equ		8			; db  tiques restantes do golpe
J_ENER		equ		9			; db  energia
J_VIT		equ		10			; db  rounds vencidos
J_COR		equ		11			; db  cor escolhida
J_PISCA		equ		12			; db  tiques de pisca depois de levar golpe
J_POSE		equ		13			; db  pose a desenhar
J_PASSO		equ		14			; db  contador da animação de caminhada
J_K_ESQ		equ		15			; db  tecla: esquerda
J_K_DIR		equ		16			; db  tecla: direita
J_K_PULA	equ		17			; db  tecla: pular
J_K_ABAIXA	equ		18			; db  tecla: abaixar
J_K_CHUTE	equ		19			; db  tecla: chute
J_K_SOCO	equ		20			; db  tecla: soco
J_DENER		equ		21			; db  energia que está desenhada na barra (0FFh = redesenhar tudo)
J_DX		equ		22			; dw  x do desenho que está na tela
J_DY		equ		24			; dw  altura do desenho que está na tela
J_DPOSE		equ		26			; db  pose do desenho que está na tela
J_DCOR		equ		27			; db  cor do desenho que está na tela
J_VIS		equ		28			; db  1 se o lutador está desenhado na tela
J_IMPACTO	equ		29			; db  1 = golpe esticado neste tique, falta conferir o acerto
J_TAM		equ		30			; tamanho da estrutura
