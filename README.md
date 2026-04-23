# Autonomous Workflow Orchestration System (AWOS)

A multi-agent document processing system built with n8n, powered by Google AI Studio and Groq, and deployed via Docker. Supports automated summarisation, classification, and data extraction across PDF, DOCX, TXT, CSV, XLS, and XLSX files through a directed orchestration architecture.

---

## Stack Ports

| Service  | Description                        | Port  |
|----------|------------------------------------|-------|
| n8n      | Workflow automation                | 5678  |
| Postgres | Database with pgvector extension   | 5432  |

---

## Prerequisites

**macOS / Windows**
- [Docker Desktop](https://www.docker.com/products/docker-desktop), includes everything (Docker + Docker Compose)

**Linux (ubuntu)**
- [Docker Engine](https://docs.docker.com/engine/install/)
- [Docker Compose plugin](https://docs.docker.com/compose/install/linux/)
```bash
sudo apt-get update
sudo apt-get install docker-compose-plugin
```
- Add your user to the Docker group:
```bash
sudo usermod -aG docker $USER && newgrp docker
```

---

## Setup

### Configure your environment

```bash
cp .env.example .env
```

This project uses Google AI Studio and Groq. You should get your API keys ready to run the project.
Open `.env` and fill in your credential values:

```.env
# Database
POSTGRES_DB=rag_db
POSTGRES_USER=rag_user
POSTGRES_PASSWORD=set/enter_your_password

# Timezone
TIMEZONE=UTC

# AI credentials
GOOGLE_API_KEY=your_google_ai_studio_key
GROQ_API_KEY=your_groq_key

# Leave this empty (auto-generated on first run)
N8N_ENCRYPTION_KEY=
```

> `N8N_ENCRYPTION_KEY` is automatically generated and written back to `.env` on first run. Do not change it after the project is running; doing so might corrupt stored credentials.

### Run

```bash
chmod +x initialise_project.sh
./initialise_project.sh
```

The script will:
- Generate missing keys and save them to `.env`
- Build and start all containers
- Wait for n8n to be ready
- Import credentials (Postgres, Google Gemini, Groq)
- Import the project workflows from `n8n_workflows/`

---

## Accessing the services

| Service  | URL                        |
|----------|----------------------------|
| n8n      | http://localhost:5678      |
| Postgres | localhost:5432             |




---

## Stopping the project

```bash
docker-compose stop
```

Or 

```bash
docker compose stop
```

## To delete and wipe all data (full reset):

```bash
docker-compose down --volumes --remove-orphans
```

Or 

```bash
docker compose down --volumes --remove-orphans
```

> NOTE: This deletes all workflow data, credentials, and the Postgres database.

---


