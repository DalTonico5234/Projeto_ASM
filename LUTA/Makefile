# Makefile - DOJO 8086
#
# Monta cada módulo com o NASM16 e liga tudo com o Freelink (ferramentas do
# FRASM, que precisa estar no PATH). Rodar no DOS/DOSBox, nesta pasta:
#   make          monta só o que mudou e gera DOJO.EXE
#   make limpa    apaga os .OBJ, .LST e o executável
# MAKE.EXE é o GNU Make do DJGPP e precisa do CWSDPMI.EXE na mesma pasta.

NASM = nasm16
LINK = freelink

# Módulos do jogo e funções gráficas do professor (o main precisa ser o primeiro)
MODULOS = main init teclado tempo grafico jogador colisao jogo \
          line circle fcircle cursor caracter plot_xy
OBJS = $(addsuffix .obj,$(MODULOS))

dojo.exe: $(OBJS)
	$(LINK) $(MODULOS),dojo

# Regra geral: cada .asm gera seu .obj e a listagem .lst
%.obj: %.asm
	$(NASM) -f obj -o $@ -l $*.lst $<

# Dependências de arquivos incluídos com %include
teclado.obj grafico.obj jogador.obj colisao.obj jogo.obj: defs.inc
line.obj: Data.asm

limpa:
	-del *.obj
	-del *.lst
	-del dojo.exe

.PHONY: limpa
