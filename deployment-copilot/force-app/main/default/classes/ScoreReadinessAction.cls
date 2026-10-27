/**
 * Agent action: score an engagement's AI readiness and save the assessment.
 * Input names here must match the action inputs in Deployment_Copilot.agent exactly (case included).
 */
public with sharing class ScoreReadinessAction {

    public class Request {
        @InvocableVariable(label='Engagement Id' description='Salesforce Id of the Engagement record' required=true)
        public Id engagementId;
        @InvocableVariable(label='Data readiness' description='Score from 1 to 5' required=true)
        public Integer dataReadiness;
        @InvocableVariable(label='Use case clarity' description='Score from 1 to 5' required=true)
        public Integer useCaseClarity;
        @InvocableVariable(label='Executive sponsorship' description='Score from 1 to 5' required=true)
        public Integer executiveSponsorship;
        @InvocableVariable(label='Responsible AI governance' description='Score from 1 to 5' required=true)
        public Integer responsibleAiGovernance;
        @InvocableVariable(label='Platform readiness' description='Score from 1 to 5' required=true)
        public Integer platformReadiness;
        @InvocableVariable(label='Change readiness' description='Score from 1 to 5' required=true)
        public Integer changeReadiness;
    }

    public class Result {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Total score') public Decimal totalScore;
        @InvocableVariable(label='Band') public String band;
        @InvocableVariable(label='Gaps') public String gaps;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='Score AI readiness'
        description='Scores six readiness dimensions from 1 to 5, saves the assessment on the engagement, and returns the weighted score, band, and gaps.'
        category='Deployment Copilot'
    )
    public static List<Result> score(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<Readiness_Assessment__c> assessments = new List<Readiness_Assessment__c>();
        List<Integer> resultIndexForAssessment = new List<Integer>();
        Map<Id, Decimal> scoreByEngagement = new Map<Id, Decimal>();

        for (Request req : requests) {
            Result res = new Result();
            results.add(res);
            if (req.engagementId == null) {
                res.success = false;
                res.message = 'No engagement selected. Find the engagement first.';
                continue;
            }
            try {
                ReadinessCalculator.Scores s = new ReadinessCalculator.Scores();
                s.dataReadiness = req.dataReadiness;
                s.useCaseClarity = req.useCaseClarity;
                s.executiveSponsorship = req.executiveSponsorship;
                s.responsibleAiGovernance = req.responsibleAiGovernance;
                s.platformReadiness = req.platformReadiness;
                s.changeReadiness = req.changeReadiness;

                ReadinessCalculator.Outcome o = ReadinessCalculator.calculate(s);

                res.success = true;
                res.totalScore = o.totalScore;
                res.band = o.band;
                res.gaps = o.gaps.isEmpty() ? 'None' : String.join(o.gaps, '; ');
                res.message = 'Assessment saved.';

                assessments.add(new Readiness_Assessment__c(
                    Engagement__c = req.engagementId,
                    Data_Readiness__c = req.dataReadiness,
                    Use_Case_Clarity__c = req.useCaseClarity,
                    Executive_Sponsorship__c = req.executiveSponsorship,
                    Responsible_AI_Governance__c = req.responsibleAiGovernance,
                    Platform_Readiness__c = req.platformReadiness,
                    Change_Readiness__c = req.changeReadiness,
                    Total_Score__c = o.totalScore,
                    Band__c = o.band,
                    Gaps__c = res.gaps
                ));
                resultIndexForAssessment.add(results.size() - 1);
                scoreByEngagement.put(req.engagementId, o.totalScore);
            } catch (ReadinessCalculator.ReadinessException e) {
                res.success = false;
                res.message = e.getMessage();
            }
        }

        if (!assessments.isEmpty()) {
            try {
                insert as user assessments;

                List<Engagement__c> toUpdate = new List<Engagement__c>();
                for (Id engId : scoreByEngagement.keySet()) {
                    toUpdate.add(new Engagement__c(Id = engId, Readiness_Score__c = scoreByEngagement.get(engId)));
                }
                update as user toUpdate;
            } catch (Exception e) {
                for (Integer idx : resultIndexForAssessment) {
                    results[idx].success = false;
                    results[idx].message = 'Could not save the assessment: ' + e.getMessage();
                }
            }
        }
        return results;
    }
}