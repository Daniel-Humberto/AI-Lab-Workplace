# Neuralytics OS Architecture Design

## STEP 1 — LAYER DECOMPOSITION

The Neuralytics OS is decomposed into five primary layers:

1. **Infrastructure Layer**
   - **Primary Tech:** Docker Compose (local) / Kubernetes + Terraform (cloud)
   - **Backup/Alternative:** Raw VM provisioning via Ansible
   - **Failure Mode:** System unresourced or port conflicts.

2. **Inference Layer**
   - **Primary Tech:** Ollama (inference) + Qdrant (vector DB RAG)
   - **Backup/Alternative:** Cloud APIs (OpenAI) / Pinecone
   - **Failure Mode:** OOM on GPU / Container crashes on large context.

3. **Agent / Orchestration Layer**
   - **Primary Tech:** LangGraph + LangSmith (Tracing)
   - **Backup/Alternative:** AutoGen / CrewAI / local file tracing
   - **Failure Mode:** Prompt drift, looping agent states, or context limit overflow.

4. **API Gateway Layer**
   - **Primary Tech:** FastAPI (REST + WebSockets)
   - **Backup/Alternative:** Express.js / Go Gin
   - **Failure Mode:** Event loop blockage on LLM calls / WebSocket timeout.

5. **Observability Layer**
   - **Primary Tech:** Prometheus + Grafana + Cadvisor
   - **Backup/Alternative:** Datadog / New Relic
   - **Failure Mode:** Alert fatigue, un-indexed metrics, lost telemetry data.

---

## STEP 2 — INTERFACE CONTRACT DESIGN

- **HTTP APIs:** Defined strictly in OpenAPI 3.1 YAML schema (`interface_contracts.yaml`).
- **Async Events:** N8N to FastAPI Webhooks (`/webhooks/n8n/alert`) push models. Producer: Prometheus AlertManager -> N8N. Consumer: FastAPI.
- **File Contracts:** N8N json workflows exported natively; Grafana provisioned entirely by explicit code mapped in `observability/grafana/dashboards`.
- **Shared State:** 
  - Redis keys limit state persistence strictly for LangGraph checkpointers.
  - Qdrant Collection named `neuralytics-logs`.
  - Prometheus Metric standardized prefixes e.g., `api_requests_total`, `agent_confidence_score_bucket`.

---

## STEP 3 — TREE OF THOUGHTS: CRITICAL DECISIONS

### Q1: LangGraph state persistence — Redis vs Postgres?
- **Option 1: Redis** 
  - Advantages: Excellent for short-lived ephemeral states in multi-agent routing. Faster memory I/O.
- **Option 2: Postgres**
  - Advantages: Highly durable, robust search space natively for complex state replay.
- **Decision:** **Redis**. 
- **Rationale:** We are optimizing for speed in local routing loops and easy deployment on portfolio K3s clusters rather than deep long-term history archiving. The multi-agent RAG workflow functions on quick ephemeral states.
- **Trade-off:** Loss of state if Redis restarts without AOF configured, but acceptable for this architecture where inputs are stateless REST calls.

### Q2: Ollama serving strategy — single container vs sidecar per agent?
- **Option 1: Single Centralized Container**
  - Advantages: Shared VRAM limits context duplication, simpler port management and easier local testing on GPUs with constrained resources.
- **Option 2: Sidecar per agent**
  - Advantages: Excellent workload isolation and scaling under K8s HPA per-agent load.
- **Decision:** **Single Centralized Container**.
- **Rationale:** The target environment is an HP Victus with an RTX 4050 6GB VRAM. Multiplexing LLMs across sidecars would immediately OOM kill the system. One localized Ollama instance ensures memory safety.
- **Trade-off:** A bottleneck occurs if multiple LangGraph agents call Ollama concurrently; latency per inference will pile up sequentially on the centralized queue.

### Q3: N8N ↔ FastAPI integration — webhook push vs polling?
- **Option 1: Webhook Push**
  - Advantages: Real-time responsiveness, fully event-driven, minimal idle resource drain.
- **Option 2: Polling**
  - Advantages: Resilient to network partitions, easy rate-limit enforcement.
- **Decision:** **Webhook Push**.
- **Rationale:** Observability rules rely on immediate intervention for Prometheus alerts. Waiting for a polling interval defeats the MTTR (Mean Time to Resolution) benefits of an AIOps stack.
- **Trade-off:** If the FastAPI gateway crashes, incoming N8N webhook alerts could be dropped. Mitigated by N8N retry mechanisms.
