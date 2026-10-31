// 11-01 fix: only real engineers keep working hours. Users only (no cases here: mixed DML rule).
List<User> fix = [SELECT Id, Name FROM User
                  WHERE Default_Working_Hours__c != null
                  AND (UserType != 'Standard' OR Is_Scheduled__c = false)];
for (User u : fix) { u.Default_Working_Hours__c = null; u.Is_Scheduled__c = false; }
Database.SaveResult[] res = Database.update(fix, false);
for (Integer i = 0; i < res.size(); i++) {
    System.debug('FIX >>> ' + fix[i].Name + ': ' + (res[i].isSuccess() ? 'cleared' : res[i].getErrors()[0].getMessage()));
}