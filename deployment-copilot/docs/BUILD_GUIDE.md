# Build guide: one weekend, about 12 hours

This repo is a scaffold. The metadata, Apex, tests, agent script, and test suite are written. You still have to deploy it, fix what your org complains about, and run the agent yourself.

That last part is the point. The value of this project is that you did it, and you can talk about every failure you hit.

**One caveat up front.** The scaffold was written without access to a live org. M0 to M3 have since been run against a Developer Edition org, and the fixes they needed are folded into the steps below. M4 to M6 (the agent) haven't been run yet, so expect a few small fixes there. The likely ones are listed at the end of this file.

| Milestone | Time | Done when |
|---|---|---|
| M0 Org and tools | 1 h | `sf org display` works and Agentforce shows up in Setup |
| M1 Data model and seed data | 1 h | 3 objects deployed, 4 engagements visible in the org |
| M2 Apex and unit tests | 2 h | All tests pass, 90%+ coverage on the six production classes |
| M3 Prompt template | 0.5 h | `Draft_Deployment_Roadmap` saved and previews a sensible draft |
| M4 Agent | 3 h | Agent validates, previews, publishes, and activates |
| M5 Agent tests and fixes | 3 h | Suite runs, failures understood, README table filled in with real results |
| M6 Polish | 2 h | Demo video, screenshots, pinned repo |

## M0. Org and tools (1 h)

1. Sign up for a free Developer Edition org at developer.salesforce.com/signup. Salesforce says the current edition includes Agentforce and Data 360, and that the org doesn't expire if you log in regularly. If you already have an older dev org, features roll out to those gradually, so a fresh one is the safer bet.
2. Install the Salesforce CLI and confirm it with `sf --version`. Install the VS Code Salesforce extensions if you use VS Code.
3. In Setup, search for **Agentforce** and turn on the Agentforce and generative AI features. Menu names move between releases, so search instead of following a path.
4. Confirm you can see Prompt Builder and the agent builder. If either is missing, stop and fix that first.
5. Log in from the CLI:

```bash
sf org login web --alias copilot --set-default
sf org display
```

## M1. Data model and seed data (1 h)

```bash
sf project deploy start -m CustomObject
sf project deploy start -m ApexClass -m PermissionSet
sf org assign permset --name Deployment_Copilot_Access
sf apex run --file scripts/apex/seed-data.apex
```

The permission set has to be assigned before the seed runs. Fields deployed through the Metadata API get no field-level security, not even for System Administrators, and anonymous Apex checks field-level security at compile time. Skip the assignment and the seed fails with `Field does not exist: Account__c on Engagement__c`. The permission set grants Apex class access too, so the classes deploy with it here. M2 runs their tests.

Open the Engagement tab or run a report. You should see four engagements and 12 weekly metric rows. If objects don't appear in the app, add them to an app's navigation in Setup.

## M2. Apex and unit tests (2 h)

The classes and permission set went in during M1. If you've changed any class since then, redeploy with `sf project deploy start -m ApexClass` first.

```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10
```

Read the test files before you run them. Be ready to explain three decisions in an interview:

- why `Blocked` overrides the score (`ReadinessCalculatorTest.missingSponsorBlocksEvenWithHighTotal`)
- why no data returns `Unknown` and not `Low` (`AdoptionCalculatorTest.noDataIsUnknownNotLow`)
- why the roadmap writer treats a null approval as a no (`RoadmapWriterActionTest.nullApprovalCountsAsNotApproved`)

Then break something on purpose. Change a weight so the total passes 100, or flip the sponsor rule, and watch which tests fail. It takes ten minutes and gives you a real story about what the tests protect.

## M3. Prompt template (0.5 h)

The template ships as metadata, so deploy it:

```bash
sf project deploy start -m GenAiPromptTemplate:Draft_Deployment_Roadmap
```

Then open it in Prompt Builder and preview it with the engagement summary from the seed data, for example:

```
Quarry Lane Onboarding Agent for Quarry Lane Financial. Stage: Identify. Status: On track. Week 2 of 12. Readiness score: not assessed yet. Roadmap: not approved yet. Business goal: Shorten new-hire system access setup from 5 days to 2.
```

Check that the draft:
- says "unknown" for things the summary doesn't state, like user counts
- starts its first phase at week 2, not week 1
- ends with the open questions, with no sign-off line

One preview is a sample of one. Run it several times, or call it through the REST API (`POST /services/data/v66.0/einstein/prompt-templates/Draft_Deployment_Roadmap/generations`) and check each draft.

To change the prompt, edit the XML and bump the version suffix. [prompts/Draft_Deployment_Roadmap.md](../prompts/Draft_Deployment_Roadmap.md) explains why: redeploying a published version reports success and changes nothing.

## M4. The agent (3 h)

```bash
sf project deploy start -m AiAuthoringBundle
sf agent validate authoring-bundle --api-name Deployment_Copilot
sf agent preview --authoring-bundle Deployment_Copilot
```

Simulated actions invent their outputs, so they hide exactly the type and binding bugs you're looking for. In your dev org with the synthetic data, go straight to real actions:

```bash
sf agent preview --authoring-bundle Deployment_Copilot --use-live-actions
```

Only do that in your dev org with the synthetic data.

Walk through these conversations by hand before you automate anything:

1. "How is adoption going for Fernhollow?" Expect High risk with flags.
2. "Check adoption for Alder Ridge." Expect a question asking which of two engagements.
3. "Score Alder Ridge Service Agent: data 5, use case 5, sponsorship 1, governance 5, platform 5, change 5." Expect Blocked.
4. "Draft a roadmap for Quarry Lane, go live in 10 weeks." Then reply "looks good, save it." Check the record. Then repeat and reply "wait, change week 3." Check that nothing saved.

When it behaves, publish and activate:

```bash
sf agent publish authoring-bundle --api-name Deployment_Copilot
sf agent activate --api-name Deployment_Copilot
```

Make sure your own user has the `Deployment_Copilot_Access` permission set. An employee agent runs with your permissions.

Write down every surprise as it happens. Those notes become the "What testing caught" table.

## M5. Agent tests and fixes (3 h)

```bash
sf agent test create --spec tests/agent/Deployment_Copilot_Tests.yaml --api-name Deployment_Copilot_Tests
sf agent test run --api-name Deployment_Copilot_Tests --wait 10 --result-format human
```

Expect some failures on the first run. That's normal. For each one, decide whether the agent is wrong or the test is wrong, fix the right one, and rerun.

Then fill in the README table, keeping to what really happened:

- the test or conversation that failed
- what the agent did
- the fix (instructions, action description, Apex, or the test itself)

Three real rows beat ten invented ones. If the first run passes everything, add two harder tests of your own, like a user who approves a roadmap and then asks for changes in the same message.

Remove the HTML comment markers around that section in the README when it has real content.

## M6. Polish (2 h)

- Record a 90-second screen capture of the four conversations from M4. Put it at the top of the README, or link it.
- Add two screenshots: the agent builder with the four subagents, and the test run results.
- Give the GitHub repo a description and topics: `salesforce`, `agentforce`, `apex`, `agent-script`, `ai-agents`.
- Pin the repo on your GitHub profile.
- Read the whole README out loud once. Cut anything you wouldn't say to a hiring manager.

## Stretch: Data 360 (not in the weekend scope)

This is the milestone that closes the biggest remaining gap against the job posting, so do it if you have another weekend.

1. In Setup, search for **Data Cloud Setup** and click **Get Started**. Provisioning takes a while. You're done when `sf api request rest /services/data/v68.0/ssot/data-spaces -o copilot` lists a `default` data space.
2. Deploy the connector permission set: `sf project deploy start -m PermissionSet:Deployment_Copilot_D360_Connector`. `setup.sh` assigns it to the connector's integration user.
3. Run `bash data360/setup.sh copilot`. It creates the 2 data streams, 2 custom data model objects, the mappings, and the `Weekly_Adoption` calculated insight, then starts the first ingestion.
4. Wait until `SELECT COUNT(*) FROM Adoption_Metric__dlm` (through `/ssot/query-sql`) returns 12, then run the insight with the command the script prints.
5. Deploy `AdoptionInsightAction`, the permission set, and the agent bundle, then publish. `get_adoption` already points at the Data 360 action.
6. Compare the two sources before you trust either. `AdoptionSnapshotAction` and `AdoptionInsightAction` take the same input, so call both for every engagement in anonymous Apex and diff the summaries.

The README's "Data 360 version" section has the comparison and the measured lag.

## Likely fixes when you first deploy

These are the places I'd look first.

| Symptom | Where to look |
|---|---|
| `preview` crashes with `Cannot read properties of undefined (reading 'replace')` | A CLI bug when the script has no `default_agent_user`, which employee agents don't need. Fixed in `@salesforce/agents` 2.3.2. Run `sf plugins install @salesforce/plugin-agent@latest`. |
| `validate` passes but `preview` rejects a parameter type | `validate` only checks syntax. Preview checks types against Apex. An Apex `Id` input needs `object` with `complex_data_type_name: "lightning__recordIdType"`, and an Apex `Integer` output needs `object` with `"lightning__integerType"`, even though the docs say to use `string` for IDs. |
| The agent says "no data" after the user picks from a list of matches | Before an engagement is selected, nothing has been looked up, but the model may still answer. Say so in the no-selection branch, and tell it to call `find_engagement` with the full name of the pick. |
| `sf agent activate` hangs | Without `--version` it waits at an interactive prompt. Pass `--version N`. |
| An action runs with `{}` as its input | A variable set from a null output is `None`, not `""`, so `!= ""` is true. Guard with `is not None and != ""`. |
| The agent answers without calling an action it was told to call | An action offered as a tool is optional, and the model can skip it. If the answer depends on it, `run` it in the reasoning logic instead. |
| Agent is active but missing from the Agentforce panel's agent list | Agents published from the CLI don't get the auto-generated access permission set that UI-built agents get. `Deployment_Copilot_Access` grants it through `agentAccesses`. Assign it, then reload the page. |
| `publish` overwrites local files | Publish retrieves the agent and its dependencies back into the project (Apex classes, the prompt template, and new `aiAgents/` and `aiAgentDefinitionVersions/` folders). Diff before you commit. |
| Data stream API says custom fields are "missing a value" | The Data 360 CRM connector runs as its own integration user, which can't read your custom objects. Assign `Deployment_Copilot_D360_Connector` to the user that holds `sfdc_a360_sfcrm_data_extract`. In the stream body, name custom fields `Field_c`, not `Field__c`. |
| Calculated insight: "one side of the math operation contains aggregation" | The validator checks the shape of the expression. `100 * SUM(a) / SUM(b)` passes. `SUM(a) * 100 / SUM(b)` and `SUM(a * 100) / SUM(b)` fail. |
| `sf api request rest --method DELETE` fails with "No 'mode' found in 'body' entry" | Pass `--body '{"mode":"raw","raw":""}'`. |
| `validate` complains about an action's outputs | Every action needs an `outputs:` block, and the names must match the Apex `@InvocableVariable` fields exactly, case included. |
| Prompt template action not found | The template API name must be exactly `Draft_Deployment_Roadmap`, and the inputs must be named `engagementSummary` and `constraints`. |
| Prompt template deploy "succeeds" but the output doesn't change | Published versions can't be changed. Bump the `_N` suffix on `activeVersionIdentifier` and `versionIdentifier`, then redeploy. |
| Deploy fails on the permission set | Deploy objects and classes first, then the permission set. The commands above already do. |
| Seed script fails with `Field does not exist` on a field you just deployed | That's missing field-level security, not a missing field. Assign `Deployment_Copilot_Access`, then rerun the seed. |
| An agent turn ignores `available when` | Check that the variable was really set. Look at the preview trace for `engagement_id`. |
| Mixed DML error in tests | `TestDataFactory.strategist()` wraps setup DML in `System.runAs`. Keep it that way. |
| Agent forgets the engagement on a new topic | Variables are agent-wide, but the router runs each turn. If it misroutes follow-ups, add a transition between subagents. |
| Roadmap saved before the user saw it | Tools are re-evaluated within a turn, so a save can follow a draft in the same turn. `save_roadmap` is gated on `draft_presented`, which only `after_reasoning` sets, so a save always needs a later user message. |
