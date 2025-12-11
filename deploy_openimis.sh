#!/bin/bash
set -e

# ===========================
# Deploy OpenIMIS Produção
# ===========================

# 1️⃣ Criar arquivos .env se não existirem
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

# 3️⃣ Inicialização (executa apenas uma vez)
if [[ -f '.init.lock' ]]; then
    echo "Initialization already done"
else
    echo "Initialization started"

    # 3.1️⃣ Subir apenas o banco
    docker compose up -d db

    # 3.2️⃣ Esperar o banco ficar pronto
    echo "Waiting for PostgreSQL to be ready..."
    until docker compose exec db pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo "PostgreSQL is ready."

    

    # 3.5️⃣ Rodar migrations e scripts do backend
    docker compose run --rm kenon-backend mix ecto.migrate
    docker compose run --rm kenon-backend mix run imisSetupScripts/imisSetup.exs

    # 3.6️⃣ Criar lockfile para não repetir inicialização
    touch '.init.lock'

    echo "Initialization finished."
    echo "Connect to https://${DOMAIN}"
    echo "Then go to https://${DOMAIN}/opensearch to import the OpenSearch dashboard"
fi

# 4️⃣ Subir todos os containers
docker compose up -d
