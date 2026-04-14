from fastapi import APIRouter
from fastapi.responses import PlainTextResponse

router = APIRouter(tags=["Metrics"])

@router.get("/metrics", response_class=PlainTextResponse)
async def metrics():
    return "# HELP api_requests_total Total API Requests\n# TYPE api_requests_total counter\napi_requests_total{method=\"GET\",endpoint=\"/health\",status=\"200\"} 1\n"
