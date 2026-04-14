import pytest
from agents.pipeline import run

@pytest.mark.asyncio
async def test_pipeline_execution():
    result = await run("Test query")
    assert "response" in result
    assert result["confidence"] >= 0.0
