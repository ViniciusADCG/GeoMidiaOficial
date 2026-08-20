# GeoMídia

Sistema web full stack para inventário, análise territorial, tramitação e visualização em mapa de mídias exteriores em Campo Grande, MS.

Produção: [geomidia-front.vercel.app](https://geomidia-front.vercel.app)

## Visão geral

O GeoMídia permite cadastrar processos de mídia exterior, visualizar sua distribuição geográfica, aplicar regras de distância, identificar conflitos territoriais e registrar o histórico das alterações. O sistema possui autenticação própria e controle de acesso por perfil.

Principais recursos:

- dashboard com indicadores agregados;
- mapa interativo com Leaflet;
- inventário pesquisável e paginado;
- fila inicial de novos processos com início de análise explícito;
- cadastro e acompanhamento de formulários/processos;
- análise espacial com PostgreSQL/PostGIS;
- regras territoriais administráveis;
- aprovação protegida contra conflitos concorrentes;
- gestão de usuários e perfis;
- auditoria de alterações com usuário, request ID e valores modificados;
- documentação OpenAPI/Swagger gerada pelo FastAPI.

## Estado atual da implantação

- frontend Vue/Vite publicado na Vercel;
- backend FastAPI publicado como uma Vercel Function;
- PostgreSQL/PostGIS hospedado no Supabase e acessado pelo backend;
- migrações Alembic aplicadas;
- administrador inicial criado;
- CORS de produção restrito ao domínio do frontend;
- regras territoriais iniciais carregadas pelas migrações;
- dados reais do banco anterior ainda **não foram migrados**;
- não há carga de demonstração no banco de produção.

Assim, o banco de produção existe e está operacional, mas o inventário começa vazio até que registros reais sejam cadastrados ou migrados.

## Arquitetura

```mermaid
flowchart LR
    U[Usuário] -->|HTTPS| F[Frontend Vue/Vite<br/>Vercel]
    F -->|REST + Bearer JWT| A[API FastAPI<br/>Vercel Function]
    A -->|SQLAlchemy + asyncpg<br/>Transaction pooler 6543| D[(Supabase<br/>PostgreSQL + PostGIS)]
    G[GitHub Actions] -->|Alembic + bootstrap<br/>Direct/Session 5432| D
```

O frontend não acessa o Supabase diretamente. Toda operação de negócio passa pela API FastAPI.

### Componentes

| Camada | Tecnologias | Responsabilidade |
| --- | --- | --- |
| Frontend | Vue 3, TypeScript, Vite, Vuetify, Pinia, Vue Router, Leaflet | Interface, navegação, estado de autenticação e mapa |
| Backend | Python 3.13, FastAPI, Pydantic, SQLAlchemy assíncrono, asyncpg | API, autenticação, autorização, regras e transações |
| Geoespacial | GeoAlchemy2 e PostGIS | Pontos geográficos, índices GiST e consultas de distância |
| Banco | PostgreSQL no Supabase | Persistência, integridade, auditoria e contador de processos |
| Migrações | Alembic | Versionamento e provisionamento do schema |
| Autenticação | JWT HS256 e Argon2 | Sessões da aplicação e hashes de senha |
| Infraestrutura | Vercel, Supabase, GitHub Actions, Docker e Nginx | Deploy, banco gerenciado, automação e execução local |

## Repositórios

O projeto principal usa submódulos Git:

- [GeoMidiaOficial](https://github.com/ViniciusADCG/GeoMidiaOficial): orquestração, Docker Compose, workflow de provisionamento e documentação;
- [geomidia-back](https://github.com/ViniciusADCG/geomidia-back): backend FastAPI;
- [geomidia-front](https://github.com/ViniciusADCG/geomidia-front): frontend Vue/Vite.

Clone tudo com:

```bash
git clone --recurse-submodules https://github.com/ViniciusADCG/GeoMidiaOficial.git
cd GeoMidiaOficial
```

Em um clone já existente:

```bash
git submodule update --init --recursive
```

Alterações em `backend` ou `frontend` devem ser publicadas primeiro no repositório correspondente. Depois, atualize e publique o ponteiro do submódulo no repositório principal.

## Estrutura do projeto

```text
GeoMidiaOficial/
├── .github/workflows/
│   └── provision-supabase.yml
├── backend/                    # submódulo geomidia-back
│   ├── app/
│   │   ├── api/routes/         # endpoints FastAPI
│   │   ├── core/               # configuração e segurança
│   │   ├── db/                 # sessão e modelos SQLAlchemy
│   │   ├── domain/             # regras territoriais
│   │   ├── bootstrap.py        # criação idempotente do administrador
│   │   ├── cli.py              # comandos administrativos
│   │   └── main.py             # aplicação ASGI
│   ├── migrations/             # revisões Alembic
│   ├── tests/                  # testes do backend
│   ├── Dockerfile
│   ├── pyproject.toml
│   └── requirements.txt
├── frontend/                   # submódulo geomidia-front
│   ├── src/
│   │   ├── router/             # rotas e guards
│   │   ├── services/           # cliente HTTP
│   │   ├── stores/             # estado Pinia
│   │   ├── views/              # telas
│   │   └── domain/             # regras usadas na interface
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   └── vercel.json
├── docker-compose.yml
├── docker-compose.prod.yml
└── .env.example
```

## Funcionalidades e telas

| Rota | Tela | Acesso |
| --- | --- | --- |
| `/login` | Autenticação | Pública |
| `/` | Dashboard | Usuários autenticados |
| `/mapa` | Mapa das mídias | Usuários autenticados |
| `/inventario` | Inventário e análise | Usuários autenticados |
| `/formularios` | Formulários de requerimento | `analyst` e `admin` |
| `/usuarios` | Administração de usuários | `admin` |
| `/regras` | Administração das regras territoriais | `admin` |

## Segurança e perfis

O sistema não usa Supabase Auth. Usuários, senhas e sessões são controlados pelo backend nas tabelas da aplicação.

| Perfil | Permissões principais |
| --- | --- |
| `viewer` | Consultar dashboard, inventário, mapa, análises, regras e atividades |
| `analyst` | Tudo de `viewer`, além de cadastrar, editar e tramitar processos e formulários |
| `admin` | Tudo de `analyst`, além de excluir registros, gerenciar usuários e regras |

Proteções implementadas:

- senhas armazenadas com Argon2;
- tokens Bearer JWT com expiração configurável;
- limite local de 5 tentativas de login em 5 minutos por cliente/usuário;
- validação do usuário ativo a cada requisição autenticada;
- impossibilidade de um administrador excluir, desativar ou remover o próprio perfil administrativo;
- garantia de pelo menos um administrador ativo;
- dados de contato omitidos das respostas para `viewer`;
- CORS configurável por origem;
- RLS habilitado nas tabelas de aplicação do Supabase;
- privilégios removidos dos papéis Supabase `anon` e `authenticated`;
- nenhuma senha de banco ou chave privilegiada enviada ao frontend.

O JWT é próprio da aplicação; `JWT_SECRET` deve ser exclusivo, aleatório e ter pelo menos 32 caracteres em produção.

## Modelo de dados

Todas as tabelas da aplicação usam explicitamente o schema `public`.

| Tabela | Finalidade |
| --- | --- |
| `users` | Usuários, perfis, hashes de senha e estado ativo |
| `media_assets` | Processos, dados da mídia, coordenadas, geometria e situação |
| `media_rules` | Regras de raio por tipo de mídia |
| `application_forms` | Formulários vinculados individualmente a um processo |
| `activity_logs` | Auditoria de cadastros, edições, aprovações, irregularidades e exclusões |
| `process_counters` | Numeração anual atômica dos processos |
| `alembic_version` | Revisão atual do schema |

`media_assets.geom` é um ponto PostGIS SRID 4326 gerado a partir de latitude e longitude. O índice GiST acelera a busca espacial.

Os códigos seguem o formato:

```text
PROC-AAAA-NNN
```

Exemplo: `PROC-2026-101`.

Situações aceitas:

```text
novos processos, análise, aprovado, irregular, exigência, vencido, cartografia, jurídico, vistoria
```

Novos pontos, processos e formulários sempre começam em `novos processos`. Esse status não pode ser selecionado novamente nem trocado por uma atualização comum. Um `analyst` ou `admin` deve usar a ação **Iniciar Análise**, que move o processo para `análise` e libera as demais situações.

## Regras territoriais

As regras iniciais são criadas pelas migrações e podem ser administradas pelo perfil `admin`.

| Tipo | Distância inicial |
| --- | ---: |
| Outdoor | 80 m |
| Painel Iluminado - Front Light | 80 m |
| Painel Iluminado - Triface | 80 m |
| Painel Eletrônico Modular - Pequeno Porte | 250 m até 5 m²; 1.000 m acima de 5 m² |
| Painel Eletrônico Modular | 1.000 m |
| Empena | 80 m |
| Empena Eletrônica | 1.000 m |

Comportamento da análise:

- mídias do mesmo tipo entram em conflito quando a distância é menor que o maior raio aplicável entre elas;
- Painel Eletrônico Modular - Pequeno Porte (`painel de led`) e Empena Eletrônica (`empena de led`) também conflitam entre si abaixo de 500 m;
- processos `irregular` são ignorados na análise;
- a consulta inicial usa `ST_DWithin` sobre `geography` no PostGIS;
- a resposta lista todos os conflitos ordenados pela distância;
- a aprovação adquire um advisory lock transacional, recalcula os conflitos e é recusada com HTTP `409` se houver divergência;
- latitude e longitude são limitadas à área operacional configurada para Campo Grande.

## Fluxo de um processo

1. Um `analyst` ou `admin` cadastra diretamente uma mídia ou preenche um formulário.
2. O backend gera o código anual do processo de forma atômica.
3. A regra ativa determina o raio territorial persistido.
4. O processo começa em `novos processos`.
5. Um `analyst` ou `admin` usa a ação dedicada **Iniciar Análise**.
6. O backend muda o status para `análise`, registra a atividade e libera a tramitação.
7. Alterações posteriores geram registros em `activity_logs`.
8. Ao tentar aprovar, o backend executa novamente a análise dentro da mesma transação.
9. Sem conflitos, a aprovação é confirmada; com conflitos, a transação é rejeitada.

## API

Em desenvolvimento, a documentação interativa fica em `http://localhost:8000/docs`.

| Prefixo/rota | Operações |
| --- | --- |
| `POST /api/auth/login` | Autenticação e emissão do JWT |
| `GET /api/auth/me` | Usuário autenticado |
| `/api/media-assets` | Listagem, indicadores, detalhe, análise, cadastro, edição e exclusão |
| `POST /api/media-assets/{id}/start-analysis` | Inicia formalmente a análise de um novo processo |
| `/api/application-forms` | Listagem, detalhe, cadastro, edição e exclusão de formulários |
| `/api/activities` | Histórico paginado |
| `/api/media-rules` | Consulta e administração das regras |
| `/api/users` | Administração de usuários |
| `/health` | Verifica a API e executa `select 1` no banco |
| `/health/live` | Liveness sem consulta ao banco |
| `/health/ready` | Readiness com consulta ao banco |

Todas as rotas de negócio, exceto login, exigem:

```http
Authorization: Bearer <token>
```

## Variáveis de ambiente

### Backend

| Variável | Obrigatória | Descrição |
| --- | --- | --- |
| `ENVIRONMENT` | Produção | Use `production` na Vercel |
| `DATABASE_URL` | Sim | URL usada pela aplicação; na Vercel use Transaction pooler `6543` |
| `DATABASE_DIRECT_URL` | Migrações | URL direta ou Session pooler `5432`; não configure na aplicação Vercel |
| `CORS_ORIGINS` | Sim | Origens separadas por vírgula, sem `/api` |
| `CREATE_TABLES` | Sim | Deve ser `false` em produção; use Alembic |
| `JWT_SECRET` | Sim | Chave aleatória; mínimo de 32 caracteres em produção |
| `JWT_ALGORITHM` | Não | Padrão `HS256` |
| `ACCESS_TOKEN_MINUTES` | Não | Padrão `30` |
| `BOOTSTRAP_ADMIN_USERNAME` | Provisionamento | Padrão `admin` quando definido pelo workflow/Docker |
| `BOOTSTRAP_ADMIN_PASSWORD` | Provisionamento | Senha inicial com pelo menos 12 caracteres |
| `BOOTSTRAP_ADMIN_NAME` | Não | Nome de exibição do administrador |
| `CITY_MIN_LATITUDE` | Não | Padrão `-20.65` |
| `CITY_MAX_LATITUDE` | Não | Padrão `-20.30` |
| `CITY_MIN_LONGITUDE` | Não | Padrão `-54.80` |
| `CITY_MAX_LONGITUDE` | Não | Padrão `-54.40` |

URLs `postgres://` e `postgresql://` são normalizadas para o driver `asyncpg`. Ao detectar a porta `6543`, o backend usa `NullPool` e desativa prepared statements para compatibilidade com o Supavisor.

### Frontend

| Variável | Obrigatória | Descrição |
| --- | --- | --- |
| `VITE_API_BASE_URL` | Sim | URL pública da API terminada em `/api` |

Variáveis `VITE_*` são incorporadas durante o build. Alterá-las na Vercel exige um novo deployment.

### Docker local

| Variável | Descrição |
| --- | --- |
| `POSTGRES_DB` | Nome do banco local |
| `POSTGRES_USER` | Usuário PostgreSQL local |
| `POSTGRES_PASSWORD` | Senha PostgreSQL local |

Nunca versione `.env`, URLs com senha, `JWT_SECRET`, senha administrativa ou credenciais privilegiadas do Supabase.

## Execução local com Docker

Pré-requisitos: Git e Docker com Docker Compose.

1. Clone os submódulos.
2. Copie `.env.example` para `.env`.
3. Substitua `JWT_SECRET` e `BOOTSTRAP_ADMIN_PASSWORD` por valores seguros.
4. Inicie os serviços:

```bash
docker compose up --build
```

Endereços locais:

- frontend: `http://localhost:3000`;
- API: `http://localhost:8000`;
- Swagger: `http://localhost:8000/docs`;
- PostgreSQL/PostGIS no host: `localhost:5433`.

O container da API executa `alembic upgrade head`, cria o administrador de forma idempotente e inicia o Uvicorn.

Para uma execução em que PostgreSQL e API não fiquem expostos diretamente no host:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d
```

Nesse modo, o Nginx do frontend encaminha `/api` para o serviço interno da API.

## Desenvolvimento sem Docker para a aplicação

### Banco local

Suba somente o PostgreSQL/PostGIS:

```bash
docker compose up -d db
```

Como o banco é exposto na porta `5433`, ajuste no `.env` do backend:

```env
DATABASE_URL=postgresql+asyncpg://geomidia:geomidia@localhost:5433/geomidia
```

### Backend

Requer Python 3.13:

```bash
cd backend
py -3.13 -m venv .venv
```

PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
alembic upgrade head
python -m app.cli bootstrap-admin
uvicorn app.main:app --reload
```

Para o bootstrap local, defina antes `BOOTSTRAP_ADMIN_USERNAME` e `BOOTSTRAP_ADMIN_PASSWORD` no `.env`.

### Frontend

Requer Node.js e npm:

```bash
cd frontend
npm ci
npm run dev
```

Use em `frontend/.env`:

```env
VITE_API_BASE_URL=http://localhost:8000/api
```

## Migrações e dados iniciais

Alembic é a única forma suportada de alterar um banco existente:

```bash
cd backend
alembic current
alembic upgrade head
```

O bootstrap do administrador é separado do startup normal da API:

```bash
python -m app.cli bootstrap-admin
```

O comando é idempotente: se o nome de usuário já existir, ele não substitui a conta ou a senha.

As migrações:

- criam as extensões `postgis` e `pgcrypto` quando necessário;
- criam e evoluem as tabelas;
- carregam as sete regras territoriais iniciais;
- detectam o schema da extensão PostGIS;
- habilitam RLS e restringem os papéis públicos do Supabase.

Existe um `backend/app/seed.py` com cinco registros fictícios para demonstração local. Ele não faz parte do deploy e **não deve ser executado em produção**.

## Testes e qualidade

Backend:

```bash
cd backend
pytest
ruff check app tests migrations
```

Frontend:

```bash
cd frontend
npm test
npm run type-check
npm run build
```

Atalhos disponíveis na raiz:

```bash
npm run dev
npm run test
npm run build
npm run type-check
```

## Provisionamento do Supabase

No Supabase, habilite/confirme `postgis` e `pgcrypto`. No painel **Connect**, há duas conexões com finalidades diferentes:

- **Transaction pooler**, porta `6543`: tráfego serverless do FastAPI na Vercel;
- **Direct connection** ou **Session pooler**, porta `5432`: Alembic, backup, restauração e tarefas administrativas.

Use Session pooler para migrações quando o executor não possuir IPv6.

No repositório principal do GitHub, crie o environment `production` com:

| Secret | Conteúdo |
| --- | --- |
| `SUPABASE_MIGRATION_DATABASE_URL` | URL direta ou Session pooler para migração |
| `BOOTSTRAP_ADMIN_PASSWORD` | Senha inicial com pelo menos 12 caracteres |

Execute manualmente **Actions → Provision Supabase → Run workflow**. O workflow instala o backend e executa:

```bash
alembic upgrade head
python -m app.cli bootstrap-admin
```

Não use a chave `anon`, `service_role` ou Supabase Auth para substituir a conexão PostgreSQL utilizada pelo backend.

## Deploy na Vercel

São dois projetos Vercel independentes.

### Backend

Importe `ViniciusADCG/geomidia-back` com:

```text
Project Name: geomidia-api
Root Directory: ./
Application Preset: FastAPI (detecção automática)
```

O entrypoint está em `backend/pyproject.toml`:

```toml
[tool.vercel]
entrypoint = "app.main:app"
```

Variáveis:

```env
ENVIRONMENT=production
DATABASE_URL=postgresql://postgres.PROJECT_REF:SENHA@HOST.pooler.supabase.com:6543/postgres
CREATE_TABLES=false
JWT_SECRET=CHAVE_ALEATORIA_COM_PELO_MENOS_32_CARACTERES
CORS_ORIGINS=https://geomidia-front.vercel.app
```

Não configure `DATABASE_DIRECT_URL` ou variáveis de bootstrap na função de produção.

Valide o deployment:

```text
https://URL-DA-API.vercel.app/health
https://URL-DA-API.vercel.app/health/live
https://URL-DA-API.vercel.app/health/ready
https://URL-DA-API.vercel.app/docs
```

### Frontend

Importe `ViniciusADCG/geomidia-front` com:

```text
Project Name: geomidia-front
Root Directory: ./
Application Preset: Vite
```

Configure:

```env
VITE_API_BASE_URL=https://URL-DA-API.vercel.app/api
```

`frontend/vercel.json` reescreve rotas da SPA para `index.html`, permitindo abrir diretamente `/mapa`, `/inventario` e outras telas.

Depois de alterar variáveis na Vercel, crie um novo deployment; deployments anteriores mantêm os valores antigos.

## Operação e diagnóstico

- `/health/live` confirma que a função iniciou, sem consultar o banco;
- `/health/ready` e `/health` executam `select 1` no PostgreSQL;
- login funcionando confirma leitura da tabela `public.users`;
- mapa vazio em uma instalação nova é esperado: `media_assets` ainda não possui registros;
- `media_rules` deve conter as regras iniciais após as migrações;
- logs da Vercel mostram erros de build e execução da API;
- logs do workflow GitHub mostram migrações e bootstrap;
- o Table Editor e o SQL Editor do Supabase permitem inspecionar o schema `public`.

Se o frontend não alcançar a API, confira:

1. `VITE_API_BASE_URL` termina em `/api`;
2. houve novo build do frontend após alterar a variável;
3. `CORS_ORIGINS` contém apenas a origem do frontend, sem `/api` e sem barra final;
4. houve novo deployment do backend após alterar o CORS;
5. `/health/ready` retorna `{"status":"ok"}`.

## Migração futura dos dados reais

A migração do banco anterior está deliberadamente pendente. Quando for iniciada, o procedimento deve ser tratado separadamente do deploy da aplicação:

1. identificar o banco de origem, versão, schema e volume;
2. gerar e testar um backup recuperável;
3. mapear colunas, tipos, situações e coordenadas antigas para o schema atual;
4. validar duplicidades, códigos de processo, e-mails e geometrias;
5. importar primeiro em um ambiente de teste;
6. comparar contagens e amostras entre origem e destino;
7. definir janela de corte e impedir gravações concorrentes;
8. importar no Supabase usando conexão direta/Session pooler;
9. ajustar `process_counters` para não repetir códigos;
10. executar validações finais e manter um plano de reversão.

Não execute `seed.py` para representar essa migração: ele contém somente dados fictícios.
