; DOJO 8086 - Jogo de luta para dois jogadores em Assembly 8086
; Projeto de Sistemas Embarcados I
;
; main.asm - Ponto de entrada e laço das partidas
;
; Módulos:
;   main.asm     ponto de entrada e laço das partidas
;   init.asm     inicialização e encerramento (vídeo e vetores de interrupção)
;   teclado.asm  INT 9h, baseado no Tecbuf
;   tempo.asm    INT 8h, baseado no ClockINT
;   grafico.asm  tela, textos, arena e placar
;   fundo.asm    cenário retrowave: paleta, desenho e cópia do fundo na memória
;                (só usa a BIOS para desenhar: nada é escrito direto na memória de vídeo)
;   cenario.asm  as retas do cenário (inclui cenario.inc)
;   copia.asm    espaço da cópia do fundo (80 KB; é o último módulo ligado)
;   jogador.asm  lutadores: controles, movimento, poses e desenho
;   colisao.asm  acerto dos golpes e limites da arena
;   jogo.asm     seleção, rounds, pausa, saída e Game Over
;   line, circle, fcircle, cursor, caracter, plot_xy: funções gráficas do professor
;   defs.inc     constantes compartilhadas
; Montagem: make (veja o Makefile)
;
; Sobre o cenário: o desenho (sol, montanhas, palmeiras, grade e carro) foi
; projetado com a ajuda de um script em Python, ferramentas/gera_fundo.py, que
; transforma as formas em uma tabela de retas (cenario.inc, 1779 retas de
; x1,y1,x2,y2 e cor). O script só é usado quando o cenário é criado ou alterado,
; fora do jogo, e o cenario.inc gerado já vem com o projeto, então a montagem
; não precisa de Python. Toda a lógica do jogo e todo o desenho na tela são em
; Assembly: o jogo percorre a tabela e desenha cada reta com a função line do
; professor (fundo.asm). A tabela é só dado, como as tabelas das poses dos
; lutadores em jogador.asm.

extern inicializa, tela_selecao, partida, tela_gameover

segment code
..start:
		MOV		AX,data						; Inicializa os registradores de segmento
		MOV		DS,AX
		MOV		AX,stack
		MOV		SS,AX
		MOV		SP,stacktop
		CALL	inicializa					; Salva o vídeo e instala INT 8h e 9h
nova_partida:
		CALL	tela_selecao				; Escolha das cores
		CALL	partida						; Melhor de 3 rounds; AL = vencedor
		CALL	tela_gameover				; Só volta se escolherem nova partida (Y)
		JMP		nova_partida

segment data

segment stack stack
		RESB	512
stacktop:
