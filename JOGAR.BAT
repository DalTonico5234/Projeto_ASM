@echo off
rem Monta o jogo com o Makefile e roda. Rode dentro do DOSBox, a partir desta pasta.
set DOJO_PATH=%PATH%
set PATH=%PATH%;..\FRASM
cd LUTA
make
if errorlevel 1 goto erro
DOJO
goto fim
:erro
echo.
echo A montagem falhou: veja as mensagens acima.
:fim
cd ..
set PATH=%DOJO_PATH%
set DOJO_PATH=
