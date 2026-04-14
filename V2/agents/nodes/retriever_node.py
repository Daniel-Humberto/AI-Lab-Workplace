from agents.state import NeuralyticsState
from agents.vectorstore import similarity_search
from agents.tracing import traceable

@traceable(name="retriever_execution")
async def retriever_node(state: NeuralyticsState) -> dict:
    docs = await similarity_search(state["query"])
    return {"retrieved_docs": docs}
