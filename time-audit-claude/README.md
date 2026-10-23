# Time Audit agent (Claude)

**Periodically checks in to ask what you're working on and how you're feeling about it and Provides a daily summary report.**

## The problem
Most people get to the end of the day or week and realize they didnt do what they wanted to do. They skipped a work out or wasted time reacting to slack and email. The first step to course correcting is awareness. This agent provides that awareness.

## What it does
1. Every two hours sends a notification and asks what you were working on, were you creating or consuming, what it energizing, neutral, draining. 
2. Weekly goals are captured 
3. A weekly summary is produced

<img width="810" height="342" alt="2026-10-15_13-23-37" src="https://github.com/user-attachments/assets/a732f5b9-9b5d-4b27-85d9-47627d6dfaf7" />
<img width="1037" height="1940" alt="2026-10-15_13-25-49" src="https://github.com/user-attachments/assets/8078111e-254f-48ee-9948-1df01c64e836" />

## How it's built
- **Tools:** Claude
- **Model:** Sonnet 5
- **Data in:** user reported survey
- **Prompt or agent design:** This is a scheduled check-in for Jonathan's "Time & Sentiment Audit" tracker — a private Artifact dashboard. It fires at 11am and 1pm America/Denver on weekdays.

1. Determine the current date and time in America/Denver. This check-in covers the block that just ended: 9:00–11:00 AM if it's the 11am run, or 11:00 AM–1:00 PM if it's the 1pm run.

2. Send Jonathan this message and wait for his reply: "Quick check-in — what did you spend the last 2 hours doing? Was it energizing, draining, or neutral? Were you mostly consuming content or creating/producing something?"

3. If he doesn't respond, or says to skip it, don't log anything — just acknowledge and end the conversation.

4. Once he replies, extract: a short activity description (a few words), sentiment (energized / drained / neutral), and mode (creating / consuming). Classify which of his weekly goals the activity mainly served: business (building his new business), income (work that generates income), exercise, or other (anything that doesn't clearly serve one of those three, including passive content consumption/distraction). If it's genuinely ambiguous, ask him which bucket fits best; otherwise pick the closest fit yourself and say which you picked.

5. Write the check-in using the Artifact tool's write_db action:, db_op "set", collection "checkins", doc_id formatted as "<YYYY-MM-DD>T<HH:MM>" using today's America/Denver date and the block's start time in 24-hour form (e.g. "2026-09-10T11:00" for the 11am run, "2026-09-10T13:00" for the 1pm run). data: {date: "YYYY-MM-DD", time: "HH:MM" (the block start, e.g. "09:00" or "11:00"), durationMinutes: 120, activity: "<short description>", sentiment: "energized"|"drained"|"neutral", mode: "creating"|"consuming", goal: "business"|"income"|"exercise"|"other", loggedAt: "<current ISO timestamp>", source: "scheduled"}.

6. Reply with a one-line confirmation of what was logged (e.g. "Logged: 9–11am, income, energized, creating.").
- **Guardrails:** Requires manual approval to submit response and generate report

## Results
- Time and Sentiment Audit of a given week. Visibility into where time is spent and resulting energy created or consumed.

## What I'd add for production
- Logging and monitoring
- An evaluation set to catch quality drift
- Access controls / data privacy

## What I learned
Awareness of how your time is spent is key to behavior change but there is a lot of friction manually tracking. This reduces that friction. 
