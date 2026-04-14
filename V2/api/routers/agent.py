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
