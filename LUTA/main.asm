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
;   jogador.asm  lutadores: controles, movimento, poses e desenho
;   colisao.asm  acerto dos golpes e limites da arena
;   jogo.asm     seleção, rounds, pausa, saída e Game Over
;   line, circle, fcircle, cursor, caracter, plot_xy: funções gráficas do professor
;   defs.inc     constantes compartilhadas
; Montagem: make (veja o Makefile)

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
