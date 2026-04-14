from fastapi import APIRouter, status
from fastapi.responses import Response

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])

@router.post("/n8n/alert", status_code=status.HTTP_202_ACCEPTED)
async def n8n_alert_webhook(payload: dict):
    # Process payload
    return Response(status_code=status.HTTP_202_ACCEPTED)
