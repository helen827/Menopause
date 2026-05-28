import asyncio
from pathlib import Path

import aiomysql
from dotenv import load_dotenv

import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.config import get_settings  # noqa: E402


async def main():
    load_dotenv(ROOT / ".env")
    settings = get_settings()
    schema = (ROOT / "schema.sql").read_text(encoding="utf-8")

    conn = await aiomysql.connect(
        host=settings.mysql_host,
        port=settings.mysql_port,
        user=settings.mysql_user,
        password=settings.mysql_password,
        autocommit=True,
        charset="utf8mb4",
    )
    try:
        async with conn.cursor() as cur:
            for statement in [part.strip() for part in schema.split(";") if part.strip()]:
                await cur.execute(statement)
    finally:
        conn.close()

    print(f"Database initialized: {settings.mysql_database}")


if __name__ == "__main__":
    asyncio.run(main())
