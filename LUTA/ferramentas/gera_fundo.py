#!/usr/bin/env python3
"""gera_fundo.py - Gera o cenário retrowave do DOJO 8086 como tabela de retas.

O cenário é "vetorizado" aqui, na hora do projeto: sol (cópia do sol da ref7,
com degradê em faixas e anel), montanhas low-poly, palmeiras, grade do chão e
uma Ferrari F40 de perfil viram uma lista de retas (x1,y1,x2,y2,cor). O jogo
(fundo.asm; os dados entram pelo cenario.asm) só percorre a lista e chama a
função line para cada reta. Áreas cheias (sol, montanhas, carro)
viram retas horizontais/verticais.

Uso:  python3 gera_fundo.py            -> escreve ../cenario.inc
      python3 gera_fundo.py previa.png -> também desenha a prévia (mesmas retas)

Coordenadas como no plot_xy: x 0-639, y 0-479 com y = 0 EMBAIXO.
As cores são os índices da paleta definida em defs.inc (C_...).
"""
import math, os, sys

# ----------------------------------------------------------------------------
# Paleta (mesma ordem de defs.inc / grafico.asm). RGB de 8 bits só para a prévia.
PALETA = [
    ('C_FUNDO',    (0x1f, 0x01, 0x4b)),   # 0  céu e chão (o que é "apagado")
    ('C_ROXO',     (0x3a, 0x0a, 0x6a)),   # 1  corpo das montanhas
    ('C_MAGENTA',  (0x8c, 0x16, 0x78)),   # 2  brilho do horizonte, base do sol, vidros
    ('C_NEON_ROSA',(0xff, 0x2b, 0xd1)),   # 3  grade, borda da arena
    ('C_SOL_AMAR', (0xff, 0xd8, 0x4c)),   # 4  sol (topo), títulos
    ('C_SOL_LARANJA',(0xff, 0x9a, 0x4c)), # 5  sol (meio)
    ('C_SOL_CORAL',(0xff, 0x4a, 0x4e)),   # 6  sol (faixas)
    ('C_SOL_ROSA', (0xff, 0x1f, 0x64)),   # 7  sol (faixas baixas), rodas
    ('C_SILHUETA', (0x0b, 0x00, 0x24)),   # 8  palmeiras, pneus
    ('C_NEON_AZUL',(0x4f, 0x6b, 0xff)),   # 9  arestas das montanhas
    ('C_HALO',     (0x5e, 0x2a, 0x5a)),   # 10 anel do sol, energia perdida
    ('C_BRANCO',   (0xff, 0xff, 0xff)),   # 11 textos, lutador atingido
    ('C_CIANO',    (0x00, 0xf0, 0xff)),   # 12 lutador
    ('C_VERDE',    (0x4d, 0xff, 0x2e)),   # 13 lutador
    ('C_LILAS',    (0xc9, 0xa8, 0xff)),   # 14 lutador, textos secundários
    ('C_VERMELHO', (0xe8, 0x10, 0x2e)),   # 15 carro F40
]
C = {nome: i for i, (nome, _) in enumerate(PALETA)}

# Arena (igual ao defs.inc)
X1, X2, Y1, Y2 = 8, 631, 46, 396
HZ = 190                       # linha do horizonte

retas = []                     # (cor, x1, y1, x2, y2, comentário do bloco)
blocos = []                    # (comentário, índice inicial)

def bloco(nome):
    blocos.append((nome, len(retas)))

def reta(cor, x1, y1, x2, y2):
    retas.append((C[cor], int(round(x1)), int(round(y1)), int(round(x2)), int(round(y2))))

def reta_grossa(cor, x1, y1, x2, y2, larg):
    """Reta de 'larg' pixels: cópias deslocadas na direção perpendicular dominante."""
    vertical = abs(y2 - y1) >= abs(x2 - x1)
    for k in range(larg):
        o = k - larg // 2
        if vertical:
            reta(cor, x1 + o, y1, x2 + o, y2)
        else:
            reta(cor, x1, y1 + o, x2, y2 + o)

def isqrt(n):
    return int(math.isqrt(max(0, n)))

# ----------------------------------------------------------------------------
# 1) Brilho do horizonte: linhas alternadas logo acima do horizonte
bloco('brilho do horizonte')
for y in range(HZ + 2, HZ + 24, 2):
    reta('C_MAGENTA', X1 + 1, y, X2 - 1, y)

# ----------------------------------------------------------------------------
# 2) Sol (cópia vetorizada do sol da ref7). Medidas tiradas da ref7 (740x740,
#    disco de diâmetro ~516): metade de cima cheia em degradê amarelo->laranja,
#    metade de baixo cortada por faixas vazias que engrossam para baixo, e um
#    anel translúcido um pouco deslocado para cima e para a direita.
SX, SY, SR = 320, 262, 96
bloco('anel do sol')
HXc, HYc, HR_EXT, HR_INT = SX + 4, SY + 5, SR + 7, SR + 4
for y in range(HZ + 1, HYc + HR_EXT + 1):
    dy = y - HYc
    he = isqrt(HR_EXT * HR_EXT - dy * dy)
    hi = isqrt(HR_INT * HR_INT - dy * dy) if abs(dy) < HR_INT else -1
    if hi < 0:
        reta('C_HALO', HXc - he, y, HXc + he, y)
    else:
        reta('C_HALO', HXc - he, y, HXc - hi - 1, y)
        reta('C_HALO', HXc + hi + 1, y, HXc + he, y)

def cor_sol(u):                 # u = distância abaixo do centro, em fração do raio
    if u < -0.45: return 'C_SOL_AMAR'
    if u < -0.05: return 'C_SOL_LARANJA'
    if u < 0.30:  return 'C_SOL_CORAL'
    if u < 0.62:  return 'C_SOL_ROSA'
    return 'C_MAGENTA'

# Faixas vazias da ref7: a primeira um pouco acima do centro, cada uma mais grossa
VAZIOS = [(-0.10 + k * 0.15, -0.10 + k * 0.15 + (1.5 + k * 1.5) / SR) for k in range(8)]
# Deslocamento "glitch" das faixas de baixo (na ref7 elas saem um pouco do disco)
GLITCH = [0, 0, 2, -2, 3, -3, 4, -4, 5]
bloco('sol')
for y in range(HZ + 1, SY + SR + 1):
    u = (SY - y) / SR
    if any(a <= u <= b for a, b in VAZIOS):
        continue
    faixa = sum(1 for a, _ in VAZIOS if u > a)            # quantas faixas vazias acima
    d = GLITCH[min(faixa, len(GLITCH) - 1)]
    hw = isqrt(SR * SR - (y - SY) ** 2)
    reta(cor_sol(u), SX - hw + d, y, SX + hw + d, y)

# ----------------------------------------------------------------------------
# 3) Montanhas low-poly (ref4/ref9): corpo cheio (colunas) e arestas neon
ME = [(X1 + 1, HZ), (X1 + 1, 232), (40, 262), (78, 236), (118, 292), (160, 248), (196, 272), (238, HZ)]
MD = [(404, HZ), (440, 268), (478, 240), (520, 300), (560, 252), (596, 276), (X2 - 1, 244), (X2 - 1, HZ)]
FACES_E = [(40, 262, 52, HZ), (78, 236, 92, HZ), (118, 292, 104, HZ), (118, 292, 140, HZ), (160, 248, 168, HZ), (196, 272, 186, HZ)]
FACES_D = [(440, 268, 452, HZ), (478, 240, 486, HZ), (520, 300, 506, HZ), (520, 300, 540, HZ), (560, 252, 566, HZ), (596, 276, 604, HZ)]

def topo(perfil, x):
    for (xa, ya), (xb, yb) in zip(perfil, perfil[1:]):
        if xa <= x <= xb and xb != xa:
            return ya + (yb - ya) * (x - xa) / (xb - xa)
    return HZ

for nome, perfil, faces in [('montanhas da esquerda', ME, FACES_E), ('montanhas da direita', MD, FACES_D)]:
    bloco(nome)
    for x in range(perfil[0][0], perfil[-1][0] + 1):
        t = int(topo(perfil, x))
        if t > HZ + 1:
            reta('C_ROXO', x, HZ + 1, x, t)
    for (xa, ya), (xb, yb) in zip(perfil, perfil[1:]):
        if not (xa == xb):                                  # bordas verticais da arena: não
            reta('C_NEON_AZUL', xa, ya, xb, yb)
    for f in faces:
        reta('C_NEON_AZUL', *f)

# ----------------------------------------------------------------------------
# 4) Palmeiras (silhuetas, ref1/ref3/ref10): tronco curvo e folhas caídas
def palmeira(bx, by, altura, curva, lado, folhas):
    pts = []
    for i in range(0, altura + 1, 6):
        f = i / altura
        pts.append((bx + curva * f * f * lado, by + i))
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        larg = max(2, int(round(5 - 3 * (ya - by) / altura)))
        reta_grossa('C_SILHUETA', xa, ya, xb, yb, larg)
    tx, ty = pts[-1]
    for ang, comp, caida in folhas:
        a = math.radians(ang)
        prev = (tx, ty)
        for s in range(1, 9):
            f = s / 8
            x = tx + math.cos(a) * comp * f
            y = ty + math.sin(a) * comp * f * 0.6 - caida * f * f
            reta_grossa('C_SILHUETA', prev[0], prev[1], x, y, max(1, int(round(4 - 3 * f))))
            prev = (x, y)

FOLHAS = [(15, 46, 22), (50, 40, 26), (100, 34, 18), (150, 42, 26), (185, 46, 22), (-30, 30, 26), (220, 30, 24)]
bloco('palmeiras')
palmeira(372, HZ, 150, 26, 1, FOLHAS)
palmeira(404, HZ, 110, -14, 1, [(a, int(c * 0.8), int(q * 0.8)) for a, c, q in FOLHAS])
palmeira(70, HZ, 128, 18, -1, FOLHAS)

# ----------------------------------------------------------------------------
# 5) Grade do chão (ref1/ref4): retas que convergem no centro do horizonte e
#    horizontais cada vez mais juntas perto do horizonte
bloco('grade do chão')
# Retas de fuga (convergem no centro do horizonte) e horizontais em magenta,
# perto da cor do chão, para a grade ficar suave e não brigar com os
# lutadores; só a linha do horizonte fica em neon. As retas de fuga começam
# na primeira horizontal (FUGA_DY abaixo do horizonte): juntas até o centro,
# elas viravam uma mancha clara no meio da tela.
COR_FUGA = os.environ.get('COR_FUGA', 'C_MAGENTA')
COR_HORIZ = os.environ.get('COR_HORIZ', 'C_MAGENTA')
FUGA_DY = int(os.environ.get('FUGA_DY', '4'))
reta('C_NEON_ROSA', X1 + 1, HZ, X2 - 1, HZ)
for k in range(-12, 13):
    xb = 320 + k * 64
    # ponto da reta (320,HZ)-(xb,Y1+1) na altura HZ-FUGA_DY
    ya = HZ - FUGA_DY
    xa = 320 + (xb - 320) * FUGA_DY / (HZ - (Y1 + 1))
    xf, yf = xb, Y1 + 1
    if xf < X1 + 1:
        yf = HZ - (HZ - (Y1 + 1)) * (320 - (X1 + 1)) / (320 - xb); xf = X1 + 1
    if xf > X2 - 1:
        yf = HZ - (HZ - (Y1 + 1)) * ((X2 - 1) - 320) / (xb - 320); xf = X2 - 1
    reta(COR_FUGA, xa, ya, xf, yf)
for dy in [4, 9, 16, 26, 40, 60, 88, 126]:
    reta(COR_HORIZ, X1 + 1, HZ - dy, X2 - 1, HZ - dy)

# ----------------------------------------------------------------------------
# 6) Ferrari F40 de perfil (refs 2, 8, 9, 10), virada para a esquerda.
#    Proporções do carro real: 4,36 m x 1,13 m, entre-eixos 2,45 m -> 150 x 38 px
def preenche_poligono(cor, pts, dx, dy):
    """Rasteriza um polígono em retas horizontais (regra par-ímpar por linha)."""
    ys = [p[1] for p in pts]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        xs = []
        for (xa, ya), (xb, yb) in zip(pts, pts[1:] + pts[:1]):
            if (ya <= y < yb) or (yb <= y < ya):
                xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
        xs.sort()
        for a, b in zip(xs[::2], xs[1::2]):
            if b - a >= 0.5:
                reta(cor, dx + math.ceil(a), dy + y, dx + math.floor(b), dy + y)

def disco(cor, xc, yc, r):
    for y in range(-r, r + 1):
        hw = isqrt(r * r - y * y)
        reta(cor, xc - hw, yc + y, xc + hw, yc + y)

CX0, CY0 = 456, HZ - 32                 # canto esquerdo de baixo do carro
CORPO = [(0, 7), (1, 14), (8, 17), (24, 20), (46, 23), (52, 24), (72, 32), (94, 33),
         (112, 29), (130, 26), (147, 25), (150, 21), (150, 10), (146, 6),
         (129, 6), (127, 12), (117, 18), (107, 12), (105, 6), (45, 6), (43, 12), (33, 18),
         (23, 12), (21, 6), (3, 5)]
bloco('carro F40')
preenche_poligono('C_VERMELHO', CORPO, CX0, CY0)
preenche_poligono('C_MAGENTA', [(56, 22), (73, 30), (91, 30), (96, 23)], CX0, CY0)      # vidro lateral
preenche_poligono('C_SILHUETA', [(100, 14), (112, 16), (112, 19), (101, 18)], CX0, CY0) # tomada de ar
reta_grossa('C_VERMELHO', CX0 + 124, CY0 + 35, CX0 + 151, CY0 + 35, 3)                 # aerofólio
reta_grossa('C_VERMELHO', CX0 + 136, CY0 + 26, CX0 + 136, CY0 + 34, 2)                 # suporte
reta('C_SILHUETA', CX0 + 46, CY0 + 9, CX0 + 104, CY0 + 9)                             # soleira
reta('C_SILHUETA', CX0 + 56, CY0 + 10, CX0 + 56, CY0 + 21)                            # porta
reta('C_SILHUETA', CX0 + 97, CY0 + 10, CX0 + 97, CY0 + 23)
reta('C_BRANCO', CX0 + 10, CY0 + 15, CX0 + 22, CY0 + 17)                              # farol escamoteável
reta_grossa('C_SOL_ROSA', CX0 + 148, CY0 + 17, CX0 + 148, CY0 + 22, 2)                 # lanterna
for xr in (33, 117):
    disco('C_SILHUETA', CX0 + xr, CY0 + 10, 10)                                        # pneu
    disco('C_SOL_ROSA', CX0 + xr, CY0 + 10, 6)                                         # roda (ref10)
    disco('C_SILHUETA', CX0 + xr, CY0 + 10, 2)                                         # cubo

# ----------------------------------------------------------------------------
# 7) Borda da arena (entra no cenário para também ficar na cópia do fundo: um
#    lutador encostado no canto pode passar por cima dela)
bloco('borda da arena')
reta('C_NEON_ROSA', X1, Y1, X2, Y1)
reta('C_NEON_ROSA', X1, Y2, X2, Y2)
reta('C_NEON_ROSA', X1, Y1, X1, Y2)
reta('C_NEON_ROSA', X2, Y1, X2, Y2)

# ----------------------------------------------------------------------------
# Saída: cenario.inc (dados incluídos pelo cenario.asm)
aqui = os.path.dirname(os.path.abspath(__file__))
saida = os.environ.get('SAIDA', os.path.join(aqui, '..', 'cenario.inc'))
with open(saida, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write('; cenario.inc - Cenário retrowave em retas (GERADO por ferramentas/gera_fundo.py,\n')
    f.write('; não edite à mão). Cada reta: DB cor; DW x1, y1, x2, y2 (coordenadas do\n')
    f.write('; plot_xy, y = 0 embaixo). A lista termina com cor = 0FFh.\n')
    f.write(f'; {len(retas)} retas, {sum(max(abs(r[3]-r[1]), abs(r[4]-r[2])) + 1 for r in retas)} pixels.\n\n')
    f.write('cenario:\n')
    marcas = dict((i, n) for n, i in blocos)
    for i, (cor, a, b, c, d) in enumerate(retas):
        if i in marcas:
            f.write(f'; --- {marcas[i]}\n')
        f.write(f'\t\t\tDB\t{cor:2d}\n\t\t\tDW\t{a}, {b}, {c}, {d}\n')
    f.write('\t\t\tDB\t0FFh\t\t\t\t\t\t; fim do cenário\n')
print(f'{saida}: {len(retas)} retas, {len(retas) * 9 + 1} bytes')

# Prévia: desenha exatamente as mesmas retas
if len(sys.argv) > 1:
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (640, 480), PALETA[0][1])
    d = ImageDraw.Draw(im)
    for cor, a, b, c, e in retas:
        d.line([(a, 479 - b), (c, 479 - e)], fill=PALETA[cor][1])
    im.save(sys.argv[1])
    print('prévia:', sys.argv[1])
