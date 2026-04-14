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
