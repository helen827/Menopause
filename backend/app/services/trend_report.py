import json
import uuid
from datetime import timedelta, timezone

from app.services.chat import _parse_comment_time, now_iso
from app.services.entities import get_entity_body, put_entity_body


REPORT_RANGES = ("7d", "30d", "90d")

SYMPTOM_RULES = [
    {
        "key": "poor_sleep",
        "label": "睡眠差",
        "icon": "moon.fill",
        "keywords": [
            "睡眠",
            "睡不着",
            "失眠",
            "醒",
            "多梦",
            "睡得差",
            "睡不好",
            "sleep well",
            "can’t sleep",
            "can't sleep",
            "insomnia",
            "broken sleep",
        ],
    },
    {
        "key": "anxiety",
        "label": "焦虑",
        "icon": "bolt.fill",
        "keywords": [
            "焦虑",
            "紧张",
            "担心",
            "心慌",
            "烦躁",
            "不安",
            "心情差",
            "情绪差",
            "低落",
            "烦",
            "upset",
            "anxious",
            "anxiety",
            "stressed",
            "stress",
        ],
    },
    {
        "key": "hot_flash",
        "label": "潮热",
        "icon": "flame.fill",
        "keywords": ["潮热", "热醒", "发热", "燥热", "出汗", "夜汗", "hot flush", "hot flash"],
    },
    {
        "key": "fatigue",
        "label": "疲惫",
        "icon": "xmark.circle.fill",
        "keywords": ["疲惫", "疲劳", "累", "没力气", "乏力", "困"],
    },
    {
        "key": "brain_fog",
        "label": "脑雾",
        "icon": "cloud.fill",
        "keywords": ["脑雾", "记不住", "注意力", "健忘", "反应慢"],
    },
    {
        "key": "urinary_leakage",
        "label": "漏尿",
        "icon": "drop.fill",
        "keywords": ["漏尿", "尿频", "尿急", "憋不住"],
    },
]


def empty_range_report(range_key):
    return {
        "range": range_key,
        "status": "empty",
        "anchor_date": None,
        "anchor_source": "latest_ai_chat_date",
        "start_date": None,
        "end_date": None,
        "generated_at": None,
        "source": {
            "type": "ai_chat_analysis",
            "chat_id": None,
            "latest_ai_chat_time": None,
            "included_user_message_count": 0,
            "included_assistant_message_count": 0,
            "evidence_comment_ids": [],
        },
        "report": None,
    }


def build_empty_trend_report_block(user_entity_id, block_id):
    return {
        "entity_type": "trend_report_block",
        "block_id": block_id,
        "user_entity_id": user_entity_id,
        "title": "身体变化趋势",
        "ranges": {range_key: empty_range_report(range_key) for range_key in REPORT_RANGES},
        "createtime": now_iso(),
        "updatetime": now_iso(),
    }


async def ensure_trend_report_block(cur, user_entity_id):
    await cur.execute(
        """
        SELECT block_id
        FROM helen.trend_report_blocks
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
            body = build_empty_trend_report_block(user_entity_id, block_id)
            await put_entity_body(cur, block_id, body)
        changed = False
        body.setdefault("entity_type", "trend_report_block")
        body.setdefault("block_id", block_id)
        body.setdefault("user_entity_id", user_entity_id)
        body.setdefault("title", "身体变化趋势")
        ranges = body.setdefault("ranges", {})
        for range_key in REPORT_RANGES:
            if range_key not in ranges:
                ranges[range_key] = empty_range_report(range_key)
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
    body = build_empty_trend_report_block(user_entity_id, block_id)
    await put_entity_body(cur, block_id, body)
    await cur.execute(
        """
        INSERT INTO helen.trend_report_blocks (user_entity_id, block_id)
        VALUES (%s, %s)
        """,
        (user_entity_id, block_id),
    )

    user_body = await get_entity_body(cur, user_entity_id)
    if isinstance(user_body, dict):
        user_body["trend_report_block_id"] = block_id
        user_body["updatetime"] = now_iso()
        await put_entity_body(cur, user_entity_id, user_body)

    return {
        "created": True,
        "block_id": block_id,
        "user_entity_id": user_entity_id,
        "body": body,
    }


async def save_trend_report_range(cur, user_entity_id, range_key, report_payload):
    if range_key not in REPORT_RANGES:
        raise ValueError("range must be one of 7d, 30d, 90d")
    block = await ensure_trend_report_block(cur, user_entity_id)
    body = block["body"]
    ranges = body.setdefault("ranges", {})
    ranges[range_key] = {
        "range": range_key,
        "status": "ready",
        "saved_at": now_iso(),
        **report_payload,
    }
    body["updatetime"] = now_iso()
    await put_entity_body(cur, block["block_id"], body)
    return {
        "created": block["created"],
        "block_id": block["block_id"],
        "user_entity_id": user_entity_id,
        "range": range_key,
        "body": body,
    }


async def refresh_trend_report_for_chat(cur, chat_id, tz_offset_minutes=480, deepseek_service=None):
    await cur.execute(
        """
        SELECT user_entity_id
        FROM helen.chat_index
        WHERE chat_id = %s
        LIMIT 1
        """,
        (chat_id,),
    )
    row = await cur.fetchone()
    if not row:
        raise ValueError("chat_id not found")
    user_entity_id = row[0]
    comments = await _load_all_chat_comments(cur, chat_id, tz_offset_minutes)
    user_comments = [item for item in comments if item.get("role") == "user"]
    if not user_comments:
        return await ensure_trend_report_block(cur, user_entity_id)

    latest_user_comment = max(user_comments, key=lambda item: item["local_time"])
    anchor_date = latest_user_comment["local_time"].date()
    block = await ensure_trend_report_block(cur, user_entity_id)
    body = block["body"]
    ranges = body.setdefault("ranges", {})
    ai_ranges = None
    ai_error = None
    if deepseek_service is not None:
        try:
            ai_ranges = await _build_ai_range_reports(
                deepseek_service=deepseek_service,
                chat_id=chat_id,
                anchor_date=anchor_date,
                latest_user_time=latest_user_comment["local_time"],
                comments=comments,
            )
        except Exception as exc:
            ai_error = str(exc)

    for range_key in REPORT_RANGES:
        ranges[range_key] = _build_range_report(
            chat_id=chat_id,
            range_key=range_key,
            anchor_date=anchor_date,
            latest_user_time=latest_user_comment["local_time"],
            comments=comments,
            ai_report=(ai_ranges or {}).get(range_key),
            ai_error=ai_error,
        )
    body["updatetime"] = now_iso()
    await put_entity_body(cur, block["block_id"], body)
    return {
        "created": block["created"],
        "block_id": block["block_id"],
        "user_entity_id": user_entity_id,
        "body": body,
    }


async def _load_all_chat_comments(cur, chat_id, tz_offset_minutes=480):
    await cur.execute(
        """
        SELECT block_id
        FROM helen.chat_blocks
        WHERE chat_id = %s
        ORDER BY id ASC
        """,
        (chat_id,),
    )
    blocks = await cur.fetchall()
    comments = []
    offset = timezone(timedelta(minutes=int(tz_offset_minutes or 0)))
    for (block_id,) in blocks:
        block_body = await get_entity_body(cur, block_id)
        if not block_body:
            continue
        for comment in block_body.get("comments", []):
            created_at = _parse_comment_time(comment.get("createtime"))
            if not created_at:
                continue
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            comments.append({**comment, "local_time": created_at.astimezone(offset)})
    return comments


async def _build_ai_range_reports(deepseek_service, chat_id, anchor_date, latest_user_time, comments):
    transcript = _build_ai_transcript(comments)
    messages = [
        {
            "role": "system",
            "content": (
                "你是一名负责生成更年期健康趋势摘要的中文助手。"
                "请严格根据聊天记录内容输出简洁 JSON，不要编造用户没有提到的症状、事件或结论。"
                "症状判断必须以用户自己提到的内容为准。"
                "输出必须是合法 JSON，不要输出 Markdown。"
            ),
        },
        {
            "role": "user",
            "content": (
                f"chat_id: {chat_id}\n"
                f"anchor_date: {anchor_date.isoformat()}\n"
                f"latest_ai_chat_time: {latest_user_time.isoformat()}\n"
                "请基于以下聊天记录，生成 7d、30d、90d 三个周期的趋势摘要。\n"
                "规则：\n"
                "1. 周期结束日期都等于 anchor_date。\n"
                "2. 只引用聊天中真实出现过的内容，优先使用用户消息判断症状。\n"
                "3. 你只需要返回这些适合 AI 总结的字段：overview、possible_triggers、recommended_next_steps。\n"
                "4. 顶层 JSON 格式必须是："
                "{\"7d\":{\"report\":{\"overview\":{...},\"possible_triggers\":{...},\"recommended_next_steps\":{...}}},"
                "\"30d\":{\"report\":{\"overview\":{...},\"possible_triggers\":{...},\"recommended_next_steps\":{...}}},"
                "\"90d\":{\"report\":{\"overview\":{...},\"possible_triggers\":{...},\"recommended_next_steps\":{...}}}}\n"
                "5. overview 里返回 title、summary、highlight_symptom_keys、confidence。\n"
                "6. possible_triggers.items 最多 2 条，每条包含 type、icon、style、text、related_symptom_keys、evidence_comment_ids、confidence。\n"
                "7. recommended_next_steps.items 最多 2 条，每条包含 key、title、desc、icon、action。\n"
                "8. evidence_comment_ids 只能使用聊天记录里真实存在的 comment_id。\n"
                "9. 如果证据不够，confidence 用 low，文案保持保守。\n\n"
                f"聊天记录：\n{transcript}"
            ),
        },
    ]
    response = await deepseek_service.complete(
        messages,
        max_tokens=1400,
        temperature=0.2,
    )
    return _parse_ai_range_reports(response["content"])


def _build_ai_transcript(comments):
    lines = []
    for item in comments:
        if item.get("role") != "user":
            continue
        comment_id = item.get("comment_id") or ""
        role = item.get("role") or "unknown"
        content = str(item.get("content") or "").replace("\n", " ").strip()[:300]
        timestamp = item["local_time"].isoformat()
        lines.append(f"[{timestamp}][{role}][{comment_id}] {content}")
    return "\n".join(lines)


def _parse_ai_range_reports(content):
    text = str(content or "").strip()
    if text.startswith("```"):
        parts = text.split("```")
        for part in parts:
            part = part.strip()
            if part.startswith("{") and part.endswith("}"):
                text = part
                break
            if "\n" in part:
                body = part.split("\n", 1)[1].strip()
                if body.startswith("{") and body.endswith("}"):
                    text = body
                    break
    payload = json.loads(text)
    if not isinstance(payload, dict):
        raise ValueError("trend report AI payload must be a JSON object")
    return {key: value for key, value in payload.items() if key in REPORT_RANGES and isinstance(value, dict)}


def _build_range_report(chat_id, range_key, anchor_date, latest_user_time, comments, ai_report=None, ai_error=None):
    days = int(range_key.replace("d", ""))
    start_date = anchor_date - timedelta(days=days - 1)
    scoped = [
        item
        for item in comments
        if start_date <= item["local_time"].date() <= anchor_date
    ]
    user_comments = [item for item in scoped if item.get("role") == "user"]
    assistant_comments = [item for item in scoped if item.get("role") == "assistant"]
    symptom_items = _summarize_symptoms(user_comments)
    recorded_days = len({item["local_time"].date() for item in user_comments})
    top_labels = [item["label"] for item in symptom_items if item["count"] > 0][:2]
    top_text = "和".join(top_labels) if top_labels else "暂未形成明显高频症状"
    overview_summary = f"过去{days}天，你记录了{recorded_days}天。最常出现的症状是{top_text}。"

    fallback_report = {
        "range": range_key,
        "status": "ready",
        "anchor_date": anchor_date.isoformat(),
        "anchor_source": "latest_ai_chat_date",
        "start_date": start_date.isoformat(),
        "end_date": anchor_date.isoformat(),
        "generated_at": now_iso(),
        "source": {
            "type": "ai_chat_analysis",
            "chat_id": chat_id,
            "latest_ai_chat_time": latest_user_time.isoformat(),
            "included_user_message_count": len(user_comments),
            "included_assistant_message_count": len(assistant_comments),
            "evidence_comment_ids": [item.get("comment_id") for item in user_comments if item.get("comment_id")],
        },
        "report": {
            "title": "本周身体变化趋势",
            "period": {
                "active_range": range_key,
                "anchor_date": anchor_date.isoformat(),
                "anchor_source": "latest_ai_chat_date",
                "start_date": start_date.isoformat(),
                "end_date": anchor_date.isoformat(),
                "recorded_days": recorded_days,
                "total_days": days,
            },
            "overview": {
                "icon": "chart.xyaxis.line",
                "title": "本周概况",
                "summary": overview_summary,
                "highlight_symptom_keys": [item["key"] for item in symptom_items if item["count"] > 0][:2],
                "confidence": "medium" if len(user_comments) >= 3 else "low",
            },
            "frequent_symptoms": {
                "title": "高频症状",
                "items": symptom_items,
            },
            "trend_cards": [
                _build_sleep_trend_card(start_date, anchor_date, user_comments),
            ],
            "possible_triggers": {
                "title": "可能触发因素",
                "items": _build_trigger_insights(user_comments, days),
            },
            "recommended_next_steps": {
                "title": "推荐下一步",
                "items": _build_next_steps(symptom_items),
            },
            "medical_checklist": {
                "button_title": "生成就医清单",
                "icon": "cross.case.fill",
                "action": {
                    "type": "generate_medical_checklist",
                    "payload": {
                        "range": range_key,
                    },
                },
            },
            "disclaimer": "趋势报告用于自我观察和就医沟通准备，不作为医学诊断或治疗建议。",
        },
    }
    if ai_report:
        merged = {
            **fallback_report,
            **{key: value for key, value in ai_report.items() if key != "report"},
        }
        merged["generation_mode"] = "ai"
        ai_inner_report = ai_report.get("report")
        if isinstance(ai_inner_report, dict):
            merged["report"] = {
                **fallback_report["report"],
                **ai_inner_report,
            }
        return merged
    if ai_error:
        fallback_report["generation_error"] = ai_error
        fallback_report["generation_mode"] = "fallback"
    else:
        fallback_report["generation_mode"] = "rules"
    return fallback_report


def _summarize_symptoms(user_comments):
    items = []
    for rule in SYMPTOM_RULES:
        matched = []
        for comment in user_comments:
            if _comment_matches_keywords(comment, rule["keywords"]):
                matched.append(comment)
        items.append(
            {
                "key": rule["key"],
                "label": rule["label"],
                "icon": rule["icon"],
                "count": len(matched),
                "unit": "次",
                "severity": _severity_from_count(len(matched)),
                "evidence_comment_ids": [
                    item.get("comment_id") for item in matched if item.get("comment_id")
                ],
            }
        )
    items.sort(key=lambda item: item["count"], reverse=True)
    return items[:4]


def _severity_from_count(count):
    if count >= 5:
        return "high"
    if count >= 2:
        return "medium"
    if count == 1:
        return "low"
    return "none"


def _build_sleep_trend_card(start_date, anchor_date, user_comments):
    labels = ["一", "二", "三", "四", "五", "六", "日"]
    dates = [start_date + timedelta(days=index) for index in range((anchor_date - start_date).days + 1)]
    recent_dates = dates[-7:]
    points = []
    for current_date in recent_dates:
        comments = [item for item in user_comments if item["local_time"].date() == current_date]
        value = min(
            sum(
                1
                for item in comments
                if _comment_matches_keywords(item, SYMPTOM_RULES[0]["keywords"])
            ),
            5,
        )
        points.append(
            {
                "label": labels[current_date.weekday()],
                "date": current_date.isoformat(),
                "value": value,
                "evidence_comment_ids": [
                    item.get("comment_id")
                    for item in comments
                    if item.get("comment_id")
                    and _comment_matches_keywords(item, SYMPTOM_RULES[0]["keywords"])
                ],
            }
        )
    return {
        "key": "sleep_trend",
        "title": "睡眠趋势",
        "chart_type": "weekly_bar",
        "description": "柱状图表示睡眠问题严重程度",
        "metric": {
            "key": "sleep_problem_severity",
            "label": "睡眠问题严重程度",
            "min": 0,
            "max": 5,
            "unit": "分",
        },
        "data_points": points,
    }


def _build_trigger_insights(user_comments, days):
    caffeine_comments = _match_comments(user_comments, ["咖啡", "咖啡因", "茶", "奶茶"])
    hot_flash_comments = _match_comments(user_comments, ["潮热", "热醒", "燥热", "出汗", "夜汗"])
    late_sleep_comments = _match_comments(user_comments, ["熬夜", "晚睡", "睡得晚", "没睡够"])
    items = []
    if hot_flash_comments and late_sleep_comments:
        items.append(
            {
                "type": "insight",
                "icon": "lightbulb.fill",
                "style": "warning",
                "text": f"过去{days}天，你多次同时提到潮热和睡眠不足。睡眠不足可能是需要继续观察的触发因素之一。",
                "related_symptom_keys": ["hot_flash", "poor_sleep"],
                "evidence_comment_ids": _comment_ids(hot_flash_comments + late_sleep_comments),
                "confidence": "medium" if len(hot_flash_comments) + len(late_sleep_comments) >= 3 else "low",
            }
        )
    if caffeine_comments and hot_flash_comments:
        items.append(
            {
                "type": "observation",
                "icon": "info",
                "style": "info",
                "text": f"过去{days}天，你同时记录过咖啡因摄入和潮热，可以继续观察二者是否有关联。",
                "related_symptom_keys": ["hot_flash"],
                "evidence_comment_ids": _comment_ids(caffeine_comments + hot_flash_comments),
                "confidence": "low",
            }
        )
    if not items:
        items.append(
            {
                "type": "observation",
                "icon": "info",
                "style": "info",
                "text": f"过去{days}天的记录还不够形成明确触发因素，可以继续记录睡眠、饮食、情绪和症状出现时间。",
                "related_symptom_keys": [],
                "evidence_comment_ids": [],
                "confidence": "low",
            }
        )
    return items[:2]


def _build_next_steps(symptom_items):
    symptom_keys = {item["key"] for item in symptom_items if item["count"] > 0}
    steps = []
    if "poor_sleep" in symptom_keys:
        steps.append(
            {
                "key": "body_scan_before_sleep",
                "title": "尝试睡前身体扫描",
                "desc": "帮助改善睡眠质量",
                "icon": "moon.fill",
                "action": {"type": "open_meditation", "payload": {"practice_id": ""}},
            }
        )
    if "hot_flash" in symptom_keys:
        steps.append(
            {
                "key": "reduce_caffeine",
                "title": "减少咖啡因摄入",
                "desc": "观察是否减少潮热",
                "icon": "cup.and.saucer.fill",
                "action": {"type": "open_record_reminder", "payload": {"reminder_type": "caffeine"}},
            }
        )
    if not steps:
        steps.append(
            {
                "key": "keep_recording",
                "title": "继续记录身体变化",
                "desc": "帮助形成更清晰的趋势",
                "icon": "square.and.pencil",
                "action": {"type": "open_ai_chat", "payload": {}},
            }
        )
    return steps[:2]


def _match_comments(user_comments, keywords):
    return [item for item in user_comments if _comment_matches_keywords(item, keywords)]


def _comment_matches_keywords(comment, keywords):
    content = str(comment.get("content") or "").casefold()
    return any(str(keyword).casefold() in content for keyword in keywords)


def _comment_ids(comments):
    seen = set()
    output = []
    for comment in comments:
        comment_id = comment.get("comment_id")
        if comment_id and comment_id not in seen:
            seen.add(comment_id)
            output.append(comment_id)
    return output
