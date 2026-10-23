@IsTest
private class ReadinessCalculatorTest {

    @IsTest
    static void allThreesScoresSixty() {
        ReadinessCalculator.Outcome o = ReadinessCalculator.calculate(TestDataFactory.scores(3, 3, 3, 3, 3, 3));
        System.assertEquals(60.0, o.totalScore);
        System.assertEquals(ReadinessCalculator.BAND_FOUNDATION, o.band);
        System.assert(o.gaps.isEmpty(), 'A 3 is not a gap');
    }

    @IsTest
    static void allFivesIsReady() {
        ReadinessCalculator.Outcome o = ReadinessCalculator.calculate(TestDataFactory.scores(5, 5, 5, 5, 5, 5));
        System.assertEquals(100.0, o.totalScore);
        System.assertEquals(ReadinessCalculator.BAND_READY, o.band);
    }

    @IsTest
    static void bandBoundaries() {
        // 4,4,4,4,4,4 = 80 -> conditions
        System.assertEquals(ReadinessCalculator.BAND_CONDITIONS,
            ReadinessCalculator.calculate(TestDataFactory.scores(4, 4, 4, 4, 4, 4)).band);
        // 5,5,4,4,4,4 = 20+20+12+12+12+12 = 88 -> ready
        System.assertEquals(ReadinessCalculator.BAND_READY,
            ReadinessCalculator.calculate(TestDataFactory.scores(5, 5, 4, 4, 4, 4)).band);
        // 2,2,2,2,2,2 = 40 -> not ready
        System.assertEquals(ReadinessCalculator.BAND_NOT_READY,
            ReadinessCalculator.calculate(TestDataFactory.scores(2, 2, 2, 2, 2, 2)).band);
    }

    @IsTest
    static void lowDimensionsAreListedAsGaps() {
        ReadinessCalculator.Outcome o = ReadinessCalculator.calculate(TestDataFactory.scores(2, 5, 5, 5, 1, 5));
        System.assertEquals(2, o.gaps.size());
        System.assert(o.gaps[0].contains('Data readiness'));
        System.assert(o.gaps[1].contains('Platform readiness'));
    }

    @IsTest
    static void missingSponsorBlocksEvenWithHighTotal() {
        ReadinessCalculator.Outcome o = ReadinessCalculator.calculate(TestDataFactory.scores(5, 5, 1, 5, 5, 5));
        System.assert(o.totalScore >= 85, 'Total would otherwise be Ready');
        System.assertEquals(ReadinessCalculator.BAND_BLOCKED, o.band);
        System.assert(String.join(o.gaps, ';').contains('no executive sponsor'));
    }

    @IsTest
    static void missingGovernanceBlocks() {
        ReadinessCalculator.Outcome o = ReadinessCalculator.calculate(TestDataFactory.scores(5, 5, 5, 1, 5, 5));
        System.assertEquals(ReadinessCalculator.BAND_BLOCKED, o.band);
        System.assert(String.join(o.gaps, ';').contains('no responsible AI governance'));
    }

    @IsTest
    static void outOfRangeScoreIsRejected() {
        try {
            ReadinessCalculator.calculate(TestDataFactory.scores(7, 3, 3, 3, 3, 3));
            System.assert(false, 'Expected an exception');
        } catch (ReadinessCalculator.ReadinessException e) {
            System.assert(e.getMessage().contains('between 1 and 5'));
        }
    }

    @IsTest
    static void missingScoreIsRejected() {
        try {
            ReadinessCalculator.calculate(TestDataFactory.scores(3, null, 3, 3, 3, 3));
            System.assert(false, 'Expected an exception');
        } catch (ReadinessCalculator.ReadinessException e) {
            System.assert(e.getMessage().contains('Use case clarity is missing'));
        }
    }

    @IsTest
    static void nullScoresObjectIsRejected() {
        try {
            ReadinessCalculator.calculate(null);
            System.assert(false, 'Expected an exception');
        } catch (ReadinessCalculator.ReadinessException e) {
            System.assert(e.getMessage().contains('No scores'));
        }
    }
}
