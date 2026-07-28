from app.services.entities import build_mobile_login, delete_entity_bodies
from app.services.meditation import delete_meditation_records_json_for_user


async def delete_mobile_account(cur, mobile, entity_id):
    login = build_mobile_login(mobile)
    entity_ids = {entity_id}
    deleted_rows = {}

    chat_ids = await _fetch_first_column(
        cur,
        """
        SELECT chat_id
        FROM helen.chat_index
        WHERE user_entity_id = %s
        """,
        (entity_id,),
    )
    entity_ids.update(chat_ids)

    if chat_ids:
        entity_ids.update(
            await _fetch_first_column(
                cur,
                f"""
                SELECT block_id
                FROM helen.chat_blocks
                WHERE chat_id IN ({_placeholders(chat_ids)})
                """,
                chat_ids,
            )
        )
    trend_block_ids = await _fetch_first_column(
        cur,
        """
        SELECT block_id
        FROM helen.trend_report_blocks
        WHERE user_entity_id = %s
        """,
        (entity_id,),
    )
    entity_ids.update(trend_block_ids)

    meditation_block_ids = await _fetch_first_column(
        cur,
        """
        SELECT block_id
        FROM helen.meditation_blocks
        WHERE user_entity_id = %s
        """,
        (entity_id,),
    )
    entity_ids.update(meditation_block_ids)

    practice_ids = await _fetch_first_column(
        cur,
        """
        SELECT practice_id
        FROM helen.meditation_practice_records
        WHERE user_entity_id = %s
        """,
        (entity_id,),
    )
    entity_ids.update(practice_ids)

    if chat_ids:
        # Prompt versions are global application configuration, not user data.
        deleted_rows["chat_prompts"] = 0
        deleted_rows["chat_blocks"] = await _delete_where_in(cur, "helen.chat_blocks", "chat_id", chat_ids)
        deleted_rows["chat_index"] = await _delete_where_in(cur, "helen.chat_index", "chat_id", chat_ids)
    else:
        deleted_rows["chat_prompts"] = 0
        deleted_rows["chat_blocks"] = 0
        deleted_rows["chat_index"] = 0

    await cur.execute(
        """
        DELETE FROM helen.trend_report_blocks
        WHERE user_entity_id = %s
        """,
        (entity_id,),
    )
    deleted_rows["trend_report_blocks"] = cur.rowcount

    await cur.execute(
        """
        DELETE FROM helen.meditation_practice_records
        WHERE user_entity_id = %s
        """,
        (entity_id,),
    )
    deleted_rows["meditation_practice_records"] = cur.rowcount

    await cur.execute(
        """
        DELETE FROM helen.meditation_blocks
        WHERE user_entity_id = %s
        """,
        (entity_id,),
    )
    deleted_rows["meditation_blocks"] = cur.rowcount

    await cur.execute(
        """
        DELETE FROM helen.index_login
        WHERE login = %s AND entity_id = %s
        """,
        (login, entity_id),
    )
    deleted_rows["index_login"] = cur.rowcount
    deleted_rows["entities"] = await delete_entity_bodies(cur, entity_ids)

    delete_meditation_records_json_for_user(entity_id)

    return {
        "deleted": True,
        "mobile": mobile,
        "login": login,
        "block_id": entity_id,
        "deleted_rows": deleted_rows,
    }


async def _fetch_first_column(cur, sql, args):
    await cur.execute(sql, args)
    return [row[0] for row in await cur.fetchall()]


async def _delete_where_in(cur, table, column, values):
    await cur.execute(
        f"""
        DELETE FROM {table}
        WHERE {column} IN ({_placeholders(values)})
        """,
        values,
    )
    return cur.rowcount


def _placeholders(values):
    return ", ".join(["%s"] * len(values))
