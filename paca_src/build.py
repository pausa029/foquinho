import base64, os, shutil
from PIL import Image
b = lambda p: 'data:image/jpeg;base64,' + base64.b64encode(open(p, 'rb').read()).decode()
src = open('src/app.html', encoding='utf-8').read().replace('{{LOGO}}', b('logo.jpg')).replace('{{COVER}}', b('cover.jpg'))
os.makedirs('dist', exist_ok=True)
# prévia (artefato): o Foquinho abre no endereço publicado
open('dist/paca.html', 'w', encoding='utf-8').write(src.replace('{{APK}}', ''))
HEAD = '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>PACA</title><meta name="description" content="PACA, Plataforma Comunitária Aberta de Autoria: rádio em áudio, serviços, cultura e Fala Cidadão, com voz e alto contraste."><meta name="theme-color" content="#17616b">%s<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%%}[hidden]{display:none!important}</style></head><body>'
body = src.replace('<title>PACA</title>\n', '', 1)
open('dist/index.html', 'w', encoding='utf-8').write(HEAD % '' + body.replace('{{APK}}', '') + '</body></html>')
# pasta do site (PACA + Foquinho dentro)
site = 'site'
shutil.rmtree(site, ignore_errors=True); os.makedirs(site)
icons = '<link rel="icon" href="icon-192.png"><link rel="apple-touch-icon" href="icon-180.png"><link rel="manifest" href="manifest.webmanifest"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="PACA">'
open(site + '/index.html', 'w', encoding='utf-8').write(HEAD % icons + body.replace('{{APK}}', 'PACA.apk') + '</body></html>')
lg = Image.open('logo.jpg').convert('RGB')
for n in (180, 192, 512):
    im = Image.new('RGB', (n, n), lg.getpixel((4, 4)))
    w = int(n * .84); h = int(w * lg.height / lg.width); im.paste(lg.resize((w, h), Image.LANCZOS), ((n - w) // 2, (n - h) // 2)); im.save(site + '/icon-%d.png' % n)
open(site + '/manifest.webmanifest', 'w').write('{"name":"PACA","short_name":"PACA","start_url":"./","display":"standalone","background_color":"#fbf1de","theme_color":"#17616b","icons":[{"src":"icon-192.png","sizes":"192x192","type":"image/png"},{"src":"icon-512.png","sizes":"512x512","type":"image/png"}]}')
open(site + '/index-semapk.html', 'w', encoding='utf-8').write(HEAD % icons + body.replace('{{APK}}', '') + '</body></html>')
print('ok', os.path.getsize(site + '/index.html'))
