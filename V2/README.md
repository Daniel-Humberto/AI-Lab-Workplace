# 🚀 Neuralytics OS

> Enterprise-grade, self-hosted, cloud-ready, and observable multi-agent AIOps platform.

[![CI](https://github.com/Neuralytics/neuralytics-os/actions/workflows/ci.yml/badge.svg)](https://github.com/Neuralytics/neuralytics-os/actions)

## 📖 Overview

**Neuralytics OS** is an advanced AIOps platform that leverages a multi-agent architecture to monitor, analyze, and resolve infrastructure incidents autonomously. Built around LangGraph, it indexes system logs securely into a local Qdrant vector database, intercepts Prometheus alerts via n8n webhook pipelines, and utilizes Ollama-driven LLMs to synthesize actionable remediation strategies—all without your data ever leaving your secure environment.

Designed from the ground up for cloud-agnostic deployment, this platform is production-ready via Terraform and fully observable through Prometheus and Grafana.

---

## ✨ Key Features

- **Multi-Agent Orchestration**: LangGraph-based workflow natively handling state management and complex routing without recursive prompt drift.
- **Local AI Inference & RAG**: On-premise language models powered by Ollama and Qdrant, delivering high-performance embeddings and strict data privacy (functional on a 6GB VRAM constraint).
- **Automated Incident Response**: n8n workflows that orchestrate complex webhook receptions from Prometheus AlertManager to our agents.
- **Async API Gateway**: FastAPI providing robust asynchronous REST and WebSocket endpoints, ensuring the event loop remains unblocked during heavy token generation.
- **Kube-Native Infrastructure**: Transition seamlessly from local Docker Compose validation to cloud EKS deployments with K3s and Terraform.

---

## 🏛️ Architecture & Stack

Please refer to the detailed [System Architecture Design](docs/architecture.md) for deeper insights.

![Architecture Setup](docs/architecture.mermaid) *(Note: Render natively via Mermaid)*

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Orchestration** | LangGraph & LangSmith | Flexible state checkpointer for multi-agent routing. |
| **Inference/RAG** | Ollama + Qdrant | Secure, offline data retention with aggressively low-latency embeddings on consumer GPUs. |
| **Automation** | n8n | Powerful workflow engine for intercepting and handling Prometheus AlertManager alerts. |
| **Gateway** | FastAPI + Uvicorn | Async-native design prevents event-loop blocking on resource-intensive LLM requests. |
| **Infrastructure** | K3s, Terraform, Docker | Frictionless transition from local validation to robust cloud-native deployments. |
| **Observability** | Prometheus, Grafana, cAdvisor | Full telemetry stack out-of-the-box. |

---

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Minimum 6GB VRAM (NVIDIA GPU recommended)
- Git & Make

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Neuralytics/neuralytics-os.git
   cd neuralytics-os
   ```

2. **Bootstrap the platform:**
   This will build the necessary images and start the services detached.
   ```bash
   chmod +x bootstrap.sh
   ./bootstrap.sh
   ```

### 🧭 Accessing the Interfaces

Once the bootstrap script completes successfully, the platform interfaces are available at:

- **FastAPI Documentation:** [http://localhost:8000/docs](http://localhost:8000/docs)
- **Grafana Dashboards:** [http://localhost:3000](http://localhost:3000) *(Default Login: `admin` / `admin`)*
- **n8n Workflow Engine:** [http://localhost:5678](http://localhost:5678)
- **LangSmith Tracing:** [http://localhost:8001](http://localhost:8001)

Check logs anytime with:
```bash
docker compose logs -f
```

---

## 📂 Project Structure

```text
├── agents/         # LangGraph nodes, pipelines, prompts, and vectorstore logic
├── api/            # FastAPI gateway and specialized routers (health, metrics, webhooks)
├── docs/           # System documentations and architecture models
├── infra/          # Cloud deployment templates (Kubernetes, Terraform, n8n workflows)
├── observability/  # Prometheus configurations, alert rules, and Grafana dashboards
├── tests/          # Testing suite for pipelines and agents
└── bootstrap.sh    # Comprehensive initialization script
```

---

## 📚 Documentation

For an in-depth understanding, please review our comprehensive documentation:
- 🏗️ [System Architecture Details](docs/architecture.md)
- ☁️ [Cloud Deployment Instructions](docs/cloud_deployment.md)
- 🧠 [LLMOps Methodology](docs/llmops.md)
- 🔌 [Interface Contracts](docs/interface_contracts.yaml)
- 🗺️ [Service Port Map](docs/service_port_map.md)

---

## 🛡️ License & Portfolio Notes

This project showcases end-to-end AI engineering bridging the gap between isolated Jupyter notebook scripts and fully observable, fault-tolerant Kube-native architectures.
