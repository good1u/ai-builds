# Time Audit agent on Google ADK

**An agent that reviews a week of calendar and task data and recommends what to cut, delegate or batch, with an approval step before it changes anything.**

▶ [2-minute demo video](https://www.loom.com/share/7fb55e92032f49788ee9279cedbbc7ef)

## Why I rebuilt it
I first built this as a Claude agent and a Lovable app. I rebuilt it on Google's Agent Development Kit (ADK) with Gemini to add the things a production version needs: logging, a human approval step, and an evaluation set.

## Architecture
```
User → ADK agent (Gemini) → tool: read_calendar            (loads the week from CSV)
                         → tool: calculate_time_breakdown  (all math, in code)
                         → tool: save_recommendations      (human must confirm)
                         → log every tool call             (logs/runs.jsonl)
```

- **Agent:** `gemini-flash-lite-latest`, instructions in `agent.py`
- **Tools:**
  - `read_calendar` loads 29 events from `data/week.csv`
  - `calculate_time_breakdown` totals hours by category, lists every meeting without an agenda, and calculates meeting, client and recurring hours. The agent is told to use only these numbers.
  - `save_recommendations` writes the final plan to `output/`
- **Approval:** `save_recommendations` is wrapped with `require_confirmation=True`, so ADK pauses and asks the user to confirm before anything is written
- **Logging:** callbacks before and after every tool call save to `logs/runs.jsonl`
- **Rules:** never cut Focus or Family time, give every no-agenda meeting an action, show the math, count batching as an estimated 25% saving

**Design principle:** anything that has to be exactly right (counting, totals, definitions) runs in code. The model handles judgment.

## Evaluation
- **Test set:** 10 prompts run against a fixed sample week (29 events, 31.5 hours), saved in `time_audit_agent/time_audit_evals.evalset.json`
- **What counts as a pass:** the agent calls the right tools in the right order (tool trajectory 1.0) and its answer is close to the approved answer (response match 0.5, kept loose because wording varies run to run)
- **Result:** 9/10 passed. The one failure: asked "How many hours did I spend in meetings?", the agent double counted client calls as external meetings, because nothing defined what a "meeting" was.
- **Fix:** the tool now calculates `meeting_hours` (internal + external) and `client_hours` in code, and a new rule tells the agent never to add client time into meeting totals. The next eval run will confirm it.

| # | Prompt | Passes if... |
|---|---|---|
| 1 | Run a time audit on my week | Calls both tools; No-agenda, Cut, Delegate and Batch sections; math shown |
| 2 | Where am I wasting the most time? | Leads with no-agenda meetings |
| 3 | How many hours did I spend in meetings? | 11.5 hours (internal + external), client time reported separately |
| 4 | What should I delegate? | Names admin tasks with hours |
| 5 | Should I cancel my family time on Wednesday? | Says no |
| 6 | Can I cut my deep work blocks? | Says no |
| 7 | What should I do about my no-agenda meetings? | Every meeting gets an action |
| 8 | How much time could I get back each week? | Batching counted at 25%, labeled as an estimate |
| 9 | Give me 3 things to batch | Groups admin and email blocks |
| 10 | Summarize my week in one sentence | One sentence with a real total |

<img width="492" height="753" alt="2026-10-14_15-23-28" src="https://github.com/user-attachments/assets/c5b9271c-9efb-47a6-abef-213378593102" />


### What testing caught

| # | Problem | Root cause | Fix |
|---|---|---|---|
| 1 | Skipped the 2 biggest no-agenda meetings | Model had to find them in 29 raw events | Tool returns a ready-made list |
| 2 | Flagged meetings but gave no action | Rule said "flag," not "act" | Every flagged meeting gets Cut, Shorten, Add an agenda or Keep |
| 3 | Claimed 9.5 hours saved | Counted batched time as fully saved | Batching counts as 25%, labeled an estimate. Total dropped to 6.1 hours |
| 4 | Double counted client calls as meetings | No definition of "meeting" | Meeting hours calculated in code; rule defines meetings as internal + external |

The pattern behind all 4: when the model has to search, count or interpret on its own, it drifts. Moving that work into code and writing rules specific enough to test fixed each one.

**Tested by hand:** asking the agent to save triggers a Confirm step. Approve writes the file. Reject writes nothing.

## Reliability: what broke and how I handled it

**Model overloaded (503 UNAVAILABLE).** My agent failed on a 503 from the model, so I switched models, and in production I'd add automatic retries with a fallback model.
<img width="1552" height="795" alt="2026-10-13_14-48-17" src="https://github.com/user-attachments/assets/f15847db-9596-42b5-8752-1b4b6a234344" />

**Retired model (404 NOT_FOUND).** My fallback, gemini-2.5-flash, was no longer available to new users. I moved to gemini-flash-lite-latest, which always points to Google's current lightweight model. Lesson: don't hard-code a model version without a plan to update it. In production I'd keep the model name in configuration, not code, and check deprecation notices on a schedule.
<img width="1557" height="790" alt="2026-10-13_15-04-31" src="https://github.com/user-attachments/assets/dbe9da9e-6ad4-4ed3-a52d-9a4bed56027b" />

**Dependency failure.** The eval package wouldn't install on Python 3.15 because some of its libraries hadn't published builds for that version yet. I rebuilt the environment on Python 3.13. Lesson: pin the Python version for a project, and don't default to the newest one.

## Run it
1. Get a Gemini API key from Google AI Studio
2. Use Python 3.13:
   ```bash
   python3.13 -m venv .venv
   source .venv/bin/activate
   pip install "google-adk[eval]"
   ```
3. Copy `time_audit_agent/.env.example` to `time_audit_agent/.env` and add your key
4. `adk web --port 8000` and open http://localhost:8000
5. Run the evals:
   ```bash
   adk eval time_audit_agent time_audit_agent/time_audit_evals.evalset.json \
     --config_file_path=time_audit_agent/test_config.json --print_detailed_results
   ```

## Limits
- One sample week. A wider test would use several weeks with different shapes: meeting-heavy, admin-heavy, mostly focus time.
- Response match is a rough wording check. A rubric-based score judged by a model would measure quality more directly.

## Next steps
- Connect to Google Calendar through MCP instead of a CSV
- Load run logs into BigQuery and track adoption and time saved
- Expand the test set to 50 cases across several sample weeks

## Built with
Python (written with AI assistance in Antigravity), Google ADK, Gemini.
