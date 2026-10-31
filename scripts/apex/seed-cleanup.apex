// WBS 11-01 – removes ALL seed data (records marked SEED-11-01), for example before a reseed.
// Order: cases, opportunities, coverage links, equipment, plans, contacts, accounts. Products are kept.
List<Account> accounts = [SELECT Id FROM Account WHERE Site = 'SEED-11-01'];
delete [SELECT Id FROM Case WHERE AccountId IN :accounts OR (SuppliedCompany = 'SEED-11-01' AND AccountId = null)];
delete [SELECT Id FROM Opportunity WHERE AccountId IN :accounts];
delete [SELECT Id FROM Equipment_Coverage__c WHERE Equipment__r.Account__c IN :accounts];
delete [SELECT Id FROM Equipment__c WHERE Account__c IN :accounts];
delete [SELECT Id FROM Coverage_Plan__c WHERE Account__c IN :accounts];
delete [SELECT Id FROM Contact WHERE AccountId IN :accounts];
delete accounts;
System.debug('CLEANUP >>> seed data removed');
