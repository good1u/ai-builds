@IsTest
private class AdoptionInsightActionTest {

    /** Stands in for Data 360. Returns canned insight rows and records the SQL it was given. */
    private class FakeQuery extends AdoptionInsightAction.InsightQuery {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        String lastSql;
        public override List<Map<String, Object>> run(String sql) {
            lastSql = sql;
            return rows;
        }
    }

    private static Map<String, Object> row(Id engagementId, Date weekEnding, String adoption, String containment, String credits) {
        return new Map<String, Object>{
            'engagement_id__c' => String.valueOf(engagementId),
            'week_ending__c' => String.valueOf(weekEnding),
            'adoption_rate__c' => adoption,
            'containment_rate__c' => containment,
            'total_credits__c' => credits
        };
    }

    private static AdoptionInsightAction.Request request(Id engagementId) {
        AdoptionInsightAction.Request r = new AdoptionInsightAction.Request();
        r.engagementId = engagementId;
        return r;
    }

    @IsTest
    static void reportsInsightRatesWithCrmScale() {
        Engagement__c e = TestDataFactory.engagement('Insight Test', Date.today().addDays(-49));
        FakeQuery fake = new FakeQuery();
        // Newest first, as the SQL orders them, with the 18 decimal places Data 360 returns.
        fake.rows.add(row(e.Id, Date.today(), '30.000000000000000000', '30.000000000000000000', '3800.000000000000000000'));
        fake.rows.add(row(e.Id, Date.today().addDays(-7), '60.000000000000000000', '70.000000000000000000', '3000.000000000000000000'));
        AdoptionInsightAction.query = fake;
        User u = TestDataFactory.strategist();

        List<AdoptionInsightAction.Result> results;
        System.runAs(u) {
            results = AdoptionInsightAction.snapshot(new List<AdoptionInsightAction.Request>{ request(e.Id) });
        }

        System.assertEquals('High', results[0].riskLevel, results[0].summary);
        System.assert(results[0].summary.contains('Week 8'), results[0].summary);
        System.assert(results[0].summary.contains('Adoption rate: 30.0%'), results[0].summary);
        System.assert(results[0].summary.contains('-30.0 points'), results[0].summary);
        System.assert(results[0].summary.contains('Credits consumed this week: 3800.'), results[0].summary);
        System.assert(fake.lastSql.contains('\'' + String.valueOf(e.Id) + '\''), fake.lastSql);
    }

    @IsTest
    static void noInsightRowsIsUnknown() {
        Engagement__c e = TestDataFactory.engagement('Insight Empty', Date.today());
        AdoptionInsightAction.query = new FakeQuery();
        User u = TestDataFactory.strategist();

        List<AdoptionInsightAction.Result> results;
        System.runAs(u) {
            results = AdoptionInsightAction.snapshot(new List<AdoptionInsightAction.Request>{ request(e.Id) });
        }
        System.assertEquals('Unknown', results[0].riskLevel);
        System.assert(results[0].summary.contains('No adoption data'));
    }

    @IsTest
    static void noAccessSkipsDataCloud() {
        Engagement__c e = TestDataFactory.engagement('Insight No Access', Date.today().addDays(-14));
        FakeQuery fake = new FakeQuery();
        fake.rows.add(row(e.Id, Date.today(), '80', '90', '100'));
        AdoptionInsightAction.query = fake;
        User u = TestDataFactory.userWithoutAccess();

        List<AdoptionInsightAction.Result> results;
        System.runAs(u) {
            try {
                results = AdoptionInsightAction.snapshot(new List<AdoptionInsightAction.Request>{ request(e.Id) });
            } catch (QueryException ex) {
                // USER_MODE rejects the object outright for a user without the permission set. Also fine.
            }
        }
        System.assertEquals(null, fake.lastSql, 'Data 360 must not be queried for an engagement the user cannot see');
        if (results != null) {
            System.assertEquals('Unknown', results[0].riskLevel);
        }
    }

    @IsTest
    static void batchKeepsEngagementsSeparate() {
        Engagement__c a = TestDataFactory.engagement('Insight Batch A', Date.today().addDays(-14));
        Engagement__c b = TestDataFactory.engagement('Insight Batch B', Date.today().addDays(-14));
        FakeQuery fake = new FakeQuery();
        fake.rows.add(row(a.Id, Date.today(), '80', '90', '100'));
        AdoptionInsightAction.query = fake;
        User u = TestDataFactory.strategist();

        List<AdoptionInsightAction.Result> results;
        System.runAs(u) {
            results = AdoptionInsightAction.snapshot(new List<AdoptionInsightAction.Request>{
                request(a.Id), request(b.Id), request(null)
            });
        }
        System.assertEquals('Low', results[0].riskLevel);
        System.assertEquals('Unknown', results[1].riskLevel);
        System.assert(results[2].summary.contains('could not find'));
    }

    @IsTest
    static void queryOutputIsKeyedByColumnName() {
        ConnectApi.CdpQueryMetadataItem first = new ConnectApi.CdpQueryMetadataItem();
        first.placeInOrder = 0;
        ConnectApi.CdpQueryMetadataItem second = new ConnectApi.CdpQueryMetadataItem();
        second.placeInOrder = 1;
        ConnectApi.CdpQueryV2Row row = new ConnectApi.CdpQueryV2Row();
        row.rowData = new List<Object>{ 'a0X000000000001AAA', 25.0 };
        ConnectApi.CdpQueryOutputV2 output = new ConnectApi.CdpQueryOutputV2();
        output.metadata = new Map<String, ConnectApi.CdpQueryMetadataItem>{
            'adoption_rate__c' => second,
            'engagement_id__c' => first
        };
        output.data = new List<ConnectApi.CdpQueryV2Row>{ row };

        List<Map<String, Object>> rows = AdoptionInsightAction.toRows(output);
        System.assertEquals(1, rows.size());
        System.assertEquals('a0X000000000001AAA', rows[0].get('engagement_id__c'));
        System.assertEquals(25.0, rows[0].get('adoption_rate__c'));

        output.data = null;
        System.assertEquals(0, AdoptionInsightAction.toRows(output).size());
    }

    @IsTest
    static void nullValuesBecomeZero() {
        AdoptionCalculator.Snapshot s = AdoptionInsightAction.toSnapshot(new Map<String, Object>{
            'week_ending__c' => '2026-10-17T00:00:00.000Z',
            'adoption_rate__c' => null,
            'containment_rate__c' => null,
            'total_credits__c' => null
        });
        System.assertEquals(Date.newInstance(2026, 10, 17), s.weekEnding);
        System.assertEquals(0, s.adoptionRate);
        System.assertEquals(0, s.creditsConsumed);
    }
}
