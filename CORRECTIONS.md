# CORRECTIONS.md — mpi.api

Base: ehealth-ua/mpi.api@39a002e (master). Usuário autorizou implementação de todas as propostas viáveis.

## Implementado

1. **`.gitignore`** — adicionados `.env`, `.env.local`, `.env.production` para evitar commit de segredos.
2. **`.env`** — removido do controle de versão (`git rm --cached`), mantido no disco local. **Não foi commitado nem exposto.**
3. **`.env.example`** (novo) — placeholders para todas as variáveis de ambiente, sem valores reais. Instrui a copiar para `.env` e preencher.
4. **`README.md`** — expandido com propósito, tecnologias (Elixir/Phoenix, PostgreSQL, Kafka), arquitetura, como instalar, configurar, segurança, especificação.

## Não implementado (requer investigação adicional)
- `eHealth-8110bd102a69.json.enc` — arquivo encriptado rastreado; conteúdo desconhecido. Não removido sem investigação prévia.
- `Dockerfile.deduplication` — fora do escopo mínimo aprovado.

## Validação
- Revisão estática concluída.
- Não executado: `mix test`, build Docker (dependências Elixir/Phoenix não disponíveis).
