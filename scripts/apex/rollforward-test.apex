// 7-07 test (CAP-06): make one segment of an open case 'stale' (yesterday), then run the nightly action.
Case c = [SELECT Id, CaseNumber, Estimated_Effort__c FROM Case
          WHERE Subject LIKE 'CAP Test 3%' AND IsClosed = false LIMIT 1];
Work_Segment__c s = [SELECT Id, Planned_Date__c FROM Work_Segment__c
                     WHERE Case__c = :c.Id ORDER BY Planned_Date__c LIMIT 1];
s.Planned_Date__c = Date.today().addDays(-1);   // pretend this work was planned yesterday and not done
update s;
System.debug('ROLL before: case ' + c.CaseNumber + ' stale segment dated ' + s.Planned_Date__c);

NightlyRollForwardAction.run();                  // exactly what the scheduled flow calls

Case after = [SELECT Needs_Replanning__c, Planned_Hours__c, Schedule_Status__c, Planned_Start__c, Planned_Finish__c
              FROM Case WHERE Id = :c.Id];
Integer stale = [SELECT COUNT() FROM Work_Segment__c WHERE Case__c = :c.Id AND Planned_Date__c < TODAY];
System.debug('ROLL after: stale left ' + stale
    + ' | Needs Replanning ' + after.Needs_Replanning__c
    + ' | Planned Hours ' + after.Planned_Hours__c + ' of ' + c.Estimated_Effort__c
    + ' | ' + after.Schedule_Status__c + ' ' + after.Planned_Start__c + ' -> ' + after.Planned_Finish__c);