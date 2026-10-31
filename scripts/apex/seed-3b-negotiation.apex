// WBS 11-01 / OTH-01 – seed 3b: the 6 Negotiation/Review opportunities.
// SAL-03 (by design not bypassable) requires at least one equipment line before Negotiation, so these deals are
// created at Proposal/Price Quote, given 1-2 product lines, and then moved to Negotiation/Review – like a real rep would.
// Limits: 4 queries, 3 DML statements.

List<Account> accounts = [SELECT Id, Name FROM Account WHERE Site = 'SEED-11-01' ORDER BY Name];
if ([SELECT COUNT() FROM Opportunity WHERE AccountId IN :accounts AND StageName = 'Negotiation/Review'] > 0) {
    System.debug('SEED >>> negotiation deals already seeded');
} else {
    Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
    List<PricebookEntry> entries = [SELECT Id, UnitPrice, Product2.Name FROM PricebookEntry
                                    WHERE Pricebook2Id = :std.Id AND IsActive = true AND Product2.IsActive = true
                                    ORDER BY Product2.Name LIMIT 8];
    List<Decimal> discounts = new List<Decimal>{ 0, 5, 8, 10, 12, 18 };

    List<Opportunity> opps = new List<Opportunity>();
    for (Integer n = 0; n < 6; n++) {
        Account a = accounts[Math.mod(n * 4 + 1, accounts.size())];
        Datetime created = Datetime.now().addDays(-(20 + n * 25));      // two of them older than 90 days -> At Risk
        Opportunity o = new Opportunity(
            Name = a.Name + ' - Negotiated equipment deal',
            AccountId = a.Id,
            Pricebook2Id = std.Id,
            StageName = 'Proposal/Price Quote',
            CloseDate = Date.today().addDays(14 + n * 9),
            Discount__c = discounts[n],
            CreatedDate = created,
            Description = 'SEED-11-01'
        );
        if (discounts[n] > 15) {
            o.Approval_Submitted_At__c = created.addDays(4);
            o.Approval_Decided_At__c = created.addDays(4).addHours(6);
        }
        opps.add(o);
    }
    insert opps;

    List<OpportunityLineItem> lines = new List<OpportunityLineItem>();
    for (Integer n = 0; n < opps.size(); n++) {
        PricebookEntry pbe = entries[Math.mod(n, entries.size())];
        lines.add(new OpportunityLineItem(OpportunityId = opps[n].Id, PricebookEntryId = pbe.Id,
            Quantity = 1 + Math.mod(n, 2), UnitPrice = pbe.UnitPrice));
    }
    insert lines;

    for (Opportunity o : opps) {
        o.StageName = 'Negotiation/Review';
    }
    update opps;
    System.debug('SEED >>> negotiation deals ' + opps.size() + ' with ' + lines.size() + ' lines');
}
