"""Пример MCP-инструмента: текущее время в любом часовом поясе.
Загрузить: POST /api/agents/mcp-tools/register
Body: { "name": "current_time", "code": "<этот код>" }
"""
import asyncio
import subprocess
from datetime import datetime, timezone, timedelta


async def current_time(timezone_offset: str = "+3") -> str:
    """Возвращает текущее время в указанном часовом поясе.
    timezone_offset: смещение от UTC в формате "+3", "-5", "+4" (по умолч. +3 = Москва)
    """
    try:
        sign = 1 if timezone_offset.startswith("+") else -1
        hours = int(timezone_offset.lstrip("+-"))
        tz = timezone(timedelta(hours=sign * hours))
        now = datetime.now(tz)
        return now.strftime(f"Текущее время (UTC{timezone_offset}): %Y-%m-%d %H:%M:%S")
    except Exception as e:
        return f"Ошибка: {e}. Используй формат '+3', '-5' и т.д."
