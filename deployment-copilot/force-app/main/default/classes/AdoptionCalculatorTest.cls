@IsTest
private class AdoptionCalculatorTest {

    private static final Date TODAY = Date.newInstance(2026, 6, 30);

    // Eligible 100 so "active" reads as a percent. Conversations 100 so "resolved" reads as a percent.
    private static Adoption_Metric__c week(Date weekEnding, Integer activePct, Integer resolvedPct) {
        return TestDataFactory.metric(null, weekEnding, 100, activePct, 100, resolvedPct);
    }

    @IsTest
    static void percentHandlesZeroAndNull() {
        System.assertEquals(0.0, AdoptionCalculator.percent(5, 0));
        System.assertEquals(0.0, AdoptionCalculator.percent(5, null));
        System.assertEquals(0.0, AdoptionCalculator.percent(null, 10));
        System.assertEquals(33.3, AdoptionCalculator.percent(1, 3));
    }

    @IsTest
    static void percentRoundsHalfUpLikeDataCloud() {
        // 12.25% exactly. SQL ROUND in Weekly_Adoption__cio gives 12.3, so Apex must too.
        System.assertEquals(12.3, AdoptionCalculator.percent(49, 400));
    }

    @IsTest
    static void noDataIsUnknownNotLow() {
        AdoptionCalculator.Assessment a = AdoptionCalculator.assess(new List<Adoption_Metric__c>(), 4);
        System.assertEquals(AdoptionCalculator.RISK_UNKNOWN, a.riskLevel);
        System.assertEquals(null, a.latest);

        System.assertEquals(AdoptionCalculator.RISK_UNKNOWN, AdoptionCalculator.assess(null, 4).riskLevel);
    }

    @IsTest
    static void healthyEngagementIsLow() {
        AdoptionCalculator.Assessment a = AdoptionCalculator.assess(new List<Adoption_Metric__c>{
            week(TODAY, 70, 75), week(TODAY.addDays(-7), 66, 72)
        }, 8);
        System.assertEquals(AdoptionCalculator.RISK_LOW, a.riskLevel);
        System.assert(a.flags.isEmpty());
        System.assertEquals(4.0, a.adoptionDeltaPoints);
        System.assertEquals(3.0, a.containmentDeltaPoints);
    }

    @IsTest
    static void lowAdoptionOnlyFlagsAfterWeekSix() {
        List<Adoption_Metric__c> data = new List<Adoption_Metric__c>{ week(TODAY, 30, 70) };
        System.assertEquals(AdoptionCalculator.RISK_LOW, AdoptionCalculator.assess(data, 3).riskLevel);
        System.assertEquals(AdoptionCalculator.RISK_MEDIUM, AdoptionCalculator.assess(data, 6).riskLevel);
    }

    @IsTest
    static void adoptionDropOverFivePointsIsFlagged() {
        AdoptionCalculator.Assessment a = AdoptionCalculator.assess(new List<Adoption_Metric__c>{
            week(TODAY, 54, 70), week(TODAY.addDays(-7), 60, 70)
        }, 4);
        System.assertEquals(AdoptionCalculator.RISK_MEDIUM, a.riskLevel);
        System.assert(a.flags[0].contains('Adoption fell 6'), a.flags[0]);
    }

    @IsTest
    static void dropOfExactlyFivePointsIsNotFlagged() {
        AdoptionCalculator.Assessment a = AdoptionCalculator.assess(new List<Adoption_Metric__c>{
            week(TODAY, 55, 70), week(TODAY.addDays(-7), 60, 70)
        }, 4);
        System.assertEquals(AdoptionCalculator.RISK_LOW, a.riskLevel);
    }

    @IsTest
    static void lowAndFallingContainmentIsHigh() {
        AdoptionCalculator.Assessment a = AdoptionCalculator.assess(new List<Adoption_Metric__c>{
            week(TODAY, 60, 40), week(TODAY.addDays(-7), 60, 60)
        }, 5);
        System.assertEquals(2, a.flags.size());
        System.assertEquals(AdoptionCalculator.RISK_HIGH, a.riskLevel);
    }

    @IsTest
    static void creditsDefaultToZeroWhenBlank() {
        Adoption_Metric__c m = week(TODAY, 50, 50);
        m.Credits_Consumed__c = null;
        System.assertEquals(0.0, AdoptionCalculator.toSnapshot(m).creditsConsumed);
    }
}
