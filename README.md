# GeoMídia

Sistema full stack para inventário, análise territorial e mapa GIS de mídia exterior em Campo Grande, MS.

## Stack

- Frontend: Vue 3, Vuetify, Pinia, Leaflet.js e Vite.
- Backend: Python, FastAPI, SQLAlchemy async e GeoAlchemy2.
- Banco: PostgreSQL com PostGIS.

## Rodando com Docker

1. Copie as variáveis:

```bash
cp .env.example .env
```

2. Suba tudo:

```bash
docker compose up --build
```

3. Acesse:

- Frontend: http://localhost:3000
- API: http://localhost:8000/docs
- Health check: http://localhost:8000/health

O banco PostGIS é inicializado com schema, índices espaciais e dados de exemplo.

## Rodando localmente

Backend:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m app.seed
uvicorn app.main:app --reload
```

Frontend:

```bash
cd frontend
npm install
npm run dev
```

## Estrutura

```text
backend/
  app/
    api/routes/        Rotas FastAPI
    db/                Sessão e modelos SQLAlchemy/PostGIS
    domain/            Regras puras de raio e conflito
    seed.py            Carga inicial
database/init/         SQL de schema e seed para Docker
frontend/
  src/
    stores/            Estado Pinia
    views/             Dashboard, inventário, mapa e login
    services/api.ts    Cliente HTTP da API
```

## Regras implementadas

- Outdoor, front light, triface e empena: raio mínimo de 80m.
- Painel de LED: 250m até 5m² e 1000m acima de 5m².
- Empena de LED: raio mínimo de 1000m.
- Painel de LED e empena de LED conflitam entre si abaixo de 500m.
