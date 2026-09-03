# DECISIONS.md — ADRs do template

> Registro de decisões arquiteturais opinativas. Cada ADR é curto: contexto, decisão, consequências. Decisões marcadas como _default trocável_ devem ter ponteiro em `docs/CUSTOMIZING.md` (Fase 3) explicando como trocar.

---

## ADR-001 — Compatibilidade dupla Claude Code + GitHub Copilot: núcleo agnóstico + adapters finos

**Status:** Decidido (usuário, 2026-09-02).

**Contexto:** O template precisa funcionar tanto com Claude Code quanto com GitHub Copilot. Os dois harnesses divergem estruturalmente: Copilot não tem Skills (progressive disclosure sob demanda) nem `settings.json` unificado; hooks nativos do Copilot são confirmados só para CLI/coding agent, não para a extensão VS Code (a superfície mais usada por devs FrontEnd) — ver `research/FINDINGS.md` §2.5.

**Decisão:** A metodologia (SDD, specs, `scripts/verify.sh`, critérios EARS) fica **agnóstica de agente**, vivendo em `specs/` e `scripts/`. Cada agente ganha um **adapter fino**:

- **Claude Code:** hooks nativos (`.claude/hooks/`), subagents (`.claude/agents/`), skills (`.claude/skills/`) — camada completa, como já especificado.
- **Copilot:** `.github/prompts/*.prompt.md` (equivalente a commands), `.github/agents/*.agent.md` (equivalente a subagents — apontando/reaproveitando `.claude/agents/*.md` quando possível, já que o VS Code lê esse diretório nativamente), `.github/hooks/*.json` (gerado a partir da mesma definição lógica dos hooks do Claude Code, onde a cobertura permitir).
- **Gate final universal:** `scripts/verify.sh` via CI (GitHub Actions) + git hooks tradicionais (husky/lefthook) é a fonte de verdade que **não depende de nenhum dos dois harnesses nativos** — os hooks nativos de cada agente são otimização de feedback rápido, não o gate que decide "pronto".

**Consequências:** Elimina o risco de o template quebrar silenciosamente no Copilot por falta de hooks confiáveis na extensão VS Code. Custo: manter 2 adapters sincronizados (commands↔prompt files, hooks Claude↔hooks Copilot) — mitigar com um script gerador único a partir de uma definição lógica compartilhada (detalhar em Fase 2/3).

## ADR-002 — `CLAUDE.md` como arquivo único de instruções raiz (sem duplicar para `AGENTS.md`)

**Status:** Decidido (research-informed, 2026-09-02).

**Contexto:** `research/FINDINGS.md` §2.5 confirma, por doc oficial do GitHub, que o Copilot lê diretamente um único `CLAUDE.md` (ou `GEMINI.md`) na raiz como alternativa ao `AGENTS.md`/`copilot-instructions.md`.

**Decisão:** Manter `CLAUDE.md` como o único arquivo de instruções persistentes na raiz do template, lido nativamente por ambos os agentes. Não duplicar conteúdo em `AGENTS.md`.

**Consequências:** Zero risco de drift entre dois arquivos de instrução. Risco residual (não confirmado 100%): pode haver inconsistência de leitura de `CLAUDE.md` entre VS Code Chat / Copilot CLI / coding agent — se isso for observado na prática durante a geração do template, criar `AGENTS.md` como redirecionamento curto (`ver CLAUDE.md`) é o fallback documentado.

## ADR-003 — `.claude/agents/*.md` como diretório único de definição de subagents

**Status:** Decidido (research-informed, 2026-09-02).

**Contexto:** VS Code Copilot lê `.claude/agents/` nativamente, rotulado "Workspace (Claude format)" (`research/FINDINGS.md` §2.5, item 4).

**Decisão:** Definir subagents uma única vez em `.claude/agents/*.md` (frontmatter Claude Code). Não manter uma cópia paralela em `.github/agents/*.agent.md` a menos que um campo específico do Copilot (ex.: `handoffs`) seja estritamente necessário e não expressável no frontmatter do Claude Code — nesse caso, gerar o `.agent.md` a partir do `.md` original via script, não escrever à mão.

**Consequências:** Um roster de subagents, uma fonte de verdade. Nesting de subagents no Copilot não tem profundidade configurável documentada — o roster deve ser desenhado assumindo o caso mais restritivo (Copilot, sem aninhamento) como baseline, com aninhamento até 3 níveis do Claude Code como capacidade extra, não como requisito.

## ADR-004 — Linter/formatter: ESLint + Prettier (não Oxlint/Oxfmt)

**Status:** Decidido (usuário, 2026-09-02), substitui a recomendação inicial de `research/FINDINGS.md` §2.3.

**Contexto:** A pesquisa de Fase 1 apontou Oxlint (v1.60, estável) + Prettier como combinação recomendada por velocidade, com Oxfmt marcado como "watch item" (beta). O usuário optou por ESLint + Prettier de forma explícita, independentemente da velocidade do Oxlint.

**Decisão:** Preset default do template usa **ESLint + Prettier**. Ecossistema de plugins ESLint (a11y, hooks do React, import order etc.) mais maduro é a razão provável — registrar aqui para não ser perdido, mesmo sem confirmação explícita do motivo pelo usuário.

**Consequências:** Lint mais lento que Oxlint em repos grandes (trade-off aceito). Trocar para Oxlint continua documentado em `docs/CUSTOMIZING.md` (Fase 3) como _default trocável_, já que a pesquisa mostrou que é uma opção viável e mais rápida.

## ADR-005 — Gerenciador de pacotes: pnpm como padrão, compatível com npm/yarn

**Status:** Decidido (usuário, 2026-09-02).

**Contexto:** `research/FINDINGS.md` §2.3 confirma pnpm 11.25 com catalogs. O usuário quer pnpm como padrão mas sem travar quem usa npm/yarn.

**Decisão:** pnpm é o gerenciador **recomendado e testado em CI**, declarado via campo `packageManager` (`corepack`) no `package.json`. Para manter compatibilidade real com npm/yarn: (1) não usar sintaxe exclusiva de pnpm nos `scripts` do `package.json` (nada de `pnpm -r` embutido em scripts que rodam via `npm run`/`yarn run`); (2) evitar depender de **catalogs** do pnpm-workspace para dependências do app-exemplo, já que catalogs não têm equivalente em npm/yarn workspaces; (3) documentar em `docs/CUSTOMIZING.md` (Fase 3) o comando equivalente de instalação para as 3 ferramentas.

**Consequências:** Abre mão de catalogs (feature só-pnpm) no exemplo mínimo para não quebrar portabilidade — quem usa pnpm em produção pode adotar catalogs depois, fora do escopo do template base.

---

## Itens resolvidos na Fase 2 (ver `docs/AGENT_ARCHITECTURE.md`)

- **Mecânica exata do ratchet** — resolvida em `docs/AGENT_ARCHITECTURE.md` §3.2: estado em `.claude/state/verify-ratchet.json`, comparação de contagem de falhas entre tentativas, reversão cirúrgica dos arquivos tocados no turno em caso de regressão, handoff humano em 6 tentativas (antes do cap nativo de 8 bloqueios do Claude Code).
- **`adversarial-reviewer` como papel dedicado** — decidido **não** criar um 7º papel; mutation-testing/verificação adversarial fica dentro do mandato do `reviewer` existente, para manter o roster enxuto (`docs/AGENT_ARCHITECTURE.md` §3.1). Revisitar como primeira extensão em `docs/CUSTOMIZING.md` se `reviewer` se mostrar sobrecarregado na prática.

## ADR-006 — Componentes: Base UI como default (não Radix) — **AMENDADO na implementação, 2026-09-02**

**Status:** Decidido na Fase 3 (Base UI), **revertido para Radix UI na implementação** após verificação ao vivo do npm.

**Contexto original:** `research/FINDINGS.md` §2.3 relatou Base UI "1.0 estável desde dez/2025", mantido pela equipe MUI, e que o shadcn/ui mudara seu default para Base UI em jul/2026.

**Correção encontrada na implementação:** `npm view @base-ui-components/react dist-tags` (checado ao vivo, 2026-09-02) mostra **`latest: 1.0.0-rc.0`**, publicado em 2025-12-04 — release candidate, não uma 1.0.0 final. A pesquisa da Fase 1 estava imprecisa nesse ponto específico (confundiu "atingiu RC" com "estável"). Isso é exatamente o tipo de divergência que `START.MD` pede para verificar antes de instalar, não confiar no relatório de pesquisa como fato definitivo.

**Decisão amendada:** O `package.json` do template instala **`@radix-ui/react-*`** (1.1.23, GA confirmado) como dependência real. Base UI continua documentado em `docs/CUSTOMIZING.md` como o caminho de upgrade recomendado assim que `@base-ui-components/react` publicar uma tag `1.0.0` final (sem sufixo `-rc`) — a checagem é um simples `npm view @base-ui-components/react dist-tags`.

**Consequências:** O preset "default trocável" nesta camada temporariamente inverte a recomendação da SPEC (Radix é o instalado, Base UI é a troca documentada) até a Base UI sair de RC. Nenhuma mudança na estrutura de componentes do template é necessária quando isso acontecer — só a dependência e o import.

## ADR-007 — Build: Vite 8 core (Rolldown por padrão), não a toolchain "Vite+"

**Status:** Decidido (Fase 3, 2026-09-02).

**Contexto:** Vite 8.2.x já usa Rolldown (bundler Rust) por padrão, sem opt-in — não é a mesma coisa que "Vite+" (toolchain unificado ainda em beta, com incerteza de governança pós-aquisição do VoidZero pelo Cloudflare em jun/2026, `research/FINDINGS.md` §2.3).

**Decisão:** Preset usa **Vite 8** puro. "Vite+" fica fora do preset, citado em `docs/CUSTOMIZING.md` como "watch item" a reavaliar quando sair de beta.

**Consequências:** Nenhuma perda de performance de build relevante — o ganho de velocidade do Rolldown já vem de graça no Vite 8 core. Reavaliar Vite+ é um item de manutenção do template, não do projeto que clona.

**Nota:** Oxlint/Oxfmt (que apareceriam como par do "Vite+") já ficaram fora do preset por ADR-004 (ESLint+Prettier) — não há decisão pendente ali, só o registro de que Oxlint é a alternativa mais rápida documentada em `docs/CUSTOMIZING.md`.

## ADR-008 — Commands vivem como Skills (`user-invocable: true`), sem pasta `.claude/commands/` separada

**Status:** Decidido (Fase 2, formalizado na Fase 3).

**Contexto:** `research/FINDINGS.md` §2.1.1 confirma que custom commands foram fundidas em Skills no Claude Code — um skill com `user-invocable: true` cria o slash-command. A pasta `.claude/commands/*.md` é forma legada que ainda funciona, mas não é mais a canônica.

**Decisão:** O template usa **só** `.claude/skills/<nome>/SKILL.md` para tudo — tanto os 7 comandos do pipeline (`/spec`, `/plan`, `/tasks`, `/implement`, `/tdd`, `/review`, `/ship`, todos com `user-invocable: true`) quanto as 10 skills de expertise de stack/cross-cutting (carregadas automaticamente por `description`/`paths`, sem `user-invocable`). Não existe `.claude/commands/` no template.

**Consequências:** Estrutura de diretório do START.MD original (`§3`, que sugeria `commands/` e `skills/` separados) é ajustada em `SPEC.md` §3. Cada skill-comando tem espelho em `.github/prompts/<nome>.prompt.md` (ADR-001) para o Copilot.
