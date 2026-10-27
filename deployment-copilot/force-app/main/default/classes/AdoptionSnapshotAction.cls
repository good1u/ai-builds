/**
 * Agent action: read weekly adoption numbers for an engagement and return a risk read.
 * Read-only. It reports risk; a human decides what to do about it.
 */
public with sharing class AdoptionSnapshotAction {

    public class Request {
        @InvocableVariable(label='Engagement Id' description='Salesforce Id of the Engagement record' required=true)
        public Id engagementId;
    }

    public class Result {
        @InvocableVariable(label='Risk level' description='Low, Medium, High, or Unknown') public String riskLevel;
        @InvocableVariable(label='Summary' description='Plain-text adoption and consumption summary') public String summary;
        @InvocableVariable(label='Flags' description='Semicolon-separated list of risk flags, or None') public String flags;
    }

    @InvocableMethod(
        label='Get adoption snapshot'
        description='Returns the latest weekly adoption rate, containment rate, credits consumed, week-over-week change, and a risk level for an engagement.'
        category='Deployment Copilot'
    )
    public static List<Result> snapshot(List<Request> requests) {
        Set<Id> engagementIds = new Set<Id>();
        for (Request r : requests) {
            if (r.engagementId != null) {
                engagementIds.add(r.engagementId);
            }
        }

        Map<Id, Engagement__c> engagements = new Map<Id, Engagement__c>([
            SELECT Id, Start_Date__c
            FROM Engagement__c
            WHERE Id IN :engagementIds
            WITH USER_MODE
        ]);

        Map<Id, List<Adoption_Metric__c>> metricsByEngagement = new Map<Id, List<Adoption_Metric__c>>();
        for (Adoption_Metric__c m : [
            SELECT Engagement__c, Week_Ending__c, Eligible_Users__c, Active_Users__c,
                   Conversations__c, Resolved_By_Agent__c, Credits_Consumed__c
            FROM Adoption_Metric__c
            WHERE Engagement__c IN :engagementIds
            WITH USER_MODE
            ORDER BY Week_Ending__c DESC
        ]) {
            if (!metricsByEngagement.containsKey(m.Engagement__c)) {
                metricsByEngagement.put(m.Engagement__c, new List<Adoption_Metric__c>());
            }
            metricsByEngagement.get(m.Engagement__c).add(m);
        }

        List<Result> results = new List<Result>();
        for (Request r : requests) {
            results.add(buildResult(r, engagements, metricsByEngagement));
        }
        return results;
    }

    private static Result buildResult(Request r, Map<Id, Engagement__c> engagements,
                                      Map<Id, List<Adoption_Metric__c>> metricsByEngagement) {
        Result res = new Result();
        if (r.engagementId == null || !engagements.containsKey(r.engagementId)) {
            res.riskLevel = AdoptionCalculator.RISK_UNKNOWN;
            res.flags = 'None';
            res.summary = 'I could not find that engagement, or you do not have access to it.';
            return res;
        }

        List<Adoption_Metric__c> metrics = metricsByEngagement.get(r.engagementId);
        Date start = engagements.get(r.engagementId).Start_Date__c;
        Integer week = 1;
        if (start != null && metrics != null && !metrics.isEmpty()) {
            week = EngagementContextAction.weekOfEngagement(start, metrics[0].Week_Ending__c);
        }

        AdoptionCalculator.Assessment a = AdoptionCalculator.assess(metrics, week);
        res.riskLevel = a.riskLevel;
        res.flags = a.flags.isEmpty() ? 'None' : String.join(a.flags, '; ');
        res.summary = summarize(a, week);
        return res;
    }

    /** Shared with AdoptionInsightAction so both sources describe a week the same way. */
    public static String summarize(AdoptionCalculator.Assessment a, Integer week) {
        if (a.latest == null) {
            return 'No adoption data has been logged for this engagement yet.';
        }
        List<String> parts = new List<String>();
        parts.add('Week ' + week + ' (week ending ' + a.latest.weekEnding.format() + ')');
        parts.add('Adoption rate: ' + a.latest.adoptionRate + '%' + delta(a.adoptionDeltaPoints));
        parts.add('Containment rate: ' + a.latest.containmentRate + '%' + delta(a.containmentDeltaPoints));
        parts.add('Credits consumed this week: ' + a.latest.creditsConsumed);
        parts.add('Risk: ' + a.riskLevel);
        return String.join(parts, '. ') + '.';
    }

    private static String delta(Decimal points) {
        if (points == null) {
            return '';
        }
        return ' (' + (points >= 0 ? '+' : '') + points + ' points vs last week)';
    }
}