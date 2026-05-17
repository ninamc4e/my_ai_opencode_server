"""Пример MCP-инструмента: счётчик слов/символов/предложений.
Загрузить: POST /api/agents/mcp-tools/register
Body: { "name": "text_counter", "code": "<этот код>" }
"""


async def text_counter(text: str) -> str:
    """Анализирует текст: считает слова, символы, предложения.
    text: текст для анализа
    """
    words = len(text.split())
    chars = len(text)
    chars_no_spaces = len(text.replace(" ", ""))
    sentences = max(1, text.count(".") + text.count("!") + text.count("?") - text.count("..."))
    return (
        f"Анализ текста:\n"
        f"• Слов: {words}\n"
        f"• Символов (с пробелами): {chars}\n"
        f"• Символов (без пробелов): {chars_no_spaces}\n"
        f"• Предложений: {sentences}"
    )
