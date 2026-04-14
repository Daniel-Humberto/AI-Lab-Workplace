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
