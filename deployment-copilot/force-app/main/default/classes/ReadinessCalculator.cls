/**
 * Pure scoring logic for the AI readiness assessment.
 * No SOQL, no DML. The agent collects the six scores from the user;
 * this class does the math so the LLM never does.
 *
 * Weights are my starting heuristics, not a Salesforce standard.
 * Change them here and the unit tests will tell you what moved.
 */
public with sharing class ReadinessCalculator {

    public class ReadinessException extends Exception {}

    public class Scores {
        public Integer dataReadiness;
        public Integer useCaseClarity;
        public Integer executiveSponsorship;
        public Integer responsibleAiGovernance;
        public Integer platformReadiness;
        public Integer changeReadiness;
    }

    public class Outcome {
        public Decimal totalScore;
        public String band;
        public List<String> gaps = new List<String>();
    }

    // Weights add up to 100.
    @TestVisible private static final Integer W_DATA = 20;
    @TestVisible private static final Integer W_USE_CASE = 20;
    @TestVisible private static final Integer W_SPONSOR = 15;
    @TestVisible private static final Integer W_GOVERNANCE = 15;
    @TestVisible private static final Integer W_PLATFORM = 15;
    @TestVisible private static final Integer W_CHANGE = 15;

    public static final String BAND_READY = 'Ready';
    public static final String BAND_CONDITIONS = 'Ready with conditions';
    public static final String BAND_FOUNDATION = 'Foundational work needed';
    public static final String BAND_NOT_READY = 'Not ready';
    public static final String BAND_BLOCKED = 'Blocked';

    public static Outcome calculate(Scores s) {
        validate(s);

        Decimal total = weighted(s.dataReadiness, W_DATA)
            + weighted(s.useCaseClarity, W_USE_CASE)
            + weighted(s.executiveSponsorship, W_SPONSOR)
            + weighted(s.responsibleAiGovernance, W_GOVERNANCE)
            + weighted(s.platformReadiness, W_PLATFORM)
            + weighted(s.changeReadiness, W_CHANGE);

        Outcome o = new Outcome();
        o.totalScore = total.setScale(1);

        addGapIfLow(o.gaps, 'Data readiness', s.dataReadiness);
        addGapIfLow(o.gaps, 'Use case clarity', s.useCaseClarity);
        addGapIfLow(o.gaps, 'Executive sponsorship', s.executiveSponsorship);
        addGapIfLow(o.gaps, 'Responsible AI governance', s.responsibleAiGovernance);
        addGapIfLow(o.gaps, 'Platform readiness', s.platformReadiness);
        addGapIfLow(o.gaps, 'Change readiness', s.changeReadiness);

        // A high total cannot hide a missing sponsor or missing governance.
        if (s.executiveSponsorship == 1 || s.responsibleAiGovernance == 1) {
            o.band = BAND_BLOCKED;
            if (s.executiveSponsorship == 1) {
                o.gaps.add('BLOCKER: no executive sponsor');
            }
            if (s.responsibleAiGovernance == 1) {
                o.gaps.add('BLOCKER: no responsible AI governance');
            }
        } else if (o.totalScore >= 85) {
            o.band = BAND_READY;
        } else if (o.totalScore >= 70) {
            o.band = BAND_CONDITIONS;
        } else if (o.totalScore >= 50) {
            o.band = BAND_FOUNDATION;
        } else {
            o.band = BAND_NOT_READY;
        }
        return o;
    }

    private static Decimal weighted(Integer score, Integer weight) {
        return (Decimal.valueOf(score) * weight) / 5;
    }

    private static void addGapIfLow(List<String> gaps, String label, Integer score) {
        if (score <= 2) {
            gaps.add(label + ' (' + score + ' of 5)');
        }
    }

    private static void validate(Scores s) {
        if (s == null) {
            throw new ReadinessException('No scores provided.');
        }
        check('Data readiness', s.dataReadiness);
        check('Use case clarity', s.useCaseClarity);
        check('Executive sponsorship', s.executiveSponsorship);
        check('Responsible AI governance', s.responsibleAiGovernance);
        check('Platform readiness', s.platformReadiness);
        check('Change readiness', s.changeReadiness);
    }

    private static void check(String label, Integer score) {
        if (score == null) {
            throw new ReadinessException(label + ' is missing. Every dimension needs a score from 1 to 5.');
        }
        if (score < 1 || score > 5) {
            throw new ReadinessException(label + ' must be between 1 and 5. Got ' + score + '.');
        }
    }
}
