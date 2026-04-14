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
