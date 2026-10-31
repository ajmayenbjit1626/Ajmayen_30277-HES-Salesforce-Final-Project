// ACC-02-R1 one-off: copy Account.Region__c onto existing cases. 1 query, 1 update.
List<Case> cases = [SELECT Id, Account.Region__c FROM Case WHERE Region__c = null AND Account.Region__c != null LIMIT 5000];
for (Case c : cases) { c.Region__c = c.Account.Region__c; }
Database.SaveResult[] res = Database.update(cases, false);
Integer ok = 0;
for (Database.SaveResult r : res) { if (r.isSuccess()) ok++; }
System.debug('REGION >>> updated ' + ok + ' of ' + cases.size());