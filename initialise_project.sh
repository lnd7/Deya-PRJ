#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}      $1${NC}"; }
warn() { echo -e "${YELLOW}     $1${NC}"; }
fail() { echo -e "${RED}        $1${NC}"; }

# 1. Validate .env exists
if [ ! -f .env ]; then
  fail ".env not found. Copy .env.example and fill in your values."
  exit 1
fi

# 2. Auto-generate keys if empty, write back to .env
echo ""
echo "#####################################"
echo "Preparing the environment"
echo "#####################################"

generate_if_missing() {
  local KEY=$1
  local VALUE=$(grep "^${KEY}=" .env | cut -d= -f2)
  if [ -z "$VALUE" ]; then
    local GENERATED=$(openssl rand -hex 32)
    # macOS requires '' argument, Linux does not
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^${KEY}=.*/${KEY}=${GENERATED}/" .env
    else
      sed -i "s/^${KEY}=.*/${KEY}=${GENERATED}/" .env
    fi
    ok "${KEY} generated and saved to .env"
  else
    ok "${KEY} already set"
  fi
}

generate_if_missing N8N_ENCRYPTION_KEY

# 3. Validate required user-filled vars
export $(grep -v '^#' .env | xargs)

REQUIRED_VARS=(POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD GOOGLE_API_KEY GROQ_API_KEY)
MISSING=0
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    fail "Missing required .env variable: ${VAR}"
    MISSING=1
  fi
done
if [ $MISSING -eq 1 ]; then
  fail "Fill in all required values in .env and re-run."
  exit 1
fi
ok "All required env vars present"

# 4. Start containers
echo ""
echo "#####################################"
echo "Starting containers"
echo "#####################################"
if command -v docker-compose &>/dev/null; then
  DOCKER_COMPOSE="docker-compose"
elif docker compose version &>/dev/null; then
  DOCKER_COMPOSE="docker compose"
else
  fail "Docker Compose not found. Install it from https://docs.docker.com/compose/"
  exit 1
fi
$DOCKER_COMPOSE up -d --build
ok "Containers started"

# 5. Wait for n8n
echo ""
echo "#####################################"
echo "Waiting for n8n to be ready"
echo "#####################################"
MAX_WAIT=60
WAITED=0
until curl -s "http://localhost:5678/healthz" | grep -q "ok"; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    fail "n8n did not become ready within ${MAX_WAIT}s"
    exit 1
  fi
  echo "    waiting... (${WAITED}s)"
  sleep 5
  WAITED=$((WAITED + 5))
done
ok "n8n is ready"

# 6. Import workflows
echo ""
echo "#####################################"
echo "Importing workflows"
echo "#####################################"
count=0
for file in ./n8n_workflows/*.json; do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    echo "   Importing: $filename"
    docker exec autonomous-workflow-n8n \
      n8n import:workflow --input="/workflows/$filename" 2>/dev/null
    if [ $? -eq 0 ]; then
      ok "Imported $filename"
      ((count++))
    else
      warn "$filename failed or already exists"
    fi
  fi
done

# 7. Import workflows
echo ""
echo "#####################################"
echo "Importing tests for workflows"
echo "#####################################"
for file in ./test_n8n_workflows/*.json; do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    echo "   Importing: $filename"
    docker exec autonomous-workflow-n8n \
      n8n import:workflow --input="/test_workflows/$filename" 2>/dev/null
    if [ $? -eq 0 ]; then
      ok "Imported $filename"
      ((count++))
    else
      warn "$filename failed or already exists"
    fi
  fi
done

# Done
echo ""
echo "#####################################"
echo -e "${GREEN}  Setup complete!${NC}"
echo "   Imported ${count} workflow(s)"
echo ""
echo "   n8n  ==>  http://localhost:5678"
echo ""
echo "  Next: open n8n and add your credentials:"
echo "  Postgres  ==> host: postgres | db: ${POSTGRES_DB} | user: ${POSTGRES_USER}"
echo "  Gemini    ==> API key: ${GOOGLE_API_KEY}"
echo "  Groq      ==> API key: ${GROQ_API_KEY}"
echo "#####################################"

echo ""
echo "#####################################"
echo " Setting up credentials"
echo "#####################################"

# Substitute .env values into credentials template
sed \
  -e "s|\${POSTGRES_DB}|${POSTGRES_DB}|g" \
  -e "s|\${POSTGRES_USER}|${POSTGRES_USER}|g" \
  -e "s|\${POSTGRES_PASSWORD}|${POSTGRES_PASSWORD}|g" \
  -e "s|\${GOOGLE_API_KEY}|${GOOGLE_API_KEY}|g" \
  -e "s|\${GROQ_API_KEY}|${GROQ_API_KEY}|g" \
  ./n8n_credentials/credentials.json > /tmp/credentials_resolved.json

# Copy resolved file into container and import
docker cp /tmp/credentials_resolved.json autonomous-workflow-n8n:/tmp/credentials.json
docker exec autonomous-workflow-n8n \
  n8n import:credentials --input=/tmp/credentials.json 2>/dev/null

if [ $? -eq 0 ]; then
  ok "Credentials imported"
else
  warn "Credentials failed or already exist"
fi


