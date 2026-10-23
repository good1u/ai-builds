@IsTest
private class RoadmapWriterActionTest {

    private static RoadmapWriterAction.Request request(Id engagementId, String text, Boolean approved) {
        RoadmapWriterAction.Request r = new RoadmapWriterAction.Request();
        r.engagementId = engagementId;
        r.roadmapText = text;
        r.approvedByUser = approved;
        return r;
    }

    private static List<RoadmapWriterAction.Result> run(RoadmapWriterAction.Request r) {
        User u = TestDataFactory.strategist();
        List<RoadmapWriterAction.Result> results;
        System.runAs(u) {
            results = RoadmapWriterAction.save(new List<RoadmapWriterAction.Request>{ r });
        }
        return results;
    }

    @IsTest
    static void approvedRoadmapIsSaved() {
        Engagement__c e = TestDataFactory.engagement('Roadmap Test', Date.today());
        List<RoadmapWriterAction.Result> results = run(request(e.Id, 'Weeks 1-2: discovery', true));

        System.assertEquals(true, results[0].success, results[0].message);
        Engagement__c saved = [SELECT Roadmap__c, Roadmap_Approved_On__c FROM Engagement__c WHERE Id = :e.Id];
        System.assertEquals('Weeks 1-2: discovery', saved.Roadmap__c);
        System.assertNotEquals(null, saved.Roadmap_Approved_On__c);
    }

    @IsTest
    static void unapprovedRoadmapIsRefused() {
        Engagement__c e = TestDataFactory.engagement('No Approval', Date.today());
        List<RoadmapWriterAction.Result> results = run(request(e.Id, 'Draft text', false));

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('not approved'));
        System.assertEquals(null, [SELECT Roadmap__c FROM Engagement__c WHERE Id = :e.Id].Roadmap__c);
    }

    @IsTest
    static void nullApprovalCountsAsNotApproved() {
        Engagement__c e = TestDataFactory.engagement('Null Approval', Date.today());
        List<RoadmapWriterAction.Result> results = run(request(e.Id, 'Draft text', null));
        System.assertEquals(false, results[0].success);
        System.assertEquals(null, [SELECT Roadmap__c FROM Engagement__c WHERE Id = :e.Id].Roadmap__c);
    }

    @IsTest
    static void blankTextIsRefused() {
        Engagement__c e = TestDataFactory.engagement('Blank Text', Date.today());
        System.assertEquals(false, run(request(e.Id, '   ', true))[0].success);
    }

    @IsTest
    static void missingEngagementIsRefused() {
        System.assertEquals(false, run(request(null, 'Text', true))[0].success);
    }

    @IsTest
    static void userWithoutAccessCannotSave() {
        Engagement__c e = TestDataFactory.engagement('No Access', Date.today());
        User u = TestDataFactory.userWithoutAccess();

        List<RoadmapWriterAction.Result> results;
        System.runAs(u) {
            results = RoadmapWriterAction.save(new List<RoadmapWriterAction.Request>{ request(e.Id, 'Draft text', true) });
        }

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.startsWith('Roadmap not saved:'), results[0].message);
        System.assertEquals(null, [SELECT Roadmap__c FROM Engagement__c WHERE Id = :e.Id].Roadmap__c);
    }

    @IsTest
    static void oversizedRoadmapIsRefused() {
        Engagement__c e = TestDataFactory.engagement('Too Long', Date.today());
        List<RoadmapWriterAction.Result> results = run(request(e.Id, 'x'.repeat(32769), true));
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('limit'));
    }
}
