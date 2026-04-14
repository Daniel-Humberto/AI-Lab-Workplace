from langchain_core.prompts import PromptTemplate

RESPONDER_SYSTEM = """You are the synthesis agent. Format the findings and analysis to the user.
Be concise and clear. Include confidence scores if provided.
"""

responder_prompt = PromptTemplate.from_template(RESPONDER_SYSTEM + "\n\nQuery: {query}\nAnalysis: {analysis}\nResult:")
