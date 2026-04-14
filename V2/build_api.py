import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content.lstrip('\n'))

def build():
    create_file("api/__init__.py", "")

    create_file("api/main.py", """
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import structlog
from contextlib import asynccontextmanager
from api.routers import agent, health, webhooks, metrics

logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing FastAPI Lifespan")
    # Warm up agents here if needed
    yield
    logger.info("Shutting down")

app = FastAPI(
    title="Neuralytics OS Gateway API",
    version="1.0.0",
    lifespan=lifespan
)

@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    logger.info("Request started", method=request.method, url=str(request.url))
    try:
        response = await call_next(request)
        logger.info("Request finished", status_code=response.status_code)
        return response
    except Exception as e:
        logger.error("Internal server error", error=str(e))
        return JSONResponse(status_code=500, content={"error": "internal_error", "details": str(e)})

app.include_router(agent.router)
app.include_router(health.router)
app.include_router(webhooks.router)
app.include_router(metrics.router)
""")

    create_file("api/routers/__init__.py", "")
    
    create_file("api/routers/agent.py", """
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, Dict

router = APIRouter(prefix="/api/v1/agent", tags=["Agents"])

class QueryRequest(BaseModel):
    query: str
    session_id: Optional[str] = None

class QueryResponse(BaseModel):
    response: str
    trace_id: str
    confidence: float
    retrieved_docs_count: int
    token_usage: Dict[str, int]
    latency_ms: int

@router.post("/query", response_model=QueryResponse)
async def query_agent(request: QueryRequest):
    from agents.pipeline import run
    result = await run(request.query, request.session_id)
    return QueryResponse(**result)
""")

    create_file("api/routers/health.py", """
from fastapi import APIRouter, status
from fastapi.responses import JSONResponse

router = APIRouter(tags=["Health"])

@router.get("/health", status_code=status.HTTP_200_OK)
async def health():
    return {"status": "ok", "services": {"database": "ok", "ollama": "ok"}}

@router.get("/ready", status_code=status.HTTP_200_OK)
async def ready():
    # Placeholder for actual dependent checks
    return {"status": "ready"}
""")

    create_file("api/routers/metrics.py", """
from fastapi import APIRouter
from fastapi.responses import PlainTextResponse

router = APIRouter(tags=["Metrics"])

@router.get("/metrics", response_class=PlainTextResponse)
async def metrics():
    return "# HELP api_requests_total Total API Requests\\n# TYPE api_requests_total counter\\napi_requests_total{method=\\"GET\\",endpoint=\\"/health\\",status=\\"200\\"} 1\\n"
""")

    create_file("api/routers/webhooks.py", """
from fastapi import APIRouter, status
from fastapi.responses import Response

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])

@router.post("/n8n/alert", status_code=status.HTTP_202_ACCEPTED)
async def n8n_alert_webhook(payload: dict):
    # Process payload
    return Response(status_code=status.HTTP_202_ACCEPTED)
""")

    create_file("api/Dockerfile", """
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ENV PYTHONPATH="/app"
COPY ./api ./api
COPY ./agents ./agents

EXPOSE 8000
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
""")

    create_file("api/requirements.txt", """
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.5.2
pydantic-settings==2.1.0
structlog==23.2.0
langgraph>=0.0.10
langchain-core>=0.1.0
qdrant-client>=1.6.4
tenacity==8.2.3
pytest==7.4.3
pytest-asyncio==0.21.1
""")

    create_file("infra/n8n/workflows/alerting_pipeline.json", """{
  "name": "Alerting Pipeline",
  "nodes": [],
  "connections": {},
  "active": false,
  "settings": {}
}""")

    create_file("infra/n8n/workflows/ingestion_scheduler.json", """{
  "name": "Ingestion Scheduler",
  "nodes": [],
  "connections": {},
  "active": false,
  "settings": {}
}""")

    print("API layer completed successfully.")

if __name__ == "__main__":
    build()
