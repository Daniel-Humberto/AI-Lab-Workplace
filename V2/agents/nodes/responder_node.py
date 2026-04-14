from agents.state import NeuralyticsState
from agents.tracing import traceable
from agents.config import settings
from langchain_ollama import ChatOllama
from langchain_core.messages import HumanMessage
import structlog

logger = structlog.get_logger()

try:
    llm = ChatOllama(
        model=settings.OLLAMA_MODEL,
        base_url=settings.OLLAMA_BASE_URL,
        temperature=0.0
    )
except Exception as e:
    logger.error("Failed to initialize ChatOllama in responder", error=str(e))
    llm = None

@traceable(name="responder_execution")
async def responder_node(state: NeuralyticsState) -> dict:
    if not llm:
        return {"response": f"Based on your query '{state['query']}', here is the analysis: {state.get('analysis', '')}"}
        
    prompt = f"""You are the final response generator for Neuralytics OS Platform.
Given the user's query: "{state['query']}"
And the underlying technical analysis:
{state.get('analysis', '')}

Formulate a clean, professional, concise response to the user. Present the findings clearly.
"""
    
    try:
        response = await llm.ainvoke([HumanMessage(content=prompt)])
        meta = response.response_metadata or {}
        
        new_in = meta.get("prompt_eval_count", 0)
        new_out = meta.get("eval_count", 0)
        
        existing_usage = state.get("token_usage", {"input": 0, "output": 0})
        total_usage = {
            "input": existing_usage.get("input", 0) + new_in,
            "output": existing_usage.get("output", 0) + new_out
        }
        
        return {
            "response": response.content,
            "token_usage": total_usage
        }
    except Exception as e:
        logger.error("Responder inference failed", error=str(e))
        return {
            "response": f"Based on your query '{state['query']}', here is the analysis: {state.get('analysis', '')}"
        }
