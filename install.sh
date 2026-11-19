#!/usr/bin/env bash
# Instala (ou atualiza) o ia-sync.
#
#   curl -fsSL https://raw.githubusercontent.com/dsilvaf3/ia-sync/main/install.sh | bash
#   ./install.sh                       # de dentro do repo clonado
#   ./install.sh --path ~/dotfiles/ia  # escolhe a pasta sem perguntar
#   ./install.sh --yes                 # aceita o padrão sem perguntar
#   ./install.sh --run                 # instala e já sincroniza
#
# Variáveis: IA_HOME (pasta, mesmo que --path), IA_SYNC_REPO (padrão dsilvaf3/ia-sync), IA_SYNC_REF (padrão main)
set -euo pipefail

REPO="${IA_SYNC_REPO:-dsilvaf3/ia-sync}"
REF="${IA_SYNC_REF:-main}"
IA="${IA_HOME:-}"
RUN=0 YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN=1 ;;
    --yes|-y) YES=1 ;;
    --path) IA="${2:?--path precisa de um caminho}"; shift ;;
    --path=*) IA="${1#--path=}" ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "opção desconhecida: $1" >&2; exit 1 ;;
  esac
  shift
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
fail() { printf '\033[1;31m ✗\033[0m %s\n' "$*" >&2; exit 1; }
tilde() { [[ "$1" == "$HOME"* ]] && echo "~${1#"$HOME"}" || echo "$1"; }

# pergunta mesmo quando rodando via `curl | bash` (o stdin é o script, então lê do terminal)
TTY=""
if [[ $YES == 0 ]] && { : </dev/tty; } 2>/dev/null; then TTY=/dev/tty; fi
ask() {  # ask <pergunta> <padrão> -> resposta
  local r=""
  if [[ -n "$TTY" ]]; then read -r -p "$1" r <"$TTY" || true; fi
  echo "${r:-$2}"
}

# ---------------------------------------------------------------- requisitos
say "conferindo requisitos"
command -v python3 >/dev/null || fail "precisa do python3 (3.11+)"
python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' \
  || fail "precisa do Python 3.11+ (tem $(python3 -V 2>&1))"
ok "$(python3 -V)"

if ! python3 -c 'import yaml' 2>/dev/null; then
  say "instalando PyYAML"
  if command -v apt-get >/dev/null; then sudo apt-get install -y python3-yaml >/dev/null
  elif command -v dnf >/dev/null; then sudo dnf install -y python3-pyyaml >/dev/null
  elif command -v pacman >/dev/null; then sudo pacman -S --noconfirm python-yaml >/dev/null
  else python3 -m pip install --user pyyaml >/dev/null 2>&1 \
         || python3 -m pip install --user --break-system-packages pyyaml >/dev/null
  fi
  python3 -c 'import yaml' 2>/dev/null || fail "não consegui instalar o PyYAML; instale à mão (pip install pyyaml)"
fi
ok "PyYAML"

# ---------------------------------------------------------------- onde instalar
BIN="$HOME/.local/bin"
DEFAULT="$HOME/.ia" LABEL="Padrão"
if [[ -L "$BIN/ia-sync" ]]; then  # já instalado: sugere a mesma pasta
  cur="$(readlink -f "$BIN/ia-sync")"
  cur="${cur%/bin/ia-sync}"
  if [[ -d "$cur" ]]; then DEFAULT="$cur" LABEL="Atual"; fi
fi

if [[ -z "$IA" ]]; then
  echo
  say "onde guardar suas skills, agentes, MCPs e configs de IA?"
  note "É uma pasta só, que vira a fonte de tudo. As IAs (~/.claude, ~/.codex...) passam a apontar pra ela."
  note "$LABEL: $(tilde "$DEFAULT")   (Enter pra usar essa, ou digite outro caminho, ex.: ~/dotfiles/ia)"
  IA="$(ask "    pasta: " "$DEFAULT")"
fi

# normaliza: ~ e caminho relativo (relativo à home)
IA="${IA/#\~/$HOME}"
[[ "$IA" == /* ]] || IA="$HOME/$IA"
IA="$(python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$IA")"

case "$IA" in
  /|"$HOME") fail "não dá pra usar $(tilde "$IA") direto; escolha uma pasta só pra isso (ex.: ~/.ia)" ;;
  "$HOME"/.claude*|"$HOME"/.codex*|"$HOME"/.copilot*|"$HOME"/.kiro*|"$HOME"/.gemini*)
    fail "$(tilde "$IA") fica dentro da pasta de uma IA; escolha uma pasta separada (ex.: ~/.ia)" ;;
esac

echo
if [[ -f "$IA/.ia-sync-home" || -f "$IA/bin/ia-sync" ]]; then
  say "$(tilde "$IA") já é uma pasta do ia-sync: vou só atualizar o script e a skill /ia-sync."
  note "Suas skills, agentes, MCPs e configs ficam como estão."
elif [[ -d "$IA" && -n "$(ls -A "$IA" 2>/dev/null)" ]]; then
  say "$(tilde "$IA") já existe e tem arquivos."
  note "Nada dela é apagado. O ia-sync só cria dentro dela: bin/, skills/, agents/, mcp/, settings/,"
  note "AGENTS.md, _backup/ e _conflicts/. Se algum desses já existir, ele usa o que já tem."
elif [[ -d "$IA" ]]; then
  say "$(tilde "$IA") existe e está vazia: vou usar ela."
else
  say "$(tilde "$IA") não existe: vou criar."
fi
[[ "$IA" != "$HOME/.ia" ]] && note "Como não é o padrão, o comando ia-sync acha essa pasta sozinho (não precisa configurar nada)."
r="$(ask "    continuar? [S/n] " "s")"
[[ "$r" =~ ^[sSyY]$ ]] || fail "cancelado"

# ---------------------------------------------------------------- arquivos
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
fetch() {  # fetch <caminho no repo> <destino>
  if [[ -n "$SRC" && -f "$SRC/$1" ]]; then
    cp "$SRC/$1" "$2"
  else
    curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/$1" -o "$2" || fail "não consegui baixar $1"
  fi
}
SHOW="$(tilde "$IA")"
localize() {  # troca ~/.ia pela pasta escolhida nos textos instalados
  [[ "$IA" == "$HOME/.ia" ]] && return 0
  python3 - "$1" "$SHOW" <<'PY'
import re, sys
p, show = sys.argv[1], sys.argv[2]
s = open(p).read()
open(p, "w").write(re.sub(r"~/\.ia(?=[/`\s)'\",.:]|$)", show, s, flags=re.M))
PY
}

say "instalando em $SHOW"
mkdir -p "$IA/bin" "$IA/skills/ia-sync" "$IA/agents" "$IA/mcp" "$IA/settings"
echo "pasta de configs de IA do ia-sync (não apague)" > "$IA/.ia-sync-home"
fetch bin/ia-sync "$IA/bin/ia-sync" && chmod +x "$IA/bin/ia-sync"
fetch skills/ia-sync/SKILL.md "$IA/skills/ia-sync/SKILL.md" && localize "$IA/skills/ia-sync/SKILL.md"
[[ -f "$IA/README.md" ]] || { fetch README.md "$IA/README.md" && localize "$IA/README.md"; }
ok "script, skill /ia-sync e README"

# instrução global: avisa todas as IAs de onde fica tudo
if ! grep -q "ia-sync:regra" "$IA/AGENTS.md" 2>/dev/null; then
  [[ -s "$IA/AGENTS.md" ]] && echo >> "$IA/AGENTS.md"
  cat >> "$IA/AGENTS.md" <<EOF
<!-- ia-sync:regra -->
## Tudo de IA fica em $SHOW

Skill, agente, MCP, permissão, instrução ou config de qualquer IA é criado ou alterado em \`$SHOW\`,
nunca direto em \`~/.claude\`, \`~/.codex\`, \`~/.copilot\`, \`~/.kiro\` ou \`~/.gemini\`.
Depois de mudar algo, rode \`ia-sync\`. Onde fica cada coisa: skill \`ia-sync\` ou \`$SHOW/README.md\`.
EOF
  ok "regra adicionada em $SHOW/AGENTS.md"
fi

# comando no PATH
mkdir -p "$BIN"
ln -sfn "$IA/bin/ia-sync" "$BIN/ia-sync"
ok "comando ia-sync ($(tilde "$BIN")/ia-sync -> $SHOW/bin/ia-sync)"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      if [[ -f "$rc" ]] && ! grep -q '.local/bin' "$rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
        ok "PATH ajustado em $(tilde "$rc") (abra um terminal novo)"
      fi
    done
    export PATH="$BIN:$PATH"
    ;;
esac

# ---------------------------------------------------------------- pronto
echo
if [[ $RUN == 1 ]]; then
  say "sincronizando"
  "$IA/bin/ia-sync"
else
  say "o que o ia-sync vai fazer (simulação, nada foi alterado):"
  "$IA/bin/ia-sync" --dry-run || true
  echo
  say "pra aplicar, rode:  ia-sync"
  note "(na 1ª vez ele faz backup de tudo em $SHOW/_backup/pre-ia-sync-<data>.tgz)"
fi
