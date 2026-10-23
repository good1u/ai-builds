/**
 * Pure adoption and consumption math. No SOQL, no DML.
 *
 * Thresholds below are starting heuristics for a 12-week engagement.
 * They are not Salesforce benchmarks. Tune them per customer.
 */
public with sharing class AdoptionCalculator {

    @TestVisible private static final Decimal MIN_ADOPTION_RATE_AFTER_WEEK_6 = 40;
    @TestVisible private static final Decimal MAX_ADOPTION_DROP_POINTS = 5;
    @TestVisible private static final Decimal MIN_CONTAINMENT_RATE = 50;
    @TestVisible private static final Decimal MAX_CONTAINMENT_DROP_POINTS = 10;
    @TestVisible private static final Integer ADOPTION_CHECK_WEEK = 6;

    public static final String RISK_LOW = 'Low';
    public static final String RISK_MEDIUM = 'Medium';
    public static final String RISK_HIGH = 'High';
    public static final String RISK_UNKNOWN = 'Unknown';

    public class Snapshot {
        public Date weekEnding;
        public Decimal adoptionRate;     // active / eligible, percent
        public Decimal containmentRate;  // resolved by agent / conversations, percent
        public Decimal creditsConsumed;
    }

    public class Assessment {
        public Snapshot latest;
        public Snapshot prior;
        public Decimal adoptionDeltaPoints;
        public Decimal containmentDeltaPoints;
        public String riskLevel;
        public List<String> flags = new List<String>();
    }

    /** Percent to one decimal place. Returns 0 when the denominator is missing or zero. */
    public static Decimal percent(Decimal numerator, Decimal denominator) {
        if (numerator == null || denominator == null || denominator == 0) {
            return 0;
        }
        return ((numerator * 100) / denominator).setScale(1);
    }

    public static Snapshot toSnapshot(Adoption_Metric__c m) {
        Snapshot s = new Snapshot();
        s.weekEnding = m.Week_Ending__c;
        s.adoptionRate = percent(m.Active_Users__c, m.Eligible_Users__c);
        s.containmentRate = percent(m.Resolved_By_Agent__c, m.Conversations__c);
        s.creditsConsumed = m.Credits_Consumed__c == null ? 0 : m.Credits_Consumed__c;
        return s;
    }

    /**
     * @param metricsNewestFirst weekly metrics for ONE engagement, newest first
     * @param engagementWeek     1-based week of the engagement as of the latest metric
     */
    public static Assessment assess(List<Adoption_Metric__c> metricsNewestFirst, Integer engagementWeek) {
        Assessment a = new Assessment();
        if (metricsNewestFirst == null || metricsNewestFirst.isEmpty()) {
            a.riskLevel = RISK_UNKNOWN;
            a.flags.add('No adoption data has been logged yet');
            return a;
        }

        a.latest = toSnapshot(metricsNewestFirst[0]);
        if (metricsNewestFirst.size() > 1) {
            a.prior = toSnapshot(metricsNewestFirst[1]);
            a.adoptionDeltaPoints = (a.latest.adoptionRate - a.prior.adoptionRate).setScale(1);
            a.containmentDeltaPoints = (a.latest.containmentRate - a.prior.containmentRate).setScale(1);
        }

        if (engagementWeek >= ADOPTION_CHECK_WEEK && a.latest.adoptionRate < MIN_ADOPTION_RATE_AFTER_WEEK_6) {
            a.flags.add('Adoption is ' + a.latest.adoptionRate + '% at week ' + engagementWeek
                + ' (floor is ' + MIN_ADOPTION_RATE_AFTER_WEEK_6 + '%)');
        }
        if (a.adoptionDeltaPoints != null && a.adoptionDeltaPoints < -MAX_ADOPTION_DROP_POINTS) {
            a.flags.add('Adoption fell ' + (-a.adoptionDeltaPoints) + ' points week over week');
        }
        if (a.latest.containmentRate < MIN_CONTAINMENT_RATE) {
            a.flags.add('The agent resolved only ' + a.latest.containmentRate + '% of conversations');
        }
        if (a.containmentDeltaPoints != null && a.containmentDeltaPoints < -MAX_CONTAINMENT_DROP_POINTS) {
            a.flags.add('Containment fell ' + (-a.containmentDeltaPoints) + ' points week over week');
        }

        if (a.flags.isEmpty()) {
            a.riskLevel = RISK_LOW;
        } else if (a.flags.size() == 1) {
            a.riskLevel = RISK_MEDIUM;
        } else {
            a.riskLevel = RISK_HIGH;
        }
        return a;
    }
}
