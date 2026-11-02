# DOJO 8086

Jogo de luta para dois jogadores no mesmo teclado, escrito em Assembly 8086 para DOS
(projeto de Sistemas Embarcados I, UFES). Modo de vídeo 12h (640x480, 16 cores),
cenário retrowave, partida em melhor de 3 rounds de 3 minutos, 10 de energia por round
e 1 de dano por golpe válido.

## Ferramentas

| Ferramenta | Uso | Onde está |
|---|---|---|
| DOSBox | ambiente DOS para montar e rodar | instalar à parte |
| NASM16 | montador (`-f obj`) | `FRASM/` |
| Freelink | ligador | `FRASM/` |
| GNU Make (DJGPP) + CWSDPMI | montagem pelo `Makefile` | `LUTA/` |
| Python 3 (opcional) | só para regenerar o cenário | `LUTA/ferramentas/gera_fundo.py` |

As rotinas gráficas `line`, `circle`, `full_circle`, `plot_xy`, `cursor` e `caracter`
são do professor. O código segue o padrão dele (Tecbuf, ClockINT, Linec).

## Compilar e executar

No DOSBox, monte a pasta do projeto e rode o `JOGAR.BAT`, que monta (`make`) e abre o jogo:

```
mount c "<caminho>/Projeto_ASM"
c:
jogar
```

Para fazer à mão: `path c:\frasm;z:\`, `cd luta`, `make` e `dojo`. O `make limpa` apaga
os `.OBJ`, os `.LST` e o executável.

Para mudar o cenário, rode `python3 LUTA/ferramentas/gera_fundo.py`, que reescreve
`LUTA/cenario.inc`. O `cenario.inc` já vem pronto, então a montagem não precisa de Python.

## Controles

| Ação | Jogador 1 | Jogador 2 |
|---|---|---|
| Andar / pular / abaixar | A D / W / S | ← → / ↑ / ↓ |
| Chute / soco | R / T | N / M |
| Rasteira | S + R | ↓ + N |
| Chute giratório | trás + R | trás + N |
| Investida | trás + T | trás + M |

Na seleção, W/S e ↑/↓ trocam a cor e ENTER começa. Na luta, P pausa e Q sai.
"Trás" é a tecla do lado oposto ao que o lutador olha.

## Principais decisões

- **Interrupções próprias.** As INT 9h (teclado) e INT 8h (relógio) são trocadas no vetor,
  como no Tecbuf e no ClockINT. Assim o jogo lê várias teclas ao mesmo tempo, dos dois
  jogadores, e cada tique (~18,2 por segundo) é um passo do jogo. Os vetores originais
  são restaurados ao sair.
- **Tela atualizada só no que muda.** A cada tique, cada lutador é apagado da posição
  antiga e redesenhado na nova; a tela nunca é limpa inteira. Assim a imagem não pisca.
- **Só BIOS, sem escrever na memória de vídeo.** Tudo é desenhado com as rotinas do
  professor. Enquanto o cenário é desenhado, cada pixel também é guardado numa cópia
  em RAM (80 KB, `copia.asm`). Para apagar um lutador, os pixels dele são repintados com
  a cor da cópia.
- **Cenário como tabela de retas.** O sol, as montanhas, as palmeiras, a grade e a
  Ferrari F40 são 1779 retas (`cenario.inc`), geradas por um script e desenhadas pela
  `line`. A paleta de 16 cores é reprogramada pela INT 10h.
- **Golpes por distância e altura.** Um golpe acerta se o adversário está na frente,
  dentro do alcance, e a ponta do golpe está na altura do corpo dele. Por isso dá para
  desviar abaixando ou pulando. Golpes no mesmo tique valem para os dois lados.
- **Ataques especiais.** Trás + chute (giratório) e trás + soco (investida, que avança
  até 60 px) alcançam mais longe e empurram mais. Em troca, duram mais e deixam quem
  errou exposto. Tiram 1 de energia, como os outros golpes.
- **Desempate por morte súbita.** Se o tempo acaba com energias iguais, a luta continua
  sem relógio e o próximo golpe válido decide. Num duplo nocaute, o round é repetido.
- **Restrições do NASM16 e do Freelink.** As retas ficam num módulo separado
  (`cenario.asm`, montado sem listagem), porque o NASM16 fica sem memória ou trava.
  O `copia.asm` é ligado por último, para as chamadas às rotinas do professor (que não
  têm `segment`) continuarem a menos de 64 KB do resto do código.
