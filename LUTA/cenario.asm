; cenario.asm - Dados do cenário retrowave: as retas de cenario.inc (gerado por
; ferramentas/gera_fundo.py). Fica separado do fundo.asm porque, rodando pelo
; make, o NASM16 fica sem memória para montar tudo junto.

global cenario

segment data
%include "cenario.inc"
