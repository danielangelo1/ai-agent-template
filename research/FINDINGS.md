# FINDINGS.md — Pesquisa Fase 1 (BUILD_FRONTEND_AGENT_TEMPLATE)

> Pesquisa conduzida em 2026-09-02 via busca real na web (WebSearch/WebFetch), priorizando fontes primárias. Cada achado traz fonte e data de verificação. Itens não confirmados estão explicitamente marcados como tal — não foram inventados.

---

## 2.1 Harness do Claude Code / Agent SDK (o "como")

Verificado em 2026-09-02, priorizando `code.claude.com/docs/en/*` (documentação oficial atual do Claude Code).

### 2.1.1 Superfícies oficiais e o que cada uma deve conter

**Achado:** A doc oficial "Extend Claude Code" lista as superfícies como: CLAUDE.md (contexto persistente carregado toda sessão), Skills (conhecimento/workflows reutilizáveis, sob demanda), Code intelligence (LSP), MCP (conexões externas), Subagents (loops isolados, retornam sumário), Dynamic workflows (scripts que orquestram muitos subagents), Cross-session messaging, Hooks (automação determinística em eventos de ciclo de vida) e Plugins/Marketplaces (empacotamento/distribuição).

Regra prática oficial de progressão: CLAUDE.md quando Claude erra uma convenção 2x → Skill quando você repete o mesmo prompt/procedimento 3x → MCP quando precisa copiar dados de um sistema externo → Subagent quando uma tarefa lateral inunda a conversa principal → Hook quando algo deve acontecer sempre, sem perguntar → Plugin quando outro repositório precisa do mesmo setup.

Regra de ouro CLAUDE.md vs Skill: **CLAUDE.md deve ficar abaixo de 200 linhas**; conteúdo de referência deve migrar para Skills (que só carregam sob demanda, custo de contexto quase zero até serem usadas). "Custom commands" (`.claude/commands/*.md`) foram **fundidas em Skills** — um skill em `.claude/skills/deploy/SKILL.md` cria `/deploy` da mesma forma que `.claude/commands/deploy.md` fazia (arquivos antigos continuam funcionando).

**Fonte:** https://code.claude.com/docs/en/features-overview — verificado 2026-09-02.

**Implicação para o template:** `.claude/commands/` como pasta separada é um padrão legado que ainda funciona, mas a forma canônica atual de empacotar um slash-command é um Skill (`.claude/skills/<nome>/SKILL.md`) com `user-invocable: true` — reconsiderar §4.3 da estrutura de diretórios do START.MD (ver `docs/DECISIONS.md`).

### 2.1.2 Formato SKILL.md — frontmatter completo e descoberta

**Achado:** Skills seguem o padrão aberto **Agent Skills** (agentskills.io), com extensões próprias do Claude Code. Frontmatter YAML, todos os campos opcionais exceto `description` (recomendado). Campos confirmados: `name`, `description` (texto combinado com `when_to_use`, truncado em **1.536 caracteres** para decisão de carregamento), `argument-hint`, `arguments`, `disable-model-invocation` (impede carregamento automático — só via `/nome`; também impede pré-carregamento em subagents/scheduled tasks desde v2.1.196), `user-invocable` (default `true`), `allowed-tools`, `disallowed-tools`, `model` (override só naquele turno), `effort`, `context: fork` (roda o skill em subagent isolado), `agent` (tipo de subagent com `context: fork`), `background` (default `true` com `context: fork`, requer v2.1.218+), `hooks`, `paths` (glob para ativação automática por arquivo), `shell`, `metadata`, `license`, `compatibility`.

Carregamento: **descrições** de skills carregam no início da sessão (custo baixo, toda requisição); o **conteúdo completo** só carrega quando usado (via `/nome` ou automaticamente por Claude). Skills com `disable-model-invocation: true` têm custo zero até invocação manual.

**Fonte:** https://code.claude.com/docs/en/skills — verificado 2026-09-02.

### 2.1.3 Hooks — lista completa de eventos e semântica

**Achado:** Lista bem mais extensa que os 5 eventos citados no meta-prompt original:

- **Lifecycle:** `SessionStart`, `SessionEnd`, `Setup`
- **Per-turn:** `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`
- **Tool-use:** `PreToolUse` (bloqueia via `permissionDecision: allow|deny`, pode reescrever input via `updatedInput`), `PermissionRequest`, `PermissionDenied`, `PostToolUse` (não bloqueia — a ferramenta já rodou), `PostToolUseFailure`, `PostToolBatch` (pode bloquear antes da próxima chamada ao modelo)
- **Subagent:** `SubagentStart`, `SubagentStop` (bloqueia via `continueSession`), `TeammateIdle`
- **Task:** `TaskCreated`, `TaskCompleted` (bloqueiam via `continueProcessing`)
- **Display/Notification:** `MessageDisplay`, `Notification`
- **Contexto/config:** `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`
- **Worktree:** `WorktreeCreate` (qualquer exit ≠0 aborta — diferente dos demais), `WorktreeRemove`
- **Compaction:** `PreCompact`, `PostCompact`
- **Model switch:** `PreModelSwitch`, `PostModelSwitch`
- **MCP elicitation:** `Elicitation`, `ElicitationResult`

**Semântica de exit code:** `0` = sucesso (lê JSON de stdout); `1` = erro não-bloqueante; `2` = **bloqueia** a ação (nos eventos que suportam bloqueio); outros códigos = não-bloqueante (varia por evento). Campos JSON de saída: `permissionDecision` (tool events), `continueSession` (session/subagent), `continueProcessing` (maioria dos outros), `updatedInput`, `additionalContext`, `systemMessage`.

**NÃO CONFIRMADO (fonte primária):** se `TaskCreated`/`TaskCompleted`/`TeammateIdle` exigem `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — visto só em fonte secundária; a doc oficial confirma que esses eventos existem e pertencem a "agent teams" (feature descrita em outra página como experimental/desabilitada por padrão), mas não fiz fetch direto confirmando o flag exato.

**Fonte:** https://code.claude.com/docs/en/hooks — verificado 2026-09-02.

### 2.1.4 Stop hook como gate determinístico — limite de bloqueios consecutivos

**Achado confirmado com número exato:** Claude Code sobrepõe (força o fim do turno) um Stop hook depois que ele **bloqueia 8 vezes consecutivas sem progresso**. Quando isso acontece, o turno é encerrado mesmo assim, com aviso explícito. Para o hook não contar progresso legítimo como bloqueio repetido, o script deve checar `stop_hook_active` no JSON de entrada e sair cedo (`exit 0`) se já `true`. O limite pode ser elevado via `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`.

Mecânica: dispara quando Claude termina de responder (não em interrupções do usuário); pode bloquear com exit 2 (`continueSession`); payload inclui `last_assistant_message`.

**Fonte:** https://code.claude.com/docs/en/hooks-guide, seção "Stop hook hits the block cap" — verificado 2026-09-02. **Número confirmado: 8.**

### 2.1.5 Subagents — frontmatter completo, seleção de modelo, aninhamento

**Achado — frontmatter:** `name` (obrigatório), `description` (obrigatório/recomendado — gatilho de roteamento automático), `tools`, `disallowedTools`, `model` (`sonnet`|`opus`|`haiku`|`fable`|ID completo|`inherit`), `permissionMode`, `maxTurns`, `skills` (pré-carrega conteúdo completo no startup do subagent), `mcpServers`, `hooks` (escopados ao subagent), `memory` (`user`|`project`|`local`), `background`, `isolation: worktree`, `effort`, `initialPrompt`, `color`, `experimental` (inclui `cacheTtl`, requer v2.1.248+).

**Ordem de resolução de modelo:** 1) parâmetro `model` na chamada da ferramenta Agent → 2) `model` no frontmatter (`inherit` usa o modelo da conversa principal) → 3) env var `CLAUDE_CODE_SUBAGENT_MODEL` → 4) modelo da conversa principal (fallback). Recomendação: especificar explicitamente modelo barato (`haiku`) para tarefas simples de leitura/exploração, evitando herança cara de Opus. Subagents nativos "Explore" e "Plan" têm cap em Opus na API (desde v2.1.198).

**Aninhamento (com histórico de versão):** por padrão, subagents podem gerar subagents **até 3 camadas abaixo da conversa principal** (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, default `"3"`). No limite, a ferramenta `Agent` é retirada (exceto forks, que a mantêm mas retorna erro). Histórico: v2.1.172–216 permitiam até 5 camadas fixas; v2.1.217–218 reduziram default para 1; v2.1.219+ fixou default em 3, configurável.

Razão documentada para capar profundidade/escopo: evita explosão combinatória de custo/tempo; mantém achados intermediários fora do contexto principal (um subagent no limite faz o trabalho e retorna 1 sumário). Escopo se restringe com `Agent(nome1, nome2)` no `tools` do coordenador, ou negando `Agent` em subagents "read-only".

**Fonte:** https://code.claude.com/docs/en/sub-agents — verificado 2026-09-02.

### 2.1.6 Padrão de "verificador independente"

**Achado (documentação oficial explícita):** A doc de Dynamic Workflows descreve exatamente este padrão: workflows podem ter "independent agents adversarially review each other's findings before they're reported", ou elaborar plano de vários ângulos e pesá-los entre si.

O workflow bundled `/deep-research` implementa isso: fan-out de buscas em vários ângulos, cross-check de fontes, **votação por claim**, síntese com citações; claims que não sobrevivem ao cross-check são filtrados. Quando verificadores não conseguem checar uma claim (ex.: rate limit), o relatório marca "não verificada" (distinto de "refutada").

Prompt de exemplo oficial: _"use a workflow to audit every route handler under src/routes/ for missing authentication checks, and adversarially verify each finding before reporting it"_.

**Fonte:** https://code.claude.com/docs/en/workflows — verificado 2026-09-02.

### 2.1.7 Plan Mode

**Achado:** Modo somente-leitura (`permissionMode: plan`) — Read/Glob/Grep/WebSearch/WebFetch/TodoRead/Write permitidos, mas sem edição de arquivos, Bash com efeito colateral ou execução de código até um plano ser apresentado e aprovado. Ativação: `Shift+Tab` até "plan mode on", `claude --permission-mode plan`, ou prefixo `/plan` num prompt único.

Racional de design confirmado (ligado ao item de prompt caching): plan mode injeta instruções como mensagens de conversa, não altera o prefixo do system prompt — preservando cache.

**NÃO CONFIRMADO por fonte primária:** que o subagent nativo "Explore" roda em Haiku por padrão (visto só em fonte secundária — DataCamp, vibecodingacademy.ai). A doc oficial de sub-agents confirma cap em Opus para Explore/Plan, não que o default seja Haiku.

**Fonte:** https://code.claude.com/docs/en/permission-modes (referenciada por outras páginas oficiais) — verificado 2026-09-02.

### 2.1.8 Roteamento de modelo: fork (breadth) vs inline (depth)

**Achado:** Doc oficial "Run agents in parallel" compara Subagents / Agent view / Agent teams / Dynamic workflows por quem coordena, se precisam se comunicar, e se tocam os mesmos arquivos. Regra central: **subagent** quando uma tarefa lateral inundaria a conversa principal com resultado não-reutilizável (isolamento de contexto = breadth); **dynamic workflow** quando o trabalho ultrapassa "um punhado de subagents" ou exige achados cross-checados em escala (dezenas a centenas de agentes por execução).

**Fork** é oficialmente "a subagent that inherits your full conversation context instead of starting fresh" — não é superfície separada, é uma forma de spawnar subagent (via `/subtask` ou modo fork automático). Workflows herdam a mesma ordem de seleção de modelo que subagents. Guideline de tamanho de workflow: `small` (<5 agentes), `medium` (<15, default), `large` (<50), `unrestricted`.

**Fonte:** https://code.claude.com/docs/en/agents e https://code.claude.com/docs/en/workflows — verificado 2026-09-02.

### 2.1.9 Prompt caching / cache hit rate

**Achado — mecanismo:** cache por **correspondência exata de prefixo**. Claude Code ordena o request em 3 camadas: (1) System prompt (muda com toolset/versão do Claude Code), (2) Project context (CLAUDE.md, auto memory — muda no início de sessão ou após `/clear`/`/compact`), (3) Conversation (muda a cada turno). Mudança numa camada invalida tudo abaixo dela na ordem listada.

**TTLs confirmados:** API oferece **5 minutos** e **1 hora** (1h cobra taxa de escrita maior). Claude Code escolhe por bucket: "Main conversation" (turnos interativos, `-p`, Agent SDK) vs "Everything else" (subagents, workflows, teammates, forks, compaction, títulos de sessão). Em assinatura, conversa principal usa **1h** por padrão; "everything else" (**incluindo subagents**) usa **5 min por padrão**, mesmo em assinatura — configurável via `subagentPromptCacheTtl` / `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL` (requer v2.1.242+). Com chave de API, ambos os buckets default para 5 min.

**O que invalida o cache:** troca de modelo, mudança de effort level, ativar fast mode, conectar/desconectar MCP server (quando ferramentas carregam no prefixo), habilitar/desabilitar plugin com MCP no prefixo, negar ferramenta inteira, `/compact`, upgrade do Claude Code.

**O que MANTÉM o cache:** editar arquivos do repo, editar CLAUDE.md em sessão ativa (não é aplicado até reload), mudar output style/permission mode, invocar skills/commands, `/recap`, `/rewind`, spawnar subagent normal (não afeta cache do pai; subagent começa com prefixo próprio — exceto **fork**, que herda o prefixo do pai e lê seu cache).

**Impacto de custo:** leitura de cache ≈ **10% da taxa padrão de input**; escrita cobra taxa maior (mais alta para TTL 1h). Recomendação oficial: "Pick your model and effort level at the top of a session, then save `/compact` for natural breaks between tasks." Em fan-out de workflow, agentes com mesmo prefixo podem compartilhar cache; Claude Code atrasa agentes subsequentes em até `CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS` (default 5000ms) para aproveitar o cache já escrito pelo primeiro.

**Fonte:** https://code.claude.com/docs/en/prompt-caching — verificado 2026-09-02. Blog oficial referenciado mas não lido diretamente: "Lessons from building Claude Code: Prompt caching is everything" (claude.com/blog/...).

### Itens não confirmados / lacunas (2.1)

1. Flag exato `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` para eventos de Task/Teammate — só fonte secundária.
2. Subagent "Explore" rodar em Haiku por padrão — só fonte secundária.
3. Blog post "Prompt caching is everything" — não lido diretamente, só referenciado.
4. Schema completo de `settings.json` (`/docs/en/settings-reference`) — não lido diretamente nesta rodada; campos de permissão vieram de páginas cruzadas. **Necessário fetch adicional antes de escrever a SPEC final** (Fase 3).

---

## 2.2 Metodologia de trabalho do agente (o "processo")

Pesquisa feita em 2026-09-02. Fontes primárias privilegiadas onde disponíveis; fontes secundárias marcadas como tal.

### 2.2.1 Spec-Driven Development (SDD) — spec-kit e afins

**Achado:** O projeto de referência é o **GitHub Spec Kit** (`github/spec-kit`), toolkit open-source oficial da GitHub (MIT) para SDD com qualquer agente de IA (Claude Code, Copilot, Gemini CLI, 30+ ferramentas). Workflow real de **6 fases**, não 4: **Constitution** (setup único — princípios inegociáveis referenciados por todos os comandos seguintes) → **Specify** (o quê/porquê) → **Plan** (stack/arquitetura) → **Tasks** (quebra em itens pequenos e testáveis) → **Implement** (execução) → **Converge** (avaliar codebase vs. spec/plan/tasks e repetir Tasks→Implement até convergir). A doc de superfície **não formaliza a spec como gate hard pass/fail entre fases** nem checkpoints humanos bloqueantes explícitos entre comandos — controle humano ocorre via prompts em linguagem natural nas fronteiras, não via gate bloqueante automático.

**Fonte:** https://github.com/github/spec-kit ; https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/ — verificado 2026-09-02. Lançado set/2025, v1.0.0, ~133k stars/12k forks em set/2026.

**Implicação para o template:** START.MD já é mais rigoroso que o spec-kit ao exigir gates humanos bloqueantes (GATE 1/2/3) — manter essa rigidez é uma diferenciação válida, não redundância.

### 2.2.2 EARS (Easy Approach to Requirements Syntax)

**Achado:** Criado por Alistair Mavin e colegas (Rolls-Royce plc), publicado no IEEE RE'09 (2009). 6 padrões oficiais:

1. **Ubiquitous:** `The <system> shall <response>` (sempre ativo, sem keyword)
2. **Event-driven:** `When <trigger>, the <system> shall <response>`
3. **State-driven:** `While <precondition>, the <system> shall <response>`
4. **Optional feature:** `Where <feature included>, the <system> shall <response>`
5. **Unwanted behaviour:** `If <trigger>, then the <system> shall <response>`
6. **Complex:** combina múltiplos keywords, ex. `While <precondition>, when <trigger>, the <system> shall <response>`

**Fonte:** https://alistairmavin.com/ears/ ; https://en.wikipedia.org/wiki/Easy_Approach_to_Requirements_Syntax — verificado 2026-09-02. Há inclusive um issue aberto no spec-kit pedindo integração EARS (https://github.com/github/spec-kit/issues/1356), confirmando relevância atual.

### 2.2.3 Loops de verificação com "ratchet"

**Achado:** Padrão real e ativamente discutido em 2026, mas terminologia fragmentada entre múltiplos autores/blogs independentes (sem um único paper/projeto canônico):

- **Verification Loop** (Encyclopedia of Agentic Coding Patterns): ciclo Change → Test → Inspect → Iterate, com exatamente 3 saídas válidas: (1) sucesso de verificação, (2) limite de tentativas esgotado, (3) escalonamento humano. Generalização do red-green-refactor de Kent Beck para agentes autônomos.
- **Git Checkpoint:** commits deliberados marcam estados "conhecidos-bons" antes/depois de trabalho arriscado; resultado ruim → `git reset --hard HEAD~1`.
- **"Ratchet"** (Addy Osmani, "Agent Harness Engineering", 19/04/2026): o harness "só aperta, nunca afrouxa" — cada erro observado do agente vira salvaguarda permanente (hook/lint/validator) em vez de correção pontual; falhas de teste/type-check/lint são reinjetadas automaticamente no contexto em vez do agente "se declarar pronto"; regras só são removidas quando modelos mais capazes as tornam redundantes.

**Fonte:** https://aipatternbook.com/verification-loop ; https://aipatternbook.com/git-checkpoint ; https://addyosmani.com/blog/agent-harness-engineering/ — verificado 2026-09-02.

**NÃO CONFIRMADO como fonte única:** a formulação exata "ratchet = regressão reverte para último checkpoint git" é uma síntese de 2-3 fontes (Verification Loop + Git Checkpoint + Ratchet de Osmani), não uma citação de fonte única.

### 2.2.4 Ciclo TDD dirigido por agente

**Achado:** Prática amplamente discutida em 2026, com problema estrutural documentado: comportamento _default_ de agentes LLM (incluindo Claude Code) é implementar primeiro e escrever testes que combinam com a implementação depois — alta cobertura, zero confiança real. Solução documentada exige disciplina explícita via CLAUDE.md/hooks: (1) nunca escrever implementação sem teste falho antes; (2) nunca escrever mais implementação do que o teste exige; (3) completar RED→GREEN→REFACTOR inteiro antes da próxima feature; (4) hook pós-edição rodando a suíte automaticamente a cada mudança.

**Fonte:** https://alexop.dev/posts/custom-tdd-workflow-claude-code-vue/ ; https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/main/guide/workflows/tdd-with-claude.md — verificado 2026-09-02.

### 2.2.5 Rounds adversariais pós-GREEN (mutation testing)

**Achado:** Vocabulário dominante é **mutation testing**, não "red-team". Fonte prática: Sławomir Radzymiński, "Mutation Testing for Agent-Written Code" (Awesome Testing, 02/08/2026) — após testes verdes, injetam-se mutações controladas no código de produção; se a suíte permanece verde apesar da mutação ("mutante sobrevive"), expõe teste "errado-mas-passando"; correção é fortalecer a suíte (teste que passa no original e falha no mutante), não o código. Exemplo citado: 100% cobertura de linha com apenas 61,29% de "mutation strength". Trabalho acadêmico paralelo (arXiv 2602.08146, "Test vs Mutant") formaliza **AdverTest**: dois agentes adversariais (mutante vs. teste) em loop bidirecional.

**Fonte:** https://www.awesome-testing.com/2026/08/mutation-testing-for-agent-written-code ; https://arxiv.org/html/2602.08146 — verificado 2026-09-02.

### 2.2.6 RPI (Research → Plan → Implement) e "mise en place"

**Achado:** RPI é metodologia de Dex Horthy (HumanLayer), blog primário de 29/08/2025: 3 fases — **Research** (entender codebase, localizar arquivos, traçar fluxo de informação) → **Plan** (instruções passo-a-passo precisas, arquivos a modificar, abordagem de verificação) → **Implement** (executar fase-a-fase, com "compactação de status" após cada fase verificada). Princípios de preparação de contexto: compactação intencional, manter utilização de context window em **40–60%**, concentrar revisão humana em research/plan (não em code review linha a linha).

Em maio/2026, Andrew Zigler (LinearB) formaliza **"Mise en Place" (MEP)** (arXiv 2605.05400, 06/05/2026) como refinamento do RPI: _contextual grounding_ → _collaborative specification_ → _task decomposition_, exigindo as 3 fases completas antes de qualquer implementação.

**Nota:** o próprio Horthy evoluiu o RPI para um framework de 7 estágios chamado **CRISPY**, após identificar problemas de adoção do RPI original (planos complexos demais, "magic words" em prompts, engenheiros não lendo código gerado).

**Fonte:** https://www.humanlayer.dev/blog/advanced-context-engineering ; https://arxiv.org/html/2605.05400 ; https://www.zenml.io/llmops-database/evolving-ai-coding-agent-workflows-from-research-plan-implement-to-crispy — verificado 2026-09-02.

### 2.2.7 Context engineering, Tool Search, orçamento de tokens

**Achado:** Fonte canônica: Anthropic, "Effective context engineering for AI agents" (29/09/2025). Context engineering = curar o conjunto ótimo de tokens durante inferência (distinto de prompt engineering). Diretriz: menor conjunto possível de tokens de alto sinal; tools mínimas e não-sobrepostas; **recuperação just-in-time** (identificadores leves — caminhos de arquivo, queries, links — em vez de pré-carregar dados). O artigo **não especifica orçamentos de token diferenciados por classe de agente** — não confirmado nesta fonte.

**Tool Search:** Anthropic, "Introducing advanced tool use on the Claude Developer Platform" (24/11/2025) — Tool Search Tool: tools com `defer_loading: true` ficam fora do prompt inicial; Claude busca e só então a definição completa entra no contexto. Números concretos: setup de 5 servidores MCP que consumiria ~55K tokens cai para **~8,7K tokens (95% de preservação de contexto)**; ganho de acurácia em avaliações MCP: Opus 4 de 49%→74%, Opus 4.5 de 79,5%→88,1% com Tool Search ativado.

**Fonte:** https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents ; https://www.anthropic.com/engineering/advanced-tool-use — verificado 2026-09-02.

**NÃO CONFIRMADO:** orçamento de tokens por classe/tipo de agente — não encontrado em fonte primária Anthropic; se o SPEC precisar disso, será decisão de design própria do projeto, não prática documentada pela Anthropic.

---

## 2.3 Stack frontend do estado da arte (o "o quê") — versões confirmadas em set/2026

Todas as versões abaixo confirmadas via NPM Registry (`registry.npmjs.org/<pkg>/latest`, consultado 2026-09-02, autoritativo) e cruzadas com changelogs/blogs oficiais.

### Core UI

- **React 19.2.8** — major continua 19.x; não há React 20 no npm (menções a "React 20 Compiler" em blogs são especulativas/clickbait, **não confirmadas**). Fonte: https://registry.npmjs.org/react ; https://react.dev/versions.
- **React Compiler 1.0.0** (`babel-plugin-react-compiler`) — **estável desde 07/10/2025**, não mais experimental. Fonte: https://react.dev/blog/2025/10/07/react-compiler-1.
- **Alternativa Vue:** 3.5.x estável; 3.6 em RC (3.6.0-rc.3, 11/08/2026) — **PARCIALMENTE NÃO CONFIRMADO** que 3.6 já é GA (blogs terceiros dizem "stable", changelog oficial do GitHub ainda mostrava RCs). Checar `github.com/vuejs/core/releases` antes de fixar no SPEC.
- **Alternativa Svelte:** 5.56.6 (major 5, sem VDOM).

### Build/Dev

- **Vite 8.2.2** (GA 12/03/2026) — unifica dev+build sob **Rolldown** por padrão. Fonte: https://vite.dev/blog/announcing-vite8.
- **Rolldown 1.0** estável desde maio/2026, bundler padrão do Vite 8, API semver congelada. Fonte: https://voidzero.dev/posts/announcing-rolldown-1-0.
- **"Vite+"** — beta desde 02/07/2026 (toolchain unificado: runtime+package manager+Vite/Vitest/Oxlint/Oxfmt/Rolldown/tsdown). **Risco de governança a monitorar:** VoidZero (empresa de Evan You por trás de Vite/Vitest/Rolldown/Oxc/Vite+) foi **adquirida pelo Cloudflare em 04/06/2026**. Não recomendado como default de produção agora — item "watch". Fonte: https://voidzero.dev/posts/announcing-vite-plus-beta ; https://siliconangle.com/2026/06/04/cloudflare-acquires-voidzero-maker-vite-javascript-toolchain/.
- **Oxlint v1.60.0** — estável, seguro para adotar como padrão hoje (drop-in, ordens de magnitude mais rápido que ESLint).
- **Oxfmt v0.45.0** — ainda **beta** (desde 24/02/2026), depende de Prettier para linguagens não suportadas nativamente; meta de paridade total é Q3/2026. **Recomendação: Oxlint + Prettier** (não Oxfmt ainda) como combinação segura em set/2026, com Oxfmt como "watch item". Fonte: https://oxc.rs/blog/2026-02-24-oxfmt-beta.

### Roteamento

- **TanStack Router 1.170.32** (`@tanstack/react-router`) — file-based, type-safe confirmado. Validação de search params: **Zod ≥3.24 e Arktype implementam Standard Schema nativamente, sem adapter dedicado**; `@tanstack/zod-adapter` continua existindo para Zod <3.24. Fonte: https://tanstack.com/router/latest/docs/framework/react/how-to/validate-search-params.

### Estado

- **TanStack Query 5.102.8** — hooks Suspense dedicados (`useSuspenseQuery` etc., substituindo a flag `suspense: true`); optimistic updates via `variables` de `useMutation`.
- **Zustand 5.0.15** — estado de cliente leve; Context do React recomendado para updates de baixa frequência (tema/i18n), Zustand para estado lido por muitos componentes/alta frequência.

### Validação/Contratos

- **Zod 4.5.4** — major 4 é o export padrão do pacote root desde maio/2025 (mais rápido, mais eficiente em `tsc`, API mais enxuta que Zod 3).
- **Arktype 2.2.3** — sintaxe "TypeScript-like", performance de validação superior em benchmarks próprios, implementa Standard Schema (interopera com TanStack sem adapter); ecossistema de integração menor que Zod.
- **Orval 8.27.0** — gera hooks React Query/SWR/Axios + validação Zod + mocks a partir de OpenAPI. Alternativas: **openapi-typescript** (só tipos, zero runtime deps, "gold standard" para controle total), **Kubb** (arquitetura modular via plugins, recomendado para times grandes), **Hey API** (intermediário). Recomendação de mercado: começar com openapi-typescript, migrar para Orval quando integração TanStack Query for prioridade.

### Estilo/UI

- **Tailwind CSS 4.3.3** — config CSS-first via `@theme` confirmado (sem `tailwind.config.js`); **OKLCH confirmado como formato de cor padrão** (paleta built-in usa OKLCH; requer Safari 16.4+/Chrome 111+/Firefox 128+); motor Oxide (Rust).
- **shadcn/ui CLI 4.20.1** — **mudança arquitetural relevante:** desde fev/2026 suporta oficialmente **Base UI** como alternativa a Radix; desde **jul/2026, Base UI é o padrão para novos projetos** no shadcn/ui (Radix não descontinuado, segue mantido para projetos existentes). Fonte: https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default.
- **Radix UI** (ex. `@radix-ui/react-dialog` 1.1.23) — segue mantido, não deprecado. Base UI é projeto separado (não rename), iniciado 2024 por ex-engenheiros Radix/MUI/Floating UI, 1.0 estável desde dez/2025, mantido pela equipe MUI. **Recomendação para o SPEC: Base UI como opção default recomendada para projetos novos, Radix como alternativa trocável/legado.**

### Testes

- **Vitest 4.1.11**, **@testing-library/react 16.3.3**, **@playwright/test 1.62.1**, **axe-core 4.13.0**.
- **MSW 2.15.0** — confirmado como padrão de mercado ("industry standard") em set/2026, ~5M downloads/semana, intercepta no nível de rede.
- **Storybook 10.6.0** — continua dominante (~2,5M downloads/semana), integração nativa com Vitest para tornar stories testáveis automaticamente. **Ladle** é alternativa leve recomendada para libs React puras pequenas/médias; **Histoire** para Vue/Svelte. Nenhuma alternativa destronou Storybook como default, mas ambas são opções válidas de troca no preset.

### Observabilidade

- **Sentry** (`@sentry/react` 10.73.0) — session replay integrado nativamente desde v7.27.0 do SDK, mascara texto/imagens/inputs por padrão.

### Gerenciador de pacotes

- **pnpm 11.25.0** — catalogs confirmado (desde pnpm 9.5): versões de dependências como constantes reutilizáveis em `pnpm-workspace.yaml`, referenciadas via `catalog:`; 3 modos (`strict`/`prefer`/`manual`, default `manual`); protocolo removido automaticamente em `publish`/`pack`.

### Itens não confirmados / cautela (2.3)

1. **Vue 3.6 GA** — fontes conflitam, checar `github.com/vuejs/core/releases` antes de fixar no SPEC.
2. **"React 20 Compiler"** — boato/clickbait, não confirmado por fonte oficial, não citar no SPEC.
3. **Oxfmt** — beta, não estável, não usar como default ainda.
4. **"Vite+"** — beta + incerteza de governança pós-aquisição Cloudflare — mencionar como risco a monitorar, não adotar como toolchain default agora.

---

## 2.4 Referências vivas (spec-kit, OpenSpec, BMAD, Spec-Flow, ralph-loop/typed-loop, kits forge/init)

Pesquisa em 2026-09-02.

### spec-kit (GitHub Spec Kit)

Ver §2.2.1. **Padrões a reaproveitar:** fase "constitution" antes de tudo; specs/plan/tasks/implement como artefatos versionáveis em disco (não só conversa); suporte multi-agente desde o design (reduz lock-in); fase final "converge" que fecha o loop contra a spec original. **Evitar:** superfície de comandos grande (6+ obrigatórios) pode gerar overhead cerimonial num template pequeno; projeto genérico não embute opinião de FrontEnd.

### OpenSpec

**Fonte:** https://github.com/Fission-AI/OpenSpec ; https://openspec.dev/ — ~67,1k stars, ativo. Filosofia "fluid not rigid, iterative not waterfall, easy not complex". Estrutura `openspec/specs/` (verdade atual) vs `openspec/changes/` (propostas: `proposal.md`, `specs/`, `design.md`, `tasks.md`); gera `AGENTS.md` de hand-off automaticamente. **Reaproveitar:** separação specs/ (estado atual) vs changes/ (proposta) como "diff" explícito de intenção antes de codar; geração automática de `AGENTS.md` central. **Evitar:** depende de markdown solto sem verificação determinística de conformidade — risco de "spec drift"; fragmentação de ecossistema (múltiplos forks não-oficiais).

### BMAD-METHOD

**Fonte:** https://github.com/bmad-code-org/BMAD-METHOD — 52,6k stars, ativo. Framework agile com ~12-21 agentes-persona (PM, Architect, UX, Dev, Scrum Master) colaborando; ciclo Clarify → Plan → Build & Verify → Learn & Adjust (loop de volta a Plan). **Reaproveitar:** "scale-adaptive intelligence" (profundidade de planejamento ajustada ao tamanho da mudança); multi-persona explícito é reaproveitável para subagents especializados (ex.: "a11y reviewer"); loop de retroalimentação Learn→Plan. **Evitar (armadilha clara de over-engineering):** 19-21 agentes + 50+ workflows é pesado demais para um template de repositório; dependência de múltiplos runtimes (Node 20.12+, Python 3.10+, uv); múltiplos módulos-produto fora de escopo (Game Dev Studio etc.) — sinal de mission creep.

### Spec-Flow

**Fonte:** https://github.com/marcusgoll/Spec-Flow — projeto pequeno (91 stars, mantenedor único), específico para Claude Code. Pipeline `spec.md`→`plan.md`→`tasks.md` (20-30 tarefas TDD)→implementação→quality gates paralelos (performance, security, a11y, cobertura)→deploy. Diferenciação por tamanho: `/quick` (<30min), `/feature`, `/epic` (>16h). **Reaproveitar:** diferenciação de fluxo por tamanho/risco da tarefa; quality gates paralelos com **acessibilidade já embutida como categoria** — diretamente relevante para o template FrontEnd; não adiciona dependência ao `package.json`. **Evitar:** baixa tração, tratar como fonte de ideias de formato, não autoridade de mercado.

### Ralph Loop / Ralph Wiggum Technique

**Fonte:** https://github.com/ghuntley/how-to-ralph-wiggum (origem: Geoffrey Huntley, mai/2025) — 1,7k stars, ativo. Técnica minimalista: `while :; do cat PROMPT.md | claude; done` — agente lê prompt, executa, atualiza plano em disco, commita, sai; loop reinicia com contexto limpo relendo o plano persistido (`IMPLEMENTATION_PLAN.md`). **Reaproveitar:** estado persistido em disco como única memória entre execuções isoladas (desacopla estado do projeto da janela de contexto); backpressure via testes/build bloqueando commit; uso de subagentes para tarefas caras mantendo orquestrador enxuto. **Evitar — riscos graves documentados pelo próprio autor:** uso de `--dangerously-skip-permissions` para loop não supervisionado é citado como risco de segurança sério ("it's not if it gets popped, it's when") — requer sandboxing/Docker/chaves de API restritas; falta de gate de verificação tipado (só heurísticas + intervenção humana via Ctrl+C/`git reset --hard`); sem review/aprovação humana estruturada — adequado para prototipagem, arriscado para produção sem adaptação.

### "typed-loop"

**NÃO ENCONTRADO** como projeto nomeado literalmente (buscas específicas não retornaram um repo/padrão com esse nome exato). O termo mais próximo é **looper** (https://github.com/ksimback/looper, 708 stars, ativo): skill do Claude Code que projeta loops de agente com **"typed verification"** — critérios tipados como `programmatic` (comando pass/fail), `judge` (outro modelo avalia contra rubrica) ou `human` (sign-off manual); fluxo Goal→Plan→Review→Deliver→Judge→Stop, com "council" de modelo diferente da família host para evitar pontos cegos correlacionados. **Reaproveitar:** tipagem explícita de critério de verificação (programmatic/judge/human) é padrão de design excelente, força decidir _como_ cada gate do template será verificado. **Evitar:** conceito nichado (single-maintainer), tratar como inspiração, não padrão de indústria.

### Kits "forge"/"init" para Claude Code

Três candidatos avaliados:

- **claudeforge/Forge** (11 stars, baixa tração): usa stop hooks do Claude Code para bloquear término até critérios de conclusão passarem — padrão determinístico forte, mas requer "Control Center" servidor web separado (acoplamento desnecessário) e adoção baixíssima.
- **peterkrueck/Claude-Code-Development-Kit** (1,4k stars): não é SDD, é camada de manutenção de contexto — 4 arquivos fixos (`spec.md`, `project-structure.md`, `progress.md`, `deployment-infrastructure.md`) sincronizados por automação, atacando o problema de "CLAUDE.md decai em poucas sessões". **Reaproveitar:** diagnóstico de decadência de contexto entre sessões + padrão de arquivos de contexto atualizados automaticamente (não manualmente).
- **sangrokjung/claude-forge** (822 stars, v4.2.0, set/2026, ativo e sério): "oh-my-zsh para Claude Code" — 16 agentes especialistas (incl. **adversarial-reviewer**), 35 comandos, 33 skills, 22+9 hooks em "6-layer security defense" (filtro de secrets, bloqueio de `curl|sh`, bloqueio de SQL destrutivo). **Reaproveitar:** arquitetura symlink+git pull para updates instantâneos; "adversarial reviewer" como agente dedicado (revisão hostil separada da normal); checklist concreto de guard-rails de segurança em hooks. **Evitar:** 16 agentes+35 comandos+33 skills é over-engineering para extrair 1:1 — curar subconjunto mínimo.

### Síntese crítica (para Fase 2/3)

**Padrões recorrentes validados por múltiplos projetos (safe bets):** (1) spec→plan→tasks→implement→verify como arquivos versionados em disco; (2) fase "constitution"/princípios fixada antes de specs; (3) gates tipados por tipo de verificação (determinístico vs julgamento de modelo vs humano); (4) diferenciação de fluxo por tamanho/risco (quick/feature/epic); (5) estado persistido em markdown como memória entre sessões; (6) hooks bloqueando saída até gate passar (determinismo real).

**Armadilhas a evitar deliberadamente:** (1) explosão de agentes/comandos/skills (BMAD, claude-forge) sem necessidade real; (2) acoplamento a toolchains/infra extra (dashboards, múltiplos runtimes); (3) loops autônomos tipo Ralph sem sandboxing e sem gate tipado; (4) tratar projetos de baixa tração (Spec-Flow, Forge) como padrão de indústria — usar como fonte de ideias de formato, não autoridade.

---

## 2.5 Compatibilidade GitHub Copilot (adicionado após feedback do usuário — o template deve funcionar com Claude Code E GitHub Copilot)

Pesquisa em 2026-09-02, complementar à §2.1. Objetivo: mapear cada superfície do Claude Code para o equivalente atual do Copilot.

### Achados por item

1. **Arquivo de instruções raiz:** `.github/copilot-instructions.md` continua padrão; há também instruções path-specific via `.github/instructions/*.instructions.md` com `applyTo` (glob). Fonte: https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot — verificado 2026-09-02.

2. **AGENTS.md — ponto de convergência forte:** Copilot coding agent suporta `AGENTS.md` na raiz (e aninhado por subdiretório) desde ago/2025; Copilot code review também (jun/2026). **Achado-chave confirmado na doc oficial:** como alternativa ao AGENTS.md, o Copilot lê diretamente um único `CLAUDE.md` (ou `GEMINI.md`) na raiz do repo — citação direta da doc: _"Alternatively, you can use a single CLAUDE.md or GEMINI.md"_. Fonte: https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot — verificado 2026-09-02. **NÃO CONFIRMADO:** se isso é 100% consistente entre VS Code Chat, CLI e coding agent (há relato de comunidade de inconsistência).

3. **Prompt files:** `.github/prompts/*.prompt.md`, invocados via `/nome` — equivalente funcional mais próximo dos slash-commands. Disponível em VS Code/Visual Studio/JetBrains; **NÃO CONFIRMADO** suporte em Copilot CLI/coding agent. Fonte: https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file.

4. **Custom agents (ex-"chat modes") — segundo ponto de convergência forte:** `.chatmode.md` foi **renomeado para `.agent.md`** (~01/11/2025), agora em `.github/agents/`. Frontmatter configura tools, instruções, modelo (com fallback), MCP servers, handoffs e subagentes. **Achado-chave:** VS Code também lê agentes no formato **`.claude/agents/`** diretamente, rotulado "Workspace (Claude format)" — ou seja, o mesmo diretório de subagents do Claude Code é lido nativamente pelo Copilot no VS Code. Nesting de subagentes não tem profundidade configurável documentada (não re-geram subagentes por padrão). Fonte: https://code.visualstudio.com/docs/agent-customization/custom-agents — verificado 2026-09-02.

5. **Hooks — mapeamento parcial mas real:** Copilot tem hooks nativos com 8 eventos (`sessionStart`, `sessionEnd`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `agentStop`, `subagentStop`, `errorOccurred`) — nomenclatura muito próxima do Claude Code. `preToolUse` retorna `allow`/`deny`/`ask` de forma determinística, mesmo padrão de enforcement. Config: `.github/hooks/*.json` (repo) ou `~/.copilot/hooks/*.json` (pessoal, CLI). **Confirmado apenas para Copilot CLI e coding agent (cloud).** **NÃO CONFIRMADO** se a extensão VS Code (superfície mais usada por devs FrontEnd) suporta hooks — doc oficial não lista, e há issues de comunidade relatando `preToolUse` não confiável dentro de subagentes (`github/copilot-cli#2392`). Fonte: https://docs.github.com/en/copilot/concepts/agents/hooks — verificado 2026-09-02.

6. **MCP:** suporte maduro, porém fragmentado por local/chave — `.vscode/mcp.json` (chave raiz `"servers"`, não `"mcpServers"`), `.github/mcp.json` (Copilot CLI, por repo), `~/.copilot/mcp-config.json` (pessoal). O Agent Host da CLI **não lê `.vscode/mcp.json` diretamente**. Fonte: https://code.visualstudio.com/docs/agent-customization/mcp-servers ; https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers — verificado 2026-09-02.

7. **Copilot coding agent (autônomo/PRs):** roda em container GitHub Actions isolado; ambiente customizável via `.github/workflows/copilot-setup-steps.yml`; lê `copilot-instructions.md`/`AGENTS.md`/`.instructions.md`; abre PR draft; quem atribui a task não pode aprovar o PR/CI. Tem `plan_mode` mencionado, mas granularidade de fases supervisionadas **NÃO ESTÁ CLARAMENTE DOCUMENTADA** (só fonte secundária). Fonte: https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent — verificado 2026-09-02.

8. **Permissões/settings:** fragmentado, sem equivalente unificado ao `settings.json` — `copilot/managed-settings.json` (org), content-exclusion via API REST, permission picker de UI/CLI, hooks em arquivo JSON separado. Fonte: https://docs.github.com/en/copilot/how-tos/configure-content-exclusion/exclude-content-from-copilot — verificado 2026-09-02.

### Síntese comparativa (Claude Code → Copilot)

| Claude Code                                        | Copilot                                                                                                                     | Mapeamento                                                                                                                                                                    |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CLAUDE.md`                                        | Lido diretamente como alternativa a `AGENTS.md`/`copilot-instructions.md`                                                   | **Quase 1:1 — convergência real, sem duplicar arquivo**                                                                                                                       |
| Skills (`SKILL.md`)                                | Sem equivalente nativo (prompt files cobrem só "comando", não "capacidade sob demanda com progressive disclosure")          | **Sem equivalente — fica Claude-Code-específico**                                                                                                                             |
| Commands (`.claude/skills/*` com `user-invocable`) | `.github/prompts/*.prompt.md`                                                                                               | **Adapter fino necessário** (frontmatter distinto, só VS Code/VS/JetBrains confirmado)                                                                                        |
| Subagents (`.claude/agents/*.md`)                  | `.github/agents/*.agent.md`, mas VS Code também lê `.claude/agents/` nativamente                                            | **Convergência forte — mesmo diretório reaproveitável**                                                                                                                       |
| Hooks (20+ eventos, Stop com cap 8)                | Hooks nativos (8 eventos, mesmo padrão allow/deny/ask) — confirmado só CLI/coding agent, não confirmado na extensão VS Code | **Mapeamento parcial — gerar `.github/hooks/*.json` a partir da mesma definição lógica; CI/git hooks (husky/lefthook) como fallback universal onde hooks nativos não cobrem** |
| `settings.json`                                    | Fragmentado (managed-settings.json, content-exclusion API, permission picker, hooks separados)                              | **Sem equivalente unificado — adapter necessário**                                                                                                                            |

### Decisão de arquitetura decorrente (registrada em `docs/DECISIONS.md`)

A pesquisa confirma que a abordagem escolhida pelo usuário — **núcleo agnóstico de agente (specs/, `scripts/verify.sh`, metodologia SDD) + adapters finos por agente** — é viável e tem 2 pontos de convergência real (não apenas adapter): `CLAUDE.md` como arquivo único lido por ambos, e `.claude/agents/*.md` como diretório de subagents lido nativamente pelo Copilot no VS Code. O gate determinístico "duro" (equivalente ao Stop hook) não pode depender só de hooks nativos do Copilot porque a cobertura na extensão VS Code não está confirmada — por isso `scripts/verify.sh` rodando via CI (GitHub Actions) + git hooks tradicionais (husky/lefthook) precisa ser a fonte de verdade universal, com os hooks nativos de cada agente (Claude Code `Stop`, Copilot `preToolUse`/`agentStop`) como otimização de feedback rápido dentro da sessão, não como gate final.

---

## Nota de segurança sobre esta pesquisa

O agente que pesquisou §2.4 (Ralph Loop) reportou que seu próprio texto de resultado, ao citar a flag `--dangerously-skip-permissions` do Ralph Loop, foi automaticamente sinalizado pelo harness como "padrão instruction-shaped" e neutralizado antes de chegar aqui. Isso é comportamento esperado do harness (a citação é conteúdo de pesquisa legítimo sobre um risco documentado pela própria comunidade Ralph Loop, não uma instrução direcionada a este agente) — nenhuma ação corretiva é necessária, mas registro aqui por transparência.
