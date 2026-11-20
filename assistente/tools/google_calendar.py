"""Integração com Google Agenda (OAuth) para o assistente pessoal.

Uso (a partir da raiz do projeto):
    python tools/google_calendar.py login
    python tools/google_calendar.py listar --dias 7
    python tools/google_calendar.py criar --titulo "Reunião" --inicio 2026-11-25T14:00 --fim 2026-11-25T15:00 [--lembrete 30]
    python tools/google_calendar.py atualizar --id ID [--titulo ...] [--inicio ...] [--fim ...] [--lembrete ...]
    python tools/google_calendar.py cancelar --id ID
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")

SCOPES = ["https://www.googleapis.com/auth/calendar"]
FUSO = "America/Sao_Paulo"
TZ = ZoneInfo(FUSO)

CREDENTIALS_FILE = RAIZ / os.getenv("GOOGLE_CREDENTIALS_FILE", "credentials.json")
TOKEN_FILE = RAIZ / os.getenv("GOOGLE_TOKEN_FILE", "token.json")
CALENDAR_ID = os.getenv("GOOGLE_CALENDAR_ID", "primary")

INSTRUCAO_LOGIN = (
    "Para refazer o login:\n"
    f"  1. Apague o arquivo {TOKEN_FILE.name} (se existir)\n"
    f"  2. Confirme que {CREDENTIALS_FILE.name} está na raiz do projeto\n"
    "  3. Rode: python tools/google_calendar.py login\n"
    "  4. Autorize o acesso no navegador com a conta Google da agenda"
)


class ErroAutenticacao(Exception):
    """Falha de login/credencial com o Google."""


# ---------------------------------------------------------------- autenticação

def _obter_credenciais(permitir_login: bool = True):
    from google.auth.exceptions import RefreshError
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow

    creds = None
    if TOKEN_FILE.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
        except (ValueError, json.JSONDecodeError) as e:
            raise ErroAutenticacao(f"{TOKEN_FILE.name} inválido ou corrompido ({e}).") from e

    if creds and creds.valid:
        return creds

    if creds and creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
        except RefreshError as e:
            raise ErroAutenticacao(f"Token expirado ou revogado ({e}).") from e
    else:
        if not permitir_login:
            raise ErroAutenticacao("Nenhum login válido encontrado.")
        if not CREDENTIALS_FILE.exists():
            raise ErroAutenticacao(
                f"Arquivo {CREDENTIALS_FILE.name} não encontrado em {RAIZ}. "
                "Baixe-o no Google Cloud Console (APIs e serviços > Credenciais > "
                "ID do cliente OAuth do tipo 'App para computador')."
            )
        try:
            flow = InstalledAppFlow.from_client_secrets_file(str(CREDENTIALS_FILE), SCOPES)
            creds = flow.run_local_server(port=0, open_browser=True)
        except Exception as e:  # noqa: BLE001 - qualquer falha do fluxo OAuth vira erro de login
            raise ErroAutenticacao(f"Falha no login OAuth ({e}).") from e

    TOKEN_FILE.write_text(creds.to_json(), encoding="utf-8")
    return creds


def _servico():
    from googleapiclient.discovery import build

    return build("calendar", "v3", credentials=_obter_credenciais(), cache_discovery=False)


def _executar(requisicao):
    """Executa uma requisição tratando erros de autenticação de forma clara."""
    from googleapiclient.errors import HttpError

    try:
        return requisicao.execute()
    except HttpError as e:
        if e.resp.status in (401, 403):
            raise ErroAutenticacao(
                f"Google recusou o acesso (HTTP {e.resp.status}): {e.reason}. "
                "Verifique se a Google Calendar API está ativada no projeto."
            ) from e
        raise


# ---------------------------------------------------------------- utilidades

def _iso(valor: str | datetime) -> str:
    """Converte 'AAAA-MM-DDTHH:MM' (ou datetime) para ISO com fuso de São Paulo."""
    dt = valor if isinstance(valor, datetime) else datetime.fromisoformat(valor)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=TZ)
    return dt.astimezone(TZ).isoformat()


def _lembretes(minutos: int) -> dict:
    return {"useDefault": False, "overrides": [{"method": "popup", "minutes": int(minutos)}]}


def _resumo(ev: dict) -> dict:
    ini = ev.get("start", {})
    fim = ev.get("end", {})
    return {
        "id": ev.get("id"),
        "titulo": ev.get("summary", "(sem título)"),
        "inicio": ini.get("dateTime") or ini.get("date"),
        "fim": fim.get("dateTime") or fim.get("date"),
        "link": ev.get("htmlLink"),
    }


# ---------------------------------------------------------------- funções

def listar_eventos(dias: int = 7) -> list[dict]:
    """Lista eventos de agora até `dias` dias à frente."""
    agora = datetime.now(TZ)
    resp = _executar(
        _servico().events().list(
            calendarId=CALENDAR_ID,
            timeMin=agora.isoformat(),
            timeMax=(agora + timedelta(days=dias)).isoformat(),
            singleEvents=True,
            orderBy="startTime",
            timeZone=FUSO,
            maxResults=250,
        )
    )
    return [_resumo(ev) for ev in resp.get("items", [])]


def criar_evento(titulo: str, inicio_iso: str, fim_iso: str, lembrete_min: int = 30) -> dict:
    corpo = {
        "summary": titulo,
        "start": {"dateTime": _iso(inicio_iso), "timeZone": FUSO},
        "end": {"dateTime": _iso(fim_iso), "timeZone": FUSO},
        "reminders": _lembretes(lembrete_min),
    }
    return _resumo(_executar(_servico().events().insert(calendarId=CALENDAR_ID, body=corpo)))


def atualizar_evento(
    id: str,
    titulo: str | None = None,
    inicio_iso: str | None = None,
    fim_iso: str | None = None,
    lembrete_min: int | None = None,
) -> dict:
    corpo: dict = {}
    if titulo is not None:
        corpo["summary"] = titulo
    if inicio_iso is not None:
        corpo["start"] = {"dateTime": _iso(inicio_iso), "timeZone": FUSO}
    if fim_iso is not None:
        corpo["end"] = {"dateTime": _iso(fim_iso), "timeZone": FUSO}
    if lembrete_min is not None:
        corpo["reminders"] = _lembretes(lembrete_min)
    if not corpo:
        raise ValueError("Nada para atualizar: informe ao menos um campo.")
    return _resumo(
        _executar(_servico().events().patch(calendarId=CALENDAR_ID, eventId=id, body=corpo))
    )


def cancelar_evento(id: str) -> None:
    _executar(_servico().events().delete(calendarId=CALENDAR_ID, eventId=id))


# ---------------------------------------------------------------- CLI

def _formatar(ev: dict) -> str:
    ini = ev["inicio"] or ""
    try:
        quando = datetime.fromisoformat(ini).astimezone(TZ).strftime("%d/%m %H:%M") if "T" in ini \
            else datetime.fromisoformat(ini).strftime("%d/%m (dia todo)")
    except ValueError:
        quando = ini
    return f"{quando} — {ev['titulo']}  [id: {ev['id']}]"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Google Agenda — assistente pessoal")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("login", help="Faz o login OAuth e gera token.json")

    sp = sub.add_parser("listar", help="Lista eventos dos próximos N dias")
    sp.add_argument("--dias", type=int, default=7)
    sp.add_argument("--json", action="store_true", help="Saída em JSON")

    sp = sub.add_parser("criar", help="Cria um evento")
    sp.add_argument("--titulo", required=True)
    sp.add_argument("--inicio", required=True, help="AAAA-MM-DDTHH:MM")
    sp.add_argument("--fim", required=True, help="AAAA-MM-DDTHH:MM")
    sp.add_argument("--lembrete", type=int, default=30, help="minutos antes")

    sp = sub.add_parser("atualizar", help="Altera um evento")
    sp.add_argument("--id", required=True)
    sp.add_argument("--titulo")
    sp.add_argument("--inicio")
    sp.add_argument("--fim")
    sp.add_argument("--lembrete", type=int)

    sp = sub.add_parser("cancelar", help="Cancela (apaga) um evento")
    sp.add_argument("--id", required=True)

    a = p.parse_args(argv)

    try:
        if a.cmd == "login":
            _obter_credenciais()
            print(f"Login OK. Token salvo em {TOKEN_FILE}")
        elif a.cmd == "listar":
            eventos = listar_eventos(a.dias)
            if a.json:
                print(json.dumps(eventos, ensure_ascii=False, indent=2))
            elif not eventos:
                print(f"Nenhum evento nos próximos {a.dias} dia(s).")
            else:
                print("\n".join(_formatar(ev) for ev in eventos))
        elif a.cmd == "criar":
            ev = criar_evento(a.titulo, a.inicio, a.fim, a.lembrete)
            print("Criado: " + _formatar(ev))
        elif a.cmd == "atualizar":
            ev = atualizar_evento(a.id, a.titulo, a.inicio, a.fim, a.lembrete)
            print("Atualizado: " + _formatar(ev))
        elif a.cmd == "cancelar":
            cancelar_evento(a.id)
            print(f"Cancelado: {a.id}")
    except ErroAutenticacao as e:
        print(f"ERRO DE AUTENTICAÇÃO: {e}\n\n{INSTRUCAO_LOGIN}", file=sys.stderr)
        return 2
    except ValueError as e:
        print(f"ERRO: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
