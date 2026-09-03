# SPEC.md — Contrato executável do template `frontend-agent-template`

> Esta é a Fase 3 do `START.MD`. Este documento é autossuficiente: alguém (ou uma sessão limpa de Claude Code) deve conseguir gerar o repositório-template inteiro só a partir dele, seguindo o roadmap da §12. Toda decisão opinativa aqui é rastreável a um ADR em `docs/meta/DECISIONS.md`; todo fato sobre harnesses é rastreável a `docs/meta/FINDINGS.md`; o desenho de papéis/gates é detalhado em `docs/meta/AGENT_ARCHITECTURE.md` — esta SPEC consolida os três num contrato único e implementável.

---

## 1. Visão & não-objetivos

### O que este template é

Um repositório-template clonável (`git clone` + customização) que transforma o Claude Code — e, com adapters finos, o GitHub Copilot — num agente de engenharia FrontEnd que:

1. Segue **Spec-Driven Development**: nenhuma linha de código de aplicação é escrita sem uma spec aprovada por humano, decomposta em tasks com critérios EARS.
2. Pratica **TDD obrigatório**: todo código de implementação nasce depois de um teste que falha (RED).
3. Não se autodeclara "pronto": a única forma de uma task ser considerada concluída é `scripts/verify.sh` sair `0` — isso é imposto por hook (`Stop`/`SubagentStop`), não por instrução em prosa.
4. Usa um **verificador independente** (`reviewer`) que nunca é a mesma sessão de quem implementou.
5. Economiza tokens por design: subagents com contexto mínimo e escopo/profundidade capados, skills carregadas sob demanda, CLAUDE.md enxuto (<200 linhas).
6. Funciona nos dois harnesses (Claude Code nativamente, Copilot via adapter) sem duplicar a fonte de verdade da metodologia.

### O que este template NÃO é

- **Não é uma aplicação FrontEnd pronta para produção.** O `src/` do template é uma prova viva mínima do harness (uma feature de exemplo), não um produto.
- **Não é dogmático sobre stack.** Todo item da §2 é _default trocável_ — trocar é seguir `docs/CUSTOMIZING.md`, não reescrever a arquitetura.
- **Não é um framework multi-produto.** A pesquisa de referências (`docs/meta/FINDINGS.md` §2.4) identificou "explosão de agentes/comandos" como a armadilha nº1 de kits análogos (BMAD, claude-forge) — este template mantém roster de 6 subagents, 10 skills, 7 comandos, deliberadamente.
- **Não garante paridade 100% entre Claude Code e Copilot.** Skills (progressive disclosure) não têm equivalente no Copilot; o gate universal (`scripts/verify.sh` via CI) é o que garante que o resultado final é o mesmo, não que a experiência de sessão seja idêntica.
- **Não substitui revisão humana.** Os 4 checkpoints humanos do fluxo (§7) são obrigatórios, não sugestões.

---

## 2. Preset de stack default

Todas as versões confirmadas em `docs/meta/FINDINGS.md` §2.3, consultadas em 2026-09-02. Cada linha é _default trocável_ — instruções de troca em `docs/CUSTOMIZING.md` (gerado na Fase de implementação, roadmap §12, item 13).

| Camada                  | Escolha default                                                                        | Versão confirmada                                                                        | Alternativa documentada                                            |
| ----------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Core UI                 | React + React Compiler                                                                 | 19.2.8 / Compiler 1.0.0 (estável)                                                        | Vue 3.5.x ou Svelte 5.56.x                                         |
| Build                   | Vite (Rolldown por padrão, ADR-007)                                                    | 8.2.2                                                                                    | — ("Vite+" é watch item, não adotado)                              |
| Lint                    | ESLint (ADR-004)                                                                       | última estável no momento da geração — checar `npm view eslint version` na implementação | Oxlint 1.60 (mais rápido, ecossistema de plugin menor)             |
| Format                  | Prettier (ADR-004)                                                                     | idem                                                                                     | Oxfmt (beta, não recomendado ainda)                                |
| Roteamento              | TanStack Router (file-based, type-safe)                                                | 1.170.32                                                                                 | React Router                                                       |
| Estado servidor         | TanStack Query                                                                         | 5.102.8                                                                                  | SWR                                                                |
| Estado cliente          | Zustand + Context (UI global de baixa frequência)                                      | 5.0.15                                                                                   | Jotai, Redux Toolkit                                               |
| Validação               | Zod                                                                                    | 4.5.4                                                                                    | Arktype 2.2.3 (interopera nativamente via Standard Schema)         |
| Codegen OpenAPI         | Orval                                                                                  | 8.27.0                                                                                   | openapi-typescript (zero runtime deps), Kubb (plugins)             |
| Estilo                  | Tailwind CSS v4 (`@theme`, OKLCH)                                                      | 4.3.3                                                                                    | —                                                                  |
| Componentes             | shadcn/ui + **Base UI** (ADR-006)                                                      | shadcn CLI 4.20.1                                                                        | Radix UI (`@radix-ui/react-*` 1.1.x)                               |
| Unit/component test     | Vitest + React Testing Library                                                         | Vitest 4.1.11 / RTL 16.3.3                                                               | —                                                                  |
| E2E                     | Playwright                                                                             | 1.62.1                                                                                   | —                                                                  |
| Mock de rede            | MSW (`onUnhandledRequest: 'error'`)                                                    | 2.15.0                                                                                   | —                                                                  |
| A11y                    | axe-core (inline via `jest-axe` equivalente para Vitest + scan de rota via Playwright) | 4.13.0                                                                                   | —                                                                  |
| Regressão visual        | Storybook                                                                              | 10.6.0                                                                                   | Ladle (libs React puras, startup mais rápido)                      |
| Observabilidade de erro | Sentry (`@sentry/react`)                                                               | 10.73.0                                                                                  | — (opcional, desligável)                                           |
| Gerenciador de pacotes  | pnpm (ADR-005)                                                                         | 11.25.0, sem uso de `catalogs` no app-exemplo                                            | npm ou yarn (compatibilidade real, não só "tecnicamente possível") |

---

## 3. Estrutura de diretórios completa

```
.
├── .claude/
│   ├── agents/                      # 6 subagents — fonte única, também lida pelo Copilot (ADR-003)
│   │   ├── planner.md
│   │   ├── test-author.md
│   │   ├── implementer.md
│   │   ├── reviewer.md
│   │   ├── a11y-auditor.md
│   │   └── refactorer.md
│   ├── skills/                      # comandos (user-invocable) + expertise sob demanda (ADR-008)
│   │   ├── spec/SKILL.md            # comando /spec
│   │   ├── plan/SKILL.md            # comando /plan
│   │   ├── tasks/SKILL.md           # comando /tasks
│   │   ├── implement/SKILL.md       # comando /implement
│   │   ├── tdd/SKILL.md             # comando /tdd
│   │   ├── review/SKILL.md          # comando /review
│   │   ├── ship/SKILL.md            # comando /ship
│   │   ├── component-conventions/SKILL.md
│   │   ├── routing-tanstack-router/SKILL.md
│   │   ├── server-state-tanstack-query/SKILL.md
│   │   ├── client-state-zustand/SKILL.md
│   │   ├── forms-validation/SKILL.md
│   │   ├── styling-tailwind-v4/SKILL.md
│   │   ├── testing-rtl-msw/SKILL.md
│   │   ├── a11y-checklist/SKILL.md
│   │   ├── error-handling/SKILL.md
│   │   └── openapi-codegen/SKILL.md
│   ├── hooks/
│   │   ├── definitions.json         # fonte única lógica dos hooks (evento, matcher, script, deny-reason)
│   │   ├── guard-destructive.sh
│   │   ├── guard-scope.sh
│   │   ├── guard-dangerous-html.sh
│   │   ├── redact-secrets.sh
│   │   ├── format.sh
│   │   ├── verify-gate.sh           # o gate — implementa o ratchet
│   │   └── log-metrics.sh
│   ├── state/                       # gitignored — estado efêmero do ratchet
│   │   └── verify-ratchet.json
│   ├── logs/                        # gitignored — métricas de observabilidade
│   │   └── metrics.jsonl
│   └── settings.json                # permissões + registro de hooks + CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1
├── .github/
│   ├── agents/                      # opcional — só se um campo Copilot-only (ex. handoffs) for necessário; gerado, não escrito à mão
│   ├── prompts/                     # espelho dos 7 comandos, gerado a partir de .claude/skills/*/SKILL.md
│   │   ├── spec.prompt.md
│   │   ├── plan.prompt.md
│   │   ├── tasks.prompt.md
│   │   ├── implement.prompt.md
│   │   ├── tdd.prompt.md
│   │   ├── review.prompt.md
│   │   └── ship.prompt.md
│   ├── hooks/                       # gerado a partir de .claude/hooks/definitions.json (ADR-001)
│   │   └── *.json
│   ├── instructions/                # opcional — instruções path-specific (feature exclusiva do Copilot, sem equivalente CC)
│   └── workflows/
│       ├── ci.yml                   # roda scripts/verify.sh — paridade local/CI
│       └── copilot-setup-steps.yml  # ambiente efêmero do Copilot coding agent
├── CLAUDE.md                        # <200 linhas — lido por Claude Code E Copilot (ADR-002)
├── SPEC.md                          # este contrato
├── specs/
│   ├── _TEMPLATE/
│   │   ├── spec.md                  # template EARS
│   │   ├── plan.md
│   │   └── tasks.md
│   └── example-feature/             # prova viva — gerada rodando o próprio pipeline uma vez
│       ├── spec.md
│       ├── plan.md
│       └── tasks.md
├── docs/
│   ├── CUSTOMIZING.md                # como clonar, trocar stack, adicionar skill/subagent
│   ├── TOKEN_BUDGET.md
│   └── meta/                        # POR QUE o template é assim — não necessário pra usá-lo;
│       ├── AGENT_ARCHITECTURE.md    # scripts/init.sh remove esta pasta ao inicializar um
│       ├── DECISIONS.md             # projeto novo (mantida só neste repo de origem)
│       └── FINDINGS.md
├── src/                              # app de exemplo mínima
│   ├── components/
│   ├── routes/
│   ├── lib/
│   └── main.tsx
├── tests/
│   ├── unit/
│   └── e2e/
├── scripts/
│   ├── init.sh                      # setup interativo pra quem clonou o template (docs/CUSTOMIZING.md §1)
│   ├── verify.sh                    # a pirâmide — chamável por humano, hook e CI
│   ├── check-critical-coverage.mjs  # valida que toda task critical:true tem teste @critical (EARS-11)
│   └── gen-hooks.mjs                # gera .github/hooks/*.json e .github/prompts/*.prompt.md a partir das fontes .claude/
├── .env.example
├── package.json                     # campo "packageManager": "pnpm@11.25.0"
├── pnpm-lock.yaml                   # + instruções de lockfile alternativo em docs/CUSTOMIZING.md
└── README.md
```

---

## 4. Definição de cada subagent

Frontmatter completo + corpo do prompt de sistema. Nenhum subagent recebe a ferramenta `Agent` (profundidade máxima = 1, `docs/meta/AGENT_ARCHITECTURE.md` §3.1). Nenhum é invocado via `context: fork` por default — cada um recebe contexto fresco (isolamento, economia de tokens).

### `.claude/agents/planner.md`

```markdown
---
name: planner
description: Turns an approved spec (specs/<feature>/spec.md) into an execution plan and an EARS-formatted task breakdown. Spawn after /spec is approved, before any code exists. Never use for writing application or test code.
tools: Read, Glob, Grep, Write, TodoWrite
model: sonnet
effort: high
---

You are the planning subagent. You read one approved spec and produce two files:
`specs/<feature>/plan.md` (technical approach, files to touch, sequencing, risks) and
`specs/<feature>/tasks.md` (an ordered list of small tasks, each with EARS-formatted
acceptance criteria and an explicit TDD note: which test proves the task done).

Rules:

- Never write to `src/` or `tests/`. Your only writes are inside `specs/<feature>/`.
- Every acceptance criterion in tasks.md MUST use one of the 6 EARS patterns
  (Ubiquitous / Event-driven / State-driven / Optional feature / Unwanted behaviour / Complex).
- Every task must be small enough for one RED→GREEN cycle. If a task needs more than one
  meaningfully separate test, split it.
- Mark any task whose acceptance criteria include a critical user flow with `critical: true`
  in tasks.md — this triggers the Playwright e2e requirement in the testability contract
  (SPEC.md §8).
- If the spec is ambiguous, do not guess: write the ambiguity as an open question at the
  top of plan.md instead of resolving it silently. A human reviews plan.md before /implement
  can start (GATE humano).
- Do not invoke other subagents. You have no Agent tool.
```

### `.claude/agents/test-author.md`

```markdown
---
name: test-author
description: Writes a single failing test (RED) for one task from tasks.md, before any implementation exists for that task. Spawn once per task at the start of the implement loop. Never use to write implementation code beyond the minimal fixtures/mocks the test itself needs.
tools: Read, Write, Edit, Bash
model: sonnet
effort: medium
skills: testing-rtl-msw
---

You are the test-authoring subagent. You receive exactly one task from `tasks.md` and its
EARS acceptance criteria. You write ONE test (or the minimal set the criteria require) that
currently fails because the behavior does not exist yet.

Rules:

- Follow the RTL/MSW conventions in the `testing-rtl-msw` skill: query by accessible role/text
  first, `data-testid` only as last resort; every network call goes through an MSW handler,
  `onUnhandledRequest: 'error'` — a test that hits real network is a failing test.
- If `tasks.md` marks the task `critical: true`, also write (or extend) a Playwright test
  tagged `@critical` covering the user-facing flow, not just a unit test.
- After writing, run `scripts/verify.sh --unit --file <path-to-your-test>`. It MUST exit
  non-zero (RED). If it passes, the test is not testing anything new — rewrite it.
- Never touch files outside `tests/**` or `src/**/*.test.*` / `src/**/*.spec.*`.
- Do not invoke other subagents. You have no Agent tool.
```

### `.claude/agents/implementer.md`

```markdown
---
name: implementer
description: Writes the minimum implementation code to turn a failing test (RED) into a passing test (GREEN) for one task. Spawn only after test-author has produced a RED test for that task. Never use to write tests or to work across multiple tasks in a single invocation.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
effort: medium
---

You are the implementation subagent. You receive one task, its acceptance criteria, and the
RED test that proves it. You write the minimum code to make that test pass without breaking
any other test.

Rules:

- Do not edit files under `specs/` or `tests/**` (test-author owns those; if the test itself
  looks wrong, say so in your final report instead of editing it).
- Do not write more implementation than the current test requires (YAGNI enforced by process,
  not just style).
- After every meaningful change, run `scripts/verify.sh`. The `verify-gate.sh` hook enforces
  the ratchet automatically (SPEC.md §5) — you do not need to track failure counts yourself,
  just keep iterating until it reports GREEN or hands off.
- A task is done only when `scripts/verify.sh` exits 0 for the whole suite, not just your
  new test.
- Do not invoke other subagents. You have no Agent tool.
```

### `.claude/agents/reviewer.md`

```markdown
---
name: reviewer
description: Independent verifier spawned after implementer reports GREEN on a task or batch. Adversarially checks quality, security, contract adherence, and mutation-style false positives in the test suite (a test that would still pass on subtly wrong code). NEVER invoke with context: fork — must not inherit implementer's reasoning. Never use to fix issues; it only reports them.
tools: Read, Grep, Glob, Bash
model: sonnet
effort: high
---

You are the independent reviewer. You did not write this code. Your job is to try to break
the claim that it is correct — not to confirm it.

Rules:

- Read-only. You never call Edit or Write. If you find a problem, you report it; you do not
  fix it.
- Run `scripts/verify.sh` yourself — do not trust a report that it already passed.
- Check, in order: (1) does the diff actually satisfy every EARS criterion in the task,
  (2) security — injection, unsanitized HTML, secrets in code/logs, unsafe deserialization,
  (3) mutation-style check — pick 2-3 non-trivial lines of new logic, mentally mutate them
  (flip a comparison, off-by-one, drop a null check) and ask whether the existing test suite
  would still pass; if yes, that is a finding (a false-positive-shaped test, not a passing one),
  (4) does the change match conventions in the relevant `.claude/skills/*/SKILL.md`.
- For each finding, state a verdict: CONFIRMED (you reproduced it) or PLAUSIBLE (you reason it
  through but could not execute a reproduction). Never state a finding as fact without one of
  these two labels.
- If a finding cannot be checked (e.g., a flaky external dependency), report it as
  "not verified" — never silently drop it and never silently upgrade it to CONFIRMED.
- Escalate to `model: opus` for this invocation (via the Agent call, not this file) when the
  change touches auth, payments, or PII handling.
- Do not invoke other subagents. You have no Agent tool.
```

### `.claude/agents/a11y-auditor.md`

```markdown
---
name: a11y-auditor
description: Runs axe-core/Playwright accessibility checks against changed components or routes and maps violations to WCAG 2.2 AA. Spawn after GREEN, in parallel with reviewer, for any task touching src/components/** or src/routes/**. Never use to fix violations; only reports them.
tools: Read, Bash, Grep
model: haiku
effort: low
---

You are the accessibility auditor. You run the a11y test command and translate structured
axe-core output into a findings list a human or `implementer` can act on.

Rules:

- Run the a11y step of `scripts/verify.sh` (`scripts/verify.sh --a11y`) against the changed
  routes/components only, not the whole app, unless asked for a full scan.
- Use the `a11y-checklist` skill to classify each violation's severity (critical/serious vs
  minor) — the gate in `verify-gate.sh` only blocks on critical/serious.
- Most violations are mechanical (missing alt text, contrast ratio, missing label) — report
  them directly. If a violation requires subjective judgment (e.g., whether alt text is
  _meaningful_, not just present), flag it explicitly as "needs sonnet-level judgment" instead
  of guessing — the invocation can be re-run with `model: sonnet` when that happens.
- Do not invoke other subagents. You have no Agent tool.
```

### `.claude/agents/refactorer.md`

```markdown
---
name: refactorer
description: Improves code structure without changing observable behavior, protected by the existing test suite. Spawn only on explicit /refactor request or a task explicitly marked refactor in tasks.md. Never use if new behavior or new tests are required — that is implementer's job.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
effort: medium
---

You are the refactoring subagent. The existing test suite is your contract: it must be 100%
green before you start and 100% green when you finish, with no new test added.

Rules:

- If making the change requires a new test, stop and report that this is not a refactor —
  hand it back as an `implementer` task instead.
- Run `scripts/verify.sh` before starting (confirm baseline is green) and after every
  meaningful change.
- Prefer small, reviewable steps over one large rewrite — each step should independently
  keep the suite green.
- Do not invoke other subagents. You have no Agent tool.
```

---

## 5. Definição de cada hook

Registrados em `.claude/settings.json` (Claude Code) e espelhados em `.github/hooks/*.json` (Copilot, gerados por `scripts/gen-hooks.mjs` a partir de `.claude/hooks/definitions.json` — ADR-001). `matcher` usa a sintaxe de matcher de tool do Claude Code (nome exato ou regex).

| #   | Evento                 | Matcher       | Script                    | Gatilho / lógica                                                                                                                                                                                                    | Retorno                                                                                                                                                                                                           |
| --- | ---------------------- | ------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `PreToolUse`           | `Bash`        | `guard-destructive.sh`    | Regex sobre o comando: `rm\s+-rf` fora de `/tmp`/scratchpad conhecidos; `push\s+(-f                                                                                                                                 | --force)`para branches em`protected_branches`(config);`reset\s+--hard` sem um checkpoint recente (`git log -1 --grep=checkpoint` dentro de 5 commits); leitura direta de segredo (`cat .env`, `printenv`, `env$`) | `permissionDecision: "deny"` com `reason` explicando a alternativa seguraem (ex.: "use scripts/verify.sh's git checkpoint mechanism instead of --hard reset") |
| 2   | `PreToolUse`           | `Write\|Edit` | `guard-scope.sh`          | Resolve o path absoluto do alvo; nega se estiver fora do `cwd` do repositório (inclui `../` que escapa do worktree)                                                                                                 | `permissionDecision: "deny"`                                                                                                                                                                                      |
| 3   | `PreToolUse`           | `Write\|Edit` | `guard-dangerous-html.sh` | Escaneia o `new_content`/diff por `dangerouslySetInnerHTML`; nega se não houver, na mesma expressão ou import do arquivo, uma chamada de sanitização (`DOMPurify.sanitize`, `sanitizeHtml`)                         | `permissionDecision: "deny"`, `reason` sugere `DOMPurify.sanitize(...)`                                                                                                                                           |
| 4   | `PostToolUse`          | `Bash`        | `redact-secrets.sh`       | Escaneia stdout/stderr do comando por padrões de token conhecidos (`sk-[a-zA-Z0-9]{20,}`, `ghp_[a-zA-Z0-9]{36}`, `AKIA[A-Z0-9]{16}`, JWT de 3 segmentos) e por strings de alta entropia (>4.0 bits/char, >20 chars) | Não bloqueia; reescreve o campo de output via `additionalContext`, substituindo matches por `[REDACTED]`                                                                                                          |
| 5   | `PostToolUse`          | `Write\|Edit` | `format.sh`               | Roda `prettier --write <arquivo>`; se `<arquivo>` é `.ts`/`.tsx`/`.js`/`.jsx`, roda também `eslint --fix <arquivo>`                                                                                                 | Exit 0 sempre (silencioso em sucesso; se `eslint --fix` não resolver tudo, os erros restantes aparecem no próximo `verify-gate.sh`, não aqui)                                                                     |
| 6   | `Stop`, `SubagentStop` | —             | `verify-gate.sh`          | Ver mecânica de ratchet abaixo                                                                                                                                                                                      | Bloqueia (exit 2) até verify 0, limite de tentativas, ou handoff                                                                                                                                                  |
| 7   | `PostToolUse`          | `*` (todas)   | `log-metrics.sh`          | Acrescenta uma linha JSONL a `.claude/logs/metrics.jsonl` com `{ts, role, model, tokens_in, tokens_out, cache_read_tokens, tool_call_count}` (campos disponíveis no payload do hook)                                | Exit 0 sempre, nunca bloqueia                                                                                                                                                                                     |

### Mecânica exata do ratchet (`verify-gate.sh`)

Estado em `.claude/state/verify-ratchet.json`:

```json
{ "last_good_sha": "<sha>", "last_failure_count": 0, "attempts_this_task": 0 }
```

Algoritmo (roda `scripts/verify.sh --json` a cada disparo):

1. **Se `stop_hook_active == true`** no payload de entrada: `exit 0` imediatamente (evita recontar um bloqueio que o próprio harness já está processando — regra de `docs/meta/FINDINGS.md` §2.1.4).
2. Roda `scripts/verify.sh --json`. Extrai `exit_code` e `failure_count` (soma de erros de cada etapa da pirâmide, §6).
3. **`exit_code == 0`:** grava `last_good_sha = $(git rev-parse HEAD)`, zera `last_failure_count` e `attempts_this_task`. `exit 0` — turno pode terminar.
4. **`exit_code != 0` e `failure_count < last_failure_count`:** progresso real. Atualiza `last_failure_count`, incrementa `attempts_this_task`. `exit 2` com a lista de falhas restantes no `systemMessage`. Não reverte nada.
5. **`exit_code != 0` e `failure_count >= last_failure_count`:** regressão ou estagnação. Roda `git diff --name-only HEAD` para listar arquivos tocados neste turno; `git checkout -- <esses arquivos>` restaura o conteúdo de `last_good_sha` **só para eles** (nunca `reset --hard` do repo inteiro — outros arquivos em progresso em paralelo não são tocados). Incrementa `attempts_this_task`. `exit 2` com mensagem: _"A última mudança piorou o resultado (X→Y falhas). Arquivos revertidos para o último estado bom. Tente uma abordagem diferente."_
6. **`attempts_this_task >= 6`:** escreve `specs/<feature>/HANDOFF_NEEDED.md` com o histórico de tentativas (lido de um log auxiliar) e `exit 0` — deixa o turno terminar graciosamente, **antes** do cap nativo de 8 bloqueios consecutivos do Claude Code (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`, `docs/meta/FINDINGS.md` §2.1.4), para que o handoff seja uma decisão do template, não uma interrupção forçada pelo harness.

Isso garante as 3 únicas saídas válidas do loop: verify `0`, limite de tentativas atingido, handoff humano — nunca uma 4ª saída onde o agente se autodeclara "pronto" (`docs/meta/FINDINGS.md` §2.2.3).

### `.claude/settings.json` — campos relevantes

```json
{
  "env": { "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH": "1" },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": ".claude/hooks/guard-destructive.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/guard-scope.sh" },
          { "type": "command", "command": ".claude/hooks/guard-dangerous-html.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": ".claude/hooks/redact-secrets.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": ".claude/hooks/format.sh" }]
      },
      {
        "matcher": "*",
        "hooks": [{ "type": "command", "command": ".claude/hooks/log-metrics.sh" }]
      }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": ".claude/hooks/verify-gate.sh" }] }
    ],
    "SubagentStop": [
      { "hooks": [{ "type": "command", "command": ".claude/hooks/verify-gate.sh" }] }
    ]
  }
}
```

---

## 6. A pirâmide de verificação (`scripts/verify.sh`)

Única fonte de verdade, chamada por: humano (`./scripts/verify.sh`), hook `verify-gate.sh`, e CI (`.github/workflows/ci.yml`). Ordem exata (mais barato/rápido primeiro, mais caro por último):

| Ordem | Etapa          | Comando                                                         | Critério RED/GREEN                                | Contribui p/ `failure_count`     |
| ----- | -------------- | --------------------------------------------------------------- | ------------------------------------------------- | -------------------------------- |
| 0     | Format check   | `prettier --check .`                                            | GREEN se nenhum arquivo precisa de reformatação   | nº de arquivos não formatados    |
| 1     | Typecheck      | `tsc --noEmit`                                                  | GREEN se 0 erros                                  | nº de erros de tipo              |
| 2     | Lint           | `eslint .`                                                      | GREEN se 0 erros (warnings não contam)            | nº de erros de lint              |
| 3     | Unit/component | `vitest run --coverage`                                         | GREEN se 0 testes falhando                        | nº de testes falhando            |
| 4     | E2E crítico    | `playwright test --grep @critical`                              | GREEN se 0 falhas nos fluxos marcados `@critical` | nº de testes e2e falhando        |
| 5     | Build          | `vite build`                                                    | GREEN se build completa sem erro                  | 1 se falhar, 0 se não            |
| 6     | A11y           | `playwright test --grep @a11y` (varre rotas-chave com axe-core) | GREEN se 0 violações `critical`/`serious`         | nº de violações critical+serious |

**Flags:**

- `--json`: emite `{"exit_code": N, "failure_count": N, "steps": [{"name","passed","count"}...]}` em vez de output humano — usado por `verify-gate.sh`.
- `--unit`: roda só a etapa 3 (usado por `test-author` para confirmar RED de um teste específico via `--file <path>`).
- `--a11y`: roda só a etapa 6 (usado por `a11y-auditor`).
- Sem flags: roda a pirâmide inteira, ordem 0→6, **para na primeira falha** em modo humano (feedback rápido); em modo `--json` roda **todas** as etapas mesmo com falha anterior, para o `failure_count` refletir o estado real completo (necessário para o ratchet comparar corretamente entre tentativas).

**Código de saída geral:** `0` só se todas as 7 etapas passarem. Qualquer etapa falhando → exit code igual ao número da primeira etapa que falhou (1-7, útil para debug rápido humano), mas em modo `--json` o campo `exit_code` é sempre `0` ou `1` (booleano) e o detalhe fica em `steps`.

---

## 7. Fluxo SDD ponta a ponta

```
/spec  →  [GATE HUMANO: spec aprovada?]  →  /plan (→ planner)  →  [GATE HUMANO: plano aprovado?]
   →  /implement (loop test-author → implementer → verify-gate.sh, por task)
   →  /review (→ reviewer + a11y-auditor, paralelo)  →  [GATE AUTOMÁTICO: achados CONFIRMED de severidade alta bloqueiam]
   →  /ship (verify.sh completo + abre PR)  →  [GATE HUMANO: aprova o PR?]  →  merge
```

Diagrama completo (Mermaid) em `docs/meta/AGENT_ARCHITECTURE.md` (seção "Diagrama do pipeline") — reproduzido aqui é redundante, a referência é a fonte de verdade.

**Checkpoints humanos (4, todos obrigatórios):** aprovação de `spec.md`, aprovação de `plan.md`/`tasks.md`, decisão sobre achados de `/review` que não sejam auto-resolvíveis, aprovação final do PR em `/ship`.

**Gates automáticos (2):** `verify-gate.sh` a cada task dentro de `/implement` (ratchet, §5); bloqueio de `/ship` se `/review` tiver achado `CONFIRMED` de severidade alta sem waiver humano explícito registrado em `specs/<feature>/tasks.md`.

---

## 8. Contrato de testabilidade

**O que conta como "coberto":** toda linha EARS de `spec.md` tem pelo menos um teste automatizado que a referencia — convenção: comentário `// covers: <id-da-linha-EARS>` no teste (ou `test.info().annotations` no Playwright). `reviewer` verifica essa rastreabilidade como parte do seu checklist (§4, `reviewer`).

**Papéis das ferramentas:**

- **Vitest + RTL:** comportamento de componente isolado; queries por papel/texto acessível antes de `data-testid`.
- **MSW:** todo teste que envolve rede usa handler MSW; `onUnhandledRequest: 'error'` — uma chamada de rede real é uma falha de teste, não um "funcionou por acidente".
- **Playwright:** fluxos de usuário ponta a ponta marcados `@critical` — obrigatório para qualquer task com `critical: true` em `tasks.md` (definido por `planner`, §4). Task crítica sem teste e2e é bloqueada por `verify-gate.sh` etapa 4.
- **axe-core:** duas camadas — inline (asserção de acessibilidade dentro do teste de componente, via etapa 3) e scan de rota completa marcado `@a11y` (etapa 6). Violação `critical`/`serious` bloqueia; `minor` vira item de backlog, não bloqueio.
- **Storybook:** não é gate de `verify.sh` (custo de manter build de Storybook em toda execução de hook seria alto) — roda em CI separado (`docs/CUSTOMIZING.md` documenta como plugar regressão visual sem inflar o loop de hook).

**Regra de features críticas:** qualquer linha EARS que descreva um fluxo com dinheiro, dados pessoais, ou autenticação é automaticamente `critical: true` (regra que `planner` aplica, não uma sugestão) — exige teste Playwright, não só unit.

---

## 9. Estratégia de economia de tokens

1. **Contexto mínimo por subagent:** nenhum subagent do roster usa `context: fork` por default (§4) — cada um recebe só o artefato relevante (task, diff, spec), nunca a conversa completa que os originou. Exceção documentada: forks só a nível de sessão principal (Explore/pesquisa), nunca dentro do roster de 6 papéis.
2. **Skills sob demanda:** `description` de cada skill carrega sempre (custo baixo); conteúdo completo só quando invocado/casado por `paths`. Skills-comando (`spec`, `plan`, etc.) usam `user-invocable: true`; skills de expertise usam `paths` glob quando aplicável (`component-conventions` só carrega em edições de `src/components/**`, por exemplo) para não competir por relevância com skills não relacionadas.
3. **Tool Search para cauda longa:** o template base não empacota nenhum MCP server por padrão (mantém o preset agnóstico). Se um projeto clonado adicionar MCP servers, `docs/CUSTOMIZING.md` recomenda `defer_loading: true` para qualquer servidor com mais de ~5 tools, conforme o mecanismo de Tool Search Tool documentado em `docs/meta/FINDINGS.md` §2.2.7 (redução de até 95% no custo de contexto do setup de tools).
4. **Política de `/compact`:** ver `docs/meta/AGENT_ARCHITECTURE.md` §3.6 — preserva ponteiro de task ativa e status de falha atual (não o histórico completo de tentativas), descarta output de ferramenta já incorporado ao raciocínio.
5. **Orçamento por papel e alertas:** tabela completa em `docs/meta/AGENT_ARCHITECTURE.md` §3.5 (planner 50k, test-author 20k, implementer 60k/task, reviewer 40k, a11y-auditor 20k, refactorer 40k). Alerta em 80% via `systemMessage`; hard stop marca a task `blocked: token_budget` em `tasks.md` — mesma via de handoff humano do ratchet, não uma saída nova.
6. **Cache:** subagents usam TTL de 5min por padrão mesmo em assinatura (`docs/meta/FINDINGS.md` §2.1.9); papéis reinvocados em lote dentro do mesmo `/implement` (`test-author`/`implementer` task após task, mesmo prefixo de sistema) podem declarar `experimental.cacheTtl: "1h"` no frontmatter quando a versão do Claude Code em uso suportar (v2.1.248+) — checar na implementação (roadmap §12, item 7) antes de assumir suporte.
7. **`CLAUDE.md` enxuto:** <200 linhas, aponta para skills em vez de despejar conteúdo inline (§3.6 de `docs/meta/AGENT_ARCHITECTURE.md` já especifica o conteúdo exato).

---

## 10. Guia de customização

Passos detalhados vivem em `docs/CUSTOMIZING.md` (gerado no roadmap §12, item 13); esta seção define o que esse guia **deve** cobrir, como contrato:

1. **Clonar e rebatizar:** `git clone` → `scripts/init.sh` (interativo: renomeia o projeto, remove `docs/meta/` — artefatos da geração do template, não do projeto que nasce dele — reescreve a "uma frase de missão" no topo de `CLAUDE.md`, reinicia o histórico git). Passos manuais equivalentes documentados como fallback.
2. **Trocar uma camada de stack:** para cada linha da tabela §2, um passo a passo de "remover X, instalar Y, quais arquivos de skill/config mudam" — cobrir no mínimo: Base UI↔Radix (componentes.json + regenerar), ESLint+Prettier↔Oxlint+Prettier, Zod↔Arktype, Orval↔openapi-typescript, React↔Vue/Svelte (mudança estrutural maior — marcar como "troca de preset inteiro", não de item isolado), pnpm↔npm/yarn (comandos equivalentes de instalação, lockfile correspondente).
3. **Adicionar uma skill:** template de `SKILL.md` mínimo + onde registrar (nenhum registro central — é descoberta por diretório).
4. **Adicionar um subagent:** template de frontmatter mínimo + lembrete explícito de manter `tools` sem `Agent` a menos que a decisão de aumentar a profundidade seja deliberada e documentada como novo ADR no projeto que clonou.
5. **Adaptar os gates:** como editar `.claude/hooks/definitions.json` e re-rodar `scripts/gen-hooks.mjs`; como adicionar uma nova etapa à pirâmide de `scripts/verify.sh` sem quebrar o parsing `--json` do ratchet.
6. **Extensão recomendada como primeiro passo, não redesign:** separar `adversarial-reviewer` do `reviewer` se este se mostrar sobrecarregado (decisão registrada em `docs/meta/DECISIONS.md`, ADR sobre roster).

---

## 11. Critérios de aceite do próprio template (EARS)

Verificáveis por máquina — checados no roadmap §12, item 15.

1. **THE `scripts/verify.sh` SHALL** sair com código `0` quando rodado num clone limpo, com dependências instaladas, sem nenhuma alteração aplicada.
2. **WHEN** um arquivo é editado via `Write` ou `Edit` numa sessão do Claude Code, **THE** hook `PostToolUse` `format.sh` **SHALL** rodar o formatter sobre esse arquivo dentro do mesmo turno.
3. **IF** um comando `Bash` corresponde a um padrão destrutivo (`rm -rf` fora de paths seguros, `push --force` para branch protegida, `reset --hard` sem checkpoint recente), **THEN THE** hook `PreToolUse` `guard-destructive.sh` **SHALL** negar o comando.
4. **WHILE** a contagem de falhas de `verify-gate.sh` não diminuiu entre tentativas consecutivas, **THE** hook **SHALL** reverter (via `git checkout --`) apenas os arquivos tocados naquele turno para `last_good_sha`.
5. **WHEN** um subagent do papel `reviewer` é invocado, **THE** invocação **SHALL NÃO** usar `context: fork`.
6. **WHERE** um subagent é definido em `.claude/agents/`, **THE** campo `tools` do seu frontmatter **SHALL NÃO** incluir `Agent`.
7. **WHEN** `attempts_this_task` atinge 6, **THE** hook **SHALL** escrever `specs/<feature>/HANDOFF_NEEDED.md` e permitir que o turno termine (não bloquear).
8. **WHEN** o mesmo repositório é aberto no GitHub Copilot (extensão VS Code), **THE** arquivos em `.claude/agents/*.md` **SHALL** ser lidos como custom agents do Copilot sem necessidade de edição manual.
9. **WHEN** o CI (`.github/workflows/ci.yml`) roda `scripts/verify.sh` num PR, **THE** resultado (pass/fail) **SHALL** ser idêntico ao de rodar `./scripts/verify.sh` localmente no mesmo commit.
10. **WHEN** o projeto é instalado com `npm install` ou `yarn install` em vez de `pnpm install`, **THE** instalação **SHALL** completar sem erro e `scripts/verify.sh` **SHALL** continuar saindo `0`.
11. **IF** uma task em `tasks.md` está marcada `critical: true` e não existe nenhum teste Playwright com tag `@critical` cobrindo sua linha EARS, **THEN THE** etapa 4 de `scripts/verify.sh` **SHALL** falhar.
12. **WHEN** `scripts/verify.sh` é chamado com `--json`, **THE** saída **SHALL** ser um JSON válido contendo `exit_code`, `failure_count` e a lista `steps` com uma entrada por etapa da pirâmide.

---

## 12. Roadmap de geração

Lista ordenada de tasks para a próxima etapa (implementação do template a partir desta SPEC). Cada item deve terminar com `scripts/verify.sh` (ou o subconjunto relevante) verde antes do próximo começar, onde aplicável.

1. Scaffold do esqueleto de diretórios completo (§3), incluindo `.gitignore` cobrindo `.claude/state/`, `.claude/logs/`, `node_modules/`.
2. `package.json` raiz com `"packageManager": "pnpm@11.25.0"`, scripts (`dev`, `build`, `verify`, `test`, `test:e2e`) escritos sem sintaxe exclusiva de pnpm (ADR-005); `pnpm-workspace.yaml` mínimo (sem `catalogs` no exemplo).
3. App de exemplo mínima em `src/`: Vite 8 + React 19 + TS, TanStack Router (2-3 rotas), TanStack Query (1 chamada mockada via MSW), Zustand (1 store simples), Tailwind v4 + shadcn/ui com Base UI (2-3 componentes), Zod (1 schema de fronteira).
4. Configurar ESLint + Prettier (ADR-004) com regras de a11y (`eslint-plugin-jsx-a11y` ou equivalente atual) e regra de import ordenado.
5. Escrever `scripts/verify.sh` implementando as 7 etapas da §6, com flags `--json`, `--unit --file`, `--a11y`.
6. Escrever os 7 scripts de hook em `.claude/hooks/` (§5) + `.claude/hooks/definitions.json` como fonte lógica única.
7. Escrever `scripts/gen-hooks.mjs`, rodar para gerar `.github/hooks/*.json` e `.github/prompts/*.prompt.md` a partir das fontes `.claude/`; checar nesta etapa se a versão do Claude Code disponível suporta `experimental.cacheTtl` (v2.1.248+) antes de incluir esse campo nos frontmatters de subagent.
8. Escrever os 6 arquivos de subagent em `.claude/agents/` (conteúdo exato da §4).
9. Escrever as 10 skills de expertise + 7 skills-comando em `.claude/skills/` (conteúdo descrito em `docs/meta/AGENT_ARCHITECTURE.md` §3.3/§3.4 — cada `SKILL.md` deve ser escrito com conteúdo real, não placeholder).
10. Escrever `CLAUDE.md` seguindo exatamente o conteúdo especificado em `docs/meta/AGENT_ARCHITECTURE.md` §3.6, checar `< 200` linhas.
11. Escrever `specs/_TEMPLATE/{spec,plan,tasks}.md` (templates EARS vazios, comentados) e depois **rodar o próprio pipeline uma vez** (`/spec` → `/plan` → `/implement` → `/review` → `/ship`) contra uma feature de exemplo real do `src/` de exemplo, gerando `specs/example-feature/` como prova viva — isso é o teste de integração do template inteiro, não opcional.
12. Escrever `.github/workflows/ci.yml` (roda `scripts/verify.sh`) e `.github/workflows/copilot-setup-steps.yml` (ambiente efêmero do Copilot coding agent).
13. Escrever `docs/CUSTOMIZING.md` (conteúdo definido em §10) e `docs/TOKEN_BUDGET.md` (conteúdo definido em `docs/meta/AGENT_ARCHITECTURE.md` §3.5, "Métricas instrumentadas").
14. Escrever `README.md` (visão geral curta + link para `SPEC.md`/`docs/CUSTOMIZING.md` — não duplicar conteúdo).
15. Rodar `scripts/verify.sh` num clone limpo (`git clone` local para um diretório novo, `pnpm install`, `./scripts/verify.sh`) e confirmar exit `0` — satisfaz critério de aceite §11.1. Repetir instalação com `npm install` e `yarn install` — critério §11.10.
16. Validação final: revisão humana comparando o repositório gerado contra os 12 critérios de aceite da §11, item a item, com evidência de comando+output para cada um (não afirmação).
