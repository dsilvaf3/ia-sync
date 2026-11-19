#!/usr/bin/env bash
# Instala (ou atualiza) o ia-sync em ~/.ia.
#
#   curl -fsSL https://raw.githubusercontent.com/dsilvaf3/ia-sync/main/install.sh | bash
#   ./install.sh            # de dentro do repo clonado
#   ./install.sh --run      # instala e já sincroniza
#
# Variáveis: IA_HOME (padrão ~/.ia), IA_SYNC_REPO (padrão dsilvaf3/ia-sync), IA_SYNC_REF (padrão main)
set -euo pipefail

REPO="${IA_SYNC_REPO:-dsilvaf3/ia-sync}"
REF="${IA_SYNC_REF:-main}"
IA="${IA_HOME:-$HOME/.ia}"
RUN=0
[[ "${1:-}" == "--run" ]] && RUN=1

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m ✗\033[0m %s\n' "$*" >&2; exit 1; }

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

# ---------------------------------------------------------------- arquivos
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
fetch() {  # fetch <caminho no repo> <destino>
  if [[ -n "$SRC" && -f "$SRC/$1" ]]; then
    cp "$SRC/$1" "$2"
  else
    curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/$1" -o "$2" || fail "não consegui baixar $1"
  fi
}

say "instalando em $IA"
mkdir -p "$IA/bin" "$IA/skills/ia-sync" "$IA/agents" "$IA/mcp" "$IA/settings"
fetch bin/ia-sync "$IA/bin/ia-sync" && chmod +x "$IA/bin/ia-sync"
fetch skills/ia-sync/SKILL.md "$IA/skills/ia-sync/SKILL.md"
[[ -f "$IA/README.md" ]] || fetch README.md "$IA/README.md"
ok "script, skill /ia-sync e README"

# instrução global: avisa todas as IAs de que tudo de IA fica em ~/.ia
if ! grep -q "ia-sync:regra" "$IA/AGENTS.md" 2>/dev/null; then
  [[ -s "$IA/AGENTS.md" ]] && echo >> "$IA/AGENTS.md"
  cat >> "$IA/AGENTS.md" <<'EOF'
<!-- ia-sync:regra -->
## Tudo de IA fica em ~/.ia

Skill, agente, MCP, permissão, instrução ou config de qualquer IA é criado ou alterado em `~/.ia`,
nunca direto em `~/.claude`, `~/.codex`, `~/.copilot`, `~/.kiro` ou `~/.gemini`.
Depois de mudar algo, rode `ia-sync`. Onde fica cada coisa: skill `ia-sync` ou `~/.ia/README.md`.
EOF
  ok "regra adicionada em $IA/AGENTS.md"
fi

# comando no PATH
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
ln -sfn "$IA/bin/ia-sync" "$BIN/ia-sync"
ok "comando $BIN/ia-sync"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      if [[ -f "$rc" ]] && ! grep -q '.local/bin' "$rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
        ok "PATH ajustado em $rc (abra um terminal novo)"
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
  echo "    (na 1ª vez ele faz backup de tudo em $IA/_backup/pre-ia-sync-<data>.tgz)"
fi
