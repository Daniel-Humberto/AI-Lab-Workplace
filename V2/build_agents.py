import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content.lstrip('\n'))

def build():
    # Base Agents Directory
    create_file("agents/__init__.py", "")

    create_file("agents/config.py", """
from pydantic_settings import BaseSettings, SettingsConfigDict

class Config(BaseSettings):
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    QDRANT_URL: str = "http://localhost:6333"
    QDRANT_COLLECTION: str = "neuralytics-logs"
    LANGSMITH_API_KEY: str = ""
    LANGSMITH_PROJECT: str = "neuralytics-os"
    OLLAMA_MODEL: str = "llama3.2:3b"
    EMBEDDING_MODEL: str = "nomic-embed-text"
    MAX_RETRIEVAL_DOCS: int = 5
    CONFIDENCE_THRESHOLD: float = 0.6
    MAX_TOKENS_PER_CALL: int = 1024

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Config()
""")

    create_file("agents/state.py", """
from typing import TypedDict, List, Optional, Dict
from typing_extensions import NotRequired

class Document(TypedDict):
    content: str
    metadata: Dict[str, str]

class NeuralyticsState(TypedDict):
    query: str
    session_id: str
    retrieved_docs: List[Document]
    analysis: Optional[str]
    response: Optional[str]
    trace_id: str
    confidence_score: float
    token_usage: Dict[str, int]
    error: Optional[str]
    retries: NotRequired[int]
""")

    # Prompts
    create_file("agents/prompts/supervisor.py", """
from langchain_core.prompts import PromptTemplate

SUPERVISOR_SYSTEM = \"\"\"You are the top-level supervisor routing requests.
Task: Evaluate the query and route it to ONE of the following agents:
- 'retriever': If the user requests logs, system state, metrics context, or internal data.
- 'analyzer': If the context requires reasoning over fetched data to diagnose a root cause.
- 'responder': If the user is just asking a general conversational query or final synthesis is ready.
Output ONLY the name of the route.
\"\"\"

supervisor_prompt = PromptTemplate.from_template(
    SUPERVISOR_SYSTEM + "\\n\\nQuery: {query}\\nCurrent State: {state}\\nRoute:"
)
""")

    create_file("agents/prompts/retriever.py", """
from langchain_core.prompts import PromptTemplate

RETRIEVER_SYSTEM = \"\"\"You are a search query formulation agent.
Extract the key search terms from the query to find relevant infrastructure logs.
Output ONLY the raw search query string.
\"\"\"

retriever_prompt = PromptTemplate.from_template(RETRIEVER_SYSTEM + "\\n\\nQuery: {query}\\nSearch Terms:")
""")

    create_file("agents/prompts/analyzer.py", """
from langchain_core.prompts import PromptTemplate

ANALYZER_SYSTEM = \"\"\"You are an analytical AI agent. Your role is to reason about retrieved
information and extract key insights. Always output your analysis in this exact format:
<reasoning>Step-by-step reasoning here</reasoning>
<analysis>Concise summary of key findings</analysis>
<confidence>HIGH|MEDIUM|LOW</confidence>
Do not include information not present in the retrieved documents.
\"\"\"

analyzer_prompt = PromptTemplate.from_template(ANALYZER_SYSTEM + "\\n\\nDocuments: {documents}\\nQuery: {query}\\nAnalysis:")
""")

    create_file("agents/prompts/responder.py", """
from langchain_core.prompts import PromptTemplate

RESPONDER_SYSTEM = \"\"\"You are the synthesis agent. Format the findings and analysis to the user.
Be concise and clear. Include confidence scores if provided.
\"\"\"

responder_prompt = PromptTemplate.from_template(RESPONDER_SYSTEM + "\\n\\nQuery: {query}\\nAnalysis: {analysis}\\nResult:")
""")

    # Tracing
    create_file("agents/tracing.py", """
import os
import structlog
from functools import wraps

logger = structlog.get_logger()

# Minimal LangSmith tracing decorator mock
def traceable(name=None):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            logger.info("Executing traced function", func_name=name or func.__name__)
            try:
                result = await func(*args, **kwargs)
                return result
            except Exception as e:
                logger.error("Function failed", func_name=name or func.__name__, error=str(e))
                raise
        return wrapper
    return decorator
""")

    # Vector Store
    create_file("agents/vectorstore.py", """
from qdrant_client import AsyncQdrantClient
from agents.config import settings
import structlog
from tenacity import retry, wait_exponential, stop_after_attempt

logger = structlog.get_logger()
client = AsyncQdrantClient(url=settings.QDRANT_URL)

@retry(wait=wait_exponential(multiplier=1, min=2, max=10), stop=stop_after_attempt(3))
async def similarity_search(query: str, limit: int = settings.MAX_RETRIEVAL_DOCS):
    logger.info("Similarity search requested", query=query)
    # Placeholder for actual embedding + search
    return [{"content": f"Mock result for {query}", "metadata": {}}]
""")

    # Nodes
    create_file("agents/nodes/__init__.py", "")
    create_file("agents/nodes/supervisor_node.py", """
from agents.state import NeuralyticsState

async def supervisor_node(state: NeuralyticsState) -> str:
    # Simplified routing logic
    docs = state.get("retrieved_docs", [])
    analysis = state.get("analysis", None)
    
    if not docs:
        return "retriever"
    elif docs and not analysis:
        return "analyzer"
    else:
        return "responder"
""")

    create_file("agents/nodes/retriever_node.py", """
from agents.state import NeuralyticsState
from agents.vectorstore import similarity_search
from agents.tracing import traceable

@traceable(name="retriever_execution")
async def retriever_node(state: NeuralyticsState) -> dict:
    docs = await similarity_search(state["query"])
    return {"retrieved_docs": docs}
""")

    create_file("agents/nodes/analyzer_node.py", """
from agents.state import NeuralyticsState
from agents.tracing import traceable

@traceable(name="analyzer_execution")
async def analyzer_node(state: NeuralyticsState) -> dict:
    analysis = f"<reasoning>Analyzed context.</reasoning>\\n<analysis>Found {len(state.get('retrieved_docs', []))} logs</analysis>\\n<confidence>HIGH</confidence>"
    return {"analysis": analysis, "confidence_score": 0.9}
""")

    create_file("agents/nodes/responder_node.py", """
from agents.state import NeuralyticsState
from agents.tracing import traceable

@traceable(name="responder_execution")
async def responder_node(state: NeuralyticsState) -> dict:
    response = f"Based on your query '{state['query']}', here is the analysis: {state.get('analysis', '')}"
    return {"response": response}
""")

    # Graph
    create_file("agents/graph.py", """
from langgraph.graph import StateGraph, END
from agents.state import NeuralyticsState
from agents.nodes.supervisor_node import supervisor_node
from agents.nodes.retriever_node import retriever_node
from agents.nodes.analyzer_node import analyzer_node
from agents.nodes.responder_node import responder_node

def build_graph():
    graph = StateGraph(NeuralyticsState)
    
    graph.add_node("retriever", retriever_node)
    graph.add_node("analyzer", analyzer_node)
    graph.add_node("responder", responder_node)
    
    graph.set_conditional_entry_point(
        supervisor_node,
        {
            "retriever": "retriever",
            "analyzer": "analyzer",
            "responder": "responder"
        }
    )
    
    graph.add_edge("retriever", "analyzer")
    graph.add_edge("analyzer", "responder")
    graph.add_edge("responder", END)
    
    return graph.compile()

compiled_graph = build_graph()
""")

    # Pipeline
    create_file("agents/pipeline.py", """
import uuid
import structlog
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
    
    try:
        final_state = await compiled_graph.ainvoke(initial_state)
        return {
            "response": final_state.get("response", "No response generated."),
            "trace_id": final_state.get("trace_id"),
            "confidence": final_state.get("confidence_score", 0.0),
            "retrieved_docs_count": len(final_state.get("retrieved_docs", [])),
            "token_usage": final_state.get("token_usage", {}),
            "latency_ms": 100 # Mock latency metrics
        }
    except Exception as e:
        logger.error("Pipeline failed", error=str(e))
        return {
            "error": "Pipeline execution failed",
            "details": str(e)
        }
""")

    # Tests Setup
    create_file("tests/agents/__init__.py", "")
    create_file("tests/agents/test_pipeline.py", """
import pytest
from agents.pipeline import run

@pytest.mark.asyncio
async def test_pipeline_execution():
    result = await run("Test query")
    assert "response" in result
    assert result["confidence"] >= 0.0
""")

    print("Agent Pipeline files completed successfully.")

if __name__ == "__main__":
    build()
