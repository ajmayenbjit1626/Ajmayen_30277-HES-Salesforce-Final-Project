// WBS 11-01 / OTH-01 – seed 3 of 4: 40 opportunities in every stage, with discounts, realistic created dates
// (some older than 90 days so Deal Health shows At Risk) and approval timestamps for the large discounts.
// Needs "Set Audit Fields upon Record Creation" (HES Data Loader) to write CreatedDate.
// Limits: 3 queries, 1 insert.

List<Account> accounts = [SELECT Id, Name FROM Account WHERE Site = 'SEED-11-01' ORDER BY Name];
if (accounts.isEmpty()) {
    System.debug('SEED >>> run seed-1 first');
} else if ([SELECT COUNT() FROM Opportunity WHERE AccountId IN :accounts] > 0) {
    System.debug('SEED >>> opportunities already seeded');
} else {
    // Owners: the sales reps (by persona permission set, no names in code) plus the running user (Sales Manager).
    List<Id> owners = new List<Id>{ UserInfo.getUserId() };
    for (PermissionSetAssignment psa : [SELECT AssigneeId FROM PermissionSetAssignment
                                        WHERE PermissionSet.Name = 'HES_Sales_Representative' AND Assignee.IsActive = true]) {
        owners.add(psa.AssigneeId);
    }
    List<String> stages = new List<String>{
        'Qualification', 'Needs Analysis', 'Proposal/Price Quote', 'Negotiation/Review', 'Closed Won', 'Closed Lost'
    };
    List<Integer> stageCounts = new List<Integer>{ 8, 7, 7, 6, 8, 4 };   // = 40
    List<Decimal> discounts = new List<Decimal>{ 0, 0, 3, 5, 8, 10, 12, 15, 18, 20 };
    List<String> deals = new List<String>{ 'Chiller replacement', 'Compressor upgrade', 'Air dryer retrofit', 'Cold room expansion', 'Plant room renewal' };

    List<Opportunity> opps = new List<Opportunity>();
    Integer n = 0;
    for (Integer s = 0; s < stages.size(); s++) {
        for (Integer k = 0; k < stageCounts[s]; k++) {
            Account a = accounts[Math.mod(n * 3, accounts.size())];
            Boolean closed = stages[s].startsWith('Closed');
            Integer createdAgo = closed ? 60 + Math.mod(n * 29, 300) : 5 + Math.mod(n * 23, 200);   // open: up to 200 days -> some At Risk
            Datetime created = Datetime.now().addDays(-createdAgo);
            Decimal discount = discounts[Math.mod(n * 7, discounts.size())];
            Opportunity o = new Opportunity(
                Name = a.Name + ' – ' + deals[Math.mod(n, deals.size())],
                AccountId = a.Id,
                OwnerId = owners[Math.mod(n, owners.size())],
                StageName = stages[s],
                Amount = 15000 + Math.mod(n * 9973, 235000),
                Discount__c = discount,
                CloseDate = closed ? created.date().addDays(30 + Math.mod(n * 13, 60)) : Date.today().addDays(10 + Math.mod(n * 17, 110)),
                CreatedDate = created,
                Description = 'SEED-11-01'
            );
            if (discount > 15) {   // historic approval (SAL-05 / AN-04 report data)
                Datetime submitted = created.addDays(3);
                o.Approval_Submitted_At__c = submitted;
                o.Approval_Decided_At__c = submitted.addHours(2 + Math.mod(n * 5, 40));
            }
            opps.add(o);
            n++;
        }
    }
    Database.SaveResult[] res = Database.insert(opps, false);
    Integer ok = 0; List<String> errors = new List<String>();
    for (Integer i = 0; i < res.size(); i++) {
        if (res[i].isSuccess()) ok++;
        else if (errors.size() < 5) errors.add(opps[i].Name + ': ' + res[i].getErrors()[0].getMessage());
    }
    System.debug('SEED >>> opportunities ' + ok + ' of ' + opps.size() + (errors.isEmpty() ? '' : ' | errors: ' + String.join(errors, ' || ')));
}
