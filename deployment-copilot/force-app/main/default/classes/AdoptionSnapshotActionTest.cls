@IsTest
private class AdoptionSnapshotActionTest {

    private static AdoptionSnapshotAction.Request request(Id engagementId) {
        AdoptionSnapshotAction.Request r = new AdoptionSnapshotAction.Request();
        r.engagementId = engagementId;
        return r;
    }

    @IsTest
    static void reportsLatestWeekAndRisk() {
        Engagement__c e = TestDataFactory.engagement('Snapshot Test', Date.today().addDays(-49));
        insert new List<Adoption_Metric__c>{
            TestDataFactory.metric(e.Id, Date.today().addDays(-7), 100, 60, 200, 140),
            TestDataFactory.metric(e.Id, Date.today(), 100, 30, 200, 60)
        };
        User u = TestDataFactory.strategist();

        List<AdoptionSnapshotAction.Result> results;
        System.runAs(u) {
            results = AdoptionSnapshotAction.snapshot(new List<AdoptionSnapshotAction.Request>{ request(e.Id) });
        }

        System.assertEquals('High', results[0].riskLevel, results[0].summary);
        System.assert(results[0].summary.contains('Week 8'), results[0].summary);
        System.assert(results[0].summary.contains('Adoption rate: 30.0%'), results[0].summary);
        System.assert(results[0].summary.contains('-30.0 points'), results[0].summary);
        System.assertNotEquals('None', results[0].flags);
    }

    @IsTest
    static void noMetricsIsUnknown() {
        Engagement__c e = TestDataFactory.engagement('Empty Test', Date.today());
        User u = TestDataFactory.strategist();

        List<AdoptionSnapshotAction.Result> results;
        System.runAs(u) {
            results = AdoptionSnapshotAction.snapshot(new List<AdoptionSnapshotAction.Request>{ request(e.Id) });
        }
        System.assertEquals('Unknown', results[0].riskLevel);
        System.assert(results[0].summary.contains('No adoption data'));
    }

    @IsTest
    static void unknownEngagementDoesNotThrow() {
        User u = TestDataFactory.strategist();
        List<AdoptionSnapshotAction.Result> results;
        System.runAs(u) {
            results = AdoptionSnapshotAction.snapshot(new List<AdoptionSnapshotAction.Request>{ request(null) });
        }
        System.assertEquals('Unknown', results[0].riskLevel);
        System.assert(results[0].summary.contains('could not find'));
    }

    @IsTest
    static void batchKeepsEngagementsSeparate() {
        Engagement__c a = TestDataFactory.engagement('Batch A', Date.today().addDays(-14));
        Engagement__c b = TestDataFactory.engagement('Batch B', Date.today().addDays(-14));
        insert new List<Adoption_Metric__c>{
            TestDataFactory.metric(a.Id, Date.today(), 100, 80, 100, 90)
        };
        User u = TestDataFactory.strategist();

        List<AdoptionSnapshotAction.Result> results;
        System.runAs(u) {
            results = AdoptionSnapshotAction.snapshot(new List<AdoptionSnapshotAction.Request>{
                request(a.Id), request(b.Id)
            });
        }
        System.assertEquals('Low', results[0].riskLevel);
        System.assertEquals('Unknown', results[1].riskLevel);
    }
}
