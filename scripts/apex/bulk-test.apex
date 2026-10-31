// 7-04 bulk check (CAP-07). Change N to 1, then 50, and compare the numbers.
Integer N = 1;
Savepoint sp = Database.setSavepoint();
try {
    Id rt = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Technical').getRecordTypeId();
    Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Service_Triage' LIMIT 1].Id;
    User eng = [SELECT Id FROM User WHERE Name = 'Eric Engineer' AND IsActive = true LIMIT 1];

    List<Case> cs = new List<Case>();
    for (Integer i = 0; i < N; i++) {
        cs.add(new Case(Subject = 'Bulk test ' + i, RecordTypeId = rt, OwnerId = queueId,
                        Origin = 'Phone', Estimated_Effort__c = 11));
    }
    insert cs;   // in a queue: nothing is planned yet

    Integer q0 = Limits.getQueries(), d0 = Limits.getDmlStatements(), r0 = Limits.getDmlRows(), c0 = Limits.getCpuTime();
    for (Case c : cs) { c.OwnerId = eng.Id; }
    update cs;   // ONE update of N cases -> trigger -> scheduling service

    Integer segs = [SELECT COUNT() FROM Work_Segment__c WHERE Case__c IN :cs];
    System.debug('BULK N=' + N
        + ' | SOQL ' + (Limits.getQueries() - q0) + ' (limit ' + Limits.getLimitQueries() + ')'
        + ' | DML statements ' + (Limits.getDmlStatements() - d0)
        + ' | DML rows ' + (Limits.getDmlRows() - r0)
        + ' | CPU ms ' + (Limits.getCpuTime() - c0)
        + ' | segments created ' + segs);
} catch (Exception e) {
    System.debug('BULK ERROR: ' + e.getMessage());
} finally {
    Database.rollback(sp);   // leave the org exactly as it was
}