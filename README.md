<div align="center">

![Banner](https://capsule-render.vercel.app/api?type=waving&color=0:000000,50:0f172a,100:000000&height=180&section=header&text=Agent%20AI%20Ops&fontSize=42&fontColor=2563eb&animation=fadeIn&fontAlignY=38&desc=GPU-Accelerated%20%7C%20Self-Hosted%20%7C%20IaC%20%7C%20DevOps&descAlignY=60&descAlign=50)

[![Docker Compose](https://img.shields.io/badge/Docker_Compose-3.8-2496ED?style=flat-square&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![NVIDIA CUDA](https://img.shields.io/badge/NVIDIA_CUDA-GPU_Accelerated-76B900?style=flat-square&logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![Ollama](https://img.shields.io/badge/Ollama-LLaMA_3.1-000000?style=flat-square&logo=ollama&logoColor=white)](https://ollama.com/)
[![n8n](https://img.shields.io/badge/n8n-Automation-EA4B71?style=flat-square&logo=n8n&logoColor=white)](https://n8n.io/)
[![Prometheus](https://img.shields.io/badge/Prometheus-v3.5.0-E6522C?style=flat-square&logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?style=flat-square&logo=grafana&logoColor=white)](https://grafana.com/)
[![Bash](https://img.shields.io/badge/IaC-Bash_Script-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: GPL](https://img.shields.io/badge/License-GNU_GPL-4EAA25?style=flat-square&logo=gnu&logoColor=white)](LICENSE)

*Workplace de infraestructura IA completo y listo para producción — sin dependencias en la nube, con soberanía total de datos.*

</div>


---


## Descripción general

**Agent AI Ops** es prototipo de plataforma de IA de nivel de producción y autohospedada, diseñada para ejecutar modelos de lenguaje grande (LLM), búsqueda vectorial y automatización inteligente íntegramente en tu propio hardware: sin dependencias de la nube, sin cuotas de uso y con soberanía total sobre los datos.

Orquestada a través de un único archivo declarativo `docker-compose.yml` y gestionada por una CLI personalizada `agentai-ops.sh`, la pila pone en marcha 15 servicios en contenedores que cubren todo el proceso de IA: desde la inferencia de modelos y el almacenamiento vectorial hasta la automatización de flujos de trabajo y la observabilidad de la GPU en tiempo real.


---


## Architecture
 
<p align="center">
  <img src="Architecture.svg"
       alt="Architecture System"
       width="900"
       style="max-width: 100%; height: auto; border-radius: 12px; box-shadow: 0px 8px 24px rgba(37, 99, 235, 0.18);">
</p>


---


## Services


### 🤖 AI & Inference

| Service | Image | Port | Description |
|---|---|---|---|
| **Ollama** | `ollama/ollama` | `11434` | Local LLM server with NVIDIA GPU acceleration. Runs `llama3.1:8b` across dual GPUs. |
| **Qdrant** | `qdrant/qdrant:v1.15-gpu-nvidia` | `6333` · `6334` | GPU-accelerated vector database for semantic search and RAG pipelines. |
| **Open WebUI** | `open-webui/open-webui` | `8088` | ChatGPT-style interface connecting to the local Ollama backend. |


### ⚙️ Automation

| Service | Image | Port | Description |
|---|---|---|---|
| **n8n** | `n8nio/n8n` | `5678` | Visual workflow automation engine. Integrates with Ollama, Qdrant, Redis, and external APIs. |


### 🗄️ Data Layer

| Service | Image | Port | Description |
|---|---|---|---|
| **PostgreSQL 15** | `postgres:15` | `5432` | Primary relational database for n8n state and Grafana data. |
| **Redis 7** | `redis:7-alpine` | `6379` | In-memory cache and message queue with AOF persistence. |
| **pgAdmin 4** | `dpage/pgadmin4` | `5050` | Web-based GUI for PostgreSQL management. |
| **RedisInsight** | `redislabs/redisinsight` | `5540` | Visual browser and profiler for Redis. |


### 📊 Observability

| Service | Image | Port | Description |
|---|---|---|---|
| **Prometheus** | `prom/prometheus:v3.5.0` | `9090` | Metrics collection with 30-day retention. Scrapes all exporters every 10–30s. |
| **Grafana** | `grafana/grafana` | `3000` | Unified dashboarding for all system, container, database, and GPU metrics. |
| **Node Exporter** | `prom/node-exporter` | — | CPU, memory, disk, and network metrics from the host OS. |
| **cAdvisor** | `gcr.io/cadvisor` | `8080` | Real-time per-container resource usage and performance metrics. |
| **DCGM Exporter** | `nvidia/dcgm-exporter` | `9400` | NVIDIA GPU utilization, memory, temperature, and power metrics. |
| **Postgres Exporter** | `prometheuscommunity/postgres-exporter` | `9187` | Query performance and connection metrics from PostgreSQL. |
| **Redis Exporter** | `oliver006/redis_exporter` | `9121` | Command stats, memory, and latency metrics from Redis. |


---


## Prometheus Monitoring Matrix

| Metric Domain | Scrape Interval | Source |
|---|:---:|---|
| System (CPU · RAM · Disk · Network) | `15s` | Node Exporter |
| Container resources (per-service) | `10s` | cAdvisor |
| GPU utilization · temperature · power | `10s` | DCGM Exporter |
| PostgreSQL queries · connections | `20s` | Postgres Exporter |
| Redis memory · commands · latency | `15s` | Redis Exporter |
| Qdrant vector index stats | `20s` | Qdrant `/metrics` |
| Grafana application metrics | `30s` | Grafana `/metrics` |
| Network I/O (netdev · sockstat) | `10s` | Node Exporter |


---


## Operations CLI

All infrastructure lifecycle management is handled through a single script with an interactive TUI or direct commands.

```bash
# Interactive menu (recommended)
bash agentai-ops.sh

# Direct commands
bash agentai-ops.sh instalar     # Full stack installation (NVIDIA toolkit, dirs, config)
bash agentai-ops.sh levantar     # Start all services
bash agentai-ops.sh bajar        # Stop all services
bash agentai-ops.sh reiniciar    # Restart (all or a single service)
bash agentai-ops.sh estado       # System status dashboard
bash agentai-ops.sh logs         # Stream logs (all or a single service)
bash agentai-ops.sh llms         # Pull LLM models into Ollama
bash agentai-ops.sh verificar    # Run health checks on all services
bash agentai-ops.sh endpoints    # Print all service URLs
bash agentai-ops.sh actualizar   # Pull latest Docker images
bash agentai-ops.sh backup       # Archive all data volumes
bash agentai-ops.sh seguridad    # Configure UFW firewall + run Lynis audit
bash agentai-ops.sh destruir     # Remove containers and volumes
bash agentai-ops.sh purge        # ⚠️ Wipe everything (irreversible)
```


---


## Quick Start


### Prerequisites

- Linux host (Ubuntu 22.04+ recommended)
- NVIDIA GPU with drivers installed
- Docker Engine + Docker Compose v2
- `curl`, `bash` ≥ 5.0


### 1 — Clone & Configure

```bash
git clone https://github.com/your-username/agent-ai-ops.git
cd agent-ai-ops
cp .env.example .env
# Edit .env — set passwords and GPU device IDs
```


### 2 — Install & Launch

```bash
# Full automated installation (NVIDIA toolkit, directory structure, config files)
sudo bash agentai-ops.sh instalar

# Start all 15 services
bash agentai-ops.sh levantar

# Pull your first LLM model
bash agentai-ops.sh llms
```


### 3 — Access Services

| Interface | URL | Notes |
|---|---|---|
| **n8n** Automation | `http://HOST:5678` | Default: `Admin` / set in `.env` |
| **Open WebUI** | `http://HOST:8088` | Chat with local LLMs |
| **Grafana** | `http://HOST:3000` | Default: `admin` / set in `.env` |
| **Prometheus** | `http://HOST:9090` | Raw metrics explorer |
| **pgAdmin** | `http://HOST:5050` | Database management |
| **RedisInsight** | `http://HOST:5540` | Cache visualization |
| **Qdrant** | `http://HOST:6333` | Vector DB dashboard |


---


## Security

The stack is designed with a **defense-in-depth** approach at the network and host level.

**Network isolation** — Services are segregated across two Docker networks. Internal services (databases, exporters) are isolated on `agent-ai-network-internal` with `internal: true`, preventing any direct external access. Only UI-facing services join the external network.

**UFW Firewall** — Automated firewall configuration restricts all service ports to the local LAN subnet (`192.168.1.0/24`). External traffic is denied by default.

```bash
# Apply firewall rules + run security audit
bash agentai-ops.sh seguridad
```

**Lynis Audit** — The `seguridad` command installs and runs [Lynis](https://cisofy.com/lynis/), a hardening and compliance auditing tool, generating a full host security report at `/var/log/lynis-report.dat`.

**Environment secrets** — All passwords and credentials are stored exclusively in `.env` (never committed) and injected at container runtime. No credentials appear in image layers or compose definitions.


---


## Project Structure

```
agent-ai-ops/
├── agentai-ops.sh          # Infrastructure CLI — the single entry point
├── docker-compose.yml      # 15-service orchestration definition
├── .env                    # Environment variables & secrets (gitignored)
│
├── monitoring/
│   └── prometheus.yml      # Scrape configs for all exporters
│
├── n8n-data/               # n8n workflows, credentials, PDFs
├── ollama-data/            # Downloaded LLM model weights
├── qdrant-data/            # Vector index storage
├── postgres-data/          # PostgreSQL data files
├── redis-data/             # Redis AOF persistence
├── grafana-data/           # Grafana dashboards & plugins (named volume)
└── prometheus-data/        # Prometheus TSDB (named volume)
```


---


## Configuration Reference

Key environment variables in `.env`:

```bash
# GPU
NVIDIA_VISIBLE_DEVICES=0,1          # Comma-separated GPU indices
OLLAMA_GPU_LAYERS=35                # Layers offloaded to GPU
OLLAMA_MAX_LOADED_MODELS=2          # Models resident in VRAM simultaneously
QDRANT_GPU_INDEXING=1               # Enable GPU-accelerated HNSW indexing

# LLM
OLLAMA_MODEL=llama3.1:8b            # Default model pulled on first run

# Data Retention
N8N_EXECUTIONS_DATA_MAX_AGE=336     # Hours (14 days)
PROMETHEUS_RETENTION=30d            # Prometheus TSDB retention window

# Timezone
TIMEZONE=America/Mexico_City
```


---


## 📝 Licencia

Este proyecto está licenciado bajo la [Licencia GNU GPL v3](LICENSE).


---


<p align="center">
  <sub>© 2026 Ing. Daniel Humberto Reyes Rocha.</sub>
</p>


---
