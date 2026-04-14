from langchain_core.prompts import PromptTemplate

RETRIEVER_SYSTEM = """You are a search query formulation agent.
Extract the key search terms from the query to find relevant infrastructure logs.
Output ONLY the raw search query string.
"""

retriever_prompt = PromptTemplate.from_template(RETRIEVER_SYSTEM + "\n\nQuery: {query}\nSearch Terms:")
