// Removes only the synthetic demo records created by seed-data.apex.
// Run:  sf apex run --file scripts/apex/reset-data.apex --target-org <alias>

List<String> accountNames = new List<String>{
    'Alder Ridge Logistics', 'Fernhollow Retail Group', 'Quarry Lane Financial'
};
List<Engagement__c> engagements = [SELECT Id FROM Engagement__c WHERE Account__r.Name IN :accountNames];

delete [SELECT Id FROM Adoption_Metric__c WHERE Engagement__c IN :engagements];
delete [SELECT Id FROM Readiness_Assessment__c WHERE Engagement__c IN :engagements];
delete engagements;
delete [SELECT Id FROM Account WHERE Name IN :accountNames];

System.debug('Demo data removed.');
