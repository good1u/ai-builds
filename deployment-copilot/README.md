# Deployment copilot (Salesforce)

**An Agentforce agent that helps a deployment strategist run a 12-week customer AI engagement: it scores AI readiness, drafts a roadmap, and watches adoption.**

> **Status:** the data model, Apex, unit tests, and prompt template are deployed and tested in a Developer Edition org. The agent itself (Agent Script, preview, publish, agent test suite) is written but hasn't been validated yet. That's next.

## The problem

I've spent my career on the delivery side of Salesforce: architect, project manager, practice lead. The demo is the easy part of an agent project. What sinks engagements comes later. Bad inputs. A missing executive sponsor. Adoption that peaks in week 4 and slides for a month.

So I built an agent around the lifecycle I'd run on a real engagement (Identify, Commit, Deploy, Consume) and made it handle those cases on purpose.

## What it does

| Job | You say | What happens |
|---|---|---|
| Score readiness | "Score Alder Ridge readiness: data 5, use case 5, sponsorship 1..." | Apex scores 6 dimensions, saves the assessment, and returns a band. A missing sponsor or missing AI governance forces **Blocked**, whatever the total says. |
| Draft a roadmap | "Draft a roadmap for Quarry Lane. Go live in 10 weeks." | A Prompt Builder template drafts 4 phases with exit checks. The agent shows the draft and asks before saving. |
| Watch adoption | "How is Fernhollow doing?" | Apex reads weekly numbers, computes adoption and containment, compares to last week, and returns a risk level with the flags behind it. |

Anything else gets a polite decline.

## How it's built

- **Tools:** Agentforce (Agent Script), Prompt Builder, Apex, Salesforce CLI
- **Model:** the org's default for the prompt template (GPT-5 Mini when I built it)
- **Data in:** 3 custom objects (Engagement, Readiness Assessment, Adoption Metric) seeded with synthetic data. Every customer is made up.
- **Agent design:** 1 employee agent with a router and 4 subagents (readiness, roadmap, adoption, off-topic), calling 4 Apex actions and 1 prompt template. Diagram in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Guardrails:** a prompt is a request, so the rules that matter most live in code.

| Rule | Enforced by |
|---|---|
| The LLM never does the math | `ReadinessCalculator`, `AdoptionCalculator` (unit tested) |
| Scores must be 1 to 5, all 6 present | `ReadinessCalculator.validate` |
| A roadmap saves only after approval | `RoadmapWriterAction` refuses unless `approvedByUser` is true |
| The saved text is the text the user saw | The agent binds the saved text to its draft variable, so the model can't reword it between "show" and "save" |
| Engagement names resolve to IDs in code | `EngagementContextAction` |
| Record contents are data, not instructions | System instructions plus a prompt-injection test case |
| Users only touch records they can see | `WITH USER_MODE` and `as user` throughout, plus a permission set. A unit test proves a user without it can't write. |

39 Apex tests pass with 100% coverage on all 6 production classes.

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
```

The full walkthrough, including the agent steps, is in [docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md).

```
force-app/main/default/
  objects/              Engagement, Readiness Assessment, Adoption Metric
  classes/              6 production classes, 6 test classes, 1 data factory
  genAiPromptTemplates/ Draft_Deployment_Roadmap (Prompt Builder template)
  aiAuthoringBundles/   Deployment_Copilot.agent (Agent Script)
  permissionsets/       Deployment_Copilot_Access
prompts/                Why the roadmap prompt is written the way it is
scripts/apex/           Seed and reset scripts
tests/agent/            Agent test suite
docs/                   Architecture and build guide
```

## What I'd add for production

- Stream the adoption numbers into Data 360 and ground the agent there instead of on a custom object
- Real risk thresholds. The 40% adoption floor, 5-point weekly drop, and 50% containment floor are my starting heuristics, with no benchmark behind them. They're constants at the top of `AdoptionCalculator`.
- A rollback in `ScoreReadinessAction`. It writes twice (the assessment, then the engagement's score), and if the second write fails, the first one stays. It can't happen with today's sharing settings, but it would if Engagement went private.
- A service agent, a channel, and a separate security review before any customer-facing version

## What I learned

Every bug so far showed up somewhere I wasn't looking. 4 of them:

| Where | What went wrong | Fix |
|---|---|---|
| Seeding data | The seed script failed with `Field does not exist: Account__c`. The field existed. Fields deployed through the Metadata API get no field-level security, not even for admins, and anonymous Apex checks it at compile time. | Assign the permission set before seeding. The build guide had the order wrong. |
| Roadmap prompt | Every draft restarted the engagement at week 1, mid-engagement. The prompt asked for "the engagement dates in the facts," and the facts had no dates, only "Week 2 of 12." | Rewrote the week rules against the format the Apex actually sends. |
| Roadmap prompt | Every draft ended with "Thank you for your time and responsiveness." The agent saves the draft word for word, so that line would have landed on the record. | A rule to end on the last open question, with the reason in the prompt. |
| Deploying the prompt fix | The deploy said **Succeeded**, and nothing changed. Published template versions can't be edited, and the Metadata API doesn't complain when you try. | Bump the version number on every change, and retrieve after deploying to confirm. |

Two of my own fixes broke things too. Telling the model to "number them as engagement weeks" pushed 2 of 5 drafts past the word limit. Then the example I added, `"Weeks 3-5"`, made 4 of 5 drafts start at week 3, because the model copied the number. Placeholder letters fixed it.

So one preview proves nothing. I ran every version of the prompt 5 times through the API and read the drafts, and that's the only reason I caught any of this.
