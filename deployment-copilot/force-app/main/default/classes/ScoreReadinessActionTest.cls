@IsTest
private class ScoreReadinessActionTest {

    private static ScoreReadinessAction.Request request(Id engagementId, Integer s) {
        ScoreReadinessAction.Request r = new ScoreReadinessAction.Request();
        r.engagementId = engagementId;
        r.dataReadiness = s;
        r.useCaseClarity = s;
        r.executiveSponsorship = s;
        r.responsibleAiGovernance = s;
        r.platformReadiness = s;
        r.changeReadiness = s;
        return r;
    }

    @IsTest
    static void savesAssessmentAndUpdatesEngagement() {
        Engagement__c e = TestDataFactory.engagement('Score Test', Date.today().addDays(-14));
        User u = TestDataFactory.strategist();

        List<ScoreReadinessAction.Result> results;
        System.runAs(u) {
            results = ScoreReadinessAction.score(new List<ScoreReadinessAction.Request>{ request(e.Id, 4) });
        }

        System.assertEquals(true, results[0].success, results[0].message);
        System.assertEquals(80.0, results[0].totalScore);
        System.assertEquals('Ready with conditions', results[0].band);
        System.assertEquals('None', results[0].gaps);
        System.assertEquals(1, [SELECT COUNT() FROM Readiness_Assessment__c WHERE Engagement__c = :e.Id]);
        System.assertEquals(80.0, [SELECT Readiness_Score__c FROM Engagement__c WHERE Id = :e.Id].Readiness_Score__c);
    }

    @IsTest
    static void invalidScoreReturnsFailureAndSavesNothing() {
        Engagement__c e = TestDataFactory.engagement('Bad Score', Date.today());
        User u = TestDataFactory.strategist();

        List<ScoreReadinessAction.Result> results;
        System.runAs(u) {
            results = ScoreReadinessAction.score(new List<ScoreReadinessAction.Request>{ request(e.Id, 9) });
        }

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('between 1 and 5'));
        System.assertEquals(0, [SELECT COUNT() FROM Readiness_Assessment__c]);
    }

    @IsTest
    static void missingEngagementIdFails() {
        User u = TestDataFactory.strategist();
        List<ScoreReadinessAction.Result> results;
        System.runAs(u) {
            results = ScoreReadinessAction.score(new List<ScoreReadinessAction.Request>{ request(null, 3) });
        }
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('No engagement selected'));
    }

    @IsTest
    static void userWithoutAccessCannotSave() {
        Engagement__c e = TestDataFactory.engagement('No Access', Date.today());
        User u = TestDataFactory.userWithoutAccess();

        List<ScoreReadinessAction.Result> results;
        System.runAs(u) {
            results = ScoreReadinessAction.score(new List<ScoreReadinessAction.Request>{ request(e.Id, 4) });
        }

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.startsWith('Could not save the assessment:'), results[0].message);
        System.assertEquals(0, [SELECT COUNT() FROM Readiness_Assessment__c]);
        System.assertEquals(null, [SELECT Readiness_Score__c FROM Engagement__c WHERE Id = :e.Id].Readiness_Score__c);
    }

    @IsTest
    static void mixedBatchKeepsGoodAndRejectsBad() {
        Engagement__c e = TestDataFactory.engagement('Batch Test', Date.today());
        User u = TestDataFactory.strategist();

        List<ScoreReadinessAction.Result> results;
        System.runAs(u) {
            results = ScoreReadinessAction.score(new List<ScoreReadinessAction.Request>{
                request(e.Id, 3), request(e.Id, 0)
            });
        }

        System.assertEquals(true, results[0].success);
        System.assertEquals(false, results[1].success);
        System.assertEquals(1, [SELECT COUNT() FROM Readiness_Assessment__c]);
    }
}
