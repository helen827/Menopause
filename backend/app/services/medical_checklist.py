import uuid

from app.services.chat import now_iso
from app.services.entities import get_entity_body, put_entity_body
from app.services.trend_report import REPORT_RANGES, ensure_trend_report_block


RANGE_LABELS = {
    "7d": "近7天",
    "30d": "近30天",
    "90d": "近90天",
}

SYMPTOM_PREVIEW_NOTES = {
    "poor_sleep": "主要表现为入睡困难、睡不踏实或夜间醒来",
    "anxiety": "可能伴随紧张、心烦或情绪波动",
    "hot_flash": "可以说明发生时段、持续多久，以及是否伴随出汗",
    "fatigue": "可以补充白天精力、工作状态和恢复速度",
    "brain_fog": "可以说明注意力、记忆力或反应速度的变化",
    "urinary_leakage": "可以说明发生场景，例如咳嗽、打喷嚏或来不及上厕所时",
}

QUESTION_TEMPLATES = {
    "poor_sleep": [
        "我的睡眠问题是否需要进一步评估？",
        "是否需要做相关检查？",
    ],
    "anxiety": [
        "这些情绪变化是否可能与围绝经期有关？",
        "是否需要关注焦虑或情绪方面的支持？",
    ],
    "hot_flash": [
        "潮热是否属于围绝经期常见表现？",
        "饮食和生活方式方面有什么建议？",
    ],
    "fatigue": [
        "持续疲惫是否需要排查其他原因？",
        "是否需要做基础检查？",
    ],
    "brain_fog": [
        "注意力和记忆力变化是否和围绝经期有关？",
    ],
    "urinary_leakage": [
        "漏尿是否需要进一步检查或盆底评估？",
    ],
}

DEFAULT_QUESTIONS = [
    "我的症状是否可能与围绝经期有关？",
    "是否需要做相关检查？",
    "是否适合激素治疗？",
    "我的睡眠问题是否需要进一步评估？",
    "饮食和生活方式有什么建议？",
]


async def load_medical_checklist(cur, user_entity_id, range_key):
    if range_key not in REPORT_RANGES:
        raise ValueError("range must be one of 7d, 30d, 90d")

    block = await ensure_trend_report_block(cur, user_entity_id)
    draft = await _load_draft(cur, user_entity_id, range_key)
    body = block["body"]
    range_data = (body.get("ranges") or {}).get(range_key) or {}
    report = range_data.get("report") or {}
    period = report.get("period") or {}
    frequent_symptoms = ((report.get("frequent_symptoms") or {}).get("items") or [])
    positive_symptoms = [item for item in frequent_symptoms if int(item.get("count") or 0) > 0]
    primary_symptoms = positive_symptoms[:3]

    suggestions = _build_question_suggestions(primary_symptoms)
    attention_items = _build_attention_items(
        primary_symptoms=primary_symptoms,
        all_symptoms=positive_symptoms,
        trigger_items=((report.get("possible_triggers") or {}).get("items") or []),
    )

    symptom_preview_lines = []
    for symptom in primary_symptoms:
        note = SYMPTOM_PREVIEW_NOTES.get(symptom.get("key"), "")
        suffix = f"（{note}）" if note else ""
        symptom_preview_lines.append(
            f"- {symptom.get('label', '症状')}：{int(symptom.get('count') or 0)}次{suffix}"
        )

    return {
        "block_id": block["block_id"],
        "user_entity_id": user_entity_id,
        "range": range_key,
        "range_label": RANGE_LABELS[range_key],
        "title": "就医沟通清单",
        "status_card": {
            "icon": "checkmark.circle.fill",
            "title": "数据已准备就绪",
            "subtitle": f"根据你{RANGE_LABELS[range_key]}的记录生成",
        },
        "summary_section": {
            "title": "主要症状汇总",
            "items": [
                {
                    "key": item.get("key"),
                    "label": item.get("label"),
                    "icon": item.get("icon") or "circle.fill",
                    "count": int(item.get("count") or 0),
                    "unit": item.get("unit") or "次",
                    "preview_note": SYMPTOM_PREVIEW_NOTES.get(item.get("key"), ""),
                }
                for item in primary_symptoms
            ],
        },
        "attention_section": {
            "title": "需要特别说明的情况",
            "items": attention_items,
        },
        "question_section": {
            "title": "想问医生的问题",
            "subtitle": "点击选择或自定义添加：",
            "suggestions": suggestions,
        },
        "preview": {
            "title": "清单预览",
            "period_label": RANGE_LABELS[range_key],
            "symptom_lines": symptom_preview_lines,
            "question_prefix": "想问医生的问题：",
        },
        "saved_state": draft,
        "history_section": {
            "title": "历史版本",
            "items": await _load_history(cur, user_entity_id, range_key),
        },
        "meta": {
            "recorded_days": int(period.get("recorded_days") or 0),
            "total_days": int(period.get("total_days") or 0),
            "anchor_date": range_data.get("anchor_date"),
            "generated_at": range_data.get("generated_at"),
        },
    }


async def save_medical_checklist(cur, user_entity_id, range_key, selected_questions, custom_question, preview_text):
    if range_key not in REPORT_RANGES:
        raise ValueError("range must be one of 7d, 30d, 90d")

    user_body = await get_entity_body(cur, user_entity_id)
    if not isinstance(user_body, dict):
        raise ValueError("user entity not found")

    drafts = user_body.setdefault("medical_checklist_drafts", {})
    current = {
        "range": range_key,
        "version_id": uuid.uuid4().hex,
        "selected_questions": [str(item).strip() for item in selected_questions if str(item).strip()],
        "custom_question": str(custom_question or "").strip(),
        "preview_text": str(preview_text or "").strip(),
        "saved_at": now_iso(),
    }
    drafts[range_key] = current
    history = user_body.setdefault("medical_checklist_history", {})
    version_items = history.setdefault(range_key, [])
    version_items.insert(0, dict(current))
    history[range_key] = version_items[:10]
    user_body["updatetime"] = now_iso()
    await put_entity_body(cur, user_entity_id, user_body)
    return current


def _build_question_suggestions(primary_symptoms):
    ordered = []
    seen = set()

    def push(question):
        if not question or question in seen:
            return
        seen.add(question)
        ordered.append(question)

    for item in primary_symptoms:
        for question in QUESTION_TEMPLATES.get(item.get("key"), []):
            push(question)

    for question in DEFAULT_QUESTIONS:
        push(question)

    return ordered[:5]


def _build_attention_items(primary_symptoms, all_symptoms, trigger_items):
    primary_keys = {item.get("key") for item in primary_symptoms}
    items = []

    for symptom in all_symptoms:
        if symptom.get("key") in primary_keys:
            continue
        count = int(symptom.get("count") or 0)
        if count <= 0:
            continue
        items.append(
            {
                "icon": "exclamationmark.triangle.fill",
                "text": (
                    f"你记录了{count}次{symptom.get('label', '症状')}，虽然频率不高，"
                    "但如果医生问起可以主动说明发生时间和伴随症状。"
                ),
            }
        )

    if not items:
        for trigger in trigger_items[:2]:
            text = str(trigger.get("text") or "").strip()
            if not text:
                continue
            items.append(
                {
                    "icon": "info.circle.fill",
                    "text": text,
                }
            )

    if not items:
        items.append(
            {
                "icon": "info.circle.fill",
                "text": "记录天数还不多，建议就诊前回想症状出现的时间、持续多久，以及是否影响睡眠、情绪和日常生活。",
            }
        )

    return items[:2]


async def _load_draft(cur, user_entity_id, range_key):
    user_body = await get_entity_body(cur, user_entity_id)
    if not isinstance(user_body, dict):
        return None
    drafts = user_body.get("medical_checklist_drafts") or {}
    draft = drafts.get(range_key)
    if not isinstance(draft, dict):
        return None
    return _normalize_saved_state(draft, range_key)


async def _load_history(cur, user_entity_id, range_key):
    user_body = await get_entity_body(cur, user_entity_id)
    if not isinstance(user_body, dict):
        return []
    history = (user_body.get("medical_checklist_history") or {}).get(range_key) or []
    if not isinstance(history, list):
        return []
    items = []
    for entry in history[:10]:
        if isinstance(entry, dict):
            items.append(_normalize_saved_state(entry, range_key))
    return items


def _normalize_saved_state(draft, range_key):
    selected_questions = [
        str(item).strip() for item in (draft.get("selected_questions") or []) if str(item).strip()
    ]
    custom_question = str(draft.get("custom_question") or "").strip()
    return {
        "range": range_key,
        "version_id": str(draft.get("version_id") or "").strip(),
        "selected_questions": selected_questions,
        "custom_question": custom_question,
        "preview_text": str(draft.get("preview_text") or "").strip(),
        "saved_at": draft.get("saved_at"),
        "question_count": len(selected_questions) + len([line for line in custom_question.splitlines() if line.strip()]),
    }
