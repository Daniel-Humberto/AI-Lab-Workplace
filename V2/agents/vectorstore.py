from qdrant_client import AsyncQdrantClient
from agents.config import settings
import structlog
from tenacity import retry, wait_exponential, stop_after_attempt
from langchain_ollama import OllamaEmbeddings

logger = structlog.get_logger()
client = AsyncQdrantClient(url=settings.QDRANT_URL)

# Instantiate the langchain embeddings model configured for our local Ollama container
embeddings = OllamaEmbeddings(
    model=settings.EMBEDDING_MODEL,
    base_url=settings.OLLAMA_BASE_URL
)

@retry(wait=wait_exponential(multiplier=1, min=2, max=10), stop=stop_after_attempt(3))
async def similarity_search(query: str, limit: int = settings.MAX_RETRIEVAL_DOCS):
    logger.info("Similarity search requested", query=query)
    
    # 1. Embed the query string
    try:
        query_vector = await embeddings.aembed_query(query)
    except Exception as e:
        logger.error("Failed to generate embeddings", error=str(e))
        return []
        
    # 2. Search across Qdrant using the generated vector
    try:
        hits = await client.search(
            collection_name=settings.QDRANT_COLLECTION,
            query_vector=query_vector,
            limit=limit
        )
        
        # 3. Return structure mapped to TypedDict `Document`
        return [
            {
                "content": str(hit.payload.get("page_content", hit.payload)), 
                "metadata": hit.payload.get("metadata", {})
            } 
            for hit in hits
        ]
    except Exception as e:
        logger.error("Failed to search Qdrant", error=str(e))
        return []
