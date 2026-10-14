# AI builds by Jonathan Osgood

I find the manual work that eats people's weeks and turn it into AI agents and automations.

I spent 15 years building on Salesforce as a developer, architect and practice director. Now I build agents with Gemini, Claude and Agentforce. This repo is where those builds live, including what broke and how I fixed it.

## The builds

| Build | What it does | Built with | Status |
|---|---|---|---|
| [Time Audit agent (Google ADK)](./ai-builds/time-audit-adk) | Reviews a week of calendar data and recommends what to cut, delegate or batch. A human approves before anything is saved. | Gemini, Google ADK, Python | Working, with logging and evals |
| [Time Audit agent (Claude)](./ai-builds/time-audit-claude) | periodically checks in to see what I'm working on, the overall sentiment and creates a daily report | Claude | Working demo |
| [Time Audit app (Lovable)](./ai-builds/time-audit-lovable) | walks user through time audit, compares to ideal week and provides dashboard | Lovable | Working demo |
| [Sales support agent (Salesforce)](./ai-builds/sales-support-agent) | CRM Record Summary Agent | Agentforce, Prompt Builder, Flow | Working demo |

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

Each of these is now a saved test case. Details are in the [Time Audit agent README](./ai-builds/time-audit-adk).

## About me

Founder of [TimeWealth Co.](https://timewealthco.com), where I help growing companies plan and build AI, CRM and automation programs. Certified Salesforce Application Architect. Based in Boulder, Colorado.

[LinkedIn](https://www.linkedin.com/in/jonathan-osgood-2b467932) · jonathanosgood@gmail.com
