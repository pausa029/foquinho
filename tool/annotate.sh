#!/bin/bash
# Publica as linhas de erro de um log como anotação do GitHub Actions.
# uso: annotate.sh arquivo 'regex' 'título'
f="$1"; pat="$2"; title="$3"
msg=$(grep -E "$pat" "$f" | head -45 | cut -c1-300)
[ -z "$msg" ] && msg=$(tail -25 "$f" | cut -c1-300)
msg="${msg//'%'/'%25'}"
msg="${msg//$'\r'/'%0D'}"
msg="${msg//$'\n'/'%0A'}"
echo "::error title=$title::$msg"
