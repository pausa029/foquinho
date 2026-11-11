import base64, os
b = lambda p: 'data:image/jpeg;base64,' + base64.b64encode(open(p, 'rb').read()).decode()
s = open('src/app.html', encoding='utf-8').read().replace('{{LOGO}}', b('logo.jpg')).replace('{{COVER}}', b('cover.jpg'))
os.makedirs('dist', exist_ok=True)
open('dist/paca.html', 'w', encoding='utf-8').write(s)
open('dist/index.html', 'w', encoding='utf-8').write('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#17616b"><style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style></head><body>' + s + '</body></html>')
print(len(s))
