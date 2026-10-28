# Deployment copilot (Salesforce)

**An Agentforce agent that helps a deployment strategist run a 12-week customer AI engagement: it scores AI readiness, drafts a roadmap, and watches adoption.**

▶️ **[Watch the demo](https://www.loom.com/share/772640f3b7744d9188f7ecfded1356d2)**: adoption from Data 360, an ambiguous name, a high readiness score that still comes back Blocked, and a roadmap that refuses to save a version nobody has seen.

> **Status:** built and running in a Developer Edition org. The agent is published and active, and its adoption numbers come from Data 360. All 20 manual test conversations in [docs/MANUAL_TESTS.md](docs/MANUAL_TESTS.md) pass against real data, and so do all 13 cases in the automated agent test suite ([tests/agent](tests/agent/Deployment_Copilot_Tests.yaml)).

## The problem

I've spent my career on the delivery side of Salesforce: architect, project manager, practice lead. The demo is the easy part of an agent project. What sinks engagements comes later. Bad inputs. A missing executive sponsor. Adoption that peaks in week 4 and slides for a month.

So I built an agent around the lifecycle I'd run on a real engagement (Identify, Commit, Deploy, Consume) and made it handle those cases on purpose.

## What it does

| Job | You say | What happens |
|---|---|---|
| Score readiness | "Score Alder Ridge readiness: data 5, use case 5, sponsorship 1..." | Apex scores 6 dimensions, saves the assessment, and returns a band. A missing sponsor or missing AI governance forces **Blocked**, whatever the total says. |
| Draft a roadmap | "Draft a roadmap for Quarry Lane. Go live in 10 weeks." | A Prompt Builder template drafts 4 phases with exit checks. The agent shows the draft and asks before saving. |
| Watch adoption | "How is Fernhollow doing?" | A Data 360 calculated insight computes weekly adoption and containment. Apex compares to last week and returns a risk level with the flags behind it. |

Anything else gets a polite decline.

<img src="docs/images/agent-chat.png" alt="The agent in the Agentforce panel reporting Fernhollow's adoption: 25.0%, down 8.3 points, containment 39.5%, risk High, with 3 flags and suggested questions" width="360">

*Fernhollow in the Agentforce panel. Every number comes from the action, and the flags explain the High.*

## How it's built

- **Tools:** Agentforce (Agent Script), Prompt Builder, Apex, Data 360, Salesforce CLI
- **Model:** the org's default for the prompt template (GPT-5 Mini when I built it)
- **Data in:** 3 custom objects (Engagement, Readiness Assessment, Adoption Metric) seeded with synthetic data. Every customer is made up. Engagement and Adoption Metric also stream into Data 360.
- **Agent design:** 1 employee agent with a router and 4 subagents (readiness, roadmap, adoption, off-topic), calling 4 Apex actions and 1 prompt template. The adoption action reads Data 360; the other 3 read CRM. Diagram in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Guardrails:** a prompt is a request, so the rules that matter most live in code.

| Rule | Enforced by |
|---|---|
| The LLM never does the math | `ReadinessCalculator`, `AdoptionCalculator` (unit tested) |
| Scores must be 1 to 5, all 6 present | `ReadinessCalculator.validate` |
| A roadmap saves only after the user has seen it | The save tool doesn't exist until a turn after the draft. Agent Script sets `draft_presented` in `after_reasoning`, once the reply with the draft has gone out. |
| A roadmap saves only after approval | `RoadmapWriterAction` refuses unless `approvedByUser` is true |
| Adoption numbers always come from the action | `get_adoption` runs in the script logic every time, so the model can't skip it and guess |
| Data 360 doesn't bypass record access | `AdoptionInsightAction` checks the engagement with a `USER_MODE` query before it queries Data 360, which doesn't apply CRM sharing |
| The saved text is the text the user saw | The agent binds the saved text to its draft variable, so the model can't reword it between "show" and "save" |
| Engagement names resolve to IDs in code | `EngagementContextAction` |
| Record contents are data, not instructions | System instructions, plus Salesforce's built-in prompt-injection guardrail, which caught the injection test case before the agent saw it |
| Users only touch records they can see | `WITH USER_MODE` and `as user` throughout, plus a permission set. A unit test proves a user without it can't write. |

![Agentforce Builder showing the router and 4 subagents, with adoption_tracking open and its conditional reasoning instructions](docs/images/agent-builder.png)

*The adoption subagent in Agentforce Builder. The `If` blocks are Agent Script logic. They run as code, so the model can't skip them.*

### Tests

All 13 cases in the agent test suite pass on subagent, actions, and response. The first run failed 6 cases. One was a real bug ("Long requests" in What I learned). The other five were my test spec's fault, and the build guide lists them.

![Agentforce Testing Center: 13 test cases, 100% subagent, action, and response pass rates](docs/images/testing-center.png)

46 Apex tests pass. Coverage is 100% on 6 of the 7 production classes and 93% on `AdoptionInsightAction`, whose 4 uncovered lines are the live Data 360 call, which can't run in a test.

<img src="docs/images/test-apex.png" alt="Apex test summary: 46 tests ran, 100% pass rate, 98% org-wide coverage" width="420">

### Run it

You need a Developer Edition org with Agentforce turned on, and the Salesforce CLI.

```bash
sf org login web --alias copilot --set-default
sf project deploy start -m CustomObject
sf project deploy start -m ApexClass -m PermissionSet
sf org assign permset --name Deployment_Copilot_Access
sf apex run --file scripts/apex/seed-data.apex
sf apex run test --test-level RunLocalTests --code-coverage --wait 10
sf project deploy start -m GenAiPromptTemplate
sf project deploy start -m AiAuthoringBundle
sf agent publish authoring-bundle --api-name Deployment_Copilot
sf agent activate --api-name Deployment_Copilot --version 1
```

For the Data 360 version, follow the stretch steps in the build guide ([data360/setup.sh](data360/setup.sh) does most of it). The agent test commands are at the top of [the test spec](tests/agent/Deployment_Copilot_Tests.yaml).

`sf agent preview` needs `@salesforce/plugin-agent` 2.2.3 or later (`sf plugins install @salesforce/plugin-agent@latest`). Older versions crash on employee agents. The full walkthrough is in [docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md).

```
force-app/main/default/
  objects/              Engagement, Readiness Assessment, Adoption Metric
  classes/              7 production classes, 7 test classes, 1 data factory
  genAiPromptTemplates/ Draft_Deployment_Roadmap (Prompt Builder template)
  aiAuthoringBundles/   Deployment_Copilot.agent (Agent Script)
  permissionsets/       Deployment_Copilot_Access, plus read access for the Data 360 connector
data360/                Data streams, data model objects, mappings, and the calculated insight SQL
prompts/                Why the roadmap prompt is written the way it is
scripts/apex/           Seed and reset scripts
tests/agent/            Agent test suite
docs/                   Architecture, build guide, manual test script, screenshots
```

## Data 360 version

The first build read adoption with SOQL. I then streamed the same records into Data 360, built a calculated insight on top, and pointed the agent at it. Both actions still exist and return the same fields, so switching back is a one-line change to the action's `target`.

```
Adoption_Metric__c ─▶ data stream ─▶ Adoption_Metric__dlm ─▶ Weekly_Adoption__cio ─▶ AdoptionInsightAction ─▶ agent
   (CRM)              (CRM connector)     (custom DMO)           (calculated insight)    (Query API + risk rules)
```

The insight does the rates ([data360/Weekly_Adoption.ci.sql](data360/Weekly_Adoption.ci.sql)). Apex still does the risk rules, so the thresholds stay in one unit-tested place for both sources. [data360/setup.sh](data360/setup.sh) rebuilds the whole Data 360 side through the REST API.

![The Weekly Adoption calculated insight in Data Cloud, showing its SQL expression](docs/images/data360-insight.png)

**Do the numbers match?** Yes. I ran both actions on all 4 engagements and the summaries were identical, character for character. I also compared every weekly rate, 12 of 12. Then I reran the adoption conversations (A1, A4, D3) through the agent with live actions, and they passed. A rounding tie the seed data never hits did differ, and that's fixed (last row of What I learned).

| | SOQL (`AdoptionSnapshotAction`) | Data 360 (`AdoptionInsightAction`) |
|---|---|---|
| Freshness | Live. A record saved a second ago shows up. | 20 to 50 minutes behind, measured. A new CRM record took 20 minutes to reach the data model object. A delete took 41. Each insight run then took 2.5 to 10 minutes, and only ran because I started it by hand. |
| Where the math lives | Apex, unit tested | SQL in the insight for the rates, Apex for the risk rules |
| Record access | `WITH USER_MODE` does it | Data 360 doesn't apply CRM sharing, so the action checks access in CRM first |
| Testing | Plain Apex tests | ConnectApi can't run in tests, so the query sits behind a class the tests replace |
| Setup | None | License, tenant provisioning, a connector permission set, 2 streams, 2 DMOs, 2 mappings, 1 insight |
| Cost | Nothing extra | Ingestion and insight runs use Data 360 credits |
| Other data sources | CRM only | Anything Data 360 ingests: other orgs, warehouses, agent session data |

**Pros of Data 360 here**
- One shared definition of "adoption rate" that dashboards, segments, and other agents can reuse
- Room to add inputs from outside CRM (agent session logs, HR systems, other orgs), which is where real adoption data lives
- The rate math runs in the platform instead of in Apex

**Cons of Data 360 here**
- Stale: 20 to 50 minutes behind CRM in my tests, plus a manual insight run
- Setup: a license, tenant provisioning, a connector permission set, 2 streams, 2 DMOs, 2 mappings, and 1 insight, where SOQL needed none
- Every ingestion and insight run costs Data 360 credits
- More to get right: it ignores CRM sharing, it rounds differently from Apex, and the query can't run in tests

**Which I'd pick for a customer.** For this exact project, SOQL. The data is 12 rows in one org, and a strategist asking "how's Fernhollow doing?" in a customer meeting wants the week they logged before the call, and with Data 360 that might not be there yet.

For a real engagement I'd pick Data 360, because the real inputs don't live in a custom object. Adoption comes from the agent's own conversation logs, and eligible users come from an HR system. And the customer's ops team will want the same adoption metric in their own dashboards. Once the data comes from more than one place, a single shared definition of "adoption rate" is worth the lag. I'd still keep the risk rules in code either way.

## What I'd add for production

- A refresh schedule for the Data 360 stream and insight, set to match how often the customer reviews adoption. Mine run by hand.
- Real adoption inputs. In production the numbers would come from the agent's own session data and credit usage, not a hand-filled custom object. That's where Data 360 starts paying for itself (see the Data 360 section).
- Real risk thresholds. The 40% adoption floor, 5-point weekly drop, and 50% containment floor are my starting heuristics, with no benchmark behind them. They're constants at the top of `AdoptionCalculator`.
- A rollback in `ScoreReadinessAction`. It writes twice (the assessment, then the engagement's score), and if the second write fails, the first one stays. It can't happen with today's sharing settings, but it would if Engagement went private.
- A service agent, a channel, and a separate security review before any customer-facing version

## What I learned

Every bug so far showed up somewhere I wasn't looking. 13 of them:

| Where | What went wrong | Fix |
|---|---|---|
| Seeding data | The seed script failed with `Field does not exist: Account__c`. The field existed. Fields deployed through the Metadata API get no field-level security, not even for admins, and anonymous Apex checks it at compile time. | Assign the permission set before seeding. The build guide had the order wrong. |
| Roadmap prompt | Every draft restarted the engagement at week 1, mid-engagement. The prompt asked for "the engagement dates in the facts," and the facts had no dates, only "Week 2 of 12." | Rewrote the week rules against the format the Apex actually sends. |
| Roadmap prompt | Every draft ended with "Thank you for your time and responsiveness." The agent saves the draft word for word, so that line would have landed on the record. | A rule to end on the last open question, with the reason in the prompt. |
| Deploying the prompt fix | The deploy said **Succeeded**, and nothing changed. Published template versions can't be edited, and the Metadata API doesn't complain when you try. | Bump the version number on every change, and retrieve after deploying to confirm. |
| Adoption check | Asked how Fernhollow was doing, the agent said "no adoption data has been logged yet." There were 6 weeks of data. The trace showed it had the tool and the instruction to call it, and skipped the call. | `get_adoption` runs in the script logic now. The "no data" wording only appears when Apex returns Unknown. |
| Roadmap save | The user said "looks good, save it" to a question about constraints. In one turn the agent drafted a roadmap, saved it, and said "saved." Nobody saw it. The approval check lived in Apex, but the model filled in the approval flag. | The save tool only appears a turn after the draft, so saving always needs another message from the user. |
| Ambiguous names | "Alder Ridge" matches 2 engagements, so the ID came back null. The script checked `!= ""`, null passed, and an action ran with no input. | Every check now tests for null too. |
| Data 360 stream | Creating the stream failed with "the following data lake fields are missing a value" for every custom field. The standard fields worked. The Data 360 connector runs as its own integration user, and that user couldn't read my custom objects. | A read-only permission set for the connector user. The Engagement stream then pulled in every field the user could read, including the full roadmap text, so the permission set is also where you limit what Data 360 copies. |
| Calculated insight | `SUM(active) * 100 / SUM(eligible)` was rejected: "one side of the math operation contains aggregation." So was `SUM(active * 100) / SUM(eligible)`. `100 * SUM(active) / SUM(eligible)` passed. It's the same math in a different order. | I tested 10 small queries to find which shape the validator accepts. |
| Data 360 numbers | Data 360 returns numbers with 18 decimal places. The agent repeats the summary word for word, so it would have said "3800.000000000000000000 credits." | The action rounds each value to the CRM field's scale, and a unit test feeds it the raw format. |
| Picking from a list | Asked about "Alder Ridge", the agent listed both matches. The user replied "The Service Agent one." In 1 of 3 runs the agent said that engagement had no adoption data, without calling anything. The data was there: 70.0% adoption. | Until an engagement is selected, the script tells the agent it hasn't looked anything up, so it can't say data is missing. It also says to look up the pick by its full name. 9 of 9 reruns passed. |
| Long requests | "Score Alder Ridge Service Agent: data 5, use case 5…" came back with "which Alder Ridge?" in 2 of 3 runs. The lookup was fine. The model had shortened the name to "Alder Ridge" before searching. The agent test suite caught it on its first run. | The script now says to pass every word of the name, including "Service Agent" or "Pilot". 5 of 5 reruns passed, and so did the full suite. |
| Comparing the two sources | Both sources matched on all 12 seed rows, but only because no row landed on a tie. At 49 of 400 users, Apex said 12.2% and Data 360 said 12.3%. | Apex rounds half up now, like SQL. A test pins the 49-of-400 case. |

The adoption check and the roadmap save are the reason this project exists. Both times the model ignored a clear instruction, and both fixes moved the rule out of the prompt and into the script.

Two of my own fixes broke things too. Telling the model to "number them as engagement weeks" pushed 2 of 5 drafts past the word limit. Then the example I added, `"Weeks 3-5"`, made 4 of 5 drafts start at week 3, because the model copied the number. Placeholder letters fixed it.

So one preview proves nothing. I ran every version of the prompt 5 times through the API and read the drafts, and that's the only reason I caught any of this.
