// WBS 11-01 – counts of the seed data (Appendix B targets: 25 / 60 / 8 / 120 / 30 / 40 / 250 / 10).
List<Account> accounts = [SELECT Id FROM Account WHERE Site = 'SEED-11-01'];
System.debug('COUNT >>> accounts ' + accounts.size()
    + ' | contacts ' + [SELECT COUNT() FROM Contact WHERE AccountId IN :accounts]
    + ' | products ' + [SELECT COUNT() FROM Product2 WHERE IsActive = true]
    + ' | equipment ' + [SELECT COUNT() FROM Equipment__c WHERE Account__c IN :accounts]
    + ' | plans ' + [SELECT COUNT() FROM Coverage_Plan__c WHERE Account__c IN :accounts]
    + ' | opportunities ' + [SELECT COUNT() FROM Opportunity WHERE AccountId IN :accounts]
    + ' | cases ' + ([SELECT COUNT() FROM Case WHERE AccountId IN :accounts] + [SELECT COUNT() FROM Case WHERE SuppliedCompany = 'SEED-11-01' AND AccountId = null])
    + ' | articles ' + [SELECT COUNT() FROM Knowledge__kav WHERE PublishStatus = 'Online' AND Language = 'en_US']);
for (AggregateResult r : [SELECT Region__c region, COUNT(Id) n FROM Case WHERE AccountId IN :accounts GROUP BY Region__c]) {
    System.debug('COUNT >>> cases in ' + r.get('region') + ': ' + r.get('n'));
}
Map<String, Integer> byPosition = new Map<String, Integer>();
for (Equipment__c e : [SELECT Coverage_Position__c FROM Equipment__c WHERE Account__c IN :accounts]) {
    String pos = e.Coverage_Position__c == null ? 'blank' : e.Coverage_Position__c;
    byPosition.put(pos, (byPosition.containsKey(pos) ? byPosition.get(pos) : 0) + 1);
}
for (String pos : byPosition.keySet()) {
    System.debug('COUNT >>> equipment ' + pos + ': ' + byPosition.get(pos));
}
