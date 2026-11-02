; copia.asm - Espaço da cópia do fundo usada por fundo.asm (4 bits por pixel,
; 320 bytes por linha da faixa y 46-301). São mais de 64 KB, então ficam em
; dois segmentos. Este módulo precisa ser o último a ser ligado (veja o Makefile).

global copia_a, copia_b

; O Freelink não começa estes segmentos em um parágrafo, então fundo.asm usa
; sempre SEG copia_a:copia_a (segmento e deslocamento dados pelo ligador)
segment copia_a_seg
copia_a		RESB	204*320					; Linhas 0-203 da faixa (LINHAS_A em fundo.asm)
segment copia_b_seg
copia_b		RESB	52*320					; Linhas 204-255
