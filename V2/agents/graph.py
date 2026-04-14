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
