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
