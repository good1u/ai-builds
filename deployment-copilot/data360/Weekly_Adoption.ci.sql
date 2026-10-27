SELECT
    Adoption_Metric__dlm.Engagement_Id__c AS engagement_id__c,
    Adoption_Metric__dlm.Week_Ending__c AS week_ending__c,
    SUM(Adoption_Metric__dlm.Eligible_Users__c) AS total_eligible__c,
    SUM(Adoption_Metric__dlm.Active_Users__c) AS total_active__c,
    SUM(Adoption_Metric__dlm.Conversations__c) AS total_conversations__c,
    SUM(Adoption_Metric__dlm.Resolved_By_Agent__c) AS total_resolved__c,
    SUM(Adoption_Metric__dlm.Credits_Consumed__c) AS total_credits__c,
    ROUND(100 * SUM(Adoption_Metric__dlm.Active_Users__c) / SUM(Adoption_Metric__dlm.Eligible_Users__c), 1) AS adoption_rate__c,
    ROUND(100 * SUM(Adoption_Metric__dlm.Resolved_By_Agent__c) / SUM(Adoption_Metric__dlm.Conversations__c), 1) AS containment_rate__c
FROM Adoption_Metric__dlm
GROUP BY engagement_id__c, week_ending__c
