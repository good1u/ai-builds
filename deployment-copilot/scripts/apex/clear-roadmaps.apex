// Clears saved roadmaps on the synthetic demo engagements so the roadmap tests can run again.
// Run:  sf apex run --file scripts/apex/clear-roadmaps.apex --target-org <alias>

List<Engagement__c> engagements = [
    SELECT Id FROM Engagement__c
    WHERE Account__r.Name IN ('Alder Ridge Logistics', 'Fernhollow Retail Group', 'Quarry Lane Financial')
];
for (Engagement__c e : engagements) {
    e.Roadmap__c = null;
    e.Roadmap_Approved_On__c = null;
}
update engagements;

System.debug('Cleared roadmaps on ' + engagements.size() + ' engagements.');
