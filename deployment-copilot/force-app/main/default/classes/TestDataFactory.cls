@IsTest
public class TestDataFactory {

    public static Engagement__c engagement(String name, Date startDate) {
        Account a = new Account(Name = name + ' Account');
        insert a;
        Engagement__c e = new Engagement__c(
            Name = name,
            Account__c = a.Id,
            Stage__c = 'Deploy',
            Status__c = 'On track',
            Start_Date__c = startDate,
            Target_End_Date__c = startDate.addDays(84),
            Business_Goal__c = 'Cut first-response time on internal IT requests.'
        );
        insert e;
        return e;
    }

    public static Adoption_Metric__c metric(Id engagementId, Date weekEnding, Integer eligible, Integer active,
                                            Integer conversations, Integer resolved) {
        return new Adoption_Metric__c(
            Engagement__c = engagementId,
            Week_Ending__c = weekEnding,
            Eligible_Users__c = eligible,
            Active_Users__c = active,
            Conversations__c = conversations,
            Resolved_By_Agent__c = resolved,
            Credits_Consumed__c = conversations * 10
        );
    }

    public static ReadinessCalculator.Scores scores(Integer data, Integer useCase, Integer sponsor,
                                                    Integer governance, Integer platform, Integer change) {
        ReadinessCalculator.Scores s = new ReadinessCalculator.Scores();
        s.dataReadiness = data;
        s.useCaseClarity = useCase;
        s.executiveSponsorship = sponsor;
        s.responsibleAiGovernance = governance;
        s.platformReadiness = platform;
        s.changeReadiness = change;
        return s;
    }

    /**
     * Creates a Standard User who holds the Deployment Copilot permission set.
     * The setup-object DML runs inside runAs so it can sit next to ordinary record inserts
     * without tripping MIXED_DML_OPERATION.
     */
    public static User strategist() {
        return standardUser(true);
    }

    /**
     * A Standard User with no Deployment Copilot permission set. Used to prove the
     * actions' "as user" DML refuses to write for someone without access.
     */
    public static User userWithoutAccess() {
        return standardUser(false);
    }

    private static User standardUser(Boolean withCopilotAccess) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniq = String.valueOf(Math.abs(Crypto.getRandomInteger()));
            u = new User(
                Alias = 'dcop', Email = 'dcop' + uniq + '@example.com', EmailEncodingKey = 'UTF-8',
                LastName = 'Strategist', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
                ProfileId = p.Id, TimeZoneSidKey = 'America/Denver', Username = 'dcop' + uniq + '@example.com.test'
            );
            insert u;
            if (withCopilotAccess) {
                PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Deployment_Copilot_Access' LIMIT 1];
                insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
            }
        }
        return u;
    }
}
