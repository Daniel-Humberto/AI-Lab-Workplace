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
