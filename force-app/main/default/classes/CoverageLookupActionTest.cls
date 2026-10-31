/**
 * Tests for CoverageLookupAction (AI-06 / SEC-05):
 * expired plan, no plan, unknown serial, a user without access, and bulk behaviour.
 */
@IsTest
private class CoverageLookupActionTest {

    private static final String SN_EXPIRED = 'SN-TEST-4412';
    private static final String SN_NO_PLAN = 'SN-TEST-0001';

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Coverage Test Customer', Region__c = 'Benelux');
        insert acc;

        Coverage_Plan__c plan = new Coverage_Plan__c(
            Account__c = acc.Id,
            Start_Date__c = Date.today().addDays(-400),
            End_Date__c = Date.today().addDays(-30),
            Status__c = 'Active'
        );
        insert plan;

        insert new List<Equipment__c>{
            new Equipment__c(Name = 'Test Chiller', Serial_Number__c = SN_EXPIRED,
                             Account__c = acc.Id, Current_Coverage_Plan__c = plan.Id),
            new Equipment__c(Name = 'Test Dryer', Serial_Number__c = SN_NO_PLAN, Account__c = acc.Id)
        };
    }

    private static CoverageLookupAction.Request req(String serial) {
        CoverageLookupAction.Request r = new CoverageLookupAction.Request();
        r.serialNumber = serial;
        return r;
    }

    @IsTest
    static void expiredPlan_returnsExpiredAndEndDate() {
        Test.startTest();
        CoverageLookupAction.Result res = CoverageLookupAction.check(
            new List<CoverageLookupAction.Request>{ req(SN_EXPIRED) })[0];
        Test.stopTest();

        Assert.areEqual('Expired', res.coveragePosition, 'Plan ended 30 days ago');
        Assert.areEqual(Date.today().addDays(-30), res.endDate, 'End date of the plan');
        Assert.isNotNull(res.planName, 'Plan name returned');
        Assert.isNull(res.message, 'No error message');
    }

    @IsTest
    static void noPlan_returnsNotCovered() {
        CoverageLookupAction.Result res = CoverageLookupAction.check(
            new List<CoverageLookupAction.Request>{ req(' sn-test-0001 ') })[0];

        Assert.areEqual('Not Covered', res.coveragePosition, 'No current plan; serial matched despite case and spaces');
        Assert.isNull(res.endDate, 'No end date without a plan');
    }

    @IsTest
    static void unknownSerial_returnsMessage() {
        CoverageLookupAction.Result res = CoverageLookupAction.check(
            new List<CoverageLookupAction.Request>{ req('SN-DOES-NOT-EXIST') })[0];

        Assert.isNull(res.coveragePosition, 'Nothing found');
        Assert.areEqual(System.Label.HES_Msg_No_Coverage_Access, res.message, 'Label message');
    }

    @IsTest
    static void userWithoutAccess_getsMessageNotData() {
        User noAccess = noAccessUser();
        CoverageLookupAction.Result res;

        System.runAs(noAccess) {
            Test.startTest();
            res = CoverageLookupAction.check(new List<CoverageLookupAction.Request>{ req(SN_EXPIRED) })[0];
            Test.stopTest();
        }

        Assert.isNull(res.coveragePosition, 'No coverage revealed to a user without access');
        Assert.isNull(res.endDate, 'No end date revealed');
        Assert.areEqual(System.Label.HES_Msg_No_Coverage_Access, res.message, 'Label message');
    }

    @IsTest
    static void bulk_answersEveryRequestWithTwoQueries() {
        List<CoverageLookupAction.Request> reqs = new List<CoverageLookupAction.Request>();
        for (Integer i = 0; i < 100; i++) {
            reqs.add(req(Math.mod(i, 2) == 0 ? SN_EXPIRED : SN_NO_PLAN));
        }

        Test.startTest();
        Integer before = Limits.getQueries();
        List<CoverageLookupAction.Result> results = CoverageLookupAction.check(reqs);
        Integer used = Limits.getQueries() - before;
        Test.stopTest();

        Assert.areEqual(100, results.size(), 'One result per request, in order');
        Assert.areEqual('Expired', results[0].coveragePosition);
        Assert.areEqual('Not Covered', results[1].coveragePosition);
        Assert.isTrue(used <= 2, 'Bulk-safe: at most 2 queries (used ' + used + ')');
    }

    /** A user with no HES permission sets: no access to Equipment or the test account. */
    private static User noAccessUser() {
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'noacc', Email = 'noaccess' + unique + '@example.com',
            Username = 'noaccess' + unique + '@hes-test.example.com',
            LastName = 'No Access', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Amsterdam'
        );
        // Minimum-access profile; falls back to a Platform licence if no Salesforce licence is free.
        List<Profile> profiles = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name IN ('Salesforce', 'Salesforce Platform')
              AND PermissionsModifyAllData = false AND PermissionsViewAllData = false
              AND Name LIKE 'Minimum Access%'
            ORDER BY UserLicense.Name
        ];
        for (Profile p : profiles) {
            u.ProfileId = p.Id;
            Database.SaveResult sr = Database.insert(u, false);
            if (sr.isSuccess()) {
                return u;
            }
            u.Id = null;
        }
        Assert.fail('Could not create a minimum-access test user');
        return null;
    }
}
