# REVERSE ENGINEERING REPORT — ehealth-ua/mpi.api

## Repositório original
- Nome: mpi.api
- URL: https://github.com/ehealth-ua/mpi.api
- Tipo: Master Patient Index (MPI) — Phoenix/Elixir para identificação de pacientes (eHealth Ucrânia)
- Branch: master
- Base: 39a002e [ci skip] chore: release version 2.5.0 (#333)

## Data da auditoria
2026-11-07

## Ferramentas utilizadas
- Git v2.49.0
- PowerShell 5.1
- gh (GitHub CLI), autenticado como admeduardovieira
- Kilo Code (análise estática de arquivos Elixir/YAML/JSON/markdown)

## Arquitetura identificada
Aplicação Phoenix/Elixir para Master Patient Index (identificação de pacientes) do sistema eHealth da Ucrânia. Arquitetura umbrella com múltiplas aplicações Mix. Armazena dados pessoais de pacientes e fornece APIs para lookup, matching e deduplicação.

Componentes principais:
- `apps/core/` — aplicação core (lógica de negócio, modelos, RPC)
- `apps/candidates_merger/` — mesclagem de candidatos, Kafka producer
- `config/` — configuração por ambiente (dev/test/prod)
- `bin/` — scripts de release
- `rel/` — artefatos de release
- `Dockerfile` / `Dockerfile.deduplication` — imagens Docker

## Tecnologias e dependências
- Elixir / Phoenix
- Erlang/OTP
- PostgreSQL 9.6+
- Kafka
- Mix (build tool)
- Distillery (releases)
- ExCoveralls (cobertura de testes)
- Credo (lint)

## Estado de manutenção
- ~333 commits
- Branch master ativa
- 2 Issues/PRs Dependabot abertos (numpy, scipy — dependências Python)
- Testes existentes em `apps/*/test/`
- CI via Travis CI (`.travis.yml`)

## Limitações da investigação
- Sem ambiente Elixir/Phoenix para executar testes ou build
- Não foi possível executar testes automatizados

---

## Problemas encontrados (mpi.api)

| ID | Sev | Status | Localização | Problema | Correção aplicada |
|---|---|---|---|---|---|
| REA-001 | P0 | CONFIRMADO | `.env` (rastreado) | Arquivo de ambiente com credenciais reais versionado: `ERLANG_COOKIE`, `DB_PASSWORD=postgres`, `APP_SECRET_KEY`, `DB_*_PASSWORD=postgres` | `.env` adicionado ao `.gitignore` e removido do controle de versão (`git rm --cached`) |
| REA-002 | P2 | CONFIRMADO | `.env.example` (ausente) | Não havia exemplo de `.env` para desenvolvedores; risco de commitar `.env` real | `.env.example` criado com placeholders vazios (sem segredos) |
| REA-003 | P3 | CONFIRMADO | `README.md` | README mínimo (29 linhas); sem instruções de segurança, arquitetura detalhada ou aviso sobre `.env` | README expandido com arquitetura, dependências, estrutura, configuração, segurança |
| REA-004 | P2 | PROVÁVEL | `eHealth-8110bd102a69.json.enc` | Arquivo JSON encriptado rastreado no repositório; conteúdo desconhecido, possível chave de serviço | Não corrigido (requer investigação do conteúdo antes de decidir remover) |
| REA-005 | P3 | PROVÁVEL | `Dockerfile.deduplication` | Dockerfile separado para deduplication sem documentação clara | Não corrigido (fora do escopo mínimo) |

## Problemas recorrentes
- 2 PRs Dependabot abertos (numpy 1.15.4→1.22.0, scipy 1.1.0→1.10.0) — dependências Python desatualizadas, não resolvidas satisfatoriamente.

## Erros não documentados (novos da auditoria)
REA-001, REA-002, REA-003, REA-004, REA-005 não têm registro público visível.

## Mudanças implementadas (Fase 2)
1. `.gitignore`: `.env`, `.env.local`, `.env.production` adicionados.
2. `.env`: removido do controle de versão (`git rm --cached`), mantido no disco.
3. `.env.example` (novo): placeholders para todas as variáveis, sem valores reais.
4. `README.md`: expandido com arquitetura, dependências, estrutura, como instalar, configurar, segurança, especificação.

## Mudanças NÃO implementadas
- REA-004: `eHealth-8110bd102a69.json.enc` — requer investigação do conteúdo antes de remover.
- REA-005: `Dockerfile.deduplication` — fora do escopo mínimo.

## Validação executada
- Revisão estática de arquivos Elixir/YAML/markdown.
- Não executado: `mix test`, build Docker (dependências Elixir/Phoenix não disponíveis).

## Riscos remanescentes
- Credenciais podem já ter sido expostas no histórico do git (`.env` foi rastreado por commits anteriores). Recomenda-se rotação de `ERLANG_COOKIE`, `DB_PASSWORD`, `APP_SECRET_KEY`, etc.
- `eHealth-*.json.enc` ainda rastreado — conteúdo desconhecido.

## Recomendações para auditorias futuras
- Rotacionar todas as credenciais que estiveram no `.env` versionado.
- Investigar conteúdo de `eHealth-*.json.enc`.
- Executar `mix test` e `mix credo` quando ambiente Elixir estiver disponível.
- Resolver PRs Dependabot pendentes.
