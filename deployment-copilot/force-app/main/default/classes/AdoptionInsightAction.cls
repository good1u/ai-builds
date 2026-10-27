/**
 * Agent action: the adoption snapshot, read from the Data 360 calculated insight Weekly_Adoption__cio
 * instead of from Adoption_Metric__c with SOQL. Same inputs, outputs, and risk rules as AdoptionSnapshotAction.
 *
 * The insight computes the weekly rates. AdoptionCalculator still applies the risk rules,
 * so both sources flag risk the same way.
 * Read-only. It reports risk; a human decides what to do about it.
 */
public with sharing class AdoptionInsightAction {

    public class Request {
        @InvocableVariable(label='Engagement Id' description='Salesforce Id of the Engagement record' required=true)
        public Id engagementId;
    }

    public class Result {
        @InvocableVariable(label='Risk level' description='Low, Medium, High, or Unknown') public String riskLevel;
        @InvocableVariable(label='Summary' description='Plain-text adoption and consumption summary') public String summary;
        @InvocableVariable(label='Flags' description='Semicolon-separated list of risk flags, or None') public String flags;
    }

    /** Runs Data 360 SQL. Tests swap in a fake, because ConnectApi.CdpQuery can't run in a test context. */
    public virtual class InsightQuery {
        public virtual List<Map<String, Object>> run(String sql) {
            ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
            input.sql = sql;
            return toRows(ConnectApi.CdpQuery.queryAnsiSqlV2(input));
        }
    }

    /** Turns the positional query output into one map per row, keyed by column name. */
    @TestVisible
    private static List<Map<String, Object>> toRows(ConnectApi.CdpQueryOutputV2 output) {
        Map<Integer, String> columnsByPosition = new Map<Integer, String>();
        for (String column : output.metadata.keySet()) {
            columnsByPosition.put(output.metadata.get(column).placeInOrder, column);
        }
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        if (output.data == null) {
            return rows;
        }
        for (ConnectApi.CdpQueryV2Row row : output.data) {
            Map<String, Object> values = new Map<String, Object>();
            for (Integer i = 0; i < row.rowData.size(); i++) {
                values.put(columnsByPosition.get(i), row.rowData[i]);
            }
            rows.add(values);
        }
        return rows;
    }

    @TestVisible private static InsightQuery query = new InsightQuery();

    @InvocableMethod(
        label='Get adoption snapshot from Data 360'
        description='Returns the latest weekly adoption rate, containment rate, credits consumed, week-over-week change, and a risk level for an engagement, from the Data 360 Weekly Adoption insight.'
        category='Deployment Copilot'
    )
    public static List<Result> snapshot(List<Request> requests) {
        Set<Id> engagementIds = new Set<Id>();
        for (Request r : requests) {
            if (r.engagementId != null) {
                engagementIds.add(r.engagementId);
            }
        }

        // Data 360 doesn't apply CRM sharing, so check the user can see each engagement here first.
        Map<Id, Engagement__c> engagements = new Map<Id, Engagement__c>([
            SELECT Id, Start_Date__c
            FROM Engagement__c
            WHERE Id IN :engagementIds
            WITH USER_MODE
        ]);

        Map<Id, List<AdoptionCalculator.Snapshot>> snapshotsByEngagement = engagements.isEmpty()
            ? new Map<Id, List<AdoptionCalculator.Snapshot>>()
            : readInsight(engagements.keySet());

        List<Result> results = new List<Result>();
        for (Request r : requests) {
            results.add(buildResult(r, engagements, snapshotsByEngagement));
        }
        return results;
    }

    private static Map<Id, List<AdoptionCalculator.Snapshot>> readInsight(Set<Id> engagementIds) {
        // Ids are typed, so they can't carry SQL. Data 360 stores the 18-character form.
        List<String> quoted = new List<String>();
        for (Id i : engagementIds) {
            quoted.add('\'' + String.valueOf(i) + '\'');
        }
        String sql = 'SELECT engagement_id__c, week_ending__c, adoption_rate__c, containment_rate__c, total_credits__c'
            + ' FROM Weekly_Adoption__cio'
            + ' WHERE engagement_id__c IN (' + String.join(quoted, ', ') + ')'
            + ' ORDER BY week_ending__c DESC';

        Map<Id, List<AdoptionCalculator.Snapshot>> byEngagement = new Map<Id, List<AdoptionCalculator.Snapshot>>();
        for (Map<String, Object> row : query.run(sql)) {
            Id engagementId = Id.valueOf(String.valueOf(row.get('engagement_id__c')));
            if (!byEngagement.containsKey(engagementId)) {
                byEngagement.put(engagementId, new List<AdoptionCalculator.Snapshot>());
            }
            byEngagement.get(engagementId).add(toSnapshot(row));
        }
        return byEngagement;
    }

    @TestVisible
    private static AdoptionCalculator.Snapshot toSnapshot(Map<String, Object> row) {
        AdoptionCalculator.Snapshot s = new AdoptionCalculator.Snapshot();
        s.weekEnding = Date.valueOf(String.valueOf(row.get('week_ending__c')).left(10));
        // Data 360 numbers come back with 18 decimal places. Match the CRM fields' scale.
        s.adoptionRate = decimalOrZero(row.get('adoption_rate__c')).setScale(1);
        s.containmentRate = decimalOrZero(row.get('containment_rate__c')).setScale(1);
        s.creditsConsumed = decimalOrZero(row.get('total_credits__c')).setScale(0);
        return s;
    }

    private static Decimal decimalOrZero(Object value) {
        return value == null ? 0 : Decimal.valueOf(String.valueOf(value));
    }

    private static Result buildResult(Request r, Map<Id, Engagement__c> engagements,
                                      Map<Id, List<AdoptionCalculator.Snapshot>> snapshotsByEngagement) {
        Result res = new Result();
        if (r.engagementId == null || !engagements.containsKey(r.engagementId)) {
            res.riskLevel = AdoptionCalculator.RISK_UNKNOWN;
            res.flags = 'None';
            res.summary = 'I could not find that engagement, or you do not have access to it.';
            return res;
        }

        List<AdoptionCalculator.Snapshot> snapshots = snapshotsByEngagement.get(r.engagementId);
        Date start = engagements.get(r.engagementId).Start_Date__c;
        Integer week = 1;
        if (start != null && snapshots != null && !snapshots.isEmpty()) {
            week = EngagementContextAction.weekOfEngagement(start, snapshots[0].weekEnding);
        }

        AdoptionCalculator.Assessment a = AdoptionCalculator.assessSnapshots(snapshots, week);
        res.riskLevel = a.riskLevel;
        res.flags = a.flags.isEmpty() ? 'None' : String.join(a.flags, '; ');
        res.summary = AdoptionSnapshotAction.summarize(a, week);
        return res;
    }
}