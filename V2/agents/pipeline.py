import uuid
import structlog
import time
from agents.graph import compiled_graph
from agents.state import NeuralyticsState

logger = structlog.get_logger()

async def run(query: str, session_id: str = None) -> dict:
    session_id = session_id or str(uuid.uuid4())
    logger.info("Starting pipeline execution", session_id=session_id)
    
    initial_state = NeuralyticsState(
        query=query,
        session_id=session_id,
        retrieved_docs=[],
        analysis=None,
        response=None,
        trace_id=str(uuid.uuid4()),
        confidence_score=0.0,
        token_usage={"input": 0, "output": 0},
        error=None
    )
    
    start_time = time.perf_counter()
    try:
        final_state = await compiled_graph.ainvoke(initial_state)
        latency_ms = int((time.perf_counter() - start_time) * 1000)
        
        return {
            "response": final_state.get("response", "No response generated."),
            "trace_id": final_state.get("trace_id"),
            "confidence": final_state.get("confidence_score", 0.0),
            "retrieved_docs_count": len(final_state.get("retrieved_docs", [])),
            "token_usage": final_state.get("token_usage", {}),
            "latency_ms": latency_ms
        }
    except Exception as e:
        logger.error("Pipeline failed", error=str(e))
        return {
            "error": "Pipeline execution failed",
            "details": str(e)
        }
