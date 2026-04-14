from langchain_core.prompts import PromptTemplate

SUPERVISOR_SYSTEM = """You are the top-level supervisor routing requests.
Task: Evaluate the query and route it to ONE of the following agents:
- 'retriever': If the user requests logs, system state, metrics context, or internal data.
- 'analyzer': If the context requires reasoning over fetched data to diagnose a root cause.
- 'responder': If the user is just asking a general conversational query or final synthesis is ready.
Output ONLY the name of the route.
"""

supervisor_prompt = PromptTemplate.from_template(
    SUPERVISOR_SYSTEM + "\n\nQuery: {query}\nCurrent State: {state}\nRoute:"
)
