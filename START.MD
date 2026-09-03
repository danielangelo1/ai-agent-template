# BUILD_FRONTEND_AGENT_TEMPLATE.md

> **O que é este arquivo.** Este é um *meta-prompt* para o Claude Code. Ele **não** te manda escrever código ainda. Ele te manda **(1) pesquisar**, **(2) pensar** e **(3) escrever uma SPEC completa** que, num segundo passo, será usada para gerar um **repositório-template de AI Agent para desenvolvimento FrontEnd**.
>
> Trate este documento como uma ordem de serviço. Execute as fases na ordem. Não pule os *gates* de aprovação humana.

---

## 0. Missão

Produzir um **repositório-template genérico, clonável e customizável** que transforma o Claude Code (e qualquer runner compatível com o Claude Agent SDK) num **agente de engenharia frontend robusto**. O template é o produto; projetos concretos serão criados a partir dele por `git clone` + customização.

O agente resultante deve otimizar simultaneamente para:

1. **Eficiência** — menos idas e vindas, menos retrabalho, execução paralela quando fizer sentido.
2. **Qualidade de entrega** — código que passa em lint, types, testes, a11y e build antes de ser dado como pronto.
3. **Testabilidade** — TDD-first, com *gates* determinísticos que o agente não consegue burlar declarando "terminei".
4. **Economia de tokens** — context engineering agressivo: contexto pequeno e de alto sinal, delegação a subagents com janelas isoladas, *skills* carregadas sob demanda.

**Princípio-mestre:** *a configuração é o fosso, não o prompt.* O valor está no harness (memória enxuta, política de permissões, biblioteca de skills, hooks que impõem os inegociáveis, subagents bem escopados), não em prompts longos.

---

## 1. Regras de execução (leia antes de tudo)

- **Pense de verdade antes de agir.** Use *extended thinking* nas fases de pesquisa e arquitetura. É esperado que você gaste tempo aqui. Não comece a criar arquivos antes de terminar a Fase 3.
- **Pesquise o estado da arte de setembro de 2026.** Seu conhecimento pode estar desatualizado. Trate versões de bibliotecas, nomes de ferramentas e APIs do Claude Code como coisas a **verificar**, não a lembrar.
- **Separe pesquisa/plano de implementação.** É a forma nº1 de evitar "resolver o problema errado com código correto".
- **Nada de suposições silenciosas.** Onde houver decisão em aberto, registre-a explicitamente em `docs/DECISIONS.md` como um ADR curto.
- **Mostre evidência, não afirmação.** Ao concluir cada fase, mostre o comando rodado e sua saída, não um "está funcionando".
- **Genérico > específico.** Nada de acoplar o template a um domínio de negócio. Tudo que for opinativo deve ser um *default* trocável, documentado como tal.

---

## 2. FASE 1 — Pesquisa (com thinking)

Antes de projetar qualquer coisa, faça varredura da realidade atual. Faça buscas reais na web e leia as fontes primárias. **Não confie em memória** para versões e APIs.

Investigue e anote descobertas em `research/FINDINGS.md` (crie a pasta):

### 2.1 Harness do Claude Code / Agent SDK (o "como" do agente)
- Superfícies oficiais atuais e o que cada uma deve possuir: **CLAUDE.md** (guia sempre-ativo, curto), **Skills** (expertise carregada sob demanda), **Hooks** (enforcement determinístico em eventos de ciclo de vida), **Subagents** (instâncias forkadas com contexto isolado), **Commands/Slash-commands**, **settings.json** (permissões).
- Eventos de hook disponíveis e o que cada um permite: `PreToolUse` (pode bloquear/`defer`), `PostToolUse`, `Stop`, `SubagentStop`, `TaskCompleted`, e afins. Confirme a lista atual e a semântica de retorno (`allow`/`deny`/`defer`).
- Mecânica do **Stop hook como gate determinístico** (bloqueia o fim do turno até um script passar) e o limite de bloqueios consecutivos antes de o Claude Code encerrar mesmo assim. Confirme o número atual.
- **Subagents:** frontmatter (`name`, `description`, `tools`, `model`, `skills`), seleção de modelo por subagent (evitar herança de modelo cara), profundidade de aninhamento suportada e por que **capar profundidade e escopo** é obrigatório.
- Padrão **verificador independente**: um subagent/modelo "fresco" que tenta *refutar* o resultado, para que quem faz não seja quem corrige a própria prova.
- **Plan Mode** e a separação exploração → plano → implementação.
- Roteamento de modelo (fork para *breadth*, inline para *depth*): quando delegar e quando **não** delegar.
- **Prompt caching / cache hit rate** e como a estrutura de contexto afeta custo por tarefa.

### 2.2 Metodologia de trabalho do agente (o "processo")
- **Spec-Driven Development (SDD):** spec como contrato executável / gate de validação, não doc para humano. Fases típicas: Specify → Plan → Tasks → Implement, cada uma com checkpoint humano.
- Notação de requisitos legível por máquina (ex.: **EARS**) para tornar critérios de aceite não-ambíguos.
- **Loops de verificação com ratchet:** o agente não pode encerrar declarando sucesso; os únicos "saídas" são o verificador sair `0`, atingir um limite, ou handoff para humano. Regressão (contagem de falhas sobe) reverte para o último checkpoint bom.
- **Ciclo TDD dirigido por agente:** escrever teste que falha (RED) → implementar → teste passa (GREEN) → commit. O teste é o gate automatizado.
- **Rounds adversariais / red-team** opcionais após GREEN: achar um caso "errado-mas-passando", adicionar checagem que falha, corrigir.
- **RPI (Research → Plan → Implement)** e disciplinas de "mise en place" (preparação deliberada de contexto).
- **Context engineering:** currar o conjunto mínimo de tokens de alto sinal; **Tool Search** para expor a cauda longa de ferramentas sem poluir o contexto; orçamento de tokens e alertas por classe de agente.

### 2.3 Stack frontend do estado da arte (o "o quê") — confirme versões atuais
Levante as versões **vigentes em set/2026** e trade-offs de cada camada. O template deve tratar a stack como **preset default trocável**, não como dogma. Investigue pelo menos:

- **Core UI:** React (confirme a major atual e status do React Compiler), e um preset alternativo (ex.: Vue/Svelte) mencionado como troca possível.
- **Build/dev:** Vite (confirme major atual; investigue Rolldown e o toolchain "Vite+"), e o par lint/format em Rust (**Oxlint/Oxfmt**) vs ESLint/Prettier.
- **Roteamento:** TanStack Router (file-based, type-safe, validação de search params via adapter Zod/Arktype).
- **Estado de servidor:** TanStack Query (Suspense, optimistic updates). **Estado de cliente:** Zustand + Context para UI global.
- **Validação/contratos:** Zod ou Arktype em toda fronteira de confiança; geração de client a partir de OpenAPI (ex.: Orval) quando houver API.
- **Estilo/UI:** Tailwind (confirme major atual, config CSS-first `@theme`, OKLCH) + biblioteca de componentes acessível (shadcn/ui, Radix).
- **Testes:** Vitest (unit/componente + RTL), Playwright (E2E de fluxos críticos), **MSW** para mock de rede, **axe-core** para a11y, e teste de regressão visual via Storybook.
- **Observabilidade de erro:** Sentry (erros + session replay) como opção.
- **Gerenciador de pacotes:** pnpm (catalogs/workspaces).

Para **cada** ferramenta, registre em `research/FINDINGS.md`: versão confirmada, fonte/URL, e uma linha de "por que está aqui (ou por que é opcional)".

### 2.4 Referências vivas a estudar
Procure e avalie criticamente projetos análogos (spec-kit, OpenSpec, BMAD, Spec-Flow, ralph-loop / typed-loop, kits "forge"/"init" de Claude Code). Extraia padrões bons; **não copie** cegamente. Anote o que reaproveitar e o que evitar.

> **GATE 1 (humano).** Ao fim da Fase 1, apresente um resumo de 1 página de `research/FINDINGS.md` com as versões confirmadas e as 5 decisões arquiteturais mais importantes em aberto. **Pare e peça aprovação** antes de projetar.

---

## 3. FASE 2 — Arquitetura do agente (com thinking, sem código ainda)

Com a pesquisa aprovada, projete o harness. Produza `docs/AGENT_ARCHITECTURE.md` descrevendo:

### 3.1 Modelo de papéis (subagents)
Defina um roster enxuto de subagents, cada um com contexto isolado, `tools` mínimas e `model` explícito (para não herdar modelo caro). Sugestão de ponto de partida — **ajuste conforme a pesquisa**:

- **`planner`** — lê a spec, produz plano e a lista de tasks (EARS). Sem escrita de código.
- **`implementer`** — executa uma task por vez, TDD-first.
- **`test-author`** — escreve os testes que falham antes da implementação.
- **`reviewer`** — verificador **independente**; tenta refutar o resultado (qualidade, segurança, a11y, contrato).
- **`a11y-auditor`** — roda axe-core e valida critérios de acessibilidade.
- **`refactorer`** — melhora sem mudar comportamento, sob proteção dos testes.

Para cada papel: quando é *spawnado*, o que **não** pode fazer, e qual gate valida seu retorno. Defina **profundidade máxima de aninhamento** e orçamento de tokens por nível.

### 3.2 Gates determinísticos (hooks)
Especifique os hooks que impõem os inegociáveis — coisas que o modelo **não pode alucinar para fora de existência**:

- `PreToolUse`: bloquear escrita fora do repositório; bloquear comandos destrutivos (`rm -rf`, force-push); redigir segredos em qualquer shell; recusar `dangerouslySetInnerHTML` sem sanitização.
- `PostToolUse`: rodar formatter após cada edição de arquivo.
- `Stop` / `SubagentStop` / `TaskCompleted`: **o gate verde**. Rodar a pirâmide de verificação (typecheck → lint → unit → e2e crítico → build → a11y) e **bloquear o fim do turno** enquanto falhar. Implementar **ratchet**: contagem de falhas é medida decrescente; regressão reverte ao último checkpoint bom (git).

Deixe claro na spec: **não existe string mágica de "pronto"**; as únicas saídas do loop são verify `0`, limite atingido, ou handoff humano.

### 3.3 Skills (expertise sob demanda)
Liste as skills que serão empacotadas (cada uma = pasta com `SKILL.md`), carregadas só quando a task casar, para economizar contexto. Ex.: `component-conventions`, `tanstack-query-patterns`, `tailwind-v4-theme`, `testing-rtl-msw`, `a11y-checklist`, `forms-validation`, `error-handling`. Cada skill deve declarar quando é relevante.

### 3.4 Comandos / workflows
Defina slash-commands que encadeiam o pipeline gatilhado: ex. `/spec`, `/plan`, `/tasks`, `/implement`, `/tdd`, `/review`, `/ship` — um pipeline gatilhado de ponta a ponta com checkpoints.

### 3.5 Orçamento de tokens e observabilidade
Defina métricas a instrumentar (custo por task, cache hit rate, eventos de compactação, tool-call count por task) e onde registrá-las. Defina limites e o que acontece ao estourar.

### 3.6 CLAUDE.md enxuto
Especifique o conteúdo do `CLAUDE.md` do template: curto, alto-sinal, apontando para skills/commands em vez de despejar tudo inline. Inclua a política de `/compact` (o que preservar ao compactar).

> **GATE 2 (humano).** Apresente `docs/AGENT_ARCHITECTURE.md` e o diagrama do pipeline. **Pare e peça aprovação** antes de escrever a SPEC final.

---

## 4. FASE 3 — Escreva a SPEC (o entregável desta ordem de serviço)

Agora produza o artefato central: **`SPEC.md`** na raiz. Esta spec é o **contrato executável** a partir do qual o repositório-template será gerado num passo posterior. Ela precisa ser autossuficiente: alguém (ou você mesmo, numa sessão limpa) deve conseguir gerar o template inteiro só a partir dela.

`SPEC.md` **deve** conter, no mínimo:

1. **Visão & não-objetivos.** O que o template é e o que explicitamente não é.
2. **Preset de stack default** (com versões confirmadas na Fase 1) e **como trocar** cada camada.
3. **Estrutura de diretórios completa** do template, anotada. Ponto de partida a refinar:

   ```
   .
   ├── .claude/
   │   ├── agents/            # subagents (um .md por papel, com frontmatter)
   │   ├── commands/          # slash-commands do pipeline
   │   ├── skills/            # skills empacotadas (pasta + SKILL.md cada)
   │   ├── hooks/             # scripts de hook (verify.sh, guard.sh, ratchet.sh...)
   │   └── settings.json      # permissões + registro de hooks
   ├── CLAUDE.md              # memória enxuta do projeto
   ├── SPEC.md                # este contrato
   ├── specs/                 # specs de feature (SDD) + template EARS
   ├── docs/
   │   ├── AGENT_ARCHITECTURE.md
   │   ├── DECISIONS.md       # ADRs
   │   ├── CUSTOMIZING.md     # como clonar e adaptar
   │   └── TOKEN_BUDGET.md
   ├── research/FINDINGS.md
   ├── src/                   # app de exemplo mínima (prova viva do harness)
   ├── tests/                 # unit + e2e de exemplo
   ├── scripts/verify.sh      # a pirâmide de verificação, chamável por humano e por hook
   ├── .github/workflows/     # CI que roda o mesmo verify.sh (paridade local/CI)
   ├── package.json
   └── README.md
   ```

4. **Definição de cada subagent** — frontmatter completo e prompt de sistema, com `tools` mínimas e `model` explícito.
5. **Definição de cada hook** — evento, gatilho, comando, semântica de retorno, e o comportamento de ratchet.
6. **A pirâmide de verificação (`scripts/verify.sh`)** — ordem exata de checagens, critério de RED/GREEN, códigos de saída. Deve ser a **mesma** fonte de verdade usada pelo Stop hook e pela CI.
7. **Fluxo SDD ponta a ponta** — do `/spec` ao `/ship`, com os checkpoints humanos e os gates automáticos marcados.
8. **Contrato de testabilidade** — o que conta como "coberto"; papéis de Vitest/RTL/Playwright/MSW/axe; regra de que features críticas exigem spec de teste.
9. **Estratégia de economia de tokens** — regras concretas: contexto mínimo por subagent, skills sob demanda, Tool Search para a cauda longa, política de compactação, orçamento e alertas.
10. **Guia de customização** — passos para clonar, trocar a stack, adicionar skills/subagents, e adaptar os gates. O template tem que ser **genérico**.
11. **Critérios de aceite do próprio template** (formato EARS), verificáveis por máquina. Ex.: *"Quando `scripts/verify.sh` roda num clone limpo, então todas as checagens passam e o exit code é 0."*
12. **Roadmap de geração** — a lista ordenada de tasks que o próximo passo (a implementação) vai executar para materializar o template a partir desta spec.

**Estilo da spec:** imperativa, sem ambiguidade, testável. Critérios de aceite em EARS. Cada decisão opinativa marcada como *default trocável* com ponteiro para `docs/CUSTOMIZING.md`.

> **GATE 3 (humano).** Entregue `SPEC.md` + `docs/DECISIONS.md`. **Pare.** A implementação do template só começa após aprovação explícita desta spec.

---

## 5. Definição de Pronto (desta ordem de serviço)

Você terminou **esta tarefa** (não o template inteiro) quando:

- [ ] `research/FINDINGS.md` existe, com versões confirmadas por fontes reais e datadas.
- [ ] `docs/AGENT_ARCHITECTURE.md` descreve roster de subagents, hooks/gates, skills, commands, orçamento de tokens e CLAUDE.md enxuto.
- [ ] `docs/DECISIONS.md` registra os ADRs das escolhas opinativas.
- [ ] `SPEC.md` está completo, autossuficiente, com critérios de aceite em EARS e roadmap de geração.
- [ ] Os três gates humanos foram respeitados (você parou e pediu aprovação em cada um).
- [ ] Nenhum código de aplicação foi escrito ainda além do que a Fase 3 exige como ilustração dentro da spec.

Ao concluir cada fase, **mostre evidência**: os comandos de busca/verificação e suas saídas. Não afirme sucesso — demonstre.

---

## 6. Lembretes finais (os inegociáveis)

- **Gates > confiança.** Se não passa no `verify.sh`, não está pronto — independente do que o modelo ache.
- **Verificador independente.** Quem escreve não assina a própria aprovação.
- **Contexto é orçamento.** Fork para largura, inline para profundidade; skills sob demanda; nada de despejar tudo no CLAUDE.md.
- **Genérico e clonável.** Todo default é trocável e documentado.
- **Determinismo onde importa.** Regras que precisam valer sempre viram hook/script, não instrução em prosa.