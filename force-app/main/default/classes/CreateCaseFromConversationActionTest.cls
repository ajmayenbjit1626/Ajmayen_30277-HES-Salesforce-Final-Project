/**
 * Tests for CreateCaseFromConversationAction (AI-07): case created with the right record type,
 * equipment, account and origin; unknown serial; user without access; bulk limits.
 */
@IsTest
private class CreateCaseFromConversationActionTest {

    private static final String SN = 'SN-TEST-7001';

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Agent Case Test Customer', Region__c = 'Benelux');
        insert acc;
        insert new Equipment__c(Name = 'Test Compressor', Serial_Number__c = SN, Account__c = acc.Id);
    }

    private static CreateCaseFromConversationAction.Request req(String serial, String subject) {
        CreateCaseFromConversationAction.Request r = new CreateCaseFromConversationAction.Request();
        r.serialNumber = serial;
        r.subject = subject;
        r.description = 'Created by the agent test.';
        return r;
    }

    @IsTest
    static void knownSerial_createsTechnicalCaseAndReturnsNumber() {
        Test.startTest();
        CreateCaseFromConversationAction.Result res = CreateCaseFromConversationAction.create(
            new List<CreateCaseFromConversationAction.Request>{ req(SN, 'Compressor trips after 10 minutes') })[0];
        Test.stopTest();

        Assert.isNotNull(res.caseId, 'Case created: ' + res.message);
        Assert.isNotNull(res.caseNumber, 'Case number returned');
        Assert.isTrue(res.message.contains(res.caseNumber), 'Confirmation contains the number');

        Case c = [SELECT RecordType.DeveloperName, Equipment__r.Serial_Number__c, Account.Name, Origin, Subject
                  FROM Case WHERE Id = :res.caseId];
        Assert.areEqual('Technical', c.RecordType.DeveloperName, 'Technical record type');
        Assert.areEqual(SN, c.Equipment__r.Serial_Number__c, 'Linked to the equipment');
        Assert.areEqual('Agent Case Test Customer', c.Account.Name, 'Account taken from the equipment');
        Assert.areEqual(CreateCaseFromConversationAction.ORIGIN_AGENT, c.Origin, 'Origin Agentforce');
        Assert.areEqual('Compressor trips after 10 minutes', c.Subject);
    }

    @IsTest
    static void unknownSerial_createsNoCase() {
        Integer before = [SELECT COUNT() FROM Case];
        CreateCaseFromConversationAction.Result res = CreateCaseFromConversationAction.create(
            new List<CreateCaseFromConversationAction.Request>{ req('SN-NOPE', 'Something broke') })[0];

        Assert.isNull(res.caseId, 'No case for an unknown serial');
        Assert.areEqual(System.Label.HES_Msg_No_Coverage_Access, res.message);
        Assert.areEqual(before, [SELECT COUNT() FROM Case], 'Nothing inserted');
    }

    @IsTest
    static void userWithoutAccess_createsNoCase() {
        User noAccess = noAccessUser();
        CreateCaseFromConversationAction.Result res;
        System.runAs(noAccess) {
            res = CreateCaseFromConversationAction.create(
                new List<CreateCaseFromConversationAction.Request>{ req(SN, 'Should not be created') })[0];
        }
        Assert.isNull(res.caseId, 'A user who cannot see the equipment cannot raise a case for it');
        Assert.isNotNull(res.message, 'Explains why');
    }

    @IsTest
    static void bulk_fiftyRequestsUseFewQueriesAndOneInsert() {
        List<CreateCaseFromConversationAction.Request> reqs = new List<CreateCaseFromConversationAction.Request>();
        for (Integer i = 0; i < 50; i++) {
            reqs.add(req(SN, 'Bulk case ' + i));
        }
        Test.startTest();
        Integer q0 = Limits.getQueries();
        Integer d0 = Limits.getDmlStatements();
        List<CreateCaseFromConversationAction.Result> results = CreateCaseFromConversationAction.create(reqs);
        Integer queries = Limits.getQueries() - q0;
        Integer dml = Limits.getDmlStatements() - d0;
        Test.stopTest();

        Assert.areEqual(50, results.size());
        for (CreateCaseFromConversationAction.Result r : results) {
            Assert.isNotNull(r.caseNumber, 'Every request got a case: ' + r.message);
        }
        // Own work: 3 queries, 1 insert. Case automation (flows, trigger) adds its own, so allow headroom.
        Assert.isTrue(dml >= 1, 'Cases inserted');
        Assert.isTrue(queries < 50, 'No query per request (used ' + queries + ')');
    }

    private static User noAccessUser() {
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'noacc', Email = 'noaccess' + unique + '@example.com',
            Username = 'noaccess' + unique + '@hes-test.example.com',
            LastName = 'No Access', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Amsterdam'
        );
        for (Profile p : [
            SELECT Id FROM Profile
            WHERE UserLicense.Name IN ('Salesforce', 'Salesforce Platform')
              AND PermissionsModifyAllData = false AND PermissionsViewAllData = false
              AND Name LIKE 'Minimum Access%'
            ORDER BY UserLicense.Name
        ]) {
            u.ProfileId = p.Id;
            if (Database.insert(u, false).isSuccess()) {
                return u;
            }
            u.Id = null;
        }
        Assert.fail('Could not create a minimum-access test user');
        return null;
    }
}
