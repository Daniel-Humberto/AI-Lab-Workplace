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
