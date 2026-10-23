# Proposal / SOW creation from Call Transcript (Claude)

**Builds a polished SOW / Proposal based on call transcripts.**

▶ [2-minute demo video](https://www.loom.com/share/da96f6c1ce484bc0b90cb979df084f6f)

## The problem
Creating proposals is time consuming and often require synthesizing lots of information from notes, calls, pricing sheets. 

## What it does
1.Connects to Google docs via MCP
2.Reviews SOW template, reviews call transcripts, reviews one pager content
3.Builds a branded SOW merging in relevant data from calls.
4. Includes a 30/60/90 day plan
5. Does not fill in a merge field if the answer is not found. 
6. Leaves merge fields highlighted for human review.
7. Provides a time stamp of where in the call transcript a data point was found

## How it's built
- **Tools:** Claude, Google Docs connector
- **Model:** Sonnet 5
- **Data in:** SOW Templates, One Pager PDFs, Cal transcripts
- **Prompt or agent design:** I'm putting together a proposal doc for [Client Name]. The output will be an updated google doc added in the client folder once complete.

Search my Google Drive for documents with "CLIENT NAME" in the title—there should be discovery call transcript notes.

Also in drive, use my Time Wealth Audit SOW TEMPLATE 2026. Only populate merge areas that are highlighted yellow and in [brackets]. Leave the highlighting after populating.

Pull the relevant information to build out these slides: Make sure to include executive summary, their challenges, our solution and how it addresses their specific situation. Create a new section with 30, 60, 90 day plan. Use content from my one pagers in drive. Use today’s date for the prepared by and valid until/date issue

Design direction: Clean and professional, but not sterile. I want something modern and approachable while still appropriate for executives. Verify that no elements overlap.

provide a  transcript timestamp for every field it filled. If the data is not in the call transcript, leave the merge field empty.

- **Guardrails:** Only fill in merge fields. Only if Data point is know. Leave merge field highligted for human review. 

## Results
- Time for proposal creation reduced significantly (from 2+ hours to 15 minutes)


## What I learned
- multiple iterations are needed before turning to a skill. Then train on high converting proposals. 
