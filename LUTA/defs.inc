; defs.inc - Constantes compartilhadas por todos os módulos do DOJO 8086
; Incluído com %include "defs.inc" (só tem EQU, não gera código nem dados)

;------------------------------------------------------------------------------
; Paleta retrowave (o modo 12h começa com a paleta padrão; aplica_paleta, em
; fundo.asm, troca as 16 cores logo depois de cada troca de modo de vídeo).
; Tirada das 10 imagens de referência: céu roxo-escuro, neon rosa e azul, sol
; em degradê do amarelo ao magenta. As cores dos lutadores (ciano, verde,
; lilás, branco) não aparecem no cenário, para eles se destacarem do fundo.
C_FUNDO		equ		0			; #1f014b  céu e chão (cor de "apagado")
C_ROXO		equ		1			; #3a0a6a  corpo das montanhas
C_MAGENTA	equ		2			; #8c1678  brilho do horizonte, base do sol
C_NEON_ROSA	equ		3			; #ff2bd1  grade do chão, borda da arena
C_SOL_AMAR	equ		4			; #ffd84c  topo do sol, títulos
C_SOL_LARANJA	equ		5			; #ff9a4c  meio do sol
C_SOL_CORAL	equ		6			; #ff4a4e  faixas do sol
C_SOL_ROSA	equ		7			; #ff1f64  faixas de baixo do sol, rodas do carro
C_SILHUETA	equ		8			; #0b0024  palmeiras, pneus
C_NEON_AZUL	equ		9			; #4f6bff  arestas das montanhas
C_HALO		equ		10			; #5e2a5a  anel do sol, energia perdida
C_BRANCO	equ		11			; #ffffff  textos, lutador atingido
C_CIANO		equ		12			; #00f0ff  lutador
C_VERDE		equ		13			; #4dff2e  lutador
C_LILAS		equ		14			; #c9a8ff  lutador, textos secundários
C_VERMELHO	equ		15			; #e8102e  Ferrari F40, lutador branco atingido

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
PULO_V		equ		27			; velocidade inicial do pulo (sobe até 135 pixels)
GRAV		equ		3			; quanto a velocidade vertical cai por tique
DIST_MIN	equ		36			; distância mínima entre os centros dos lutadores
ALT_CRUZA	equ		92			; diferença de altura para um passar por cima da cabeça do outro
ALC_SOCO	equ		54			; distância máxima para o soco acertar
ALC_CHUTE	equ		60			; distância máxima para o chute acertar
ALT_TOPO_PE	equ		108			; altura do topo da cabeça de um lutador em pé
ALT_TOPO_BX	equ		73			; altura do topo da cabeça de um lutador abaixado
ALT_BASE_AR	equ		18			; altura do ponto mais baixo de um lutador no ar (acima do J_Y)
TOL_V		equ		10			; folga vertical para o golpe pegar o adversário
T_GOLPE		equ		6			; duração de um soco ou chute, em tiques
T_IMPACTO	equ		4			; tique do golpe em que o acerto é verificado (no ar,
										; também nos 2 tiques seguintes)
EMPURRA		equ		8			; recuo de quem leva um golpe
T_PISCA		equ		3			; tiques que o lutador atingido fica branco
JANELA_RAST	equ		3			; abaixar até 3 tiques antes (ou depois) do chute = rasteira

; Ataques especiais: apertar a tecla de trás (a do lado oposto ao que o lutador
; olha) até JANELA_ESP tiques antes ou depois do golpe, em pé e no chão.
; Trás + chute = chute giratório; trás + soco = investida. Tiram 1 de energia
; como os outros golpes, mas alcançam mais longe e empurram bem mais; em troca
; demoram mais e deixam quem errou parado e exposto.
JANELA_ESP	equ		3			; tiques da janela da tecla de trás
T_GIRO		equ		10			; duração do chute giratório, em tiques
T_INVESTIDA	equ		9			; duração da investida
ALC_GIRO	equ		66			; alcance do chute giratório (o pé desenhado chega a 48)
ALC_INV		equ		58			; alcance do soco da investida (o lutador avança junto)
VEL_INV		equ		10			; avanço da investida por tique (6 tiques: 60 pixels)
EMPURRA_ESP	equ		28			; recuo de quem leva um ataque especial

;------------------------------------------------------------------------------
; Postura do lutador (J_EST). O golpe é independente da postura: o lutador
; pode socar ou chutar em pé, abaixado ou no ar (J_ATQ diz qual golpe está
; em andamento) e a pose desenhada muda conforme a combinação.
E_PARADO	equ		0			; em pé, no chão
E_ABAIXADO	equ		1			; abaixado, no chão
E_PULO		equ		2			; no ar

; Golpe em andamento (J_ATQ)
ATQ_NENHUM	equ		0
ATQ_SOCO	equ		1
ATQ_CHUTE	equ		2
ATQ_RASTEIRA	equ		3			; abaixar e chutar juntos, estando em pé
ATQ_GIRO	equ		4			; trás + chute: chute giratório
ATQ_INVESTIDA	equ		5			; trás + soco: investida com o punho

; Poses (índice da tabela "poses" em jogador.asm)
P_PARADO	equ		0
P_ABAIXADO	equ		1
P_PULO		equ		2
P_SOCO		equ		3			; em pé: soco reto
P_CHUTE		equ		4			; em pé: chute reto
P_ANDA		equ		5			; passo da caminhada
P_SOCO_BX	equ		6			; abaixado: soco na diagonal para cima
P_CHUTE_BX	equ		7			; abaixado: chute na diagonal para cima
P_SOCO_AR	equ		8			; no ar: soco na diagonal para baixo
P_CHUTE_AR	equ		9			; no ar: chute na diagonal para baixo
P_RASTEIRA	equ		10			; rasteira: perna esticada rente ao chão
P_ANDA_BX	equ		11			; caminhada abaixado: pernas cruzando
P_PASSADA_BX	equ		12			; caminhada abaixado: passada larga
P_GIRO_1	equ		13			; chute giratório: começa a virar, de lado
P_GIRO_2	equ		14			; chute giratório: de costas, braços abertos
P_GIRO_CHUTE	equ		15			; chute giratório: perna esticada na altura da cabeça
P_INV_PREP	equ		16			; investida: preparo, punho recolhido
P_INVESTIDA	equ		17			; investida: avançando com o punho esticado

;------------------------------------------------------------------------------
; Estrutura de um lutador (deslocamentos dentro de jog1/jog2)
J_X			equ		0			; dw  x do centro do corpo
J_Y			equ		2			; dw  altura do pulo (0 = no chão)
J_VY		equ		4			; dw  velocidade vertical (com sinal)
J_DIR		equ		6			; db  1 olha para a direita, -1 (0FFh) para a esquerda
J_EST		equ		7			; db  postura (E_...)
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
J_ATQ		equ		30			; db  golpe em andamento (ATQ_...)
J_TBX		equ		31			; db  tiques com a tecla de abaixar apertada (satura em 255)
J_DDIR		equ		32			; db  direção do desenho que está na tela
J_ACERTOU	equ		33			; db  1 = o golpe em andamento já acertou
J_TTRAS		equ		34			; db  tiques com a tecla de trás apertada (satura em 255)
J_TAM		equ		35			; tamanho da estrutura
