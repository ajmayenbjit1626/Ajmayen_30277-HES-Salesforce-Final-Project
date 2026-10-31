// WBS 11-01 / OTH-01 – seed 1 of 4: 25 accounts across the 4 regions and 60 contacts.
// Marker: every seed account has Site = 'SEED-11-01' (a filterable field) (used by the count and clean-up scripts).
// Run as admin with HES Data Loader assigned and Deliverability = System email only.
// Limits: 2 queries, 2 inserts.

if ([SELECT COUNT() FROM Account WHERE Site = 'SEED-11-01'] > 0) {
    System.debug('SEED >>> accounts already seeded – run seed-cleanup.apex first if you want to reseed');
} else {
    List<String> names = new List<String>{
        // Benelux (8)
        'Rotterdam Cold Storage BV', 'Antwerp Food Logistics NV', 'Utrecht Data Centre BV', 'Ghent Brewery Group NV',
        'Eindhoven Precision Parts BV', 'Luxembourg Pharma SA', 'Delft Dairy Cooperative', 'Liège Plastics SA',
        // Nordics (6)
        'Gothenburg Marine Services AB', 'Oslo Seafood Processing AS', 'Aarhus Bakeries A/S', 'Helsinki Paper Mill Oy',
        'Malmö Hospital Facilities AB', 'Bergen Cold Chain AS',
        // DACH (6)
        'Hamburg Port Refrigeration GmbH', 'Munich Auto Components GmbH', 'Zurich Chocolate Works AG', 'Vienna Hotel Group GmbH',
        'Stuttgart Machine Tools GmbH', 'Basel Life Sciences AG',
        // UK & Ireland (5)
        'Manchester Print Works Ltd', 'Dublin Beverage Company Ltd', 'Leeds Frozen Foods Ltd', 'Bristol Aerospace Parts Ltd',
        'Cork Medical Devices Ltd'
    };
    List<String> regions = new List<String>();
    for (Integer i = 0; i < 8; i++) regions.add('Benelux');
    for (Integer i = 0; i < 6; i++) regions.add('Nordics');
    for (Integer i = 0; i < 6; i++) regions.add('DACH');
    for (Integer i = 0; i < 5; i++) regions.add('UK & Ireland');

    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < names.size(); i++) {
        accounts.add(new Account(
            Name = names[i],
            Region__c = regions[i],
            Site = 'SEED-11-01',
            Description = 'SEED-11-01 demo customer (Appendix B sample data)'
        ));
    }
    Database.DMLOptions dml = new Database.DMLOptions();
    dml.duplicateRuleHeader.allowSave = true;
    Database.insert(accounts, dml);

    List<String> firstNames = new List<String>{ 'Anna', 'Lars', 'Sofie', 'Pieter', 'Emma', 'Jonas', 'Mia', 'Thomas', 'Eva', 'Oliver', 'Lena', 'Ruben' };
    List<String> lastNames = new List<String>{ 'de Vries', 'Johansson', 'Müller', 'Murphy', 'Jansen', 'Nielsen', 'Schmidt', 'Walsh', 'Peeters', 'Larsen', 'Huber', 'Byrne' };
    List<String> titles = new List<String>{ 'Facility Manager', 'Maintenance Lead', 'Operations Director', 'Purchasing Manager' };
    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < 60; i++) {
        Account a = accounts[Math.mod(i, 25)];
        String fn = firstNames[Math.mod(i, firstNames.size())];
        String ln = lastNames[Math.mod(i * 7, lastNames.size())];
        contacts.add(new Contact(
            AccountId = a.Id,
            FirstName = fn,
            LastName = ln,
            Title = titles[Math.mod(i, titles.size())],
            Email = fn.toLowerCase() + '.' + ln.toLowerCase().replace(' ', '').replace('ü', 'u') + i + '@example.com',
            Description = 'SEED-11-01'
        ));
    }
    Database.insert(contacts, dml);
    System.debug('SEED >>> accounts ' + accounts.size() + ', contacts ' + contacts.size());
}
