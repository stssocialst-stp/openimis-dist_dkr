#!/bin/bash
set -e

# ===========================
# Deploy OpenIMIS corrigido
# ===========================

# 1️⃣ Renomear ou criar arquivos .env
if [[ -f '.env' ]]; then
    echo "Using existing env files"
else
    echo "Creating env files from examples"
    cp .env.example .env
    cp .env.lightning.example .env.lightning
    cp .env.openSearch.example .env.openSearch
fi

# 2️⃣ Carregar variáveis de ambiente
source .env
source .env.lightning
source .env.openSearch

# 3️⃣ Inicialização (só roda uma vez)
if [[ -f '.init.lock' ]]; then
    echo "Initialization already done"
else
    echo "Initialization started"

    # 3.1️⃣ Subir apenas o banco
    docker compose up -d db

    # 3.2️⃣ Esperar o banco ficar pronto
    echo "Waiting for PostgreSQL to be ready..."
    until docker compose exec db pg_isready -U ${POSTGRES_USER} > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo "PostgreSQL is ready."

    # 3.3️⃣ Criar banco (ignorar se já existir)
    docker compose run -e PGPASSWORD=${POSTGRES_PASSWORD} --rm db bash -c "
    psql -h db -U ${POSTGRES_USER} -tc \"SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'\" | grep -q 1 || \
    createdb -h db -U ${POSTGRES_USER} ${POSTGRES_DB}
    "

    # 3.4️⃣ Rodar migrations e scripts do backend
    docker compose run --rm kenon-backend mix ecto.migrate
    docker compose run --rm kenon-backend mix run imisSetupScripts/imisSetup.exs

    # 3.5️⃣ Lockfile para não repetir inicialização
    touch '.init.lock'

    echo "Initialization finished. Connect to https://${DOMAIN}"
    echo "Then go to https://${DOMAIN}/opensearch to import the OpenSearch dashboard"
fi

# 4️⃣ Subir todos os containers (backend, frontend, etc.)
docker compose up -d
