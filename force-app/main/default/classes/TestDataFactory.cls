/**
 * Test data for the scheduling tests (7-08). No hardcoded Ids or profile names.
 * engineers(): creates test users with the running admin's profile. If the org has no free
 * Salesforce licence (LICENSE_LIMIT_EXCEEDED, see docs/persona-mapping.md), it falls back to the
 * org's existing scheduled engineers; their hour settings are changed only inside the test and rolled back.
 */
@IsTest
public class TestDataFactory {
    public static List<User> engineers(Integer count, Decimal hoursPerDay) {
        List<User> users = new List<User>();
        String stamp = String.valueOf(System.currentTimeMillis());
        for (Integer i = 0; i < count; i++) {
            String u = 'eng' + i + '.' + stamp + '@hes-test.com';
            users.add(new User(LastName = 'Engineer ' + i, Alias = 'eng' + i, Email = u, Username = u,
                ProfileId = UserInfo.getProfileId(), TimeZoneSidKey = 'Europe/Amsterdam', LocaleSidKey = 'en_GB',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
                Default_Working_Hours__c = hoursPerDay, Is_Scheduled__c = true));
        }
        try {
            System.runAs(new User(Id = UserInfo.getUserId())) { insert users; }   // avoids mixed setup/non-setup DML
            return users;
        } catch (DmlException e) {
            if (e.getDmlType(0) != StatusCode.LICENSE_LIMIT_EXCEEDED) { throw e; }
        }
        List<User> existing = [SELECT Id FROM User WHERE IsActive = true AND Is_Scheduled__c = true
                               ORDER BY CreatedDate LIMIT :count];
        for (User u : existing) { u.Default_Working_Hours__c = hoursPerDay; }
        System.runAs(new User(Id = UserInfo.getUserId())) { update existing; }
        return existing;
    }

    public static List<Case> technicalCases(Integer count, Decimal effort) {
        Account a = new Account(Name = 'Test Customer', Region__c = 'Benelux');
        insert a;
        Id rt = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Technical').getRecordTypeId();
        Id triage = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Service_Triage' LIMIT 1].Id;
        List<Case> cs = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cs.add(new Case(Subject = 'Test ' + i, AccountId = a.Id, RecordTypeId = rt, OwnerId = triage,
                            Origin = 'Phone', Estimated_Effort__c = effort));
        }
        insert cs;
        return cs;
    }
}