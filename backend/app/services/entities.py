import json
import uuid


def database_for_entity_id(entity_id):
    remainder = int(entity_id, 16) % 2
    return "helen1" if remainder == 0 else "helen2"


def decode_entity_body(body):
    if isinstance(body, str):
        raw = body
    else:
        raw = bytes(body).decode("utf-8")
    return json.loads(raw)


def build_mobile_login(mobile):
    return f"mobile:+86{mobile}"


async def put_entity_body(cur, entity_id, body):
    database = database_for_entity_id(entity_id)
    body_bytes = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    await cur.execute(
        f"""
        INSERT INTO {database}.entities (entity_id, body)
        VALUES (%s, %s)
        ON DUPLICATE KEY UPDATE body = %s
        """,
        (entity_id, body_bytes, body_bytes),
    )


async def get_or_create_mobile_entity(cur, mobile):
    login = build_mobile_login(mobile)
    await cur.execute(
        """
        SELECT entity_id
        FROM helen.index_login
        WHERE login = %s
        LIMIT 1
        """,
        (login,),
    )
    row = await cur.fetchone()
    if row:
        entity_id = row[0]
        database = database_for_entity_id(entity_id)
        body = await get_entity_body(cur, entity_id)
        return {
            "created": False,
            "mobile": mobile,
            "login": login,
            "entity_id": entity_id,
            "database": database,
            "body": body,
        }

    entity_id = uuid.uuid4().hex
    database = database_for_entity_id(entity_id)
    body = {
        "entity_id": entity_id,
        "mobile": mobile,
        "login": login,
    }
    body_bytes = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    await cur.execute(
        """
        INSERT INTO helen.index_login (login, entity_id, search)
        VALUES (%s, %s, %s)
        """,
        (login, entity_id, mobile),
    )
    await cur.execute(
        f"""
        INSERT INTO {database}.entities (entity_id, body)
        VALUES (%s, %s)
        """,
        (entity_id, body_bytes),
    )
    return {
        "created": True,
        "mobile": mobile,
        "login": login,
        "entity_id": entity_id,
        "database": database,
        "body": body,
    }


async def get_entity_body(cur, entity_id):
    database = database_for_entity_id(entity_id)
    await cur.execute(
        f"""
        SELECT body
        FROM {database}.entities
        WHERE entity_id = %s
        LIMIT 1
        """,
        (entity_id,),
    )
    row = await cur.fetchone()
    if not row:
        return None
    return decode_entity_body(row[0])
