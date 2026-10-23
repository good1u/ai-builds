/**
 * Agent action: find an engagement by name and return a plain-text summary.
 * Resolving the name to an Id happens here, in code, so the agent never guesses an Id.
 */
public with sharing class EngagementContextAction {

    private static final Integer MAX_MATCHES = 5;

    public class Request {
        @InvocableVariable(label='Engagement name' description='Full or partial engagement name, or the customer account name' required=true)
        public String engagementName;
    }

    public class Result {
        @InvocableVariable(label='Match count') public Integer matchCount;
        @InvocableVariable(label='Engagement Id' description='Set only when exactly one engagement matched') public String engagementId;
        @InvocableVariable(label='Summary' description='Plain-text engagement summary, or the list of candidate names when several matched') public String summary;
    }

    @InvocableMethod(
        label='Find engagement'
        description='Finds an engagement by name or customer account name. Returns its Id and a text summary when exactly one matches, or candidate names when several match.'
        category='Deployment Copilot'
    )
    public static List<Result> find(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(lookup(req.engagementName));
        }
        return results;
    }

    private static Result lookup(String rawName) {
        Result res = new Result();
        String term = String.isBlank(rawName) ? '' : rawName.trim();
        if (term.length() < 2) {
            res.matchCount = 0;
            res.summary = 'Give me at least two characters of the engagement or customer name.';
            return res;
        }
        String pattern = '%' + term + '%';

        List<Engagement__c> matches = [
            SELECT Id, Name, Account__r.Name, Stage__c, Status__c, Start_Date__c, Target_End_Date__c,
                   Readiness_Score__c, Business_Goal__c, Roadmap_Approved_On__c
            FROM Engagement__c
            WHERE Name LIKE :pattern OR Account__r.Name LIKE :pattern
            WITH USER_MODE
            ORDER BY Name
            LIMIT :MAX_MATCHES
        ];

        res.matchCount = matches.size();
        if (matches.isEmpty()) {
            res.summary = 'No engagement matches "' + term + '".';
        } else if (matches.size() == 1) {
            res.engagementId = matches[0].Id;
            res.summary = describe(matches[0]);
        } else {
            List<String> names = new List<String>();
            for (Engagement__c e : matches) {
                names.add(e.Name);
            }
            res.summary = 'Several engagements match: ' + String.join(names, ', ') + '. Ask the user which one.';
        }
        return res;
    }

    @TestVisible
    private static String describe(Engagement__c e) {
        List<String> parts = new List<String>();
        parts.add(e.Name + ' for ' + (e.Account__r != null ? e.Account__r.Name : 'no account'));
        parts.add('Stage: ' + e.Stage__c);
        parts.add('Status: ' + e.Status__c);
        if (e.Start_Date__c != null) {
            Integer weekNumber = weekOfEngagement(e.Start_Date__c, Date.today());
            parts.add('Week ' + weekNumber + (e.Target_End_Date__c != null
                ? ' of ' + weekOfEngagement(e.Start_Date__c, e.Target_End_Date__c.addDays(-1)) : ''));
        }
        parts.add('Readiness score: ' + (e.Readiness_Score__c == null ? 'not assessed yet' : String.valueOf(e.Readiness_Score__c)));
        parts.add('Roadmap: ' + (e.Roadmap_Approved_On__c == null ? 'not approved yet' : 'approved'));
        if (String.isNotBlank(e.Business_Goal__c)) {
            // Goals are usually typed as sentences; drop the period so the join below doesn't double it.
            parts.add('Business goal: ' + e.Business_Goal__c.trim().removeEnd('.'));
        }
        return String.join(parts, '. ') + '.';
    }

    /** Engagement weeks are 1-based: the first 7 days are week 1. Never below 1. */
    public static Integer weekOfEngagement(Date startDate, Date asOf) {
        Integer days = startDate.daysBetween(asOf);
        if (days < 0) {
            return 1;
        }
        return (Decimal.valueOf(days) / 7).intValue() + 1;
    }
}
