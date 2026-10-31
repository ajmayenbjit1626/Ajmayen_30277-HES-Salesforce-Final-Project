// WBS 11-01 / OTH-01 – seed 4 of 4: 250 cases over the last 12 months.
// Technical (Breakdown / Maintenance / Installation, with equipment and effort) and Billing; all regions;
// Email / Web / Phone / Agentforce; 40 % closed. Open technical cases go to the regional queue, about 20 to the
// scheduled engineers (the scheduling engine plans them), 10 cases without account go to Service Triage.
// Case.Region__c is filled by the Case before-save flow from the account.
// Needs HES Data Loader (validation bypass + CreatedDate). Limits: about 8 queries, 2 inserts.

List<Account> accounts = [SELECT Id, Name, Region__c, (SELECT Id FROM Contacts ORDER BY CreatedDate)
                          FROM Account WHERE Site = 'SEED-11-01' ORDER BY Name];
Map<Id, List<Equipment__c>> unitsByAccount = new Map<Id, List<Equipment__c>>();
for (Equipment__c e : [SELECT Id, Name, Account__c FROM Equipment__c WHERE Account__c IN :accounts ORDER BY Serial_Number__c]) {
    if (!unitsByAccount.containsKey(e.Account__c)) unitsByAccount.put(e.Account__c, new List<Equipment__c>());
    unitsByAccount.get(e.Account__c).add(e);
}
if (accounts.isEmpty()) {
    System.debug('SEED >>> run seed-1 and seed-2 first');
} else if ([SELECT COUNT() FROM Case WHERE AccountId IN :accounts] > 0) {
    System.debug('SEED >>> cases already seeded');
} else {
    Id rtTech = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Technical').getRecordTypeId();
    Id rtBill = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Billing').getRecordTypeId();

    Map<String, Id> queueByName = new Map<String, Id>();
    for (Group q : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue'
                    AND DeveloperName IN ('Benelux_Technical', 'Nordics_Technical', 'DACH_Technical', 'UK_Ireland_Technical', 'Service_Triage', 'Billing')]) {
        queueByName.put(q.DeveloperName, q.Id);
    }
    Map<String, Id> queueByRegion = new Map<String, Id>{
        'Benelux' => queueByName.get('Benelux_Technical'),
        'Nordics' => queueByName.get('Nordics_Technical'),
        'DACH' => queueByName.get('DACH_Technical'),
        'UK & Ireland' => queueByName.get('UK_Ireland_Technical')
    };
    List<User> engineers = [SELECT Id FROM User WHERE IsActive = true AND Is_Scheduled__c = true AND Default_Working_Hours__c != null];

    List<String> types = new List<String>{ 'Breakdown', 'Maintenance', 'Installation' };
    List<String> origins = new List<String>{ 'Email', 'Web', 'Phone', 'Email', 'Web', 'Agentforce' };
    List<String> openStatuses = new List<String>{ 'New', 'Working', 'New', 'Escalated' };
    List<String> priorities = new List<String>{ 'Medium', 'High', 'Low', 'Medium' };
    List<Decimal> efforts = new List<Decimal>{ 2, 4, 6, 8, 11, 16, 20, 24, 32, 40 };
    Map<String, List<String>> subjects = new Map<String, List<String>>{
        'Breakdown' => new List<String>{ 'stops on high-pressure alarm', 'not cooling', 'trips after a few minutes', 'making a clicking noise', 'dew point too high' },
        'Maintenance' => new List<String>{ 'annual service due', 'filter replacement', 'oil change', 'seasonal shutdown', 'controller check' },
        'Installation' => new List<String>{ 'installation of new unit', 'site survey for installation', 'commissioning after delivery' }
    };
    List<String> billingSubjects = new List<String>{ 'Question about invoice', 'Invoice amount differs from quote', 'Request copy of invoice', 'Payment terms query' };

    List<Case> cases = new List<Case>();
    Integer engineerCases = 0;
    for (Integer i = 0; i < 250; i++) {
        Boolean noAccount = i >= 240;                       // 10 triage cases from unknown senders
        Account a = noAccount ? null : accounts[Math.mod(i, accounts.size())];
        Boolean billing = !noAccount && Math.mod(i, 6) == 0;
        Boolean closed = !noAccount && Math.mod(i, 10) < 4;
        Datetime created = Datetime.now().addDays(-(closed ? 20 + Math.mod(i * 13, 340) : Math.mod(i * 7, 60)));

        Case c = new Case(
            Origin = origins[Math.mod(i, origins.size())],
            Priority = priorities[Math.mod(i, priorities.size())],
            Status = closed ? 'Closed' : openStatuses[Math.mod(i, openStatuses.size())],
            CreatedDate = created,
            Description = 'SEED-11-01 sample case'
        );
        if (noAccount) {
            c.RecordTypeId = rtTech;
            c.Subject = 'Enquiry from unknown sender ' + (i - 239);
            c.SuppliedEmail = 'unknown' + i + '@example.com';
            c.SuppliedCompany = 'SEED-11-01';
            c.Status = 'New';
            c.OwnerId = queueByName.get('Service_Triage');
        } else if (billing) {
            c.RecordTypeId = rtBill;
            c.AccountId = a.Id;
            c.ContactId = a.Contacts.isEmpty() ? null : a.Contacts[0].Id;
            c.Subject = billingSubjects[Math.mod(i, billingSubjects.size())];
            c.OwnerId = queueByName.get('Billing');
        } else {
            String caseType = types[Math.mod(i, types.size())];
            List<String> options = subjects.get(caseType);
            List<Equipment__c> accUnits = unitsByAccount.containsKey(a.Id) ? unitsByAccount.get(a.Id) : new List<Equipment__c>();
            Equipment__c unit = accUnits.isEmpty() ? null : accUnits[Math.mod(i, accUnits.size())];
            c.RecordTypeId = rtTech;
            c.AccountId = a.Id;
            c.ContactId = a.Contacts.isEmpty() ? null : a.Contacts[Math.mod(i, a.Contacts.size())].Id;
            c.Type = caseType;
            c.Equipment__c = unit == null ? null : unit.Id;
            c.Subject = (unit == null ? 'Equipment' : unit.Name) + ' – ' + options[Math.mod(i, options.size())];
            c.Estimated_Effort__c = efforts[Math.mod(i * 3, efforts.size())];
            Boolean toEngineer = !engineers.isEmpty() && (closed || (Math.mod(i, 5) == 1 && engineerCases < 20));
            if (toEngineer) {
                c.OwnerId = engineers[Math.mod(i, engineers.size())].Id;
                if (!closed) engineerCases++;
            } else {
                c.OwnerId = queueByRegion.get(a.Region__c);
            }
        }
        cases.add(c);
    }

    Database.SaveResult[] res = Database.insert(cases, false);
    Integer ok = 0; List<String> errors = new List<String>(); List<Case> inserted = new List<Case>();
    for (Integer i = 0; i < res.size(); i++) {
        if (res[i].isSuccess()) { ok++; inserted.add(cases[i]); }
        else if (errors.size() < 5) errors.add(cases[i].Subject + ': ' + res[i].getErrors()[0].getMessage());
    }

    // Required skills on every third open technical case (SVC-04 data for the Required Skills list).
    List<Skill__c> skills = [SELECT Id FROM Skill__c ORDER BY Name LIMIT 10];
    List<Case_Skill__c> caseSkills = new List<Case_Skill__c>();
    if (!skills.isEmpty()) {
        for (Integer i = 0; i < inserted.size(); i++) {
            Case c = inserted[i];
            if (c.RecordTypeId == rtTech && c.Status != 'Closed' && c.Equipment__c != null && Math.mod(i, 3) == 0) {
                caseSkills.add(new Case_Skill__c(Case__c = c.Id, Skill__c = skills[Math.mod(i, skills.size())].Id));
            }
        }
        Database.insert(caseSkills, false);
    }
    System.debug('SEED >>> cases ' + ok + ' of ' + cases.size() + ', engineer-owned open ' + engineerCases
        + ', case skills ' + caseSkills.size() + (errors.isEmpty() ? '' : ' | errors: ' + String.join(errors, ' || ')));
}
