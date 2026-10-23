"""Time Audit agent built with Google's Agent Development Kit (ADK).

Reads a week of calendar data, does the time math in code, and recommends
what to cut, delegate or batch. Saving recommendations requires a human to
click Confirm. Every tool call is logged to logs/runs.jsonl.
"""

import csv
import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from google.adk.agents.llm_agent import Agent
from google.adk.tools import FunctionTool

BASE = Path(__file__).parent
DATA_FILE = BASE / "data" / "week.csv"
LOG_FILE = BASE / "logs" / "runs.jsonl"
OUTPUT_DIR = BASE / "output"


# ---------- helpers ----------

def _hours(start: str, end: str) -> float:
    fmt = "%H:%M"
    delta = datetime.strptime(end, fmt) - datetime.strptime(start, fmt)
    return round(delta.total_seconds() / 3600, 2)


def _load_events() -> list[dict]:
    with open(DATA_FILE, newline="") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        r["hours"] = _hours(r["start"], r["end"])
        r["attendees"] = int(r["attendees"])
    return rows


# ---------- tools ----------

def read_calendar() -> dict:
    """Reads the user's calendar for the week and returns every event.

    Returns:
        dict: status and a list of events with date, start, end, title,
        category, attendees, has_agenda, recurring and hours.
    """
    try:
        events = _load_events()
        return {"status": "success", "event_count": len(events), "events": events}
    except FileNotFoundError:
        return {"status": "error", "message": f"No calendar file at {DATA_FILE}"}


def calculate_time_breakdown() -> dict:
    """Calculates where the week's hours went. Use this for all numbers.

    Returns:
        dict: total hours, hours by category, every meeting without an agenda
        (with hours), hours in recurring meetings, and the event titles that
        took 2+ hours this week.
    """
    events = _load_events()
    by_category = defaultdict(float)
    by_title = defaultdict(float)
    no_agenda = defaultdict(float)
    recurring = 0.0
    for e in events:
        by_category[e["category"]] += e["hours"]
        by_title[e["title"]] += e["hours"]
        is_meeting = "meeting" in e["category"].lower()
        if is_meeting and e["has_agenda"] == "no":
            no_agenda[e["title"]] += e["hours"]
        if e["recurring"] == "yes":
            recurring += e["hours"]
    largest = {t: round(h, 2) for t, h in by_title.items() if h >= 2.0}
    return {
        "status": "success",
        "total_hours": round(sum(e["hours"] for e in events), 2),
        "hours_by_category": {k: round(v, 2) for k, v in by_category.items()},
        "meetings_without_agenda": {k: round(v, 2) for k, v in sorted(no_agenda.items(), key=lambda x: -x[1])},
        "meeting_hours_without_agenda": round(sum(no_agenda.values()), 2),
        "recurring_hours": round(recurring, 2),
        "largest_time_blocks": dict(sorted(largest.items(), key=lambda x: -x[1])),
    }


def save_recommendations(recommendations: str) -> dict:
    """Saves the final recommendations to a file. Only call this after the
    user asks to save. A human must confirm before it runs.

    Args:
        recommendations: The full recommendations text in markdown.

    Returns:
        dict: status and the path of the saved file.
    """
    OUTPUT_DIR.mkdir(exist_ok=True)
    path = OUTPUT_DIR / f"time_audit_{datetime.now():%Y%m%d_%H%M%S}.md"
    path.write_text(recommendations)
    return {"status": "success", "saved_to": str(path)}


# ---------- logging callbacks ----------

def _log(entry: dict) -> None:
    LOG_FILE.parent.mkdir(exist_ok=True)
    entry["timestamp"] = datetime.now().isoformat(timespec="seconds")
    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(entry, default=str) + "\n")


def log_tool_start(tool, args, tool_context):
    _log({
        "event": "tool_start",
        "invocation_id": getattr(tool_context, "invocation_id", None),
        "tool": tool.name,
        "args": args,
    })
    return None  # None means: let the tool run normally


def log_tool_end(tool, args, tool_context, tool_response):
    _log({
        "event": "tool_end",
        "invocation_id": getattr(tool_context, "invocation_id", None),
        "tool": tool.name,
        "status": tool_response.get("status") if isinstance(tool_response, dict) else None,
    })
    return None  # None means: keep the tool's real response


# ---------- agent ----------

INSTRUCTION = """
You are a time audit coach for busy founders and team leads.

When the user asks for a time audit:
1. Call read_calendar to see the week.
2. Call calculate_time_breakdown. Use ONLY its numbers. Never do math yourself.
3. Recommend changes in three groups: Cut, Delegate, Batch.
   - Name the specific events and the hours each one takes.
   - Estimate hours reclaimed per week for each recommendation.
4. End with one line: total hours reclaimed per week if they follow the plan.

Rules:
- Never recommend cutting anything in the Focus or Family categories.
- Start with a section called "No-agenda meetings" that lists EVERY item in
  meetings_without_agenda with its hours. Then give Cut, Delegate and Batch.
- When you add hours together, show the numbers you added.
- Every meeting in No-agenda meetings must get an action: Cut, Shorten, Add an
  agenda, or Keep (with a one-line reason). Don't list a meeting without an action.
- For Batch items, count only the time saved by grouping, estimated at 25% of the
  batched hours. Label it as an estimate.
- Keep it short and concrete. No generic productivity advice.
- Only call save_recommendations if the user asks to save the plan.
"""

root_agent = Agent(
    model="gemini-flash-lite-latest",
    name="time_audit_agent",
    description="Audits a week of calendar data and recommends what to cut, delegate or batch.",
    instruction=INSTRUCTION,
    tools=[
        read_calendar,
        calculate_time_breakdown,
        FunctionTool(save_recommendations, require_confirmation=True),
    ],
    before_tool_callback=log_tool_start,
    after_tool_callback=log_tool_end,
)
