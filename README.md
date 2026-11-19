# ia-sync

**Uma pasta só (`~/.ia`) pra skills, agentes, MCPs, instruções e configs de todas as suas IAs.**
Funciona com Claude Code, Codex, GitHub Copilot CLI, Kiro e Gemini CLI.

Você cria a skill, o agente ou o MCP uma vez em `~/.ia`, roda `ia-sync`, e ele passa a valer em todas.
Já tem coisa espalhada pelas IAs? Na primeira vez ele traz tudo pra `~/.ia`, deixa no mesmo padrão
e põe link no lugar. Nada se perde: antes de mexer ele faz backup.

---

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/dsilvaf3/ia-sync/main/install.sh | bash
```

Ou clonando o repo:

```bash
git clone https://github.com/dsilvaf3/ia-sync.git
cd ia-sync && ./install.sh
```

O instalador:
1. confere o Python 3.11+ e instala o PyYAML se faltar;
2. coloca o script em `~/.ia/bin/ia-sync` e o comando `ia-sync` em `~/.local/bin` (ajusta o PATH se precisar);
3. instala a skill `/ia-sync`, que ensina as IAs a usar o padrão;
4. adiciona no `~/.ia/AGENTS.md` a regra "tudo de IA fica em ~/.ia";
5. mostra uma **simulação** do que vai acontecer. Nada é alterado até você rodar:

```bash
ia-sync
```

Quer instalar e já sincronizar? Use `./install.sh --run` (ou `curl ... | bash -s -- --run`).
**Atualizar** é rodar o instalador de novo.

Sistemas: Linux, macOS e WSL. No Windows, use pelo WSL, porque o ia-sync trabalha com symlinks.

---

## Dia a dia

| Quero... | Faço isso em `~/.ia` | Depois |
|---|---|---|
| criar uma skill | `skills/<nome>/SKILL.md` (+ scripts na mesma pasta) | `ia-sync` |
| criar um agente | `agents/<nome>.md` | `ia-sync` |
| adicionar um MCP | `mcp/servers.json` (+ segredo em `secrets.env`) | `ia-sync` |
| mudar uma instrução global | `AGENTS.md` | já vale na hora |
| mudar a config de uma IA | `settings/<ia>/...` | já vale na hora |

```bash
ia-sync             # traz o que estiver solto nas IAs e sincroniza tudo
ia-sync --dry-run   # mostra o que faria, sem mexer
ia-sync status      # o que está ligado em cada IA
```

Dentro de qualquer IA também dá pra pedir `/ia-sync`.

---

## O que ele traz das IAs e como deixa

| O quê | Vem de | Fica em `~/.ia` | O que ele ajusta sozinho |
|---|---|---|---|
| Skills | `~/.<ia>/skills/*` | `skills/<nome>/` | conserta o cabeçalho (aspas, `name` igual à pasta, `description` se faltar) e troca `~/.claude/skills/...` (e das outras) por `~/.ia/skills/...` |
| Agentes | Claude `.md`, Copilot `.agent.md`, Codex `.toml`, Kiro `.json`/`.md` | `agents/<nome>.md` | converte pro formato único e guarda os campos que só aquela IA entende |
| Instruções | `CLAUDE.md`, `AGENTS.md`, `copilot-instructions.md`, `GEMINI.md`, steering do Kiro que vale sempre | `AGENTS.md` | junta tudo num arquivo só |
| Configs | Claude `settings.json`, Codex `config.toml`, Copilot `config.json`, Gemini `settings.json`, Kiro (abaixo) | `settings/<ia>/` | — |
| MCPs | todas | `mcp/servers.json` | converte pra um formato só, tira os segredos pro `secrets.env` e guarda os campos que só uma IA usa |

**Kiro** (respeita `KIRO_HOME`): `settings/cli.json`, `settings/permissions.yaml`, `settings/sandbox.json`,
as pastas `hooks/`, `workflows/` e `powers/`, o steering condicional e o Kiro IDE (`~/.config/Kiro/User/settings.json` e `keybindings.json`).

Se a mesma coisa existe em duas IAs:
- **igual** (ou só muda o caminho de cada IA): fica uma só;
- **diferente**: a segunda vai pro `~/.ia/_conflicts/` e aparece um aviso pra você juntar à mão.

**Ele não mexe em:** coisas de repositório (`<repo>/.claude/`, `<repo>/AGENTS.md`, `.mcp.json`, `.kiro/specs`),
MCPs de projeto do Claude, skills de plugins ou do próprio fornecedor, e estado das IAs (sessões, logins, logs).

---

## Formatos

### Skill — `~/.ia/skills/minha-skill/SKILL.md`

```markdown
---
name: "minha-skill"
description: "O que faz e quando usar. Uso: /minha-skill <arg>."
---

Instruções...
Script: ~/.ia/skills/minha-skill/run.sh
```

### Agente — `~/.ia/agents/revisor.md`

```markdown
---
name: "revisor"
description: "Quando usar esse agente"
tools: Read, Bash          # opcional, só Claude
codex:                     # opcional, campos que só o Codex usa
  model: gpt-5
kiro:                      # opcional, campos que só o Kiro usa
  tools: [read]
---

Prompt do agente.
```

O mesmo vale pra `copilot:`. O Claude lê esse arquivo direto. Pros outros, o ia-sync gera o arquivo no formato de cada um.

### MCP — `~/.ia/mcp/servers.json`

```json
{
  "mcpServers": {
    "meu-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "pacote-mcp"],
      "env": { "TOKEN": "${MCP_MEU_TOKEN}" }
    },
    "outro": {
      "type": "http",
      "url": "https://exemplo.com/mcp",
      "headers": { "Authorization": "Bearer ${MCP_OUTRO_TOKEN}" },
      "skip": ["copilot"],
      "kiro": { "autoApprove": ["read"] }
    }
  }
}
```

Em `~/.ia/secrets.env` (chmod 600, fora do git):

```
MCP_MEU_TOKEN="..."
MCP_OUTRO_TOKEN="..."
```

Opções por MCP: `"only": ["claude"]`, `"skip": ["copilot"]`, `"disabled": true`, e campos de uma IA só numa chave com o nome dela.

---

## Avisos (⚠)

| Aviso | O que fazer |
|---|---|
| `diverge ... movido para _conflicts` | compare (`diff -r`) com a versão do `~/.ia`, junte o que faltar e apague a pasta do conflito |
| `não tinha 'description'; gerei uma` | revise a descrição no `SKILL.md` |
| `não consegui consertar sozinho` | arrume o cabeçalho do `SKILL.md` à mão |
| `editado fora do ~/.ia` | você editou um arquivo gerado; o original está no `_backup`, leve a mudança pro `~/.ia` |
| `variável ${X} não definida` | adicione `X="..."` no `secrets.env` |

---

## Como funciona

- **Link** onde a IA aceita o arquivo como ele é: skills, instruções e configs. Editou em `~/.ia`, já valeu.
- **Arquivo gerado** onde cada IA tem formato próprio: agentes e MCPs (no Claude, via `claude mcp add-json`).
  Se você editar um gerado direto, o próximo sync faz backup antes de sobrescrever.
- Se uma IA reescreve a própria config e o link vira arquivo comum, o próximo `ia-sync` fica com a versão nova e liga de novo.
- Uma IA só entra se a pasta dela existir. Instalou uma IA nova? Roda `ia-sync`.

```
~/.ia/
  AGENTS.md            instruções globais
  skills/              skills
  agents/              agentes
  mcp/servers.json     MCPs
  secrets.env          segredos (fora do git)
  settings/<ia>/       config de cada IA
  bin/ia-sync          o script
  _backup/             tudo que foi tirado do lugar
  _conflicts/          o que você precisa juntar à mão
```

**Versionar o seu `~/.ia`:** dá pra fazer `git init` nele. O `.gitignore` gerado já deixa de fora os segredos, os backups
e as configs onde os MCPs ficam com o segredo preenchido.

**Desfazer:** `tar -xzf ~/.ia/_backup/pre-ia-sync-<data>.tgz -C ~` restaura o que existia antes do primeiro sync.

**Outra IA:** adicione um bloco em `tools()` no `bin/ia-sync` com os caminhos dela. PRs são bem-vindos.

## Licença

MIT
