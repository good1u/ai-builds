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

`preview` runs with simulated actions by default. That's fine for checking routing. Once routing works, switch to real actions against your seed data:

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

1. Create a Salesforce CRM data stream for `Adoption_Metric__c` and `Engagement__c` in Data 360.
2. Map them to data model objects.
3. Build a calculated insight for weekly adoption rate and containment rate.
4. Ground the agent on it, so `adoption_tracking` reads from Data 360 instead of Apex SOQL.
5. Add a README section that compares the two approaches and says which one you'd pick for a customer and why.

The exact Data 360 screens change often. Use the current help docs while you build and write down what you did.

## Likely fixes when you first deploy

These are the places I'd look first.

| Symptom | Where to look |
|---|---|
| `validate` rejects a parameter type | In `Deployment_Copilot.agent`, `integer` and `string` for IDs are my best reading of the docs. Try `number` for scores or `id` for IDs. |
| `validate` complains about an action's outputs | Every action needs an `outputs:` block, and the names must match the Apex `@InvocableVariable` fields exactly, case included. |
| Prompt template action not found | The template API name must be exactly `Draft_Deployment_Roadmap`, and the inputs must be named `engagementSummary` and `constraints`. |
| Prompt template deploy "succeeds" but the output doesn't change | Published versions can't be changed. Bump the `_N` suffix on `activeVersionIdentifier` and `versionIdentifier`, then redeploy. |
| Deploy fails on the permission set | Deploy objects and classes first, then the permission set. The commands above already do. |
| Seed script fails with `Field does not exist` on a field you just deployed | That's missing field-level security, not a missing field. Assign `Deployment_Copilot_Access`, then rerun the seed. |
| An agent turn ignores `available when` | Check that the variable was really set. Look at the preview trace for `engagement_id`. |
| Mixed DML error in tests | `TestDataFactory.strategist()` wraps setup DML in `System.runAs`. Keep it that way. |
| Agent forgets the engagement on a new topic | Variables are agent-wide, but the router runs each turn. If it misroutes follow-ups, add a transition between subagents. |
| Roadmap saved when you said "wait" | Tighten the `save_roadmap` instructions, then add that exact phrase to the test suite. |
