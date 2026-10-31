// WBS 11-01 / OTH-01 – seed 2 of 4: 8 products (reused if they exist), standard price book entries,
// 120 equipment units with serial numbers SN-5001.., 30 coverage plans (current, expiring, expired, draft) with links.
// Run after seed-1. Limits: about 8 queries, 6 DML statements.

List<Account> accounts = [SELECT Id, Name FROM Account WHERE Site = 'SEED-11-01' ORDER BY Name];
if (accounts.isEmpty()) {
    System.debug('SEED >>> run seed-1 first');
} else if ([SELECT COUNT() FROM Equipment__c WHERE Serial_Number__c LIKE 'SN-5%' AND Account__c IN :accounts] > 0) {
    System.debug('SEED >>> equipment already seeded');
} else {
    // ---- Products (reuse by name) ----
    List<String> productNames = new List<String>{
        'Air-Cooled Chiller 200 kW', 'Water-Cooled Chiller 500 kW', 'Extreme Chiller', 'Screw Compressor 75 kW',
        'Ac Compressor', 'Refrigerated Air Dryer 500 m3/h', 'Desiccant Air Dryer 300 m3/h', 'Hyper Gas Cooler'
    };
    List<Decimal> prices = new List<Decimal>{ 48000, 96000, 125000, 38000, 9500, 14500, 21000, 33000 };
    Map<String, Product2> byName = new Map<String, Product2>();
    for (Product2 p : [SELECT Id, Name, IsActive FROM Product2 WHERE Name IN :productNames]) {
        byName.put(p.Name, p);
    }
    List<Product2> newProducts = new List<Product2>();
    for (Integer i = 0; i < productNames.size(); i++) {
        if (!byName.containsKey(productNames[i])) {
            Product2 p = new Product2(Name = productNames[i], IsActive = true,
                ProductCode = 'HES-P' + String.valueOf(i + 1).leftPad(2, '0'),
                Description = 'SEED-11-01 Helios equipment product');
            newProducts.add(p);
            byName.put(p.Name, p);
        }
    }
    insert newProducts;

    Pricebook2 std = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
    if (!std.IsActive) { std.IsActive = true; update std; }
    Set<Id> priced = new Set<Id>();
    for (PricebookEntry pbe : [SELECT Product2Id FROM PricebookEntry WHERE Pricebook2Id = :std.Id]) {
        priced.add(pbe.Product2Id);
    }
    List<PricebookEntry> entries = new List<PricebookEntry>();
    for (Integer i = 0; i < productNames.size(); i++) {
        Product2 p = byName.get(productNames[i]);
        if (!priced.contains(p.Id)) {
            entries.add(new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p.Id, UnitPrice = prices[i], IsActive = true));
        }
    }
    insert entries;

    // ---- Equipment: 120 units ----
    List<Equipment__c> units = new List<Equipment__c>();
    for (Integer i = 0; i < 120; i++) {
        Account a = accounts[Math.mod(i, accounts.size())];
        String productName = productNames[Math.mod(i * 3, productNames.size())];
        String serial = 'SN-' + (5001 + i);
        Integer ageDays = 90 + Math.mod(i * 37, 1500);
        units.add(new Equipment__c(
            Name = productName + ' ' + serial,
            Serial_Number__c = serial,
            Account__c = a.Id,
            Product__c = byName.get(productName).Id,
            Install_Date__c = Date.today().addDays(-ageDays),
            Last_Service_Date__c = Math.mod(i, 3) == 0 ? null : Date.today().addDays(-Math.mod(i * 11, 300))
        ));
    }
    insert units;

    // ---- Coverage plans: 30 ----
    // 0-17 current (Covered), 18-22 ending within 45 days (Covered, renewal due), 23-26 ended (Expired), 27-29 Draft.
    List<Coverage_Plan__c> plans = new List<Coverage_Plan__c>();
    for (Integer p = 0; p < 30; p++) {
        Account a = accounts[Math.mod(p, accounts.size())];
        Date startDate; Date endDate; String status;
        if (p < 18)      { startDate = Date.today().addDays(-200 - p * 5); endDate = Date.today().addDays(165 + p * 10); status = 'Active'; }
        else if (p < 23) { startDate = Date.today().addDays(-340);         endDate = Date.today().addDays(10 + (p - 18) * 8); status = 'Active'; }
        else if (p < 27) { startDate = Date.today().addDays(-500);         endDate = Date.today().addDays(-30 - (p - 23) * 20); status = 'Expired'; }
        else             { startDate = Date.today().addDays(30);           endDate = Date.today().addDays(395); status = 'Draft'; }
        plans.add(new Coverage_Plan__c(Account__c = a.Id, Start_Date__c = startDate, End_Date__c = endDate, Status__c = status));
    }
    insert plans;

    // ---- Links: up to 3 not-yet-linked units of the plan's account; set Current Coverage Plan (not for Draft) ----
    Map<Id, List<Equipment__c>> unitsByAccount = new Map<Id, List<Equipment__c>>();
    for (Equipment__c e : units) {
        if (!unitsByAccount.containsKey(e.Account__c)) unitsByAccount.put(e.Account__c, new List<Equipment__c>());
        unitsByAccount.get(e.Account__c).add(e);
    }
    List<Equipment_Coverage__c> links = new List<Equipment_Coverage__c>();
    Map<Id, Equipment__c> unitUpdates = new Map<Id, Equipment__c>();
    for (Coverage_Plan__c plan : plans) {
        Integer taken = 0;
        for (Equipment__c e : unitsByAccount.get(plan.Account__c)) {
            if (taken == 3) break;
            if (unitUpdates.containsKey(e.Id)) continue;
            links.add(new Equipment_Coverage__c(Equipment__c = e.Id, Coverage_Plan__c = plan.Id));
            unitUpdates.put(e.Id, new Equipment__c(Id = e.Id, Current_Coverage_Plan__c = plan.Status__c == 'Draft' ? null : plan.Id));
            taken++;
        }
    }
    insert links;
    update unitUpdates.values();

    System.debug('SEED >>> new products ' + newProducts.size() + ', price entries ' + entries.size()
        + ', equipment ' + units.size() + ', plans ' + plans.size() + ', links ' + links.size());
}
