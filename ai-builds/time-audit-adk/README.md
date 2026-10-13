# Time Audit agent on Google ADK

**An agent that reviews a week of calendar and task data and recommends what to cut, delegate or batch, with an approval step before it changes anything.**

▶ [2-minute demo video](link)

## Why I rebuilt it
I first built this as a Claude agent and a Lovable app. I rebuilt it on Google's Agent Development Kit (ADK) with Gemini to add the things a production version needs: logging, a human approval step, and an evaluation set.

## Architecture
```
User → ADK agent (Gemini) → tool: read_calendar (CSV / Google Sheet)
                         → tool: propose_changes
                         → approval callback (human confirms)
                         → log every run (input, tool calls, output)
```

- **Agent:** [model name], instructions in `agent.py`
- **Tools:** `read_calendar` [describe], `propose_changes` [describe]
- **Approval:** a callback pauses before any write and asks the user to confirm
- **Logging:** each run saved to [file / folder] with input, tool calls and output

## Evaluation
- **Test set:** [10] sample weeks with expected recommendations (`eval/`)
- **What counts as a pass:** [e.g., flags every meeting over 60 min with no agenda; never suggests cutting a blocked focus time]
- **Result:** [X/10] passed. [One sentence on what failed and why.]

 ## Reliability: what broke and how I handled it.
 my agent failed on a 503 from the model, so I switched models, and in production I'd add automatic retries with a fallback model
<img width="1552" height="795" alt="2026-10-13_14-48-17" src="https://github.com/user-attachments/assets/f15847db-9596-42b5-8752-1b4b6a234344" />

Retired model (404 NOT_FOUND). My fallback, gemini-2.5-flash, was no longer available to new users. I moved to gemini-3.8-flash. Lesson: don't hard-code a model version without a plan to update it. In production I'd keep the model name in configuration, not code, and check deprecation notices on a schedule.
<img width="1552" height="795" alt="2026-10-13_14-48-17" src="https://github.com/user-attachments/assets/2c7a8866-99ed-43c9-aa6a-5681e44d9482" />


## Run it
1. Get a Gemini API key from Google AI Studio
2. `pip install google-adk`
3. Add your key to `.env`
4. `adk web` and open the local URL

## Next steps
- Connect to Google Calendar through MCP instead of a CSV
- Load run logs into BigQuery and track adoption and time saved
- Expand the test set to [50] cases

## Built with
Python (written with AI assistance in Antigravity), Google ADK, Gemini.
