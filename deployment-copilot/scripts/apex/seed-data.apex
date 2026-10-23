// Synthetic demo data. Every company here is made up.
// Run once:  sf apex run --file scripts/apex/seed-data.apex --target-org <alias>
// Undo:      sf apex run --file scripts/apex/reset-data.apex --target-org <alias>

Date today = Date.today();

List<Account> accounts = new List<Account>{
    new Account(Name = 'Alder Ridge Logistics'),
    new Account(Name = 'Fernhollow Retail Group'),
    new Account(Name = 'Quarry Lane Financial')
};
insert accounts;

List<Engagement__c> engagements = new List<Engagement__c>{
    // Healthy: adoption climbing, containment steady.
    new Engagement__c(
        Name = 'Alder Ridge Service Agent', Account__c = accounts[0].Id, Stage__c = 'Consume', Status__c = 'On track',
        Start_Date__c = today.addDays(-56), Target_End_Date__c = today.addDays(28),
        Business_Goal__c = 'Cut first-response time on internal shipment-exception requests.'),
    // Earlier pilot for the same customer. Gives the "several matches" case something to find.
    new Engagement__c(
        Name = 'Alder Ridge Pilot', Account__c = accounts[0].Id, Stage__c = 'Consume', Status__c = 'On track',
        Start_Date__c = today.addDays(-130), Target_End_Date__c = today.addDays(-46),
        Business_Goal__c = 'Prove an agent can answer carrier rate questions.'),
    // At risk: adoption peaked in week 4 and has been falling since.
    new Engagement__c(
        Name = 'Fernhollow IT Helpdesk Agent', Account__c = accounts[1].Id, Stage__c = 'Consume', Status__c = 'At risk',
        Start_Date__c = today.addDays(-49), Target_End_Date__c = today.addDays(35),
        Business_Goal__c = 'Deflect password and access requests from the IT queue.'),
    // Brand new: no readiness score, no roadmap, no metrics.
    new Engagement__c(
        Name = 'Quarry Lane Onboarding Agent', Account__c = accounts[2].Id, Stage__c = 'Identify', Status__c = 'On track',
        Start_Date__c = today.addDays(-7), Target_End_Date__c = today.addDays(77),
        Business_Goal__c = 'Shorten new-hire system access setup from 5 days to 2.')
};
insert engagements;

// Weeks ending at -35, -28, -21, -14, -7, 0 days.
Integer[] offsets = new Integer[]{ -35, -28, -21, -14, -7, 0 };

// Alder Ridge Service Agent: eligible 400
Integer[] alderActive = new Integer[]{ 120, 150, 190, 230, 260, 280 };
Integer[] alderConv = new Integer[]{ 250, 320, 410, 500, 560, 610 };
Integer[] alderResolved = new Integer[]{ 140, 200, 270, 340, 390, 430 };

// Fernhollow IT Helpdesk Agent: eligible 600
Integer[] fernActive = new Integer[]{ 180, 240, 270, 250, 200, 150 };
Integer[] fernConv = new Integer[]{ 400, 520, 560, 500, 430, 380 };
Integer[] fernResolved = new Integer[]{ 260, 340, 330, 260, 190, 150 };

List<Adoption_Metric__c> metrics = new List<Adoption_Metric__c>();
for (Integer i = 0; i < offsets.size(); i++) {
    metrics.add(new Adoption_Metric__c(
        Engagement__c = engagements[0].Id, Week_Ending__c = today.addDays(offsets[i]),
        Eligible_Users__c = 400, Active_Users__c = alderActive[i],
        Conversations__c = alderConv[i], Resolved_By_Agent__c = alderResolved[i],
        Credits_Consumed__c = alderConv[i] * 10));
    metrics.add(new Adoption_Metric__c(
        Engagement__c = engagements[2].Id, Week_Ending__c = today.addDays(offsets[i]),
        Eligible_Users__c = 600, Active_Users__c = fernActive[i],
        Conversations__c = fernConv[i], Resolved_By_Agent__c = fernResolved[i],
        Credits_Consumed__c = fernConv[i] * 10));
}
insert metrics;

System.debug('Seeded ' + engagements.size() + ' engagements and ' + metrics.size() + ' weekly metrics.');
