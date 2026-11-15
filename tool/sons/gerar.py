"""Gera os sons de fundo do Foquinho (sem arquivos de terceiros).
Cada som é um loop de 30 s que emenda sem corte. Saída: assets/sons/*.m4a"""
import numpy as np, subprocess, os, wave, tempfile
from scipy.signal import butter, sosfilt

SR = 32000
DUR = 30
FADE = 2.0
rng = np.random.default_rng(7)
N = int(SR * (DUR + FADE))
t = np.arange(N) / SR

def lp(x, f, o=2): return sosfilt(butter(o, f, 'low', fs=SR, output='sos'), x)
def hp(x, f, o=2): return sosfilt(butter(o, f, 'high', fs=SR, output='sos'), x)
def bp(x, a, b, o=2): return sosfilt(butter(o, [a, b], 'band', fs=SR, output='sos'), x)

def brown(n):
    w = rng.standard_normal(n)
    b = np.cumsum(w)
    b = hp(b, 20)
    return b / np.max(np.abs(b))

def pink(n):
    w = rng.standard_normal(n)
    # filtro de Paul Kellet simplificado
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    from scipy.signal import lfilter
    p = lfilter(b, a, w)
    return p / np.max(np.abs(p))

def loop(x):
    """Emenda o fim no começo com crossfade, para tocar em loop sem clique."""
    L = int(SR * DUR); F = int(SR * FADE)
    body = x[:L].copy()
    fade_in = np.linspace(0, 1, F)
    body[:F] = body[:F] * fade_in + x[L:L + F] * (1 - fade_in)
    return body

def norm(x, peak=0.6):
    return x / np.max(np.abs(x)) * peak

def drops(n, rate, dur_ms, f1, f2, amp):
    out = np.zeros(n)
    k = int(rate * n / SR)
    pos = rng.integers(0, n - SR, k)
    L = int(SR * dur_ms / 1000)
    env = np.exp(-np.linspace(0, 8, L))
    for p in pos:
        burst = bp(rng.standard_normal(L), f1, f2) * env * amp * rng.uniform(0.3, 1)
        out[p:p + L] += burst
    return out

def chuva():
    base = lp(pink(N), 6000) * 0.5 + hp(lp(rng.standard_normal(N), 9000), 1500) * 0.25
    base *= 1 + 0.08 * np.sin(2 * np.pi * t / 7.5)
    return norm(loop(base + drops(N, 60, 25, 2000, 7000, 0.6)), 0.55)

def ondas():
    b = lp(brown(N), 900) + 0.25 * lp(pink(N), 3000)
    # 4 ondas em 30 s (período 7,5 s) -> o loop fecha certinho
    env = 0.25 + 0.75 * (0.5 - 0.5 * np.cos(2 * np.pi * t / 7.5)) ** 2
    return norm(loop(b * env), 0.55)

def lareira():
    base = lp(brown(N), 500) * 0.8
    crack = drops(N, 9, 12, 1500, 6000, 1.2) + drops(N, 25, 6, 3000, 9000, 0.5)
    return norm(loop(base + crack), 0.5)

def ruido():
    return norm(loop(lp(brown(N), 1200)), 0.5)

def sino():
    n = int(SR * 2.5); tt = np.arange(n) / SR
    s = np.zeros(n)
    for f, a, d in [(880, 1, 1.6), (1320, 0.5, 1.1), (1760, 0.25, 0.7), (2640, 0.12, 0.4)]:
        s += a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / d * 2.2)
    # segunda nota (sobe uma quinta), suave
    off = int(SR * 0.28)
    s2 = np.zeros(n)
    for f, a, d in [(1318.5, 0.8, 1.4), (1977.7, 0.35, 0.9)]:
        s2[off:] += a * np.sin(2 * np.pi * f * tt[:n - off]) * np.exp(-tt[:n - off] / d * 2.2)
    s = s + s2
    s[:200] *= np.linspace(0, 1, 200)
    return norm(s, 0.8)

def salvar(nome, x):
    os.makedirs('assets/sons', exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        tmp = f.name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'aac', '-b:a', '56k', f'assets/sons/{nome}.m4a'], check=True)
    os.remove(tmp)

for nome, fn in [('chuva', chuva), ('ondas', ondas), ('lareira', lareira), ('ruido', ruido), ('sino', sino)]:
    salvar(nome, fn())
    print(nome, os.path.getsize(f'assets/sons/{nome}.m4a') // 1024, 'KB')
