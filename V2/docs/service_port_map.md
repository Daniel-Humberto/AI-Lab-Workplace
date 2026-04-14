# Expected Service Port Mapping
This map ensures zero port conflicts on execution context.

| Service Name         | Port  | Protocol | Exposed To Host? | Health Endpoint                | Notes                                    |
|----------------------|-------|----------|------------------|--------------------------------|------------------------------------------|
| `fastapi-gateway`    | 8000  | HTTP/WS  | YES              | `/health` & `/ready`           | Core API                                 |
| `langsmith-console`  | 8001  | HTTP     | YES              | `/api/health`                  | Self-Hosted Tracing                      |
| `grafana`            | 3000  | HTTP     | YES              | `/api/health`                  | Visualizations                           |
| `n8n`                | 5678  | HTTP     | YES              | `/healthz`                     | Automation workflows                     |
| `qdrant`             | 6333  | HTTP     | YES              | `/readyz`                      | Vector DB                                |
| `ollama`             | 11434 | HTTP     | YES              | `/api/tags`                    | Target local model runtime               |
| `prometheus`         | 9090  | HTTP     | YES              | `/-/healthy`                   | Metrics                                  |
| `alertmanager`       | 9093  | HTTP     | NO               | `/-/healthy`                   | Prometheus alerting                      |
| `node-exporter`      | 9100  | HTTP     | NO               | `/metrics`                     | Host metrics                             |
| `cadvisor`           | 8080  | HTTP     | NO               | `/healthz`                     | Container hardware metrics               |
| `redis`              | 6379  | TCP      | NO               | `redis-cli ping`               | Used for ephemeral LangGraph states      |

**Constraint Check Successful:** 
No collisions between 8000, 8001, 3000, 5678, 6333, 11434, 9090, 8080, and 9100.
All expected boundaries mapped.
