@IsTest
private class EngagementContextActionTest {

    private static List<EngagementContextAction.Result> find(String term) {
        EngagementContextAction.Request r = new EngagementContextAction.Request();
        r.engagementName = term;
        return EngagementContextAction.find(new List<EngagementContextAction.Request>{ r });
    }

    @IsTest
    static void singleMatchReturnsIdAndSummary() {
        Engagement__c e = TestDataFactory.engagement('Alder Ridge Rollout', Date.today().addDays(-15));
        User u = TestDataFactory.strategist();

        List<EngagementContextAction.Result> results;
        System.runAs(u) {
            results = find('Alder Ridge');
        }

        System.assertEquals(1, results[0].matchCount);
        System.assertEquals((String) e.Id, results[0].engagementId);
        System.assert(results[0].summary.contains('Week 3'), results[0].summary);
        System.assert(results[0].summary.contains('not assessed yet'));
        System.assert(results[0].summary.endsWith('internal IT requests.'), results[0].summary);
        System.assert(!results[0].summary.contains('..'), results[0].summary);
    }

    @IsTest
    static void matchesOnAccountName() {
        TestDataFactory.engagement('Plain Name', Date.today());
        User u = TestDataFactory.strategist();

        List<EngagementContextAction.Result> results;
        System.runAs(u) {
            results = find('Plain Name Account');
        }
        System.assertEquals(1, results[0].matchCount);
    }

    @IsTest
    static void severalMatchesReturnNamesNotAnId() {
        TestDataFactory.engagement('Fern Phase 1', Date.today());
        TestDataFactory.engagement('Fern Phase 2', Date.today());
        User u = TestDataFactory.strategist();

        List<EngagementContextAction.Result> results;
        System.runAs(u) {
            results = find('Fern');
        }

        System.assertEquals(2, results[0].matchCount);
        System.assertEquals(null, results[0].engagementId);
        System.assert(results[0].summary.contains('Fern Phase 1'));
        System.assert(results[0].summary.contains('Fern Phase 2'));
    }

    @IsTest
    static void noMatchSaysSo() {
        User u = TestDataFactory.strategist();
        List<EngagementContextAction.Result> results;
        System.runAs(u) {
            results = find('Does Not Exist');
        }
        System.assertEquals(0, results[0].matchCount);
        System.assert(results[0].summary.contains('No engagement matches'));
    }

    @IsTest
    static void shortOrBlankTermIsRejected() {
        System.assertEquals(0, find('a')[0].matchCount);
        System.assertEquals(0, find(null)[0].matchCount);
    }

    @IsTest
    static void weekMathIsOneBasedAndNeverBelowOne() {
        Date start = Date.newInstance(2026, 1, 1);
        System.assertEquals(1, EngagementContextAction.weekOfEngagement(start, start));
        System.assertEquals(1, EngagementContextAction.weekOfEngagement(start, start.addDays(6)));
        System.assertEquals(2, EngagementContextAction.weekOfEngagement(start, start.addDays(7)));
        System.assertEquals(12, EngagementContextAction.weekOfEngagement(start, start.addDays(83)));
        System.assertEquals(1, EngagementContextAction.weekOfEngagement(start, start.addDays(-5)));
    }
}
