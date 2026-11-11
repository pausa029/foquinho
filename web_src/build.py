import glob, os
src = '/home/claude/pausa/src'
js = ''.join(open(f, encoding='utf-8').read() + '\n' for f in sorted(glob.glob(src + '/*.js')))
css = open(src + '/style.css', encoding='utf-8').read()
fonts = open(src + '/fonts.css', encoding='utf-8').read()
head = '''<title>Foquinho</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap">
<style>
''' + fonts + css + '''</style>
<div id="root"><div class="pad col page"><p class="muted">Abrindo o Foquinho…</p></div></div>
<div id="toast" class="toast" role="status" hidden></div>
<div id="live" class="sr" aria-live="polite"></div>
<script>
''' + js + '''</script>
'''
open('/home/claude/pausa/dist/foquinho.html', 'w', encoding='utf-8').write(head)
# standalone copy for local testing (full document)
open('/home/claude/pausa/dist/test.html', 'w', encoding='utf-8').write(
    '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
    '<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;font:14px system-ui}img{max-width:100%}[hidden]{display:none!important}</style></head><body>'
    + head + '</body></html>')
print('bytes', len(head.encode()))
