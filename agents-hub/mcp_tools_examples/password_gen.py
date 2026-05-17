"""Пример MCP-инструмента: генератор безопасных паролей.
Загрузить: POST /api/agents/mcp-tools/register
Body: { "name": "password_gen", "code": "<этот код>" }
"""
import secrets
import string


async def password_gen(length: int = 16, use_symbols: bool = True) -> str:
    """Генерирует безопасный случайный пароль.
    length: длина пароля (8-64, по умолч. 16)
    use_symbols: включать ли спецсимволы (!@#$% etc)
    """
    length = max(8, min(64, length))
    chars = string.ascii_letters + string.digits
    if use_symbols:
        chars += "!@#$%^&*()_+-=[]{}|;:,.<>?"
    password = "".join(secrets.choice(chars) for _ in range(length))
    return f"Пароль ({length} символов): {password}"
