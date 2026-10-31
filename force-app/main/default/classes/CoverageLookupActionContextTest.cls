/**
 * Tests for AI-06-R1: the coverage action uses the record the user has open
 * (Case or Equipment) when no serial number is given. The original
 * CoverageLookupActionTest keeps covering the serial-number and no-access paths.
 */
@IsTest
private class CoverageLookupActionContextTest {
  @TestSetup
  static void setup() {
    Account acc = new Account(Name = 'Context Test Account');
    insert acc;
    Coverage_Plan__c plan = new Coverage_Plan__c(
      Account__c = acc.Id,
      Status__c = 'Active',
      Start_Date__c = Date.today().addDays(-30),
      End_Date__c = Date.today().addDays(300)
    );
    insert plan;
    Equipment__c eq = new Equipment__c(
      Name = 'Context Chiller',
      Account__c = acc.Id,
      Serial_Number__c = 'SN-CTX-01',
      Current_Coverage_Plan__c = plan.Id
    );
    insert eq;
    insert new List<Case>{
      new Case(
        Subject = 'Unit trips on start-up',
        Origin = 'Phone',
        AccountId = acc.Id,
        Equipment__c = eq.Id
      ),
      new Case(
        Subject = 'No equipment linked',
        Origin = 'Phone',
        AccountId = acc.Id
      )
    };
  }

  private static CoverageLookupAction.Result run(
    String serial,
    String recordId
  ) {
    CoverageLookupAction.Request req = new CoverageLookupAction.Request();
    req.serialNumber = serial;
    req.recordId = recordId;
    return CoverageLookupAction.check(
      new List<CoverageLookupAction.Request>{ req }
    )[0];
  }

  @IsTest
  static void caseOnScreen_usesItsEquipment() {
    Case c = [SELECT Id FROM Case WHERE Equipment__c != NULL LIMIT 1];
    Test.startTest();
    CoverageLookupAction.Result res = run(null, c.Id);
    Test.stopTest();
    Assert.areEqual(
      'SN-CTX-01',
      res.serialNumber,
      'Serial should come from the case equipment'
    );
    Assert.areEqual(
      'Covered',
      res.coveragePosition,
      'Active plan started 30 days ago is Covered'
    );
    Assert.isNotNull(res.planName, 'Plan name returned');
    Assert.isNull(res.message, 'No message when an answer is given');
  }

  @IsTest
  static void equipmentOnScreen_usesThatUnit() {
    Equipment__c eq = [SELECT Id FROM Equipment__c LIMIT 1];
    CoverageLookupAction.Result res = run('', eq.Id);
    Assert.areEqual(
      'SN-CTX-01',
      res.serialNumber,
      'Serial should come from the open equipment'
    );
    Assert.areEqual(
      Date.today().addDays(300),
      res.endDate,
      'Plan end date returned'
    );
  }

  @IsTest
  static void typedSerial_winsOverPageContext() {
    Case c = [SELECT Id FROM Case WHERE Equipment__c = NULL LIMIT 1];
    CoverageLookupAction.Result res = run('sn-ctx-01', c.Id);
    Assert.areEqual(
      'Covered',
      res.coveragePosition,
      'Typed serial (any case) is used even on another case'
    );
  }

  @IsTest
  static void caseWithoutEquipment_explains() {
    Case c = [SELECT Id FROM Case WHERE Equipment__c = NULL LIMIT 1];
    CoverageLookupAction.Result res = run(null, c.Id);
    Assert.areEqual(
      System.Label.HES_Agent_Case_No_Equipment,
      res.message,
      'Case without equipment asks for a serial'
    );
    Assert.isNull(res.coveragePosition, 'No coverage guessed');
  }

  @IsTest
  static void otherPageOrNoContext_asksForSerial() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Assert.areEqual(
      System.Label.HES_Agent_Need_Serial,
      run(null, acc.Id).message,
      'Account page: ask for serial'
    );
    Assert.areEqual(
      System.Label.HES_Agent_Need_Serial,
      run(null, null).message,
      'Home page: ask for serial'
    );
    Assert.areEqual(
      System.Label.HES_Agent_Need_Serial,
      run(null, 'not-an-id').message,
      'Invalid context ignored'
    );
  }

  @IsTest
  static void bulk_mixedRequests_staysWithinThreeQueries() {
    Case c = [SELECT Id FROM Case WHERE Equipment__c != NULL LIMIT 1];
    Equipment__c eq = [SELECT Id FROM Equipment__c LIMIT 1];
    List<CoverageLookupAction.Request> reqs = new List<CoverageLookupAction.Request>();
    for (Integer i = 0; i < 200; i++) {
      CoverageLookupAction.Request r = new CoverageLookupAction.Request();
      if (Math.mod(i, 3) == 0) {
        r.serialNumber = 'SN-CTX-01';
      } else if (Math.mod(i, 3) == 1) {
        r.recordId = c.Id;
      } else {
        r.recordId = eq.Id;
      }
      reqs.add(r);
    }
    Test.startTest();
    List<CoverageLookupAction.Result> results = CoverageLookupAction.check(
      reqs
    );
    Integer used = Limits.getQueries();
    Test.stopTest();
    Assert.areEqual(200, results.size(), 'One result per request');
    Assert.isTrue(used <= 3, 'At most 3 SOQL for 200 requests, used ' + used);
    for (CoverageLookupAction.Result r : results) {
      Assert.areEqual('Covered', r.coveragePosition, 'Every request resolved');
    }
  }
}
