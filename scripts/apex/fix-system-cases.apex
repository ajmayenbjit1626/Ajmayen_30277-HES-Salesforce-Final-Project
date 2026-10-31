// 11-01 fix: re-assign cases the seed gave to the "System" user to the real scheduled engineers.
User sysUser = [SELECT Id FROM User WHERE Name = 'System' LIMIT 1];
List<User> engineers = [SELECT Id FROM User WHERE IsActive = true AND Is_Scheduled__c = true
                        AND Default_Working_Hours__c != null AND Id != :sysUser.Id];
List<Case> cases = [SELECT Id FROM Case WHERE OwnerId = :sysUser.Id];
for (Integer i = 0; i < cases.size(); i++) {
    cases[i].OwnerId = engineers[Math.mod(i, engineers.size())].Id;
}
update cases;
System.debug('FIX >>> moved ' + cases.size() + ' cases to ' + engineers.size() + ' engineers');