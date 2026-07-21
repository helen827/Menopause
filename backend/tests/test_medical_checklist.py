from app.services.medical_checklist import _build_attention_items, _build_question_suggestions, _normalize_saved_state


def test_question_suggestions_prioritize_primary_symptoms_without_duplicates():
    symptoms = [
        {"key": "poor_sleep", "label": "睡眠差", "count": 4},
        {"key": "anxiety", "label": "焦虑", "count": 2},
    ]
    questions = _build_question_suggestions(symptoms)
    assert questions[0] == "我的睡眠问题是否需要进一步评估？"
    assert len(questions) == len(set(questions))
    assert len(questions) <= 5


def test_attention_items_fall_back_to_guidance_when_no_data_exists():
    items = _build_attention_items([], [], [])
    assert len(items) == 1
    assert "记录天数还不多" in items[0]["text"]


def test_saved_state_counts_selected_and_multiline_custom_questions():
    state = _normalize_saved_state(
        {"selected_questions": ["问题一", "", "问题二"], "custom_question": "自定义一\n\n自定义二"},
        "30d",
    )
    assert state["selected_questions"] == ["问题一", "问题二"]
    assert state["question_count"] == 4
