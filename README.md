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

- Outdoor, front light, triface e empena: raio mínimo de 80 m.
- Painel de LED: 250 m até 5 m² e 1.000 m acima de 5 m².
- Empena de LED: raio mínimo de 1.000 m.
- Painel de LED e empena de LED conflitam entre si abaixo de 500 m.
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
