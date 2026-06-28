import json
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from app.services.entities import get_entity_body, put_entity_body
from app.services.trend_report import SYMPTOM_RULES


MEDITATION_RECORDS_FILE = Path(__file__).resolve().parents[2] / "content" / "meditation_records.json"


MODE_RHYTHMS = {
    "mood": {
        "key": "mood",
        "label": "舒缓心情",
        "scene": "柔风麦田",
        "rhythm_text": "吸 4 秒，呼 6 秒",
        "phases": [
            {"phase": "inhale", "label": "吸气", "seconds": 4},
            {"phase": "exhale", "label": "呼气", "seconds": 6},
        ],
        "target_symptoms": ["anxiety"],
    },
    "sleep": {
        "key": "sleep",
        "label": "助眠安睡",
        "scene": "深睡轨道",
        "rhythm_text": "吸 4 秒，停 7 秒，呼 8 秒",
        "phases": [
            {"phase": "inhale", "label": "吸气", "seconds": 4},
            {"phase": "hold", "label": "停留", "seconds": 7},
            {"phase": "exhale", "label": "呼气", "seconds": 8},
        ],
        "target_symptoms": ["poor_sleep"],
    },
    "hot_flash": {
        "key": "hot_flash",
        "label": "缓解潮热",
        "scene": "清凉潮汐",
        "rhythm_text": "吸 5 秒，呼 5 秒",
        "phases": [
            {"phase": "inhale", "label": "吸气", "seconds": 5},
            {"phase": "exhale", "label": "呼气", "seconds": 5},
        ],
        "target_symptoms": ["hot_flash"],
    },
}

MODE_ALIASES = {
    "舒缓心情": "mood",
    "mood_reset": "mood",
    "calm": "mood",
    "助眠安睡": "sleep",
    "sleep_reset": "sleep",
    "insomnia": "sleep",
    "缓解潮热": "hot_flash",
    "cool": "hot_flash",
    "hotflash": "hot_flash",
}


def build_empty_meditation_block(user_entity_id, block_id):
    return {
        "entity_type": "meditation_block",
        "block_id": block_id,
        "user_entity_id": user_entity_id,
        "title": "冥想练习数据",
        "practice_ids": [],
        "practices": [],
        "stats": {
            "total_practice_count": 0,
            "completed_practice_count": 0,
            "total_duration_seconds": 0,
            "latest_practice_id": None,
            "latest_practice_at": None,
            "mode_counts": {},
        },
        "createtime": now_iso(),
        "updatetime": now_iso(),
    }


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def parse_datetime(value):
    if not value:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    text = str(value).strip()
    if text.endswith("Z"):
        text = f"{text[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def mode_from_payload(payload):
    raw_key = str(payload.get("mode_key") or payload.get("mode") or "").strip()
    key = MODE_ALIASES.get(raw_key, raw_key)
    if key not in MODE_RHYTHMS:
        raise ValueError("mode_key must be one of mood, sleep, hot_flash")
    return MODE_RHYTHMS[key]


def _safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


async def record_meditation_practice(cur, user_entity_id, payload):
    mode = mode_from_payload(payload)
    practice_id = str(payload.get("practice_id") or uuid.uuid4().hex).replace("-", "").lower()
    if len(practice_id) != 32:
        raise ValueError("practice_id must be a 32-character hex string")

    started_at = parse_datetime(payload.get("started_at") or payload.get("practice_date"))
    ended_at = parse_datetime(payload.get("ended_at") or payload.get("completed_at"))
    duration_seconds = _safe_int(payload.get("duration_seconds"), 0)
    cycle_count = _safe_int(payload.get("cycle_count") or payload.get("cycles"), 0)

    if not started_at:
        started_at = datetime.now(timezone.utc)
    if not ended_at and duration_seconds > 0:
        ended_at = started_at + timedelta(seconds=duration_seconds)
    if ended_at and duration_seconds <= 0:
        duration_seconds = max(0, int((ended_at - started_at).total_seconds()))

    completed = bool(payload.get("completed", True))
    source = str(payload.get("source") or "ios").strip() or "ios"
    note = str(payload.get("note") or "").strip()

    body = {
        "entity_type": "meditation_practice",
        "practice_id": practice_id,
        "user_entity_id": user_entity_id,
        "mode": mode,
        "started_at": started_at.astimezone(timezone.utc).isoformat(),
        "ended_at": ended_at.astimezone(timezone.utc).isoformat() if ended_at else None,
        "duration_seconds": duration_seconds,
        "cycle_count": cycle_count,
        "completed": completed,
        "source": source,
        "note": note,
        "createtime": now_iso(),
        "updatetime": now_iso(),
    }
    await put_entity_body(cur, practice_id, body)
    meditation_block = await ensure_meditation_block(cur, user_entity_id)
    await upsert_meditation_practice_to_block(cur, meditation_block["block_id"], body)
    await cur.execute(
        """
        INSERT INTO helen.meditation_practice_records
          (practice_id, user_entity_id, mode_key, mode_label, started_at_utc, ended_at_utc,
           duration_seconds, cycle_count, completed, source)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
          mode_key = VALUES(mode_key),
          mode_label = VALUES(mode_label),
          started_at_utc = VALUES(started_at_utc),
          ended_at_utc = VALUES(ended_at_utc),
          duration_seconds = VALUES(duration_seconds),
          cycle_count = VALUES(cycle_count),
          completed = VALUES(completed),
          source = VALUES(source)
        """,
        (
            practice_id,
            user_entity_id,
            mode["key"],
            mode["label"],
            started_at.astimezone(timezone.utc).replace(tzinfo=None),
            ended_at.astimezone(timezone.utc).replace(tzinfo=None) if ended_at else None,
            duration_seconds,
            cycle_count,
            1 if completed else 0,
            source,
        ),
    )
    await _sync_meditation_records_json(cur, user_entity_id)
    return body


async def ensure_meditation_block(cur, user_entity_id):
    await cur.execute(
        """
        SELECT block_id
        FROM helen.meditation_blocks
        WHERE user_entity_id = %s
        LIMIT 1
        """,
        (user_entity_id,),
    )
    row = await cur.fetchone()
    if row:
        block_id = row[0]
        body = await get_entity_body(cur, block_id)
        if not body:
            body = build_empty_meditation_block(user_entity_id, block_id)
            await put_entity_body(cur, block_id, body)
        changed = False
        body.setdefault("entity_type", "meditation_block")
        body.setdefault("block_id", block_id)
        body.setdefault("user_entity_id", user_entity_id)
        body.setdefault("title", "冥想练习数据")
        body.setdefault("practice_ids", [])
        body.setdefault("practices", [])
        body.setdefault(
            "stats",
            {
                "total_practice_count": 0,
                "completed_practice_count": 0,
                "total_duration_seconds": 0,
                "latest_practice_id": None,
                "latest_practice_at": None,
                "mode_counts": {},
            },
        )
        if not body.get("practices"):
            if await _backfill_meditation_block(cur, user_entity_id, block_id, body):
                changed = True
        if changed:
            body["updatetime"] = now_iso()
            await put_entity_body(cur, block_id, body)
        return {
            "created": False,
            "block_id": block_id,
            "user_entity_id": user_entity_id,
            "body": body,
        }

    block_id = uuid.uuid4().hex
    body = build_empty_meditation_block(user_entity_id, block_id)
    await put_entity_body(cur, block_id, body)
    await cur.execute(
        """
        INSERT INTO helen.meditation_blocks (user_entity_id, block_id)
        VALUES (%s, %s)
        """,
        (user_entity_id, block_id),
    )

    user_body = await get_entity_body(cur, user_entity_id)
    if isinstance(user_body, dict):
        user_body["meditation_block_id"] = block_id
        user_body["updatetime"] = now_iso()
        await put_entity_body(cur, user_entity_id, user_body)

    return {
        "created": True,
        "block_id": block_id,
        "user_entity_id": user_entity_id,
        "body": body,
    }


async def _backfill_meditation_block(cur, user_entity_id, block_id, block_body):
    await cur.execute(
        """
        SELECT practice_id
        FROM helen.meditation_practice_records
        WHERE user_entity_id = %s
        ORDER BY started_at_utc DESC, id DESC
        """,
        (user_entity_id,),
    )
    rows = await cur.fetchall()
    if not rows:
        return False

    practices = []
    for (practice_id,) in rows:
        practice_body = await get_entity_body(cur, practice_id)
        if isinstance(practice_body, dict):
            practices.append(practice_body)

    block_body["practice_ids"] = [item["practice_id"] for item in practices if item.get("practice_id")]
    block_body["practices"] = practices
    _refresh_meditation_block_stats(block_body)
    block_body["updatetime"] = now_iso()
    await put_entity_body(cur, block_id, block_body)
    return True


async def upsert_meditation_practice_to_block(cur, block_id, practice_body):
    block_body = await get_entity_body(cur, block_id)
    if not isinstance(block_body, dict):
        raise ValueError("meditation block not found")

    practices = list(block_body.get("practices") or [])
    practice_id = practice_body.get("practice_id")
    replaced = False
    for index, item in enumerate(practices):
        if item.get("practice_id") == practice_id:
            practices[index] = practice_body
            replaced = True
            break
    if not replaced:
        practices.append(practice_body)

    practices.sort(key=lambda item: item.get("started_at") or "", reverse=True)
    block_body["practices"] = practices
    block_body["practice_ids"] = [item.get("practice_id") for item in practices if item.get("practice_id")]
    _refresh_meditation_block_stats(block_body)
    block_body["updatetime"] = now_iso()
    await put_entity_body(cur, block_id, block_body)


def _refresh_meditation_block_stats(block_body):
    practices = list(block_body.get("practices") or [])
    mode_counts = {}
    completed_count = 0
    total_duration_seconds = 0
    latest_practice_id = None
    latest_practice_at = None

    for item in practices:
        if item.get("completed"):
            completed_count += 1
        total_duration_seconds += _safe_int(item.get("duration_seconds"), 0)
        mode = item.get("mode") or {}
        mode_key = mode.get("key")
        if mode_key:
            mode_counts[mode_key] = mode_counts.get(mode_key, 0) + 1
        started_at = item.get("started_at")
        if started_at and (latest_practice_at is None or started_at > latest_practice_at):
            latest_practice_at = started_at
            latest_practice_id = item.get("practice_id")

    block_body["stats"] = {
        "total_practice_count": len(practices),
        "completed_practice_count": completed_count,
        "total_duration_seconds": total_duration_seconds,
        "latest_practice_id": latest_practice_id,
        "latest_practice_at": latest_practice_at,
        "mode_counts": mode_counts,
    }


async def load_meditation_activity(cur, user_entity_id, year, month, tz_offset_minutes=0):
    offset = timezone(timedelta(minutes=int(tz_offset_minutes or 0)))
    await cur.execute(
        """
        SELECT practice_id, mode_key, mode_label, started_at_utc, ended_at_utc,
               duration_seconds, cycle_count, completed, source
        FROM helen.meditation_practice_records
        WHERE user_entity_id = %s
        ORDER BY started_at_utc ASC, id ASC
        """,
        (user_entity_id,),
    )
    rows = await cur.fetchall()
    _write_meditation_records_json_for_user(user_entity_id, [_record_from_row(row) for row in rows])
    practice_days = set()
    all_practice_dates = set()
    mode_counts = {}
    total_duration_seconds = 0
    latest_practice = None

    for row in rows:
        record = _record_from_row(row)
        started_at = parse_datetime(record["started_at"])
        if not started_at:
            continue
        local_date = started_at.astimezone(offset).date()
        all_practice_dates.add(local_date)
        if local_date.year == year and local_date.month == month:
            practice_days.add(local_date.day)
            total_duration_seconds += record["duration_seconds"]
            mode_counts[record["mode_key"]] = mode_counts.get(record["mode_key"], 0) + 1
            latest_practice = record

    today = datetime.now(offset).date()
    streak = 0
    cursor = today
    while cursor in all_practice_dates:
        streak += 1
        cursor -= timedelta(days=1)

    return {
        "year": year,
        "month": month,
        "practice_days": sorted(practice_days),
        "practice_count": sum(mode_counts.values()),
        "practice_streak": streak,
        "total_duration_seconds": total_duration_seconds,
        "mode_counts": mode_counts,
        "latest_practice": latest_practice,
    }


async def load_meditation_records(cur, user_entity_id, limit=50):
    await cur.execute(
        """
        SELECT practice_id, mode_key, mode_label, started_at_utc, ended_at_utc,
               duration_seconds, cycle_count, completed, source
        FROM helen.meditation_practice_records
        WHERE user_entity_id = %s
        ORDER BY started_at_utc DESC, id DESC
        LIMIT %s
        """,
        (user_entity_id, int(limit)),
    )
    return [_record_from_row(row) for row in await cur.fetchall()]


async def _sync_meditation_records_json(cur, user_entity_id):
    await cur.execute(
        """
        SELECT practice_id, mode_key, mode_label, started_at_utc, ended_at_utc,
               duration_seconds, cycle_count, completed, source
        FROM helen.meditation_practice_records
        WHERE user_entity_id = %s
        ORDER BY started_at_utc ASC, id ASC
        """,
        (user_entity_id,),
    )
    rows = await cur.fetchall()
    _write_meditation_records_json_for_user(user_entity_id, [_record_from_row(row) for row in rows])


def _load_meditation_records_json():
    if not MEDITATION_RECORDS_FILE.exists():
        return {
            "updated_at": now_iso(),
            "users": {},
        }
    try:
        with MEDITATION_RECORDS_FILE.open("r", encoding="utf-8") as fp:
            data = json.load(fp)
    except (OSError, json.JSONDecodeError):
        return {
            "updated_at": now_iso(),
            "users": {},
        }
    if not isinstance(data, dict):
        data = {}
    if not isinstance(data.get("users"), dict):
        data["users"] = {}
    data.setdefault("updated_at", now_iso())
    return data


def _write_meditation_records_json_for_user(user_entity_id, records):
    data = _load_meditation_records_json()
    users = data.setdefault("users", {})

    records = sorted(
        [record for record in records if isinstance(record, dict)],
        key=lambda item: item.get("started_at") or "",
    )

    dates = {}
    total_practice_count = 0
    total_duration_seconds = 0
    latest_started_at = None

    for record in records:
        started_at = parse_datetime(record.get("started_at"))
        if not started_at:
            continue
        date_key = started_at.date().isoformat()
        duration_seconds = _safe_int(record.get("duration_seconds"), 0)
        entry = dates.setdefault(
            date_key,
            {
                "date": date_key,
                "practice_count": 0,
                "total_duration_seconds": 0,
                "sessions": [],
            },
        )
        entry["practice_count"] += 1
        entry["total_duration_seconds"] += duration_seconds
        entry["sessions"].append(
            {
                "practice_id": record.get("practice_id"),
                "mode_key": record.get("mode_key"),
                "mode_label": record.get("mode_label"),
                "started_at": record.get("started_at"),
                "ended_at": record.get("ended_at"),
                "duration_seconds": duration_seconds,
                "cycle_count": _safe_int(record.get("cycle_count"), 0),
                "completed": bool(record.get("completed")),
                "source": record.get("source") or "",
            }
        )
        total_practice_count += 1
        total_duration_seconds += duration_seconds
        started_at_text = record.get("started_at")
        if started_at_text and (latest_started_at is None or started_at_text > latest_started_at):
            latest_started_at = started_at_text

    users[user_entity_id] = {
        "user_entity_id": user_entity_id,
        "total_practice_count": total_practice_count,
        "total_duration_seconds": total_duration_seconds,
        "latest_started_at": latest_started_at,
        "dates": [dates[key] for key in sorted(dates.keys(), reverse=True)],
    }
    data["updated_at"] = now_iso()

    MEDITATION_RECORDS_FILE.parent.mkdir(parents=True, exist_ok=True)
    temp_path = MEDITATION_RECORDS_FILE.with_suffix(".tmp")
    with temp_path.open("w", encoding="utf-8") as fp:
        json.dump(data, fp, ensure_ascii=False, indent=2)
    temp_path.replace(MEDITATION_RECORDS_FILE)


async def build_practice_symptom_correlation(cur, user_entity_id, days=30, tz_offset_minutes=0):
    days = max(7, min(int(days or 30), 180))
    offset = timezone(timedelta(minutes=int(tz_offset_minutes or 0)))
    end_date = datetime.now(offset).date()
    start_date = end_date - timedelta(days=days - 1)
    date_range = [start_date + timedelta(days=index) for index in range(days)]

    practice_by_date = {day: [] for day in date_range}
    symptom_by_date = {rule["key"]: {day: 0 for day in date_range} for rule in SYMPTOM_RULES}

    for record in await _records_in_range(cur, user_entity_id, start_date, end_date, offset):
        practice_by_date.setdefault(record["local_date"], []).append(record)

    comments = await _load_user_comments(cur, user_entity_id)
    for comment in comments:
        created_at = parse_datetime(comment.get("createtime"))
        if not created_at:
            continue
        local_date = created_at.astimezone(offset).date()
        if local_date < start_date or local_date > end_date:
            continue
        content = str(comment.get("content") or "")
        for rule in SYMPTOM_RULES:
            if _matches_keywords(content, rule["keywords"]):
                symptom_by_date[rule["key"]][local_date] += 1

    practice_dates = {day for day, records in practice_by_date.items() if records}
    non_practice_dates = [day for day in date_range if day not in practice_dates]
    correlations = []
    for rule in SYMPTOM_RULES:
        counts = symptom_by_date[rule["key"]]
        practice_values = [counts[day] for day in practice_dates]
        non_practice_values = [counts[day] for day in non_practice_dates]
        avg_with = _average(practice_values)
        avg_without = _average(non_practice_values)
        delta = avg_with - avg_without
        correlations.append(
            {
                "symptom_key": rule["key"],
                "symptom_label": rule["label"],
                "days_with_practice": len(practice_values),
                "days_without_practice": len(non_practice_values),
                "avg_symptom_count_on_practice_days": round(avg_with, 3),
                "avg_symptom_count_on_non_practice_days": round(avg_without, 3),
                "delta": round(delta, 3),
                "direction": _direction(delta),
                "confidence": _confidence(len(practice_values), sum(practice_values) + sum(non_practice_values)),
            }
        )

    mode_counts = {}
    for records in practice_by_date.values():
        for record in records:
            mode_counts[record["mode_key"]] = mode_counts.get(record["mode_key"], 0) + 1

    return {
        "range_days": days,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "practice_days": sorted(day.isoformat() for day in practice_dates),
        "practice_count": sum(mode_counts.values()),
        "mode_counts": mode_counts,
        "correlations": correlations,
        "note": "相关性为按天聚合的初步统计，不代表因果关系；需要更多连续记录后置信度会提高。",
    }


def _record_from_row(row):
    started_at = row[3]
    ended_at = row[4]
    if isinstance(started_at, datetime) and started_at.tzinfo is None:
        started_at = started_at.replace(tzinfo=timezone.utc)
    if isinstance(ended_at, datetime) and ended_at.tzinfo is None:
        ended_at = ended_at.replace(tzinfo=timezone.utc)
    return {
        "practice_id": row[0],
        "mode_key": row[1],
        "mode_label": row[2],
        "started_at": started_at.isoformat() if started_at else None,
        "ended_at": ended_at.isoformat() if ended_at else None,
        "duration_seconds": int(row[5] or 0),
        "cycle_count": int(row[6] or 0),
        "completed": bool(row[7]),
        "source": row[8] or "",
    }


async def _records_in_range(cur, user_entity_id, start_date, end_date, offset):
    await cur.execute(
        """
        SELECT practice_id, mode_key, mode_label, started_at_utc, ended_at_utc,
               duration_seconds, cycle_count, completed, source
        FROM helen.meditation_practice_records
        WHERE user_entity_id = %s
        ORDER BY started_at_utc ASC, id ASC
        """,
        (user_entity_id,),
    )
    records = []
    for row in await cur.fetchall():
        record = _record_from_row(row)
        started_at = parse_datetime(record["started_at"])
        if not started_at:
            continue
        local_date = started_at.astimezone(offset).date()
        if start_date <= local_date <= end_date:
            record["local_date"] = local_date
            records.append(record)
    return records


async def _load_user_comments(cur, user_entity_id):
    await cur.execute(
        """
        SELECT chat_id
        FROM helen.chat_index
        WHERE user_entity_id = %s
        """,
        (user_entity_id,),
    )
    comments = []
    for (chat_id,) in await cur.fetchall():
        await cur.execute(
            """
            SELECT block_id
            FROM helen.chat_blocks
            WHERE chat_id = %s
            ORDER BY id ASC
            """,
            (chat_id,),
        )
        for (block_id,) in await cur.fetchall():
            block_body = await get_entity_body(cur, block_id)
            if not block_body:
                continue
            comments.extend(
                comment
                for comment in block_body.get("comments", [])
                if comment.get("role") == "user"
            )
    return comments


def _matches_keywords(content, keywords):
    lowered = content.lower()
    return any(str(keyword).lower() in lowered for keyword in keywords)


def _average(values):
    return sum(values) / len(values) if values else 0


def _direction(delta):
    if delta <= -0.2:
        return "lower_on_practice_days"
    if delta >= 0.2:
        return "higher_on_practice_days"
    return "no_clear_difference"


def _confidence(practice_days, symptom_mentions):
    if practice_days >= 8 and symptom_mentions >= 8:
        return "medium"
    if practice_days >= 3 and symptom_mentions >= 3:
        return "low"
    return "insufficient_data"
