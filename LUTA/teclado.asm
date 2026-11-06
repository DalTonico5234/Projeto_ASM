; teclado.asm - Tratamento do teclado pela interrupção de hardware INT 9h
;
; Baseado no programa Tecbuf: a rotina de interrupção lê o código
; Make/Break na porta 60h e guarda num buffer circular (p_i / p_t). O laço
; principal esvazia o buffer com le_teclado, que mantém uma tabela com o estado
; de cada tecla (para os dois jogadores segurarem teclas ao mesmo tempo) e uma
; tabela de "tecla nova" (apertou agora), usada para golpes e menus.
; Nenhuma leitura de tecla passa pela INT 21h.

%include "defs.inc"

global instala_teclado, restaura_teclado, le_teclado, tecla_nova, tecla_press, limpa_novas

segment code

;------------------------------------------------------------------------------
; instala_teclado: salva o vetor original da INT 9h e aponta para isr_teclado
instala_teclado:
		PUSH	AX
		PUSH	ES
		CLI									; Sem interrupções enquanto o vetor é trocado
		XOR		AX,AX
		MOV		ES,AX						; ES = 0, região dos vetores de interrupção
		MOV		AX,[ES:INT9*4]				; IP original da INT 9h
		MOV		[offset_dos],AX
		MOV		AX,[ES:INT9*4+2]			; CS original da INT 9h
		MOV		[cs_dos],AX
		MOV		[ES:INT9*4+2],CS			; Novo vetor: CS deste programa
		MOV		WORD [ES:INT9*4],isr_teclado	; e o offset da rotina
		STI
		POP		ES
		POP		AX
		RET

;------------------------------------------------------------------------------
; restaura_teclado: devolve o vetor original da INT 9h (retorno seguro ao DOS)
restaura_teclado:
		PUSH	AX
		PUSH	ES
		CLI
		XOR		AX,AX
		MOV		ES,AX
		MOV		AX,[cs_dos]
		MOV		[ES:INT9*4+2],AX
		MOV		AX,[offset_dos]
		MOV		[ES:INT9*4],AX
		STI
		POP		ES
		POP		AX
		RET

;------------------------------------------------------------------------------
; isr_teclado: executada a cada tecla apertada ou solta (INT 9h)
isr_teclado:
		PUSH	AX
		PUSH	BX
		PUSH	DS
		MOV		AX,data						; A interrupção pode chegar durante uma chamada à BIOS,
		MOV		DS,AX						; então DS é recarregado aqui
		IN		AL,kb_data					; Código Make/Break da tecla (porta 60h)
		MOV		BX,[p_i]
		INC		BX							; Próxima posição do buffer circular
		AND		BX,TAM_BUF-1
		CMP		BX,[p_t]					; Buffer cheio? Descarta o código em vez de
		JE		isr_t_fim					; sobrescrever o que ainda não foi lido
		MOV		[BX+tecla],AL
		MOV		[p_i],BX
isr_t_fim:
		IN		AL,kb_ctl					; Pulso no bit 7 da porta 61h: libera o
		OR		AL,80h						; registrador do teclado para o próximo código
		OUT		kb_ctl,AL
		AND		AL,7Fh
		OUT		kb_ctl,AL
		MOV		AL,eoi						; Fim de interrupção para o PIC
		OUT		pictrl,AL
		POP		DS
		POP		BX
		POP		AX
		IRET

;------------------------------------------------------------------------------
; le_teclado: esvazia o buffer e atualiza as tabelas estado[] e nova[]
; Deve ser chamada sempre no laço principal.
le_teclado:
		PUSH	AX
		PUSH	BX
le_t_laco:
		MOV		BX,[p_t]
		CMP		BX,[p_i]					; p_t = p_i: nada novo no buffer
		JE		le_t_fim
		INC		BX
		AND		BX,TAM_BUF-1
		MOV		AL,[BX+tecla]				; Código lido pela interrupção
		MOV		[p_t],BX
		CMP		AL,0E0h						; Prefixo das teclas estendidas (setas): ignora
		JE		le_t_laco
		CMP		AL,0E1h						; Prefixo da tecla Pause: ignora
		JE		le_t_laco
		MOV		BL,AL
		AND		BX,007Fh					; BX = código Make da tecla (0-127)
		TEST	AL,80h						; Bit 7 = 1: código Break (tecla solta)
		JNZ		le_t_solta
		CMP		BYTE [BX+estado],0			; Só marca "nova" se a tecla estava solta,
		JNE		le_t_segura					; assim a repetição automática não conta
		MOV		BYTE [BX+nova],1
le_t_segura:
		MOV		BYTE [BX+estado],1
		JMP		le_t_laco
le_t_solta:
		MOV		BYTE [BX+estado],0
		JMP		le_t_laco
le_t_fim:
		POP		BX
		POP		AX
		RET

;------------------------------------------------------------------------------
; tecla_nova: AL = código Make. Devolve AL = 1 se a tecla foi apertada desde a
; última consulta (e apaga a marca), AL = 0 se não. ZF reflete o resultado.
tecla_nova:
		PUSH	BX
		MOV		BL,AL
		XOR		BH,BH
		MOV		AL,[BX+nova]
		MOV		BYTE [BX+nova],0
		OR		AL,AL
		POP		BX
		RET

;------------------------------------------------------------------------------
; tecla_press: AL = código Make. Devolve AL = 1 se a tecla está pressionada.
tecla_press:
		PUSH	BX
		MOV		BL,AL
		XOR		BH,BH
		MOV		AL,[BX+estado]
		OR		AL,AL
		POP		BX
		RET

;------------------------------------------------------------------------------
; limpa_novas: esquece as teclas apertadas antes de uma tela nova
limpa_novas:
		PUSH	AX
		PUSH	CX
		PUSH	DI
		PUSH	ES
		CALL	le_teclado					; Primeiro atualiza o estado do que está no buffer
		MOV		AX,DS
		MOV		ES,AX
		MOV		DI,nova
		MOV		CX,128
		XOR		AL,AL
		CLD
		REP		STOSB
		POP		ES
		POP		DI
		POP		CX
		POP		AX
		RET

segment data
		kb_data		EQU	60h					; Porta de leitura do teclado
		kb_ctl		EQU	61h					; Porta de reset para pedir nova interrupção
		pictrl		EQU	20h					; Porta do PIC
		eoi			EQU	20h					; Byte de fim de interrupção
		INT9		EQU	9h					; Interrupção de hardware do teclado
		TAM_BUF		EQU	64					; Tamanho do buffer circular (potência de 2)
cs_dos		DW	0							; CS original da INT 9h
offset_dos	DW	0							; IP original da INT 9h
tecla		TIMES TAM_BUF DB 0				; Buffer circular de códigos Make/Break
p_i			DW	0							; Índice escrito pela interrupção
p_t			DW	0							; Índice lido pelo laço principal
estado		TIMES 128 DB 0					; 1 = tecla pressionada agora
nova		TIMES 128 DB 0					; 1 = tecla apertada e ainda não consultada
