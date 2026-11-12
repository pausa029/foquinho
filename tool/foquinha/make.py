# Desenha a Foquinha (mascote) em SVG, em várias poses.
O = '#17423a'   # contorno
W = '#ffffff'
BELLY = '#e2f3ec'
OR = '#f28c3c'
CHEEK = '#ffb3a7'

def flipper(cx, cy, rot, rx=34, ry=19):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="{O}"/>',
            f'<ellipse cx="{cx}" cy="{cy}" rx="{rx-7}" ry="{ry-7}" transform="rotate({rot} {cx} {cy})" fill="{W}"/>')

def seal(pose):
    # nadadeiras por pose: (cx, cy, rotação)
    L = {'feliz': (98, 290, 55), 'acenando': (98, 290, 55), 'apontando': (98, 290, 55),
         'comemorando': (92, 205, -50), 'pensando': (98, 290, 55)}[pose]
    R = {'feliz': (302, 290, -55), 'acenando': (318, 168, -65), 'apontando': (338, 262, 0),
         'comemorando': (308, 205, 50), 'pensando': (248, 238, -20)}[pose]
    fl, fr = flipper(*L), flipper(*R)
    tails = [flipper(168, 372, 20, 30, 16), flipper(232, 372, -20, 30, 16)]
    out = []
    # contorno (formas largas) e depois o preenchimento por cima: vira uma silhueta só
    shapes = [('ellipse', dict(cx=200, cy=265, rx=118, ry=108)), ('circle', dict(cx=200, cy=172, r=96))]
    def tag(t, a, extra):
        return f'<{t} ' + ' '.join(f'{k}="{v}"' for k, v in a.items()) + f' {extra}/>'
    for t in tails: out.append(t[0])
    for t, a in shapes: out.append(tag(t, a, f'fill="{W}" stroke="{O}" stroke-width="14"'))
    for t in tails: out.append(t[1])
    for t, a in shapes: out.append(tag(t, a, f'fill="{W}"'))
    out.append(f'<ellipse cx="200" cy="292" rx="70" ry="56" fill="{BELLY}"/>')
    out.append(fl[0]); out.append(fl[1])
    if pose != 'pensando': out.append(fr[0]); out.append(fr[1])
    # presilha laranja (o alvo do ícone)
    out.append(f'<circle cx="268" cy="96" r="27" fill="{OR}" stroke="{O}" stroke-width="5"/><circle cx="268" cy="96" r="15" fill="{W}"/><circle cx="268" cy="96" r="7" fill="{OR}"/>')
    # olhos
    if pose == 'comemorando':
        for x in (160, 240):
            out.append(f'<path d="M{x-15} 166 Q{x} 146 {x+15} 166" fill="none" stroke="{O}" stroke-width="7" stroke-linecap="round"/>')
    else:
        dy = -6 if pose == 'pensando' else 0
        dx = 5 if pose in ('pensando', 'apontando') else 0
        for x in (160, 240):
            out.append(f'<circle cx="{x}" cy="162" r="17" fill="{O}"/><circle cx="{x+dx+5}" cy="{156+dy}" r="6" fill="{W}"/>')
    # bochechas
    out.append(f'<circle cx="128" cy="200" r="15" fill="{CHEEK}" opacity=".8"/><circle cx="272" cy="200" r="15" fill="{CHEEK}" opacity=".8"/>')
    # focinho, nariz, boca, bigodes
    out.append(f'<ellipse cx="200" cy="204" rx="44" ry="28" fill="{BELLY}"/>')
    out.append(f'<ellipse cx="200" cy="190" rx="15" ry="10" fill="{O}"/>')
    if pose == 'pensando':
        out.append(f'<path d="M190 214 Q200 210 210 214" fill="none" stroke="{O}" stroke-width="5" stroke-linecap="round"/>')
    elif pose == 'comemorando':
        out.append(f'<path d="M184 206 Q200 232 216 206 Z" fill="{O}"/><path d="M191 214 Q200 224 209 214" fill="#ff8f8f"/>')
    else:
        out.append(f'<path d="M184 208 Q192 218 200 208 Q208 218 216 208" fill="none" stroke="{O}" stroke-width="5" stroke-linecap="round"/>')
    for y, ang in ((196, -6), (208, 0), (220, 6)):
        out.append(f'<line x1="146" y1="{y}" x2="104" y2="{y+ang}" stroke="{O}" stroke-width="4" stroke-linecap="round"/>')
        out.append(f'<line x1="254" y1="{y}" x2="296" y2="{y+ang}" stroke="{O}" stroke-width="4" stroke-linecap="round"/>')
    if pose == 'pensando':
        out.append(fr[0]); out.append(fr[1])
        out.append(f'<circle cx="330" cy="70" r="10" fill="{W}" stroke="{O}" stroke-width="4"/><circle cx="350" cy="40" r="15" fill="{W}" stroke="{O}" stroke-width="4"/>')
    if pose == 'acenando':
        out.append(f'<path d="M352 120 q14 10 10 28 M366 104 q22 16 16 44" fill="none" stroke="{OR}" stroke-width="6" stroke-linecap="round"/>')
    if pose == 'comemorando':
        for x, y, c, r in ((60, 110, OR, 0), (340, 90, '#2b56b3', 30), (90, 60, '#2b56b3', 60), (320, 140, '#f6c344', -20), (50, 170, '#f6c344', 15), (360, 200, OR, 45)):
            out.append(f'<rect x="{x}" y="{y}" width="14" height="22" rx="3" fill="{c}" transform="rotate({r} {x} {y})"/>')
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">' + ''.join(out) + '</svg>'

import os
os.makedirs('svg', exist_ok=True)
for p in ('feliz', 'acenando', 'apontando', 'comemorando', 'pensando'):
    open(f'svg/{p}.svg', 'w').write(seal(p))
print('ok')
