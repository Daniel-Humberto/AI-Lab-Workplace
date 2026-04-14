import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content.lstrip('\n'))

def build():
    # Prometheus Config
    create_file("observability/prometheus/prometheus.yml", """
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/rules/alerts.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "fastapi-gateway"
    metrics_path: /metrics
    static_configs:
      - targets: ["fastapi-gateway:8000"]

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]

  - job_name: "node-exporter"
    scrape_interval: 30s
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "qdrant"
    scrape_interval: 30s
    metrics_path: /metrics
    static_configs:
      - targets: ["qdrant:6333"]

  - job_name: "ollama"
    static_configs:
      - targets: ["ollama:11434"]
""")

    # Prometheus Alerts
    create_file("observability/prometheus/rules/alerts.yml", """
groups:
  - name: neuralytics_alerts
    rules:
      - alert: HighAPILatency
        expr: histogram_quantile(0.95, rate(api_request_duration_seconds_bucket[5m])) > 2
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High API Latency on FastAPI"
          
      - alert: AgentLowConfidence
        expr: rate(agent_confidence_score_bucket{le="0.5"}[5m]) > 0.3
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Agent pipeline confidence dropping"

      - alert: ContainerMemoryHigh
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.85
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "Container Memory limits near 85%"

      - alert: OllamaDown
        expr: up{job="ollama"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Ollama instance unreachable"

      - alert: QdrantCollectionEmpty
        expr: qdrant_documents_total == 0
        for: 1m
        labels:
          severity: info
        annotations:
          summary: "Qdrant collection empty"
""")

    # Alertmanager
    create_file("observability/alertmanager/alertmanager.yml", """
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'n8n-webhook'

receivers:
  - name: 'n8n-webhook'
    webhook_configs:
      - url: 'http://fastapi-gateway:8000/webhooks/n8n/alert'
        send_resolved: true
""")

    # Grafana Provisioning
    create_file("observability/grafana/provisioning/datasources/prometheus.yaml", """
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
""")

    create_file("observability/grafana/provisioning/dashboards/dashboards.yaml", """
apiVersion: 1
providers:
  - name: 'Neuralytics Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
""")

    # Dashboards
    create_file("observability/grafana/dashboards/neuralytics_overview.json", """{
  "uid": "neuralytics-overview",
  "title": "Neuralytics Overview",
  "timezone": "browser",
  "refresh": "30s",
  "schemaVersion": 38,
  "panels": [
    {
      "type": "stat",
      "title": "API Health",
      "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 }
    }
  ]
}""")

    create_file("observability/grafana/dashboards/llm_performance.json", """{
  "uid": "llm-perf",
  "title": "LLM Performance Analytics",
  "schemaVersion": 38,
  "panels": []
}""")

    create_file("observability/grafana/dashboards/infrastructure.json", """{
  "uid": "infra-dash",
  "title": "Infrastructure Metrics",
  "schemaVersion": 38,
  "panels": []
}""")

    print("Observability stack completed successfully.")

if __name__ == "__main__":
    build()
