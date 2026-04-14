import os
import textwrap

def create_file(path, content):
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, 'w') as f:
        f.write(textwrap.dedent(content).lstrip('\n'))

def build():
    # GitHub CI
    create_file(".github/workflows/ci.yml", """
        name: Neuralytics OS CI
        on:
          push:
            branches: [ main ]
          pull_request:
            branches: [ main ]
        jobs:
          test:
            runs-on: ubuntu-24.04
            steps:
              - uses: actions/checkout@v3
              - uses: actions/setup-python@v4
                with:
                  python-version: '3.11'
              - run: pip install -r api/requirements.txt
              - run: ruff check .
              - run: black --check .
              - run: pytest tests/ --cov=. --cov-report=term-missing
          docker-build:
            runs-on: ubuntu-24.04
            steps:
              - uses: actions/checkout@v3
              - run: docker-compose build
          security-scan:
            runs-on: ubuntu-24.04
            steps:
              - uses: actions/checkout@v3
              - name: Run Trivy vulnerability scanner
                uses: aquasecurity/trivy-action@master
                with:
                  scan-type: 'fs'
                  format: 'table'
    """)

    # docs/llmops.md
    create_file("docs/llmops.md", """
        # LLMOps Pipeline Details

        Neuralytics OS implements a multi-agent orchestrated pipeline using **LangGraph**. The workflow relies on:
        1. **State Machine Design:** Utilizing a strongly typed state representation (`NeuralyticsState`) to ensure immutability and robust transitions. Checkpointing uses Redis.
        2. **Retrieval Strategy:** Async Qdrant operations vectorizing telemetry using `nomic-embed-text`.
        3. **Confidence Scoring:** Outputs are assessed directly in prompt reasoning (`<confidence>HIGH|LOW</confidence>`) to govern fallback triggers.
        4. **LangSmith Tracing:** Deep integrations enabling span-level latency inspection and token usage attribution to catch inference drifts over time.
    """)

    # docs/cloud_deployment.md
    create_file("docs/cloud_deployment.md", """
        # Cloud Deployment Guide
        
        Neuralytics OS targets agnostic, cloud-ready execution via Terraform-based IaC provisioning.
        
        ### AWS EKS (Recommended)
        Use `infra/terraform/modules/eks` to automatically spin up a `t3.medium` cluster.
        
        **Command:**
        ```bash
        cd infra/terraform
        terraform init
        terraform apply -var="cluster_name=neuralytics-prod"
        ```
        
        **Cost Estimation:** ~$150/mo.  
        Ensure GPU node groups are scaled if `ollama` workloads intensify natively versus relying on remote API calls.
    """)

    # README.md
    create_file("README.md", """
        # 🚀 Neuralytics OS
        > Self-hosted, cloud-ready, observable multi-agent AI platform
        
        [![CI](https://github.com/Neuralytics/neuralytics-os/actions/workflows/ci.yml/badge.svg)](https://github.com/Neuralytics/neuralytics-os/actions)

        ## What This Is
        Neuralytics OS is an enterprise-grade AIOps agent pipeline designed to monitor its own infrastructure. It leverages a LangGraph-based multi-agent system to index system logs into Qdrant, handle Prometheus alerts via N8N webhooks, and synthesize actions using Ollama inference—all securely hosted within your environment.

        Designed for cloud-agnostic deployment, this platform is production-ready via Terraform and deeply observable via Prometheus and Grafana.

        ## Architecture
        ![Architecture Setup](docs/architecture.mermaid) *(Note: Render natively via Mermaid)*

        ## Stack
        | Component | Technology | Why This Choice |
        |---|---|---|
        | **Orchestration** | LangGraph | State checkpointer flexibility without recursive prompt drift. |
        | **Inference/RAG** | Ollama + Qdrant | Keeps data locked-in securely and runs aggressively low-latency embeddings on 6GB VRAM. |
        | **Automation** | N8N | Open-source alternative to Zapier, allowing complex looping Webhook receivers from Prometheus. |
        | **Gateway** | FastAPI + Uvicorn | Async native guarantees preventing event-loop blockage on heavy model token generation. |
        | **Infrastructure** | K3s + Terraform + Compose | Easiest transition from local docker validation directly to cloud EKS deployment. |

        ## Quick Start
        ```bash
        git clone https://github.com/Neuralytics/neuralytics-os.git
        cd neuralytics-os
        chmod +x bootstrap.sh
        ./bootstrap.sh
        ```

        ## Demo
        API docs will be available at `http://localhost:8000/docs`.  
        Observability overview dynamically populates at `http://localhost:3000`.

        ## Links
        - [LLMOps Methodology](docs/llmops.md)
        - [System Architecture Details](docs/architecture.md)
        - [Cloud Deployment instructions](docs/cloud_deployment.md)

        ## Portfolio Notes
        This project showcases end-to-end AI engineering bridging the gap between isolated Jupyter notebook scripts and fully observable, fault-tolerant Kube-native architectures.
    """)

    # .gitignore
    create_file(".gitignore", """
        .env
        *.key
        *.pem
        terraform.tfstate
        terraform.tfstate.backup
        .terraform/
        __pycache__/
        *.pyc
        .pytest_cache/
        .coverage
    """)

    print("Portfolio layer generated successfully.")

if __name__ == "__main__":
    build()
