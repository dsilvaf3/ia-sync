---
name: ia-sync
description: "Centraliza tudo de IA (skills, agentes, MCPs, permissões, instruções e configs do Claude, Codex, Copilot, Kiro, Gemini) em ~/.ia e liga por symlink nas ferramentas do WSL. Use ao criar/alterar skill, agente, MCP, permissão ou config de qualquer IA, ou quando algo foi criado direto em ~/.claude, ~/.codex etc. e precisa voltar pro padrão. Uso: /ia-sync [status]."
argument-hint: "[status | --dry-run]"
allowed-tools: Bash(ia-sync:*), Bash(~/.ia/bin/ia-sync:*), Read(~/.ia/**), Edit(~/.ia/**), Write(~/.ia/**)
---

# ia-sync

`~/.ia` (ou `$IA_HOME`) é a **única** fonte de configuração de IA. As ferramentas
(`~/.claude`, `~/.codex`, `~/.copilot`, e `~/.kiro`/`~/.gemini` se existirem no WSL) só têm
symlinks ou arquivos gerados apontando pra cá. Symlinks são só no WSL; o lado Windows não é tocado.

## Estrutura

```
~/.ia/
  AGENTS.md                      instruções globais -> CLAUDE.md / AGENTS.md / copilot-instructions.md
  skills/<nome>/SKILL.md         skills (link por skill em cada ferramenta)
  agents/<nome>.md               agentes formato Claude -> link no Claude; gerado .toml (Codex), .agent.md (Copilot), .json (Kiro)
                                 (campos só de uma IA vão em `codex:` / `kiro:` / `copilot:` no frontmatter)
  mcp/servers.json               MCPs (formato Claude mcpServers) -> claude mcp add-json, bloco no config.toml do Codex, mcp-config.json do Copilot
  secrets.env                    segredos (chmod 600, fora do git) usados como ${VAR} no servers.json
  settings/claude/settings.json  -> ~/.claude/settings.json (permissões, hooks, plugins, modelo)
  settings/codex/config.toml     -> ~/.codex/config.toml
  settings/copilot/config.json   -> ~/.copilot/config.json
  settings/kiro/                 Kiro ($KIRO_HOME ou ~/.kiro): cli.json, permissions.yaml, sandbox.json (-> settings/),
                                 hooks/, workflows/, powers/ (pasta inteira), steering/ (steering condicional, link por arquivo),
                                 ide/settings.json e ide/keybindings.json (-> ~/.config/Kiro/User/)
  settings/gemini/settings.json  -> ~/.gemini/settings.json (o ia-sync só reescreve a chave mcpServers)
  bin/ia-sync                    o script (também em ~/.local/bin/ia-sync)
  _backup/  _conflicts/          o que o script tirou do lugar
```

## O que fazer

Se `$ARGUMENTS` for `status`, rode `ia-sync status` e mostre o resultado. Senão:

1. Faça a mudança pedida **dentro de `~/.ia`** (nunca em `~/.claude`, `~/.codex`...):
   - **Skill nova**: `~/.ia/skills/<nome>/SKILL.md`. Frontmatter com `name` igual à pasta e
     `description` (e `argument-hint`) **entre aspas** duplas, senão o Codex não carrega (`: ` sem aspas é YAML inválido).
     Scripts da skill na mesma pasta, chamados por `~/.ia/skills/<nome>/<script>` (nunca `~/.claude/skills/...`).
   - **Agente**: `~/.ia/agents/<nome>.md` com frontmatter `name`, `description` (opcional `tools`, `model`, só o Claude usa) e o prompt no corpo.
   - **MCP**: entrada em `~/.ia/mcp/servers.json` → `mcpServers.<nome>`:
     - stdio: `{"type":"stdio","command":"npx","args":[...],"env":{"TOKEN":"${MCP_X_TOKEN}"}}`
     - http: `{"type":"http","url":"https://...","headers":{"Authorization":"${MCP_X_AUTH}"}}`
     - segredo vai em `~/.ia/secrets.env` (`MCP_X_TOKEN="..."`), nunca literal no servers.json.
     - opcional: `"only": ["claude"]`, `"skip": ["copilot"]`, `"disabled": true`.
     - campos de uma IA só: chave com o nome dela, ex. `"kiro": {"autoApprove": [...]}`.
   - **Permissões/config**: edite `~/.ia/settings/claude/settings.json` ou `~/.ia/settings/codex/config.toml`
     (no Codex, não mexa no bloco `# >>> ia-sync mcp` — ele é gerado).
   - **Instrução global**: edite `~/.ia/AGENTS.md`.
2. Rode `ia-sync` (use `--dry-run` antes se a mudança for grande).
3. Leia a saída. Para cada `⚠`:
   - *diverge ... movido para _conflicts*: compare com `diff -r` o que está em `~/.ia/_conflicts/...` com a versão em `~/.ia`,
     mescle o que for novo e apague a pasta do conflito.
   - *frontmatter YAML inválido*: coloque o valor entre aspas.
   - *editado fora do ~/.ia*: o arquivo gerado foi alterado direto; o original está em `~/.ia/_backup/`, leve a mudança pro `~/.ia`.
4. Diga ao usuário o que mudou e em quais ferramentas.

## Quando algo foi criado fora do padrão

Rodar `ia-sync` já resolve: ele **importa** pra `~/.ia` toda skill, agente (Claude `.md`, Copilot `.agent.md`,
Codex `.toml`, Kiro `.json`/`.md`, convertidos pro formato Claude, com os campos específicos guardados em
`codex:`/`kiro:`/`copilot:` no frontmatter), instrução (steering do Kiro que vale sempre entra no AGENTS.md), config (Claude, Codex, Copilot, Kiro, Gemini) e MCP
(de todas, incluindo o `settings.json` do Gemini) que achar solto, e troca o original por link.
Também **padroniza sozinho**: frontmatter da skill com aspas e `name` = pasta (gera `description` se faltar),
e caminhos `~/.claude/skills/<x>/...` (e das outras IAs) viram `~/.ia/skills/<x>/...`.
Itens iguais (inclusive os que só mudam o caminho) são deduplicados, diferentes vão pra `_conflicts`.
Pastas gerenciadas pelos fornecedores (`~/.claude/skills/synced`, `~/.codex/skills/.system`) e coisas de
repositório não são tocadas. Na 1ª execução faz backup em `_backup/pre-ia-sync-<data>.tgz` e instala o comando.
Doc completa pro usuário: `~/.ia/README.md`.

Se o Claude/Codex reescrever o `settings.json`/`config.toml` e o link quebrar (virar arquivo comum),
o próximo `ia-sync` adota a versão nova (backup da anterior em `_backup`) e religa.

## Ferramenta nova

Pra suportar outra IA, adicione um bloco em `tools()` no `~/.ia/bin/ia-sync` com os caminhos de skills,
agentes, instruções, MCP e configs dela, e rode `ia-sync`.
