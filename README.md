# GeoMídia

Sistema full stack para inventário, análise territorial e mapa GIS de mídia exterior em Campo Grande, MS.

## Stack

- Frontend: Vue 3, Vuetify, Pinia, Vue Router, Leaflet e Vite.
- Backend: FastAPI, SQLAlchemy assíncrono, Pydantic, JWT e Argon2.
- Banco: PostgreSQL/PostGIS, com migrações Alembic.
- Entrega: Docker multi-stage, Nginx e GitHub Actions.

## Segurança e perfis

Todas as rotas de negócio exigem autenticação. Há três perfis:

- `viewer`: consulta inventário, mapa, análises e atividades.
- `analyst`: também cadastra, edita, aprova e reprova processos.
- `admin`: também exclui registros e administra usuários.

As aprovações executam a análise territorial na mesma transação. Alterações geram auditoria com usuário, request ID e valores modificados.

## Rodando com Docker

1. Copie `.env.example` para `.env`.
2. Troque obrigatoriamente `JWT_SECRET` e `BOOTSTRAP_ADMIN_PASSWORD`.
3. Inicie os serviços:

```bash
docker compose up --build
```

O primeiro startup cria o administrador configurado no `.env`. A senha precisa ter pelo menos 12 caracteres.

- Aplicação: http://localhost:3000
- OpenAPI: http://localhost:8000/docs
- Liveness: http://localhost:8000/health/live
- Readiness: http://localhost:8000/health/ready

Para uma implantação sem expor o PostgreSQL:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d
```

## Desenvolvimento local

Backend com Python 3.13:

```bash
cd backend
py -3.13 -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
alembic upgrade head
uvicorn app.main:app --reload
```

Frontend:

```bash
cd frontend
npm ci
npm run dev
```

O Vite usa `VITE_API_BASE_URL`; no container, o Nginx encaminha `/api` para o backend.

## Verificações

```bash
cd backend
pytest
ruff check app tests migrations

cd ../frontend
npm test
npm run build
```

## Regras territoriais

- Outdoor, Painel Iluminado - Front Light, Painel Iluminado - Triface e Empena: raio mínimo de 80 m.
- Painel Eletrônico Modular - Pequeno Porte: 250 m até 5 m² e 1.000 m acima de 5 m².
- Painel Eletrônico Modular: raio mínimo de 1.000 m.
- Empena Eletrônica: raio mínimo de 1.000 m.
- Painel Eletrônico Modular - Pequeno Porte e Empena Eletrônica conflitam entre si abaixo de 500 m.
- Processos reprovados não participam da análise.
- Novos processos sempre começam como pendentes.

O endpoint de análise retorna todos os conflitos encontrados, ordenados por distância. As coordenadas também são limitadas à área operacional configurada para Campo Grande.

## Banco e operação

- `alembic upgrade head` é a única forma suportada de migrar ambientes existentes.
- `CREATE_TABLES` deve permanecer `false` em produção.
- O número do processo usa contador anual atômico no PostgreSQL.
- Listagens são paginadas e os indicadores usam agregações SQL.
- Use `/health/live` para liveness e `/health/ready` para readiness.

`backend` e `frontend` são submódulos Git; clone o projeto com `git clone --recurse-submodules` ou execute `git submodule update --init --recursive`.

## Deploy com Supabase e Vercel

A implantação recomendada usa três componentes independentes:

- Supabase: PostgreSQL com PostGIS.
- Vercel `geomidia-api`: backend FastAPI, com raiz em `backend`.
- Vercel `geomidia-web`: frontend Vue/Vite, com raiz em `frontend`.

### 1. Preparar o Supabase

Habilite `postgis` e `pgcrypto` em **Database > Extensions**. Antes da primeira migração, confirme no SQL Editor:

```sql
select extension.extname, namespace.nspname as schema_name
from pg_extension extension
join pg_namespace namespace on namespace.oid = extension.extnamespace
where extension.extname in ('postgis', 'pgcrypto');
```

As migrações detectam o schema do PostGIS e configuram o `search_path` da conexão da aplicação. Elas também habilitam RLS e removem os privilégios de `anon` e `authenticated` nas tabelas do GeoMídia. O frontend nunca deve receber a senha do banco nem a chave `service_role`.

No painel **Connect**, copie:

- **Transaction pooler**, porta `6543`: tráfego do FastAPI na Vercel.
- **Direct connection** ou **Session pooler**, porta `5432`: Alembic e provisionamento.

Use o Session pooler para a migração quando o executor não possuir conectividade IPv6.

### 2. Migrar e criar o primeiro administrador

Cadastre estes secrets no ambiente `production` do GitHub:

- `SUPABASE_MIGRATION_DATABASE_URL`: URL direta ou Session pooler, nunca a porta `6543`.
- `BOOTSTRAP_ADMIN_PASSWORD`: senha com pelo menos 12 caracteres.

Execute manualmente o workflow **Provision Supabase**. Ele roda, nesta ordem:

```bash
alembic upgrade head
python -m app.cli bootstrap-admin
```

O comando do administrador é idempotente e não altera uma conta que já exista. Para executar localmente, configure `DATABASE_DIRECT_URL`, `BOOTSTRAP_ADMIN_USERNAME` e `BOOTSTRAP_ADMIN_PASSWORD` antes dos dois comandos.

### 3. Publicar o backend

Crie um projeto Vercel com **Root Directory** igual a `backend`. O entrypoint FastAPI está configurado no `pyproject.toml`. Cadastre:

```env
DATABASE_URL=postgresql://postgres.PROJECT_REF:SENHA@HOST.pooler.supabase.com:6543/postgres
ENVIRONMENT=production
CREATE_TABLES=false
JWT_SECRET=uma-chave-aleatoria-com-pelo-menos-32-caracteres
CORS_ORIGINS=https://URL-DO-FRONTEND.vercel.app
```

Não configure `DATABASE_DIRECT_URL` na aplicação Vercel. Essa credencial é exclusiva para migrações e administração. O backend detecta a porta `6543`, desativa prepared statements e deixa o Supavisor gerenciar as conexões.

Depois do deploy, valide:

```text
https://URL-DA-API.vercel.app/health/live
https://URL-DA-API.vercel.app/health/ready
https://URL-DA-API.vercel.app/docs
```

### 4. Publicar o frontend

Crie outro projeto Vercel com **Root Directory** igual a `frontend` e configure:

```env
VITE_API_BASE_URL=https://URL-DA-API.vercel.app/api
```

O `vercel.json` do frontend encaminha as rotas da SPA para `index.html`. Depois que a URL final do frontend existir, atualize `CORS_ORIGINS` no projeto do backend e faça um novo deploy da API.

Como `backend` e `frontend` são submódulos, suas alterações precisam ser publicadas nos respectivos repositórios e os ponteiros do repositório principal precisam ser atualizados antes do deploy pelo Git.
