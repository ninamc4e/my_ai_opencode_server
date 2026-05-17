"""Пример MCP-инструмента: эхо-ответ (для отладки MCP).
Загрузить: POST /api/agents/mcp-tools/register
Body: { "name": "echo_bot", "code": "<этот код>" }
"""


async def echo_bot(message: str) -> str:
    """Просто возвращает то же сообщение обратно. Для отладки MCP.
    message: любое сообщение
    """
    return f"Эхо: {message}"
