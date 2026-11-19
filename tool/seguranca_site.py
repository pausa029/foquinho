#!/usr/bin/env python3
"""Protege as páginas do site antes de publicar no GitHub Pages.

O GitHub Pages não deixa configurar cabeçalhos de segurança, então este script
coloca as proteções dentro de cada página (.html), na hora de publicar:

- Content-Security-Policy (CSP): o navegador só roda os scripts desta página
  (conferidos pelo "hash" SHA-256 de cada um) e só conversa com os endereços
  liberados abaixo. Um script injetado por alguém não roda.
- Referrer-Policy: não manda o endereço completo da página para outros sites.
- Proteção contra "clickjacking": a página não aparece se outro site tentar
  colocá-la escondida dentro de um quadro (iframe) para enganar cliques.

Roda sozinho no GitHub Actions (veja .github/workflows/build.yml). Para testar:
    python3 tool/seguranca_site.py PASTA_DO_SITE
"""
import base64
import hashlib
import pathlib
import re
import sys

SUPABASE = "https://iqteaquzluhmgydgpmzk.supabase.co"

SCRIPT = re.compile(r"<script(?P<attrs>[^>]*)>(?P<body>.*?)</script>", re.S | re.I)
HEAD = re.compile(r"<head[^>]*>", re.I)
CHARSET = re.compile(r"<meta[^>]+charset[^>]*>", re.I)

# Sem cabeçalhos no GitHub Pages, "frame-ancestors" não funciona em <meta>.
# Então: a página começa escondida e só aparece se não estiver dentro de um quadro.
ANTI_QUADRO = (
    '<style id="fq-anti-quadro">html{display:none!important}</style>'
    "<script>if(self===top){document.getElementById('fq-anti-quadro').remove()}"
    "else{try{top.location=self.location}catch(e){}}</script>"
)


def hashes(html: str) -> list[str]:
    out = []
    for m in SCRIPT.finditer(html):
        if re.search(r"\bsrc\s*=", m.group("attrs"), re.I):
            continue
        body = m.group("body")
        if not body.strip():
            continue
        h = base64.b64encode(hashlib.sha256(body.encode("utf-8")).digest()).decode()
        out.append(f"'sha256-{h}'")
    return sorted(set(out))


def politica(html: str, flutter: bool) -> str:
    scripts = " ".join(["'self'"] + hashes(html) + (["'wasm-unsafe-eval'"] if flutter else []))
    regras = {
        "default-src": "'self'",
        "script-src": scripts,
        "style-src": "'self' 'unsafe-inline' https://fonts.googleapis.com",
        "font-src": "'self' data: https://fonts.gstatic.com",
        "img-src": "'self' data: blob:",
        "media-src": "'self' data: blob:",
        "connect-src": f"'self' {SUPABASE}" + (" https://fonts.gstatic.com https://www.gstatic.com" if flutter else ""),
        "worker-src": "'self' blob:",
        "manifest-src": "'self'",
        "frame-src": "'none'",
        "object-src": "'none'",
        # O app Flutter usa <base href="/web/">; as outras páginas não usam <base>.
        "base-uri": "'self'" if flutter else "'none'",
        "form-action": "'self'",
        "upgrade-insecure-requests": "",
    }
    return "; ".join(f"{k} {v}".strip() for k, v in regras.items())


def proteger(arquivo: pathlib.Path) -> bool:
    html = arquivo.read_text(encoding="utf-8")
    if 'http-equiv="Content-Security-Policy"' in html:
        return False
    flutter = "flutter_bootstrap.js" in html or "main.dart.js" in html
    redireciona = 'http-equiv="refresh"' in html
    extra = '' if redireciona else ANTI_QUADRO
    if not re.search(r'<meta[^>]+name="referrer"', html, re.I):
        extra = '<meta name="referrer" content="strict-origin-when-cross-origin">' + extra
    # A CSP precisa vir antes de qualquer script: logo depois do charset (ou do <head>).
    alvo = CHARSET.search(html) or HEAD.search(html)
    pos = alvo.end() if alvo else 0
    html = html[:pos] + extra + html[pos:]
    csp = f'<meta http-equiv="Content-Security-Policy" content="{politica(html, flutter)}">'
    html = html[:pos] + csp + html[pos:]
    arquivo.write_text(html, encoding="utf-8")
    return True


def main() -> None:
    pasta = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "site")
    feitos = [p for p in sorted(pasta.rglob("*.html")) if proteger(p)]
    for p in feitos:
        print("protegida:", p.relative_to(pasta))
    if not feitos:
        print("nenhuma página nova para proteger")


if __name__ == "__main__":
    main()
