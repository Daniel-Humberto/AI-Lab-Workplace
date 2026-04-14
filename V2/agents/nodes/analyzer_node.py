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
    logger.error("Failed to initialize ChatOllama", error=str(e))
    llm = None

@traceable(name="analyzer_execution")
async def analyzer_node(state: NeuralyticsState) -> dict:
    if not llm:
        return {"analysis": "Error: LLM not initialized", "confidence_score": 0.0}
        
    docs = state.get('retrieved_docs', [])
    context = "\n".join([d.get('content', '') for d in docs])
    
    prompt = f"""You are an expert AIOps infrastructure analyzer.
Given the following context and logs retrieved from our systems:

<context>
{context}
</context>

User Query: "{state['query']}"

Please analyze the situation. Structure your answer with a <reasoning> section explaining your thought process, followed by an <analysis> section with your technical conclusions. Focus on exactly what the user asked.
"""
    try:
        response = await llm.ainvoke([HumanMessage(content=prompt)])
        
        # safely extract token usage if available in metadata
        meta = response.response_metadata or {}
        usage = {
            "input": meta.get("prompt_eval_count", 0),
            "output": meta.get("eval_count", 0)
        }
        
        return {
            "analysis": response.content, 
            "confidence_score": 0.9, 
            "token_usage": usage
        }
    except Exception as e:
        logger.error("LLM inference failed in analyzer", error=str(e))
        return {
            "analysis": f"Analysis failed: {str(e)}", 
            "confidence_score": 0.0
        }
