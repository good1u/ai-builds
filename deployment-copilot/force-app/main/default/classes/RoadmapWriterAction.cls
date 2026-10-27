/**
 * Agent action: save an approved roadmap on the engagement.
 *
 * The approval check lives HERE, in code. The prompt also tells the agent to ask first,
 * but the prompt is a request and this is a lock.
 */
public with sharing class RoadmapWriterAction {

    private static final Integer MAX_LENGTH = 32768;

    public class Request {
        @InvocableVariable(label='Engagement Id' description='Salesforce Id of the Engagement record' required=true)
        public Id engagementId;
        @InvocableVariable(label='Roadmap text' description='The roadmap draft exactly as shown to the user' required=true)
        public String roadmapText;
        @InvocableVariable(label='Approved by user' description='True only if the user explicitly approved saving this roadmap in this conversation' required=true)
        public Boolean approvedByUser;
    }

    public class Result {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='Save approved roadmap'
        description='Saves a roadmap on the engagement. Refuses unless the user explicitly approved it.'
        category='Deployment Copilot'
    )
    public static List<Result> save(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<Engagement__c> toUpdate = new List<Engagement__c>();
        List<Integer> resultIndexForUpdate = new List<Integer>();

        for (Request req : requests) {
            Result res = new Result();
            results.add(res);

            if (req.approvedByUser != true) {
                res.success = false;
                res.message = 'Roadmap not saved. The user has not approved it yet. Show the draft and ask for approval.';
            } else if (req.engagementId == null) {
                res.success = false;
                res.message = 'Roadmap not saved. No engagement is selected.';
            } else if (String.isBlank(req.roadmapText)) {
                res.success = false;
                res.message = 'Roadmap not saved. There is no draft to save.';
            } else if (req.roadmapText.length() > MAX_LENGTH) {
                res.success = false;
                res.message = 'Roadmap not saved. It is ' + req.roadmapText.length() + ' characters and the limit is ' + MAX_LENGTH + '.';
            } else {
                res.success = true;
                res.message = 'Roadmap saved to the engagement.';
                toUpdate.add(new Engagement__c(
                    Id = req.engagementId,
                    Roadmap__c = req.roadmapText,
                    Roadmap_Approved_On__c = System.now()
                ));
                resultIndexForUpdate.add(results.size() - 1);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                update as user toUpdate;
            } catch (Exception e) {
                for (Integer idx : resultIndexForUpdate) {
                    results[idx].success = false;
                    results[idx].message = 'Roadmap not saved: ' + e.getMessage();
                }
            }
        }
        return results;
    }
}