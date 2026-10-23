# AI builds by Jonathan

I find manual workflows that eat people's time and turn them into AI agents and automations. 15 years building on Salesforce, now building agents with Claude, Gemini and Agentforce.

This repo is where those builds live, including what broke and how I fixed it.

## The builds

| Build | What it does | Tools | Demo |
|---|---|---|---|
| [Time Audit agent (Google ADK)](./time-audit-adk) | Reviews a week of calendar and task data and recommends what to cut, delegate or batch. A human approves before anything is saved. | Gemini, Google ADK, Python | [2-min video](https://www.loom.com/share/7fb55e92032f49788ee9279cedbbc7ef) |
| [Time Audit agent (Claude)](./time-audit-claude) | Periodically checks in to ask what you're working on and how you're feeling about it, then provides a daily summary report. | Claude, scheduled tasks, Artifacts | |
| [Time Audit app (Lovable)](./time-audit-lovable) | Surveys a user on where their 168 hours per week went, compares against a goal week and provides a chart. | Lovable, Claude, Supabase | |
| [Sales support agent (Salesforce)](./sales-support-agent) | An AI agent that answers questions from knowledge articles and manages CRM records like opportunities, contacts and activities. | Agentforce, Prompt Builder, Flow | |
| [Call to proposal agent (Claude)](./Call-to-proposal-claude) | Creates a polished proposal from call transcripts in minutes. | Claude, RAG, Google Docs Connector | [2-min video](https://www.loom.com/share/da96f6c1ce484bc0b90cb979df084f6f) |

## How I build

1. **Start with the workflow.** Map how the work gets done today and where the hours go before picking a tool.
2. **Put the math in code.** The model handles judgment. Anything that has to be exactly right, like hour totals, runs in code so the model can't invent numbers.
3. **Keep a human in the loop.** Agents recommend. People approve anything that writes, sends or changes data.
4. **Log everything.** Every tool call is recorded, so I can see what the agent did and why.
5. **Test against real cases.** Every failure becomes a test case, so it can't quietly come back.

## What testing caught

The Time Audit agent looked fine on its first run. Checking it against its own rules told a different story:

| Run | What went wrong | Fix |
|---|---|---|
| 1 | Skipped the 2 biggest no-agenda meetings (4 hours a week) | The tool now returns a ready-made list of every no-agenda meeting |
| 2 | Flagged meetings but gave no action for them | New rule: every flagged meeting gets Cut, Shorten, Add an agenda or Keep |
| 2 | Counted batched time as fully saved, inflating the total to 9.5 hours | Batching now counts as an estimated 25% saving. The total dropped to a realistic 5.9 hours |

Each of these is now a saved test case. Details are in the [Time Audit agent README](./time-audit-adk).

## About me

Founder of [TimeWealth Co.](https://timewealthco.com), where I help growing companies plan and build AI, CRM and automation programs. Certified Salesforce Application Architect. Based in Boulder, Colorado.

[LinkedIn](https://www.linkedin.com/in/jonathan-osgood-2b467932) · jonathan@timewealthco.com
