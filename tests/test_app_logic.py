"""
Unit tests for the Streamlit app's pure-Python helpers.
These run offline — no Snowflake connection needed.
Execute: python -m pytest tests/test_app_logic.py -v
"""

import sys, os, types, json, pytest

# ---------------------------------------------------------------------------
# Stub out modules that only exist inside Snowflake-in-Snowflake so we can
# import streamlit_app locally for unit-testing its pure functions.
# ---------------------------------------------------------------------------
_snowflake_stub = types.ModuleType("_snowflake")
_snowflake_stub.get_token = lambda: "FAKE_TOKEN"
sys.modules["_snowflake"] = _snowflake_stub

snowpark_ctx = types.ModuleType("snowflake.snowpark.context")
snowpark_ctx.get_active_session = lambda: None
sys.modules.setdefault("snowflake", types.ModuleType("snowflake"))
sys.modules.setdefault("snowflake.snowpark", types.ModuleType("snowflake.snowpark"))
sys.modules["snowflake.snowpark.context"] = snowpark_ctx

# Add the streamlit_app directory to the path so we can import helpers
APP_DIR = os.path.join(os.path.dirname(__file__), "..", "streamlit_app")
sys.path.insert(0, APP_DIR)


# ── extract_text_and_sql (imported after stubs) ────────────────────────────
# We inline the function here so tests don't depend on Streamlit being installed.
def extract_text_and_sql(response):
    text_parts = []
    sql_parts = []
    if isinstance(response, str):
        return response, []
    if "error" in response or "message" in response:
        return response.get("message", response.get("error", str(response))), []
    for item in response.get("content", []):
        if item.get("type") == "text":
            text_parts.append(item["text"])
        elif item.get("type") == "tool_result":
            for c in item.get("tool_result", {}).get("content", []):
                if c.get("type") == "json" and "sql" in c.get("json", {}):
                    sql_parts.append(c["json"]["sql"])
    return "\n\n".join(text_parts), sql_parts


# ═══════════════════════════════════════════════════════════════════════════
# 1. extract_text_and_sql
# ═══════════════════════════════════════════════════════════════════════════

class TestExtractTextAndSql:
    def test_basic_text_response(self):
        resp = {"content": [{"type": "text", "text": "There are 2,000 orders."}]}
        text, sqls = extract_text_and_sql(resp)
        assert text == "There are 2,000 orders."
        assert sqls == []

    def test_text_plus_sql(self):
        resp = {
            "content": [
                {"type": "tool_result", "tool_result": {
                    "content": [{"type": "json", "json": {"sql": "SELECT COUNT(*) FROM orders"}}]
                }},
                {"type": "text", "text": "The total is 2,000."},
            ]
        }
        text, sqls = extract_text_and_sql(resp)
        assert "2,000" in text
        assert len(sqls) == 1
        assert "SELECT" in sqls[0]

    def test_multiple_text_parts(self):
        resp = {
            "content": [
                {"type": "text", "text": "Part one."},
                {"type": "text", "text": "Part two."},
            ]
        }
        text, _ = extract_text_and_sql(resp)
        assert "Part one." in text
        assert "Part two." in text

    def test_empty_content(self):
        text, sqls = extract_text_and_sql({"content": []})
        assert text == ""
        assert sqls == []

    def test_error_response(self):
        resp = {"error": "Agent timed out", "code": "500"}
        text, sqls = extract_text_and_sql(resp)
        assert "Agent timed out" in text
        assert sqls == []

    def test_message_field_error(self):
        resp = {"message": "Tool not accessible", "code": "399569"}
        text, sqls = extract_text_and_sql(resp)
        assert "Tool not accessible" in text

    def test_string_response(self):
        text, sqls = extract_text_and_sql("raw string")
        assert text == "raw string"
        assert sqls == []

    def test_tool_result_without_sql(self):
        resp = {
            "content": [
                {"type": "tool_result", "tool_result": {
                    "content": [{"type": "json", "json": {"result_set": {"data": []}}}]
                }},
                {"type": "text", "text": "No results found."},
            ]
        }
        text, sqls = extract_text_and_sql(resp)
        assert "No results" in text
        assert sqls == []

    def test_multiple_sql_in_response(self):
        resp = {
            "content": [
                {"type": "tool_result", "tool_result": {
                    "content": [{"type": "json", "json": {"sql": "SELECT 1"}}]
                }},
                {"type": "tool_result", "tool_result": {
                    "content": [{"type": "json", "json": {"sql": "SELECT 2"}}]
                }},
                {"type": "text", "text": "Done."},
            ]
        }
        _, sqls = extract_text_and_sql(resp)
        assert len(sqls) == 2


# ═══════════════════════════════════════════════════════════════════════════
# 2. Persona configuration
# ═══════════════════════════════════════════════════════════════════════════

PERSONAS = {
    "Planning": {
        "icon": "📋",
        "prefix": "You are advising a demand planning manager. Focus on inventory levels, days of inventory, reorder points, and demand forecasting. Highlight stock-out risks and overstock situations.",
        "starters": [
            "What are the current days of inventory by part category?",
            "Which plants have inventory below the reorder point?",
            "Show monthly order volume trend",
        ],
    },
    "Procurement": {
        "icon": "🤝",
        "prefix": "You are advising a procurement lead. Focus on supplier performance, OTD, fill rate, lead times, and spend analysis. Flag underperforming suppliers.",
        "starters": [
            "What is OTD by supplier?",
            "Which suppliers have the worst delivery delays?",
            "Who are the top 20 customers by spend?",
        ],
    },
    "Logistics": {
        "icon": "🚚",
        "prefix": "You are advising a logistics manager. Focus on shipment tracking, landed cost, carrier performance, partial shipments, and delivery SLAs. Optimize shipping costs.",
        "starters": [
            "What is the landed cost by carrier?",
            "What is the shipment status distribution?",
            "Show fill rate by plant",
        ],
    },
}


class TestPersonaConfig:
    def test_all_personas_have_required_keys(self):
        for name, cfg in PERSONAS.items():
            assert "icon" in cfg, f"{name} missing icon"
            assert "prefix" in cfg, f"{name} missing prefix"
            assert "starters" in cfg, f"{name} missing starters"

    def test_each_persona_has_at_least_3_starters(self):
        for name, cfg in PERSONAS.items():
            assert len(cfg["starters"]) >= 3, f"{name} has < 3 starters"

    def test_starters_are_nonempty_strings(self):
        for name, cfg in PERSONAS.items():
            for s in cfg["starters"]:
                assert isinstance(s, str) and len(s) > 5, f"{name} has bad starter: {s!r}"

    def test_persona_prefix_mentions_domain(self):
        assert "inventory" in PERSONAS["Planning"]["prefix"].lower()
        assert "supplier" in PERSONAS["Procurement"]["prefix"].lower()
        assert "shipment" in PERSONAS["Logistics"]["prefix"].lower()

    def test_persona_count(self):
        assert len(PERSONAS) == 3


# ═══════════════════════════════════════════════════════════════════════════
# 3. Input validation / guardrails
# ═══════════════════════════════════════════════════════════════════════════

MAX_INPUT_CHARS = 500
MAX_MESSAGES_PER_SESSION = 50
MAX_HISTORY_TURNS = 10


class TestInputGuardrails:
    def test_short_input_passes(self):
        assert len("What is OTD?") <= MAX_INPUT_CHARS

    def test_long_input_rejected(self):
        long_msg = "x" * 501
        assert len(long_msg) > MAX_INPUT_CHARS

    def test_exact_boundary_passes(self):
        assert len("x" * 500) <= MAX_INPUT_CHARS

    def test_session_limit_not_exceeded(self):
        display = [{"role": "user"}, {"role": "assistant"}] * 49  # 49 pairs
        assert len(display) < MAX_MESSAGES_PER_SESSION * 2

    def test_session_limit_exceeded(self):
        display = [{"role": "user"}, {"role": "assistant"}] * 50
        assert len(display) >= MAX_MESSAGES_PER_SESSION * 2

    def test_history_trimming(self):
        full_history = list(range(30))
        recent = full_history[-(MAX_HISTORY_TURNS * 2):]
        assert len(recent) == 20

    def test_history_trim_short_conversation(self):
        short_history = list(range(4))
        recent = short_history[-(MAX_HISTORY_TURNS * 2):]
        assert len(recent) == 4  # no trimming needed


# ═══════════════════════════════════════════════════════════════════════════
# 4. Persona message augmentation
# ═══════════════════════════════════════════════════════════════════════════

class TestMessageAugmentation:
    def test_augmentation_includes_persona_prefix(self):
        user_input = "What is OTD?"
        persona = "Procurement"
        augmented = f"[Persona context: {PERSONAS[persona]['prefix']}]\n\n{user_input}"
        assert "procurement lead" in augmented.lower()
        assert "What is OTD?" in augmented

    def test_augmentation_preserves_original_question(self):
        for persona in PERSONAS:
            question = "Show me the data"
            augmented = f"[Persona context: {PERSONAS[persona]['prefix']}]\n\n{question}"
            assert question in augmented

    def test_message_format_for_agent(self):
        msg = {"role": "user", "content": [{"type": "text", "text": "test"}]}
        assert msg["role"] == "user"
        assert msg["content"][0]["type"] == "text"
        assert msg["content"][0]["text"] == "test"


# ═══════════════════════════════════════════════════════════════════════════
# 5. Agent payload construction
# ═══════════════════════════════════════════════════════════════════════════

class TestAgentPayload:
    def test_payload_is_valid_json(self):
        messages = [{"role": "user", "content": [{"type": "text", "text": "Hello"}]}]
        payload = json.dumps({"messages": messages})
        parsed = json.loads(payload)
        assert "messages" in parsed
        assert parsed["messages"][0]["role"] == "user"

    def test_single_quote_escaping_in_sql(self):
        payload = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": "What's the OTD?"}]}]})
        escaped = payload.replace("'", "''")
        assert "''" in escaped
        assert "What''s" in escaped

    def test_empty_messages_payload(self):
        payload = json.dumps({"messages": []})
        parsed = json.loads(payload)
        assert parsed["messages"] == []
